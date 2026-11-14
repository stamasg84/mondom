import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../speech/alarm_volume.dart';
import '../speech/loudness.dart';
import '../speech/speaker.dart';
import '../speech/speech_speed.dart';
import '../storage/backup.dart';
import '../voices/voice.dart';

/// Small sound settings: speech boost, and the alarm volume (the phone's own
/// level, or Mondom's own level raised while an alarm plays, restored after).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.alarmVolume,
    required this.speaker,
    this.backup,
    this.voice,
    this.sampleText,
  });

  final AlarmVolume alarmVolume;
  final Speaker speaker;

  /// Null hides the backup section.
  final BackupService? backup;

  /// The selected voice; null hides the speed slider.
  final Voice? voice;

  /// Said when the speed slider is released.
  final String? sampleText;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AlarmVolumeMode? _mode;
  double _level = 1.0;
  bool _boost = true;
  bool _busy = false;
  double _speed = 1.0;

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
    final v = widget.voice;
    final speed = v == null ? 1.0 : await speechSpeed(v.id);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _level = level;
      _boost = boost;
      _speed = speed;
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

  Future<void> _saveSpeed(double v) async {
    final voice = widget.voice;
    if (voice == null) return;
    await setSpeechSpeed(voice.id, v);
    // Hear the new speed.
    final text = widget.sampleText;
    if (text != null && text.isNotEmpty) await widget.speaker.speak(text);
  }

  Future<void> _resetSpeed() async {
    setState(() => _speed = 1.0);
    await _saveSpeed(1.0);
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
    final mode = _mode;
    final playing = widget.speaker.alarmPlaying;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: mode == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  _header(l10n.settingsSpeechSection),
                  SwitchListTile(
                    value: _boost,
                    onChanged: _setBoost,
                    title: Text(
                      l10n.settingsBoostTitle,
                      style: const TextStyle(fontSize: 22),
                    ),
                    subtitle: Text(
                      l10n.settingsBoostHelp,
                      style: const TextStyle(fontSize: 16),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  if (widget.voice != null) ..._speedSection(l10n),
                  _header(l10n.settingsAlarmSection),
                  RadioGroup<AlarmVolumeMode>(
                    groupValue: mode,
                    onChanged: _setMode,
                    child: Column(
                      children: [
                        _radio(AlarmVolumeMode.system, l10n.alarmVolumeSystem),
                        _radio(AlarmVolumeMode.custom, l10n.alarmVolumeCustom),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: _level,
                      onChanged: mode == AlarmVolumeMode.custom
                          ? (v) => setState(() => _level = v)
                          : null,
                      onChangeEnd: widget.alarmVolume.setLevel,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 64,
                      child: playing
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
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
                              icon: const Icon(Icons.campaign, size: 32),
                              label: Text(
                                l10n.alarmVolumeTest,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                    ),
                  ),
                  if (widget.backup != null) ..._backupSection(l10n),
                ],
              ),
      ),
    );
  }

  List<Widget> _speedSection(AppLocalizations l10n) {
    final v = widget.voice!;
    final name = v.kind == VoiceKind.system ? l10n.systemVoice : v.label;
    const divisions =
        ((speechSpeedMax - speechSpeedMin) / speechSpeedStep + 0.5) ~/ 1;
    return [
      ListTile(
        title: Text(
          l10n.settingsSpeedTitle,
          style: const TextStyle(fontSize: 22),
        ),
        subtitle: Text(
          l10n.settingsSpeedFor(name),
          style: const TextStyle(fontSize: 16),
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Slider(
          key: const Key('speech-speed'),
          value: _speed.clamp(speechSpeedMin, speechSpeedMax).toDouble(),
          min: speechSpeedMin,
          max: speechSpeedMax,
          divisions: divisions,
          onChanged: (x) => setState(() => _speed = x),
          onChangeEnd: (x) => _saveSpeed((x * 100).round() / 100),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.settingsSpeedSlower,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              l10n.settingsSpeedFaster,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      if ((_speed - 1.0).abs() > 0.001)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              key: const Key('speech-speed-reset'),
              onPressed: _resetSpeed,
              child: Text(
                l10n.settingsSpeedReset,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _backupSection(AppLocalizations l10n) => [
    _header(l10n.backupSection),
    if (_busy)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(l10n.backupWorking, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    ListTile(
      enabled: !_busy,
      leading: const Icon(Icons.save_alt, size: 32),
      title: Text(l10n.backupCreate, style: const TextStyle(fontSize: 22)),
      subtitle: Text(
        l10n.backupCreateHelp,
        style: const TextStyle(fontSize: 16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: _export,
    ),
    ListTile(
      enabled: !_busy,
      leading: const Icon(Icons.restore, size: 32),
      title: Text(l10n.backupRestore, style: const TextStyle(fontSize: 22)),
      subtitle: Text(
        l10n.backupRestoreHelp,
        style: const TextStyle(fontSize: 16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: _restore,
    ),
  ];

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _radio(AlarmVolumeMode value, String title) =>
      RadioListTile<AlarmVolumeMode>(
        value: value,
        title: Text(title, style: const TextStyle(fontSize: 22)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
}
