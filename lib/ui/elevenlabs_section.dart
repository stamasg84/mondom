import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../speech/voice_recorder.dart' as platform;
import '../voices/catalog.dart';
import '../voices/elevenlabs_access.dart';
import '../voices/elevenlabs_client.dart';
import '../voices/voice.dart';
import '../voices/voice_installer.dart';
import 'app_theme.dart';

/// What the ElevenLabs settings section needs from the app.
class ElevenLabsSettings {
  const ElevenLabsSettings({
    required this.access,
    required this.catalog,
    required this.installer,
    required this.voice,
    required this.onSelect,
  });

  final ElevenLabsAccess access;
  final Catalog Function() catalog;
  final VoiceInstaller installer;

  /// The active voice: its language picks the offline fallback voices; an
  /// ElevenLabs one is replaced when the key is deleted and reloaded when a
  /// new key is saved.
  final Voice Function() voice;

  /// Makes a voice the active voice (saves it and loads the engine).
  final Future<void> Function(Voice voice) onSelect;

  ElevenLabsSettings withOnSelect(Future<void> Function(Voice) f) =>
      ElevenLabsSettings(
        access: access,
        catalog: catalog,
        installer: installer,
        voice: voice,
        onSelect: f,
      );
}

/// The ElevenLabs part of the settings screen. Without a key: a short note,
/// the manual link and the key field. With a key: its status and credit, the
/// offline fallback voice, the expressive switch and deleting the key.
class ElevenLabsSection extends StatefulWidget {
  const ElevenLabsSection({
    super.key,
    required this.settings,
    this.openUrl = platform.openUrl,
  });

  final ElevenLabsSettings settings;
  final Future<bool> Function(String url) openUrl;

  @override
  State<ElevenLabsSection> createState() => _ElevenLabsSectionState();
}

class _ElevenLabsSectionState extends State<ElevenLabsSection> {
  final _keyController = TextEditingController();
  bool _loaded = false;
  bool _hasKey = false;
  bool _checking = false;
  bool _expressive = false;
  String? _error;
  bool _urlFailed = false;
  ElevenLabsSubscription? _subscription;
  final _installed = <CatalogVoice>[];
  String _fallbackId = '';

