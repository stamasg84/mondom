import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_localizations.dart';
import '../speech/speech_speed.dart';
import '../voices/catalog.dart';
import '../voices/elevenlabs_access.dart';
import '../voices/elevenlabs_client.dart';
import '../voices/language_names.dart';
import '../voices/system_tts_info.dart';
import '../voices/voice.dart';
import '../voices/voice_installer.dart';
import 'app_theme.dart';
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
    this.speak,
    this.reloadCatalog,
  });

  /// Fetches the remote catalog again. Called when the picker opens on the
  /// bundled fallback (e.g. the network wasn't up yet at app start).
  final Future<Catalog> Function()? reloadCatalog;

  /// Says [text] with the active voice; used to hear a new speed.
  final Future<void> Function(String text)? speak;

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
  late Catalog _catalog = widget.catalog;
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

  /// The selected voice's speech speed (shown in its card).
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _previewer = widget.previewer ?? DefaultVoicePreviewer();
    _systemInfo = widget.systemInfo ?? DefaultSystemTtsInfo();
    WidgetsBinding.instance.addObserver(this);
    _refreshInstalled();
    _loadElevenLabs();
    _loadSpeed();
    _retryCatalog();
  }

  Future<void> _retryCatalog() async {
    final reload = widget.reloadCatalog;
    if (reload == null || !(_catalog.isBundled || _catalog.voices.isEmpty)) {
      return;
    }
    final fresh = await reload();
    if (!mounted || fresh.isBundled || fresh.voices.isEmpty) return;
    setState(() => _catalog = fresh);
    await _refreshInstalled();
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
        _catalog.byId(id)?.language ??
        (id.startsWith('system-') ? id.substring('system-'.length) : null);
    return fromVoice != null && _languages.contains(fromVoice)
        ? fromVoice
        : _uiLanguage;
  }

  /// Catalog languages: the UI language first, then the rest by their
  /// UI-language name. Without a catalog (offline) just the UI language.
  List<String> get _languages {
    final ui = _uiLanguage;
    final codes = {for (final v in _catalog.voices) v.language};
    if (codes.isEmpty) return [ui];
    final others = codes.where((c) => c != ui).toList()
      ..sort((a, b) => languageName(a, ui).compareTo(languageName(b, ui)));
    return [if (codes.contains(ui)) ui, ...others];
  }

  Future<void> _refreshInstalled() async {
    for (final v in _catalog.voices) {
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
          catalog: _catalog,
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
    final text = _catalog.sampleText[lang];
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

  Future<void> _loadSpeed() async {
    final id = _selectedId;
    if (id.isEmpty) return;
    final speed = await speechSpeed(id);
    if (mounted && id == _selectedId) setState(() => _speed = speed);
  }

  Future<void> _saveSpeed(double v) async {
    await setSpeechSpeed(_selectedId, v);
    // Hear the new speed.
    final text = _catalog.sampleText[_language ?? _uiLanguage];
    if (text != null) await widget.speak?.call(text);
  }

  Future<void> _resetSpeed() async {
    setState(() => _speed = 1.0);
    await _saveSpeed(1.0);
  }

  Future<void> _select(Voice v) async {
    setState(() {
      _selectedId = v.id;
      _speed = 1.0;
    });
    _loadSpeed();
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
    final count = _catalog.voices
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
    final voices = _catalog.forLanguage(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voicePickerTitle),
        automaticallyImplyLeading: !widget.firstRun,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _voicesHeading(l10n, ui, lang),
            if (_catalog.isBundled || _catalog.voices.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  l10n.downloadsNeedInternet,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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

  /// Heading of the voice list naming the language, with a link that
  /// switches it (only when the catalog has other languages).
  Widget _voicesHeading(AppLocalizations l10n, String ui, String lang) {
    final scheme = Theme.of(context).colorScheme;
    final name = languageName(lang, ui);
    // Hungarian language names are lowercase inside a sentence.
    final inText = ui == 'hu' ? name.toLowerCase() : name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.voicesForLanguage(inText),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          if (_languages.length > 1)
            TextButton(
              key: const Key('language-selector'),
              onPressed: _chooseLanguage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.changeLanguage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.outline),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _systemRow(String lang, AppLocalizations l10n) {
    final system = Voice.system(lang);
    final isSelected = _selectedId == system.id;
    // Unknown yet (check running or failed) counts as installed.
    final status = _availability[lang] ?? SystemVoiceAvailability.installed;
    final sample = _catalog.sampleText[lang];

    // A selected system voice keeps working whatever the check says.
    if (isSelected || status == SystemVoiceAvailability.installed) {
      return _row(
        key: const Key('voice-system'),
        title: l10n.systemVoice,
        subtitle: l10n.systemVoiceInfo,
        onPlay: sample == null
            ? null
            : () => _previewer.speakSystem(sample, lang),
        selected: isSelected,
        onSelect: () => _select(system),
      );
    }
    if (status == SystemVoiceAvailability.missingData) {
      return _row(
        key: const Key('voice-system'),
        title: l10n.systemVoice,
        subtitle: l10n.systemVoiceMissing,
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
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.elevenLabsSection,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    l10n.elevenLabsSectionSubtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_elHasKey)
              IconButton(
                key: const Key('elevenlabs-gear'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                iconSize: 28,
                tooltip: l10n.elevenLabsSettings,
                color: scheme.primary,
                icon: const Icon(Icons.settings),
                onPressed: () => _openElevenLabs(lang),
              ),
          ],
        ),
      ),
      if (!_elHasKey)
        Material(
          color: scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: kBorderRadius,
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('elevenlabs-setup'),
            onTap: () => _openElevenLabs(lang),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: scheme.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l10n.elevenLabsSetup,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.outline),
                  ],
                ),
              ),
            ),
          ),
        )
      else ...[
        if (_elNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_elNote!, key: const Key('elevenlabs-note')),
          ),
        for (final v in voices) _elevenLabsRow(v, lang, l10n),
      ],
    ];
  }

  Widget _elevenLabsRow(ElevenLabsVoice v, String lang, AppLocalizations l10n) {
    final voice = Voice.elevenLabs(lang, v.id, v.name);
    final isSelected = _selectedId == voice.id;
    return _row(
      key: Key('voice-${voice.id}'),
      title: v.name,
      onPlay: _catalog.sampleText[lang] == null
          ? null
          : () => _playElevenLabs(v, lang),
      playTooltip: l10n.elevenLabsTrial,
      selected: isSelected,
      onSelect: () => _select(voice),
    );
  }

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

    Widget? trailing;
    if (downloading) {
      trailing = TextButton(
        onPressed: _token?.cancel,
        child: Text(l10n.cancel),
      );
    } else if (installed) {
      trailing = null; // the selection radio
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
      selected: installed && !downloading && _selectedId == v.id,
      onSelect: installed && !downloading ? () => _select(v.toVoice()) : null,
      onDelete: installed && !downloading ? () => _delete(v) : null,
      deleteTooltip: l10n.deleteVoice,
      playTooltip: l10n.playSample,
    );
  }

  /// A white voice card. A selectable voice (onSelect != null) gets a radio
  /// at the end and the whole card selects it; the selected card has a
  /// brand-blue border and holds that voice's speed slider.
  Widget _row({
    required Key key,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool selected = false,
    VoidCallback? onSelect,
    VoidCallback? onPlay,
    bool showProgress = false,
    double? progress,
    String? progressLabel,
    VoidCallback? onDelete,
    String? deleteTooltip,
    String? playTooltip,
    Widget? footer,
  }) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: kBorderRadius,
          side: selected
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selected ? null : onSelect,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      iconSize: 36,
                      color: scheme.primary,
                      tooltip: playTooltip ?? l10n.playSample,
                      icon: const Icon(Icons.play_circle_outline),
                      onPressed: onPlay,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: deleteTooltip,
                        color: scheme.onSurfaceVariant,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                      ),
                    ?trailing,
                    if (onSelect != null)
                      IconButton(
                        iconSize: 30,
                        tooltip: selected ? l10n.selected : l10n.select,
                        color: scheme.outline,
                        disabledColor: scheme.primary,
                        icon: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onPressed: selected ? null : onSelect,
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
                if (selected) _speedControl(l10n, scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _speedControl(AppLocalizations l10n, ColorScheme scheme) {
    const divisions =
        ((speechSpeedMax - speechSpeedMin) / speechSpeedStep + 0.5) ~/ 1;
    final muted = TextStyle(fontSize: 16, color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 16, color: scheme.outlineVariant),
          Text(
            l10n.settingsSpeedTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Slider(
            key: const Key('speech-speed'),
            // Track ends line up with the Lassabb / Gyorsabb labels.
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            value: _speed.clamp(speechSpeedMin, speechSpeedMax).toDouble(),
            min: speechSpeedMin,
            max: speechSpeedMax,
            divisions: divisions,
            onChanged: (x) => setState(() => _speed = x),
            onChangeEnd: (x) => _saveSpeed((x * 100).round() / 100),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.settingsSpeedSlower, style: muted),
              Text(l10n.settingsSpeedFaster, style: muted),
            ],
          ),
          if ((_speed - 1.0).abs() > 0.001)
            TextButton(
              key: const Key('speech-speed-reset'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: _resetSpeed,
              child: Text(
                l10n.settingsSpeedReset,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
