import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../voices/catalog.dart';
import '../voices/elevenlabs_access.dart';
import '../voices/elevenlabs_client.dart';
import '../voices/language_names.dart';
import '../voices/system_tts_info.dart';
import '../voices/voice.dart';
import '../voices/voice_installer.dart';
import 'elevenlabs_screen.dart';

/// Plays voice previews. Replaceable in tests.
abstract class VoicePreviewer {
  /// Streams the sample at [url]. Returns false when it can't be played.
  Future<bool> playSample(String url);

  /// Plays a WAV. Returns false when it can't be played.
  Future<bool> playBytes(Uint8List wav);

  /// Speaks [text] with the system voice.
  Future<void> speakSystem(String text, String language);

  Future<void> stop();
  void dispose();
}

class DefaultVoicePreviewer implements VoicePreviewer {
  final _player = AudioPlayer();
  FlutterTts? _tts;

  @override
  Future<bool> playSample(String url) async {
    try {
      await stop();
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return false;
      await _player.play(BytesSource(res.bodyBytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> playBytes(Uint8List wav) async {
    try {
      await stop();
      await _player.play(BytesSource(wav));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speakSystem(String text, String language) async {
    await stop();
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage(language);
    await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _tts?.stop();
  }

  @override
  void dispose() {
    _player.dispose();
    _tts?.stop();
  }
}

/// Voice list for one language (chosen with a selector): system voice +
/// catalog voices (downloadable / installed).
class VoicePickerScreen extends StatefulWidget {
  const VoicePickerScreen({
    super.key,
    required this.catalog,
    required this.installer,
    required this.selectedId,
    required this.onSelect,
    this.firstRun = false,
    this.previewer,
    this.systemInfo,
    this.elevenLabs,
    this.selectedLabel,
  });

  final Catalog catalog;
  final VoiceInstaller installer;
  final String selectedId;

  /// Makes [voice] the active voice (saves it and loads the engine).
  final Future<void> Function(Voice voice) onSelect;

  /// First launch: hides the back arrow and closes after a voice is chosen.
  final bool firstRun;
  final VoicePreviewer? previewer;

  /// Android TTS availability per language. Replaceable in tests.
  final SystemTtsInfo? systemInfo;

  /// Null hides the ElevenLabs section.
  final ElevenLabsAccess? elevenLabs;

  /// Display name of the selected voice (kept for an ElevenLabs voice, whose
  /// name can't be looked up offline).
  final String? selectedLabel;

  @override
  State<VoicePickerScreen> createState() => _VoicePickerScreenState();
}

class _VoicePickerScreenState extends State<VoicePickerScreen>
    with WidgetsBindingObserver {
  late final VoicePreviewer _previewer;
  late final SystemTtsInfo _systemInfo;
  late String _selectedId = widget.selectedId;
  final _availability = <String, SystemVoiceAvailability>{};
  final _installed = <String>{};
  String? _language;
  bool _checkedInstalled = false;
  String? _downloadingId;
  double _progress = 0;
  InstallStage _stage = InstallStage.downloading;
  InstallCancelToken? _token;
  String? _message;

  bool _elKeyChecked = false;
  bool _elHasKey = false;
  List<ElevenLabsVoice>? _elVoices;
  String? _elNote;

  @override
  void initState() {
    super.initState();
    _previewer = widget.previewer ?? DefaultVoicePreviewer();
    _systemInfo = widget.systemInfo ?? DefaultSystemTtsInfo();
    WidgetsBinding.instance.addObserver(this);
    _refreshInstalled();
    _loadElevenLabs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_language == null) {
      _language = _initialLanguage();
      _refreshAvailability();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _token?.cancel();
    _previewer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have installed voice data in Android's settings.
    if (state == AppLifecycleState.resumed) _refreshAvailability();
  }

  String get _uiLanguage => Localizations.localeOf(context).languageCode;

  /// Opened from settings: the selected voice's language; first run (nothing
  /// selected): the UI language.
  String _initialLanguage() {
    final id = widget.selectedId;
    final fromVoice =
        widget.catalog.byId(id)?.language ??
        (id.startsWith('system-') ? id.substring('system-'.length) : null);
    return fromVoice != null && _languages.contains(fromVoice)
        ? fromVoice
        : _uiLanguage;
  }

  /// Catalog languages: the UI language first, then the rest by their
  /// UI-language name. Without a catalog (offline) just the UI language.
  List<String> get _languages {
    final ui = _uiLanguage;
    final codes = {for (final v in widget.catalog.voices) v.language};
    if (codes.isEmpty) return [ui];
    final others = codes.where((c) => c != ui).toList()
      ..sort((a, b) => languageName(a, ui).compareTo(languageName(b, ui)));
    return [if (codes.contains(ui)) ui, ...others];
  }

  Future<void> _refreshInstalled() async {
    for (final v in widget.catalog.voices) {
      if (await widget.installer.isInstalled(v.id)) _installed.add(v.id);
    }
    if (mounted) setState(() => _checkedInstalled = true);
  }

  Future<void> _refreshAvailability() async {
    final lang = _language;
    if (lang == null) return;
    final result = await _systemInfo.availability(lang);
    if (mounted) setState(() => _availability[lang] = result);
  }

  /// Fetches the account's voices (needs internet). Offline or on any
  /// failure only the currently selected ElevenLabs voice is listed.
  Future<void> _loadElevenLabs() async {
    final access = widget.elevenLabs;
    if (access == null) return;
    final key = await access.keyStore.read();
    if (!mounted) return;
    if (key == null) {
      setState(() {
        _elKeyChecked = true;
        _elHasKey = false;
        _elVoices = null;
        _elNote = null;
      });
      return;
    }
    setState(() {
      _elKeyChecked = true;
      _elHasKey = true;
    });
    final client = access.clientFactory(key);
    try {
      final voices = await client.listVoices();
      if (mounted) {
        setState(() {
          _elVoices = voices;
          _elNote = null;
        });
      }
    } on ElevenLabsException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _elVoices = null;
          _elNote = e.reason == ElevenLabsFailure.offline
              ? l10n.elevenLabsNoInternet
              : l10n.elevenLabsListFailed;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _elVoices = null;
          _elNote = AppLocalizations.of(context).elevenLabsListFailed;
        });
      }
    } finally {
      client.close();
    }
  }

  Voice? get _selectedVoice {
    final id = _selectedId;
    if (!id.startsWith('elevenlabs:')) return null;
    final parts = id.split(':');
    return Voice.elevenLabs(
      parts[1],
      parts.skip(2).join(':'),
      widget.selectedLabel ?? '',
    );
  }

  Future<void> _openElevenLabs(String lang) async {
    final access = widget.elevenLabs!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ElevenLabsScreen(
          access: access,
          catalog: widget.catalog,
          installer: widget.installer,
          language: lang,
          selected: _selectedVoice,
          onSelect: (v) async {
            if (mounted) setState(() => _selectedId = v.id);
            await widget.onSelect(v);
          },
        ),
      ),
    );
    if (mounted) await _loadElevenLabs();
  }

