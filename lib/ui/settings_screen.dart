import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../speech/alarm_volume.dart';
import '../speech/loudness.dart';
import '../speech/speaker.dart';
import '../storage/backup.dart';
import 'app_theme.dart';
import 'elevenlabs_section.dart';
import 'theme_mode.dart';

/// Settings: speech boost, the optional ElevenLabs voice, the alarm volume
/// (the phone's own level, or Mondom's own level raised while an alarm
/// plays, restored after) and backup.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.alarmVolume,
    required this.speaker,
    this.backup,
    this.elevenLabs,
    this.showElevenLabs = false,
  });

  /// Null hides the ElevenLabs section.
  final ElevenLabsSettings? elevenLabs;

  /// Opened from the voice picker: scroll to the ElevenLabs section.
  final bool showElevenLabs;

  final AlarmVolume alarmVolume;
  final Speaker speaker;

  /// Null hides the backup section.
  final BackupService? backup;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AlarmVolumeMode? _mode;
  double _level = 1.0;
  bool _boost = true;
  bool _busy = false;
  final _elevenLabsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.speaker.addListener(_changed);
    _load();
  }

  Future<void> _load() async {
    final mode = await widget.alarmVolume.mode();
    final level = await widget.alarmVolume.level();
    final boost = await speechBoostEnabled();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _level = level;
      _boost = boost;
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.speaker.removeListener(_changed);
    // Leaving the screen ends a running test.
    if (widget.speaker.alarmPlaying) widget.speaker.stop();
    super.dispose();
  }

  Future<void> _setMode(AlarmVolumeMode? m) async {
    if (m == null) return;
    setState(() => _mode = m);
    await widget.alarmVolume.setMode(m);
  }

  Future<void> _setBoost(bool v) async {
    setState(() => _boost = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(speechBoostKey, v);
    } catch (_) {}
  }

  Future<void> _run(Future<String?> Function() job, String failed) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    String? message;
    try {
      message = await job();
    } on BackupException catch (e) {
      message = e.code == 'version'
          ? l10n.restoreErrorVersion
          : l10n.restoreErrorFormat;
    } catch (_) {
      message = failed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _export() {
    final l10n = AppLocalizations.of(context);
    return _run(() async {
      final n = await widget.backup!.export();
      return n == null ? null : l10n.backupDone(n);
    }, l10n.backupFailed);
  }

  Future<void> _restore() {
    final l10n = AppLocalizations.of(context);
    return _run(() async {
      final r = await widget.backup!.restore();
      return r == null
          ? null
          : l10n.restoreDone(r.listsAdded, r.listsSkipped, r.recordingsCopied);
    }, l10n.restoreFailed);
  }

  void _test() {
    widget.speaker.play(
      const SentenceRowData(text: '', soundKey: 'bell', alarm: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 16, color: scheme.onSurfaceVariant);
    final mode = _mode;
    final playing = widget.speaker.alarmPlaying;
    final elevenLabs = widget.elevenLabs;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: mode == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _heading(l10n.settingsSpeechSection),
                  _card(
                    SwitchListTile(
                      value: _boost,
                      onChanged: _setBoost,
                      title: Text(l10n.settingsBoostTitle, style: _title),
                      subtitle: Text(l10n.settingsBoostHelp, style: muted),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                  _heading(l10n.settingsAppearanceSection),
                  _card(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeModeSetting,
                        builder: (context, themeMode, _) =>
                            RadioGroup<ThemeMode>(
                              groupValue: themeMode,
                              onChanged: (m) {
                                if (m != null) setThemeMode(m);
                              },
                              child: Column(
                                children: [
                                  _themeRadio(
                                    ThemeMode.system,
                                    l10n.themeSystem,
                                  ),
                                  _themeRadio(ThemeMode.light, l10n.themeLight),
                                  _themeRadio(ThemeMode.dark, l10n.themeDark),
                                ],
                              ),
                            ),
                      ),
                    ),
                  ),
                  _heading(l10n.settingsAlarmSection),
                  _card(
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RadioGroup<AlarmVolumeMode>(
                            groupValue: mode,
                            onChanged: _setMode,
                            child: Column(
                              children: [
                                _radio(
                                  AlarmVolumeMode.system,
                                  l10n.alarmVolumeSystem,
                                ),
                                _radio(
                                  AlarmVolumeMode.custom,
                                  l10n.alarmVolumeCustom,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Slider(
                              value: _level,
                              onChanged: mode == AlarmVolumeMode.custom
                                  ? (v) => setState(() => _level = v)
                                  : null,
                              onChangeEnd: widget.alarmVolume.setLevel,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: SizedBox(
                              height: 64,
                              child: playing
                                  ? FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: widget.speaker.stop,
                                      icon: const Icon(Icons.stop, size: 32),
                                      label: Text(
                                        l10n.stopAlarm,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _test,
                                      icon: const Icon(
                                        Icons.campaign,
                                        size: 32,
                                      ),
                                      label: Text(
                                        l10n.alarmVolumeTest,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.backup != null) ..._backupSection(l10n, muted),
                  // Last: optional, and depends on an external provider.
                  if (elevenLabs != null) ...[
                    _heading(l10n.elevenLabsSection, key: _elevenLabsKey),
                    ElevenLabsSection(
                      settings: elevenLabs,
                      // Scroll once it has its full height (it is last, so
                      // earlier the list can't scroll far enough).
                      onLoaded: widget.showElevenLabs
                          ? _scrollToElevenLabs
                          : null,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  void _scrollToElevenLabs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _elevenLabsKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx);
    });
  }

  static const _title = TextStyle(fontSize: 20, fontWeight: FontWeight.w600);

  List<Widget> _backupSection(AppLocalizations l10n, TextStyle muted) {
    final scheme = Theme.of(context).colorScheme;
    return [
      _heading(l10n.backupSection),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(l10n.backupWorking, style: muted),
                  ],
                ),
              ),
            _backupRow(
              Icons.save_alt,
              l10n.backupCreate,
              l10n.backupCreateHelp,
              _export,
              muted,
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            _backupRow(
              Icons.restore,
              l10n.backupRestore,
              l10n.backupRestoreHelp,
              _restore,
              muted,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _backupRow(
    IconData icon,
    String title,
    String help,
    VoidCallback onTap,
    TextStyle muted,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      enabled: !_busy,
      leading: Icon(icon, size: 32, color: scheme.primary),
      title: Text(title, style: _title),
      subtitle: Text(help, style: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
    );
  }

  Widget _heading(String text, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(text, style: _title),
  );

  Widget _card(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _themeRadio(ThemeMode value, String title) => RadioListTile<ThemeMode>(
    key: Key('theme-${value.name}'),
    value: value,
    title: Text(title, style: const TextStyle(fontSize: 20)),
    contentPadding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
  );

  Widget _radio(AlarmVolumeMode value, String title) =>
      RadioListTile<AlarmVolumeMode>(
        value: value,
        title: Text(title, style: const TextStyle(fontSize: 20)),
        // The radio's own padding puts the circle in line with card text.
        contentPadding: const EdgeInsets.fromLTRB(6, 4, 16, 4),
      );
}
