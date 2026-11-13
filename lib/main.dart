import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'speech/alarm_volume.dart';
import 'speech/recording_store.dart';
import 'speech/speaker.dart';
import 'storage/backup.dart';
import 'storage/database.dart';
import 'storage/lists_repository.dart';
import 'ui/speaking_screen.dart';
import 'ui/voice_picker.dart';
import 'voices/catalog.dart';
import 'voices/elevenlabs_access.dart';
import 'voices/elevenlabs_cache.dart';
import 'voices/elevenlabs_client.dart';
import 'voices/elevenlabs_engine.dart';
import 'voices/elevenlabs_key_store.dart';
import 'voices/language_names.dart';
import 'voices/piper_engine.dart';
import 'voices/system_engine.dart';
import 'voices/voice.dart';
import 'voices/voice_engine.dart';
import 'voices/voice_installer.dart';

void main() => runApp(const MondomApp());

class MondomApp extends StatelessWidget {
  const MondomApp({super.key, this.home = const HomeScreen()});

  /// Overridable for tests.
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Hungarian phones get Hungarian; everything else falls back to English.
      localeResolutionCallback: (locale, supported) =>
          locale?.languageCode == 'hu'
          ? const Locale('hu')
          : const Locale('en'),
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: home,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _prefKey = 'voiceId';
  static const _nameKey = 'voiceName';

  final _alarmVolume = AlarmVolume();
  final _recordings = RecordingStore();
  late final Speaker _speaker;
  AppDatabase? _db;
  ListsRepository? _repo;

  final _installer = VoiceInstaller();
  Catalog _catalog = Catalog.empty;

  Voice _voice = Voice.system('hu');

  @override
  void initState() {
    super.initState();
    _speaker = Speaker(
      engineFactory: _createEngine,
      alarmVolume: _alarmVolume,
      recordings: _recordings,
    )..addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    // The app may have been killed during an alarm with the volume raised.
    await _alarmVolume.restore();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final db = AppDatabase.open();
    final repo = ListsRepository(db);
    setState(() {
      _db = db;
      _repo = repo;
    });
    unawaited(_sweepRecordings(repo));
    await _installer.cleanupStaging();
    final info = await PackageInfo.fromPlatform();
    _catalog = await CatalogRepository(appVersion: info.version).load();
    if (!mounted) return;
    final uiLang = Localizations.localeOf(context).languageCode;
    final savedId = prefs.getString(_prefKey);
    final saved = _catalog.byId(savedId ?? '');
    if (saved != null && await _installer.isInstalled(saved.id)) {
      _voice = saved.toVoice();
    } else if (savedId != null && savedId.startsWith('elevenlabs:')) {
      final parts = savedId.split(':');
      _voice = Voice.elevenLabs(
        parts[1],
        parts.skip(2).join(':'),
        prefs.getString(_nameKey) ?? '',
      );
    } else if (savedId != null && savedId.startsWith('system-')) {
      _voice = Voice.system(savedId.substring('system-'.length));
    } else {
      _voice = Voice.system(uiLang);
    }
    await _speaker.setVoice(_voice);
    // History title follows the speech language (also fixes older installs).
    if (savedId != null && await repo.isSeeded()) {
      await repo.syncHistoryTitle(_voice.languageCode);
    }
    if (savedId == null) {
      // First launch: no voice chosen yet.
      if (mounted) await _openPicker(firstRun: true);
      // Left the picker without choosing: the system voice is in use, so the
      // app still gets its lists, in the UI language.
      if (!await repo.isSeeded()) await repo.addSeedLists(uiLang);
    } else if (!await repo.isSeeded()) {
      // Safety net for a seed that never happened (e.g. killed mid-start).
      await repo.addSeedLists(_voice.languageCode);
    }
  }

  /// Removes recording files no row references (guards in [RecordingStore]).
  Future<void> _sweepRecordings(ListsRepository repo) async {
    try {
      await _recordings.sweep(await repo.referencedRecordings());
    } catch (_) {}
  }

  Future<void> _openPicker({bool firstRun = false}) async {
    final support = await getApplicationSupportDirectory();
    if (!mounted) return;
    final access = ElevenLabsAccess(
      keyStore: SecureElevenLabsKeyStore(),
      cache: ElevenLabsCache(Directory('${support.path}/elevenlabs_cache')),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VoicePickerScreen(
          catalog: _catalog,
          installer: _installer,
          // First run: nothing is selected yet, so every row, including the
          // system voice, has a button that picks it and closes the picker.
          selectedId: firstRun ? '' : _voice.id,
          firstRun: firstRun,
          onSelect: _selectVoice,
          elevenLabs: access,
          selectedLabel: _voice.label,
        ),
      ),
    );
  }

  Future<VoiceEngine> _createEngine(Voice v) async => switch (v.kind) {
    VoiceKind.system => SystemEngine(v),
    VoiceKind.piper => PiperEngine(
      voiceDir: await _installer.voiceDir(v.id),
      espeakDataDir: await _installer.espeakDataDir(),
      modelFile: _catalog.byId(v.id)!.modelFile,
    ),
    VoiceKind.elevenlabs => await _createElevenLabsEngine(v),
  };

  /// The fallback is the voice in `elevenLabsFallbackVoiceId` if it is still
  /// installed, otherwise the system voice of the voice's language.
  Future<VoiceEngine> _createElevenLabsEngine(Voice v) async {
    final prefs = await SharedPreferences.getInstance();
    final fallbackId = prefs.getString(elevenLabsFallbackKey);
    final entry = _catalog.byId(fallbackId ?? '');
    final fallbackVoice =
        entry != null && await _installer.isInstalled(entry.id)
        ? entry.toVoice()
        : Voice.system(v.languageCode);
    final key = await SecureElevenLabsKeyStore().read();
    final support = await getApplicationSupportDirectory();
    return ElevenLabsEngine(
      voice: v,
      client: key == null ? null : ElevenLabsClient(http.Client(), key),
      fallback: await _createEngine(fallbackVoice),
      fallbackVoice: fallbackVoice,
      cache: ElevenLabsCache(Directory('${support.path}/elevenlabs_cache')),
      modelId: () async =>
          (await SharedPreferences.getInstance()).getBool(
                elevenLabsExpressiveKey,
              ) ??
              false
          ? elevenLabsExpressiveModel
          : elevenLabsFlashModel,
    );
  }

  Future<void> _selectVoice(Voice v) async {
    final languageChanged = v.languageCode != _voice.languageCode;
    _voice = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, v.id);
    if (v.kind == VoiceKind.elevenlabs) {
      await prefs.setString(_nameKey, v.label);
    }
    await _speaker.setVoice(v);
    // After the switch, so a question doesn't delay the new voice.
    await _repo?.offerSeedLists(
      v.languageCode,
      ask: _askAddSeedLists(v),
      languageChanged: languageChanged,
    );
  }

  Future<bool> Function() _askAddSeedLists(Voice v) => () async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final ui = Localizations.localeOf(context).languageCode;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          l10n.addSeedListsQuestion(
            languageName(v.languageCode, ui, midSentence: true),
          ),
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.noAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.addAction),
          ),
        ],
      ),
    );
    return yes ?? false;
  };

  @override
  void dispose() {
    _db?.close();
    _speaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return SpeakingScreen(
      speaker: _speaker,
      repo: repo,
      voice: () => _voice,
      onOpenVoicePicker: _openPicker,
      backup: BackupService(repo: repo, recordings: _recordings),
    );
  }
}