  Future<void> _playElevenLabs(ElevenLabsVoice v, String lang) async {
    final text = widget.catalog.sampleText[lang];
    final access = widget.elevenLabs;
    if (text == null || access == null) return;
    var paidOnly = false;
    await _play(() async {
      try {
        final wav = await access.sample(v.id, text, lang);
        return await _previewer.playBytes(wav);
      } on ElevenLabsException catch (e) {
        paidOnly = e.reason == ElevenLabsFailure.voiceNotAllowed;
        return false;
      } catch (_) {
        return false;
      }
    }, why: (l10n) => paidOnly ? l10n.elevenLabsPaidOnly : null);
  }

  Future<void> _select(Voice v) async {
    setState(() => _selectedId = v.id);
    await widget.onSelect(v);
    if (widget.firstRun && mounted) Navigator.of(context).pop();
  }

  Future<void> _download(CatalogVoice v) async {
    final l10n = AppLocalizations.of(context);
    final token = InstallCancelToken();
    setState(() {
      _downloadingId = v.id;
      _progress = 0;
      _stage = InstallStage.downloading;
      _token = token;
      _message = null;
    });
    var ok = false;
    try {
      await widget.installer.install(
        v,
        cancel: token,
        onStage: (st) {
          if (mounted) setState(() => _stage = st);
        },
        onProgress: (received, total) {
          if (mounted) setState(() => _progress = received / total);
        },
      );
      ok = true;
    } on InstallCancelledException {
      // The user cancelled; nothing to report.
    } catch (_) {
      if (mounted) setState(() => _message = l10n.downloadFailed);
    }
    if (!mounted) return;
    setState(() {
      _downloadingId = null;
      _token = null;
      if (ok) _installed.add(v.id);
    });
    if (ok) await _select(v.toVoice());
  }

