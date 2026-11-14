import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../voices/catalog.dart';
import '../voices/elevenlabs_access.dart';
import '../voices/elevenlabs_client.dart';
import '../voices/voice.dart';
import '../voices/voice_installer.dart';

/// Setup for the optional ElevenLabs voice: the user's own API key, the voice
/// that speaks without internet, and the expressive switch.
class ElevenLabsScreen extends StatefulWidget {
  const ElevenLabsScreen({
    super.key,
    required this.access,
    required this.catalog,
    required this.installer,
    required this.language,
    required this.selected,
    required this.onSelect,
  });

  final ElevenLabsAccess access;
  final Catalog catalog;
  final VoiceInstaller installer;

  /// The speech language the offline fallback voice belongs to.
  final String language;

  /// The active voice (null on first run); an ElevenLabs one is replaced when
  /// its key is deleted and reloaded when a new key is saved.
  final Voice? selected;

  /// Makes [voice] the active voice (saves it and loads the engine).
  final Future<void> Function(Voice voice) onSelect;

  @override
  State<ElevenLabsScreen> createState() => _ElevenLabsScreenState();
}

class _ElevenLabsScreenState extends State<ElevenLabsScreen> {
  final _keyController = TextEditingController();
  bool _loaded = false;
  bool _hasKey = false;
  bool _checking = false;
  bool _expressive = false;
  String? _error;
  bool _saved = false;
  ElevenLabsSubscription? _subscription;
  final _installed = <CatalogVoice>[];
  String _fallbackId = '';

  Voice get _systemVoice => Voice.system(widget.language);

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
    final key = await widget.access.keyStore.read();
    for (final v in widget.catalog.forLanguage(widget.language)) {
      if (await widget.installer.isInstalled(v.id)) _installed.add(v);
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
    final client = widget.access.clientFactory(key);
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
      _saved = false;
    });
    final client = widget.access.clientFactory(key);
    String? error;
    try {
      await client.listVoices();
      await widget.access.keyStore.write(key);
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
        _saved = true;
        _subscription = null;
        _keyController.clear();
      }
    });
    if (error == null) {
      _loadCredit(key);
      // A selected ElevenLabs voice still holds the old key: reload it.
      final v = widget.selected;
      if (v != null && v.kind == VoiceKind.elevenlabs) await widget.onSelect(v);
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
    await widget.access.keyStore.clear();
    await widget.access.cache.clear();
    if (!mounted) return;
    setState(() {
      _hasKey = false;
      _subscription = null;
      _saved = false;
    });
    if (widget.selected?.kind == VoiceKind.elevenlabs) {
      await widget.onSelect(_fallbackVoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.elevenLabsScreenTitle)),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    l10n.elevenLabsIntro,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  _manualLink(l10n),
                  const SizedBox(height: 16),
                  _keyField(l10n),
                  if (_hasKey) ..._keySection(l10n),
                ],
              ),
      ),
    );
  }

  /// No url-opening channel yet (T41): the address is shown as selectable text.
  Widget _manualLink(AppLocalizations l10n) {
    final hu = Localizations.localeOf(context).languageCode == 'hu';
    final url = hu
        ? 'https://github.com/stamasg84/mondom/blob/main/README.hu.md#elevenlabs'
        : 'https://github.com/stamasg84/mondom#elevenlabs';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.elevenLabsManualLink,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SelectableText(
          url,
          key: const Key('elevenlabs-manual-url'),
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _keyField(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            helperText: l10n.elevenLabsKeyHint,
            helperMaxLines: 4,
            helperStyle: const TextStyle(fontSize: 16),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
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
        if (_saved)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.elevenLabsKeySaved,
              key: const Key('elevenlabs-saved'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
      ],
    );
  }

  List<Widget> _keySection(AppLocalizations l10n) {
    final s = _subscription;
    return [
      if (s != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            _creditText(l10n, s),
            key: const Key('elevenlabs-credit'),
            style: const TextStyle(fontSize: 18),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Text(
          l10n.elevenLabsFallbackChoice,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      RadioGroup<String>(
        groupValue: _fallbackId,
        onChanged: _setFallback,
        child: Column(
          children: [
            RadioListTile<String>(
              key: Key('fallback-${_systemVoice.id}'),
              value: _systemVoice.id,
              title: Text(
                l10n.systemVoice,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            for (final v in _installed)
              RadioListTile<String>(
                key: Key('fallback-${v.id}'),
                value: v.id,
                title: Text(v.label, style: const TextStyle(fontSize: 20)),
              ),
          ],
        ),
      ),
      SwitchListTile(
        key: const Key('elevenlabs-expressive'),
        value: _expressive,
        onChanged: _setExpressive,
        title: Text(
          l10n.elevenLabsExpressive,
          style: const TextStyle(fontSize: 20),
        ),
        subtitle: Text(
          l10n.elevenLabsExpressiveSubtitle,
          style: const TextStyle(fontSize: 16),
        ),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          key: const Key('elevenlabs-delete'),
          onPressed: _deleteKey,
          icon: const Icon(Icons.delete_outline),
          label: Text(
            l10n.elevenLabsDeleteKey,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    ];
  }

  String _creditText(AppLocalizations l10n, ElevenLabsSubscription s) {
    final used = _grouped(s.used);
    final limit = _grouped(s.limit);
    final reset = s.resetsAt;
    return reset == null
        ? l10n.elevenLabsCreditNoDate(used, limit)
        : l10n.elevenLabsCredit(
            used,
            limit,
            MaterialLocalizations.of(context).formatMediumDate(reset),
          );
  }

  /// 10000 -> "10 000" (a no-break space, as in Hungarian).
  static String _grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}