  ElevenLabsSettings get _s => widget.settings;
  String get _language => _s.voice().languageCode;
  Voice get _systemVoice => Voice.system(_language);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _s.access.keyStore.read();
    for (final v in _s.catalog().forLanguage(_language)) {
      if (await _s.installer.isInstalled(v.id)) _installed.add(v);
    }
    final stored = prefs.getString(elevenLabsFallbackKey);
    if (!mounted) return;
    setState(() {
      _hasKey = key != null;
      _expressive = prefs.getBool(elevenLabsExpressiveKey) ?? false;
      _fallbackId = _installed.any((v) => v.id == stored)
          ? stored!
          : _systemVoice.id;
      _loaded = true;
    });
    if (key != null) _loadCredit(key);
  }

  Future<void> _loadCredit(String key) async {
    final client = _s.access.clientFactory(key);
    try {
      final s = await client.subscription();
      if (mounted) setState(() => _subscription = s);
    } catch (_) {
      // The credit line is a convenience; hide it on any failure.
    } finally {
      client.close();
    }
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context);
    final key = _keyController.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final client = _s.access.clientFactory(key);
    String? error;
    try {
      await client.listVoices();
      await _s.access.keyStore.write(key);
    } on ElevenLabsException catch (e) {
      error = switch (e.reason) {
        ElevenLabsFailure.offline => l10n.elevenLabsErrOffline,
        ElevenLabsFailure.badKey => l10n.elevenLabsErrBadKey,
        ElevenLabsFailure.missingPermission => l10n.elevenLabsErrPermission,
        _ => l10n.elevenLabsErrOther,
      };
    } catch (_) {
      error = l10n.elevenLabsErrOther;
    } finally {
      client.close();
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _error = error;
      if (error == null) {
        _hasKey = true;
        _subscription = null;
        _keyController.clear();
      }
    });
    if (error == null) {
      _loadCredit(key);
      // A selected ElevenLabs voice still holds the old key: reload it.
      final v = _s.voice();
      if (v.kind == VoiceKind.elevenlabs) await _s.onSelect(v);
    }
  }

  Voice get _fallbackVoice {
    for (final v in _installed) {
      if (v.id == _fallbackId) return v.toVoice();
    }
    return _systemVoice;
  }

  Future<void> _setFallback(String? id) async {
    if (id == null) return;
    setState(() => _fallbackId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(elevenLabsFallbackKey, id);
  }

  Future<void> _setExpressive(bool v) async {
    setState(() => _expressive = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(elevenLabsExpressiveKey, v);
  }

  Future<void> _deleteKey() async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          l10n.elevenLabsDeleteKeyQuestion,
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.elevenLabsDeleteKey),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _s.access.keyStore.clear();
    await _s.access.cache.clear();
    if (!mounted) return;
    setState(() {
      _hasKey = false;
      _subscription = null;
    });
    if (_s.voice().kind == VoiceKind.elevenlabs) {
      await _s.onSelect(_fallbackVoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _hasKey ? _keySection(l10n) : [_setupCard(l10n)],
    );
  }

  Widget _card({Key? key, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: key,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: kBorderRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  String get _manualUrl => Localizations.localeOf(context).languageCode == 'hu'
      ? 'https://github.com/stamasg84/mondom/blob/main/README.hu.md#elevenlabs'
      : 'https://github.com/stamasg84/mondom#elevenlabs';

  Future<void> _openManual() async {
    final ok = await widget.openUrl(_manualUrl);
    if (!ok && mounted) setState(() => _urlFailed = true);
  }

  /// No key yet: what ElevenLabs is, the manual, the key field.
  Widget _setupCard(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.elevenLabsIntro,
              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('elevenlabs-manual'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: _openManual,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.elevenLabsManualLink,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.outline),
                  ],
                ),
              ),
            ),
            if (_urlFailed)
              SelectableText(
                _manualUrl,
                key: const Key('elevenlabs-manual-url'),
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 4),
            _keyField(l10n),
          ],
        ),
      ),
    );
  }

  Widget _keyField(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('elevenlabs-key'),
          controller: _keyController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          style: const TextStyle(fontSize: 20),
          decoration: InputDecoration(
            labelText: l10n.elevenLabsKeyLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        // Outside the field, so it lines up with the note above.
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.elevenLabsKeyHint,
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: FilledButton(
            key: const Key('elevenlabs-check'),
            onPressed: _checking ? null : _check,
            child: _checking
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Text(
                    l10n.elevenLabsCheck,
                    style: const TextStyle(fontSize: 20),
                  ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              key: const Key('elevenlabs-error'),
              style: TextStyle(color: scheme.error, fontSize: 18),
            ),
          ),
      ],
    );
  }

  /// Key saved: status + credit + delete, the fallback voice, expressive.
  List<Widget> _keySection(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 16, color: scheme.onSurfaceVariant);
    final s = _subscription;
    return [
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: scheme.primary, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.elevenLabsKeySaved,
                          key: const Key('elevenlabs-saved'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s != null)
                          Text(
                            _creditText(l10n, s),
                            key: const Key('elevenlabs-credit'),
                            style: muted,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            InkWell(
              key: const Key('elevenlabs-delete'),
              onTap: _deleteKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: scheme.onSurfaceVariant,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        l10n.elevenLabsDeleteKey,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      _card(
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.elevenLabsFallbackChoice,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              RadioGroup<String>(
                groupValue: _fallbackId,
                onChanged: _setFallback,
                child: Column(
                  children: [
                    RadioListTile<String>(
                      key: Key('fallback-${_systemVoice.id}'),
                      contentPadding: _radioPadding,
                      value: _systemVoice.id,
                      title: Text(
                        l10n.systemVoice,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    for (final v in _installed)
                      RadioListTile<String>(
                        key: Key('fallback-${v.id}'),
                        contentPadding: _radioPadding,
                        value: v.id,
                        title: Text(
                          v.label,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      _card(
        child: SwitchListTile(
          key: const Key('elevenlabs-expressive'),
          value: _expressive,
          onChanged: _setExpressive,
          title: Text(
            l10n.elevenLabsExpressive,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l10n.elevenLabsExpressiveSubtitle, style: muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
    ];
  }

  /// The radio's own padding puts the circle in line with card text.
  static const _radioPadding = EdgeInsets.fromLTRB(6, 0, 16, 0);

  String _creditText(AppLocalizations l10n, ElevenLabsSubscription s) {
    final used = _grouped(s.used);
    final limit = _grouped(s.limit);
    final reset = s.resetsAt;
    return reset == null
        ? l10n.elevenLabsCreditNoDate(used, limit)
        : l10n.elevenLabsCredit(
            used,
            limit,
            MaterialLocalizations.of(context).formatShortMonthDay(reset),
          );
  }

  /// 10000 -> "10 000" (a no-break space, as in Hungarian).
  static String _grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}