  Future<void> _delete(CatalogVoice v) async {
    if (_selectedId == v.id) await _select(Voice.system(v.language));
    await widget.installer.delete(v.id);
    if (mounted) setState(() => _installed.remove(v.id));
  }

  /// Plays a sample; on failure shows why in a SnackBar, which stays visible
  /// however far the list is scrolled. [why] can give a specific reason.
  Future<void> _play(
    Future<bool> Function() play, {
    String? Function(AppLocalizations l10n)? why,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final ok = await play();
    if (ok || !mounted) return;
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(why?.call(l10n) ?? l10n.sampleUnavailable)),
    );
  }

  Future<void> _chooseLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: _languageSheet,
    );
    if (picked != null && picked != _language && mounted) {
      setState(() => _language = picked);
      _refreshAvailability();
    }
  }

  Widget _languageSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = _uiLanguage;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final code in _languages) _languageTile(context, code, ui, l10n),
        ],
      ),
    );
  }

  Widget _languageTile(
    BuildContext context,
    String code,
    String ui,
    AppLocalizations l10n,
  ) {
    final name = languageName(code, ui);
    final native = nativeLanguageName(code);
    final count = widget.catalog.voices
        .where((v) => v.language == code && _installed.contains(v.id))
        .length;
    return ListTile(
      key: Key('language-$code'),
      minTileHeight: 56,
      title: Text(
        native == name ? name : '$name ($native)',
        style: const TextStyle(fontSize: 20),
      ),
      subtitle: count > 0 ? Text(l10n.installedVoicesCount(count)) : null,
      trailing: count > 0 ? const Icon(Icons.check) : null,
      selected: code == _language,
      onTap: () => Navigator.of(context).pop(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ui = _uiLanguage;
    final lang = _language ?? ui;
    final voices = widget.catalog.forLanguage(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voicePickerTitle),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_languages.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _languageSelector(l10n, ui, lang),
              ),
            if (widget.catalog.isBundled || widget.catalog.voices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.downloadsNeedInternet),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ?_systemRow(lang, l10n),
            for (final v in voices) _catalogRow(v, l10n),
            if (widget.elevenLabs != null &&
                _elKeyChecked &&
                elevenLabsLanguages.contains(lang))
              ..._elevenLabsSection(lang, l10n),
          ],
        ),
      ),
    );
  }

  /// The main control of the screen (it decides which voices are listed), so
  /// it is the most prominent element: tall, tinted, with a globe and arrow.
  Widget _languageSelector(AppLocalizations l10n, String ui, String lang) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton(
        key: const Key('language-selector'),
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.primary, width: 2),
        ),
        onPressed: _chooseLanguage,
        child: Row(
          children: [
            const Icon(Icons.language, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.languageSelectorLabel(languageName(lang, ui)),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 36),
          ],
        ),
      ),
    );
  }

  Widget? _systemRow(String lang, AppLocalizations l10n) {
    final system = Voice.system(lang);
    final isSelected = _selectedId == system.id;
    // Unknown yet (check running or failed) counts as installed.
    final status = _availability[lang] ?? SystemVoiceAvailability.installed;
    final sample = widget.catalog.sampleText[lang];

    // A selected system voice keeps working whatever the check says.
    if (isSelected || status == SystemVoiceAvailability.installed) {
      return _row(
        key: const Key('voice-system'),
        title: l10n.systemVoice,
        subtitle: l10n.systemVoiceInfo,
        onPlay: sample == null
            ? null
            : () => _previewer.speakSystem(sample, lang),
        trailing: isSelected
            ? _selectedLabel(l10n)
            : OutlinedButton(
                onPressed: () => _select(system),
                child: Text(l10n.select),
              ),
      );
    }
    if (status == SystemVoiceAvailability.missingData) {
      return _row(
        key: const Key('voice-system'),
        title: l10n.systemVoice,
        subtitle: l10n.systemVoiceMissing,
        trailing: const SizedBox.shrink(),
        // Too long for the trailing slot: it would squeeze the title.
        footer: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _systemInfo.openInstallVoiceData,
              child: Text(l10n.downloadInAndroidSettings),
            ),
          ),
        ),
      );
    }
    // Unsupported: hidden, except for the UI language, so the picker never
    // looks voiceless.
    if (lang != _uiLanguage) return null;
    return _row(
      key: const Key('voice-system'),
      title: l10n.systemVoice,
      subtitle: l10n.systemVoiceUnsupported,
      trailing: const SizedBox.shrink(),
    );
  }

  List<Widget> _elevenLabsSection(String lang, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedVoice;
    // Offline: just the selected voice (if it belongs to this language).
    final voices =
        _elVoices ??
        [
          if (selected != null && selected.languageCode == lang)
            ElevenLabsVoice(selected.elevenLabsVoiceId, selected.label),
        ];
    return [
      Padding(
        key: const Key('elevenlabs-header'),
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.elevenLabsSection,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
            Text(l10n.elevenLabsSectionSubtitle),
          ],
        ),
      ),
      if (!_elHasKey)
        _row(
          key: const Key('elevenlabs-setup'),
          title: l10n.elevenLabsSetup,
          trailing: OutlinedButton(
            onPressed: () => _openElevenLabs(lang),
            child: Text(l10n.elevenLabsSetup),
          ),
        )
      else ...[
        if (_elNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_elNote!, key: const Key('elevenlabs-note')),
          ),
        for (final v in voices) _elevenLabsRow(v, lang, l10n),
        _row(
          key: const Key('elevenlabs-settings'),
          title: l10n.elevenLabsSettings,
          trailing: OutlinedButton(
            onPressed: () => _openElevenLabs(lang),
            child: Text(l10n.elevenLabsSettings),
          ),
        ),
      ],
    ];
  }

  Widget _elevenLabsRow(ElevenLabsVoice v, String lang, AppLocalizations l10n) {
    final voice = Voice.elevenLabs(lang, v.id, v.name);
    final isSelected = _selectedId == voice.id;
    return _row(
      key: Key('voice-${voice.id}'),
      title: v.name,
      onPlay: widget.catalog.sampleText[lang] == null
          ? null
          : () => _playElevenLabs(v, lang),
      playTooltip: l10n.elevenLabsTrial,
      trailing: isSelected
          ? _selectedLabel(l10n)
          : OutlinedButton(
              onPressed: () => _select(voice),
              child: Text(l10n.select),
            ),
    );
  }

  Widget _selectedLabel(AppLocalizations l10n) => Chip(
    avatar: const Icon(Icons.check, size: 18),
    label: Text(l10n.selected),
  );

  Widget _catalogRow(CatalogVoice v, AppLocalizations l10n) {
    final installed = _installed.contains(v.id);
    final downloading = _downloadingId == v.id;
    final gender = switch (v.gender) {
      VoiceGender.male => l10n.genderMale,
      VoiceGender.female => l10n.genderFemale,
      VoiceGender.unknown => null,
    };
    final size = l10n.voiceSizeMb((v.sizeBytes / 1000000).round());
    final subtitle = [?gender, size].join(' · ');

    Widget trailing;
    if (downloading) {
      trailing = TextButton(
        onPressed: _token?.cancel,
        child: Text(l10n.cancel),
      );
    } else if (installed && _selectedId == v.id) {
      trailing = _selectedLabel(l10n);
    } else if (installed) {
      trailing = OutlinedButton(
        onPressed: () => _select(v.toVoice()),
        child: Text(l10n.select),
      );
    } else {
      trailing = FilledButton(
        onPressed: _downloadingId == null && _checkedInstalled
            ? () => _download(v)
            : null,
        child: Text(l10n.download),
      );
    }

    return _row(
      key: Key('voice-${v.id}'),
      title: v.label,
      subtitle: subtitle,
      onPlay: () => _play(() => _previewer.playSample(v.sampleUrl)),
      showProgress: downloading,
      progress: _stage == InstallStage.downloading ? _progress : null,
      progressLabel: downloading && _stage != InstallStage.downloading
          ? l10n.installing
          : null,
      trailing: trailing,
      onDelete: installed && !downloading ? () => _delete(v) : null,
      deleteTooltip: l10n.deleteVoice,
      playTooltip: l10n.playSample,
    );
  }

  Widget _row({
    required Key key,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onPlay,
    bool showProgress = false,
    double? progress,
    String? progressLabel,
    VoidCallback? onDelete,
    String? deleteTooltip,
    String? playTooltip,
    Widget? footer,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  iconSize: 36,
                  tooltip:
                      playTooltip ?? AppLocalizations.of(context).playSample,
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: onPlay,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20)),
                      if (subtitle != null) Text(subtitle),
                    ],
                  ),
                ),
                trailing,
                if (onDelete != null)
                  IconButton(
                    tooltip: deleteTooltip,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            ?footer,
            if (showProgress)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // value == null → indeterminate (unpacking has no
                    // measurable progress).
                    LinearProgressIndicator(value: progress),
                    if (progressLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(progressLabel),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
