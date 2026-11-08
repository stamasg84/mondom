import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../speech/recording_store.dart';
import '../speech/speaker.dart';
import '../speech/voice_recorder.dart';
import '../storage/lists_repository.dart';

/// A sentence to record: the row id and the text shown while recording.
class RecordingTarget {
  const RecordingTarget({required this.id, required this.text});
  final int id;
  final String text;
}

enum _Phase { idle, recording, review }

/// Records the own voice for [targets], one at a time. Tap to start, tap to
/// stop (never press-and-hold: weak hands). The new take replaces a row's old
/// recording only on Mentés, which is the only thing that touches the DB.
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.targets,
    required this.repo,
    required this.store,
    required this.speaker,
    required this.recorder,
    this.maxLength = maxRecordingLength,
    this.openSettings = openAppSettings,
    this.tempDir,
  });

  final List<RecordingTarget> targets;
  final ListsRepository repo;
  final RecordingStore store;
  final Speaker speaker;
  final VoiceRecorder recorder;
  final Duration maxLength;

  /// Opens the app's Android settings (microphone permission denied).
  final Future<void> Function() openSettings;

  /// Where takes are written before Mentés (default: the system temp dir).
  final Directory? tempDir;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.idle;
  int _index = 0;
  double _level = 0;
  bool _denied = false;
  bool _failed = false;
  bool _busy = false; // a start/stop/save is in flight
  String? _takePath;
  Timer? _limit;
  StreamSubscription<double>? _levels;

  RecordingTarget get _target => widget.targets[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _limit?.cancel();
    _levels?.cancel();
    if (_phase == _Phase.recording) {
      unawaited(widget.recorder.stop().catchError((_) => null));
    }
    unawaited(widget.recorder.dispose());
    unawaited(widget.speaker.stop());
    _deleteTake();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The microphone stops with the app; keep what was recorded so far.
    if (state == AppLifecycleState.paused && _phase == _Phase.recording) {
      _stopRecording();
    }
  }

  void _deleteTake() {
    final p = _takePath;
    _takePath = null;
    if (p == null) return;
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _denied = false;
      _failed = false;
    });
    try {
      // Nothing may play into the microphone.
      await widget.speaker.stop();
      if (!await widget.recorder.requestPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      _deleteTake();
      final dir = widget.tempDir ?? Directory.systemTemp;
      final path =
          '${dir.path}/mondom_take_${DateTime.now().microsecondsSinceEpoch}.wav';
      await widget.recorder.start(path);
      _takePath = path;
      _levels = widget.recorder.levels.listen((v) {
        if (mounted) setState(() => _level = v);
      });
      _limit = Timer(widget.maxLength, _stopRecording);
      if (mounted) {
        setState(() {
          _phase = _Phase.recording;
          _level = 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _stopRecording() async {
    if (_phase != _Phase.recording || _busy) return;
    _busy = true;
    _limit?.cancel();
    await _levels?.cancel();
    _levels = null;
    try {
      final path = await widget.recorder.stop();
      if (path != null) _takePath = path;
      if (!mounted) return;
      setState(() {
        _level = 0;
        if (_takePath == null) {
          _phase = _Phase.idle;
          _failed = true;
        } else {
          _phase = _Phase.review;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _failed = true;
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _listen() async {
    final p = _takePath;
    if (p != null) await widget.speaker.previewRecording(p);
  }

  Future<void> _again() async {
    await widget.speaker.stop();
    _deleteTake();
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  Future<void> _save() async {
    final p = _takePath;
    if (p == null || _busy) return;
    _busy = true;
    try {
      await widget.speaker.stop();
      final name = await widget.store.adopt(p);
      _takePath = null; // adopt moved it
      await widget.repo.setSentenceRecording(_target.id, name);
      if (!mounted) return;
      if (_index + 1 < widget.targets.length) {
        setState(() {
          _index++;
          _phase = _Phase.idle;
        });
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _busy = false;
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recordDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.recordDiscard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    if (_phase == _Phase.recording) {
      _limit?.cancel();
      await _levels?.cancel();
      _levels = null;
      try {
        await widget.recorder.stop();
      } catch (_) {}
      _phase = _Phase.idle; // dispose must not stop it again
    }
    _deleteTake();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _phase == _Phase.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.recordAction)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        _target.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_denied) ...[
                  Text(
                    l10n.micDenied,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  _big(
                    label: l10n.openAppSettings,
                    onPressed: widget.openSettings,
                    tonal: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_failed) ...[
                  Text(
                    l10n.recordFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: scheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                ..._controls(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(AppLocalizations l10n) {
    switch (_phase) {
      case _Phase.idle:
        return [
          _big(label: l10n.recordAction, icon: Icons.mic, onPressed: _start),
        ];
      case _Phase.recording:
        return [
          Row(
            children: [
              Icon(Icons.circle, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    key: const ValueKey('level'),
                    value: _level,
                    minHeight: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _big(
            label: l10n.recordDone,
            icon: Icons.stop,
            onPressed: _stopRecording,
          ),
        ];
      case _Phase.review:
        return [
          _big(
            label: l10n.recordListen,
            icon: Icons.play_arrow,
            onPressed: _listen,
            tonal: true,
          ),
          const SizedBox(height: 12),
          _big(
            label: l10n.recordAgain,
            icon: Icons.replay,
            onPressed: _again,
            tonal: true,
          ),
          const SizedBox(height: 12),
          _big(label: l10n.saveAction, icon: Icons.check, onPressed: _save),
        ];
    }
  }

  Widget _big({
    required String label,
    required Future<void> Function() onPressed,
    IconData? icon,
    bool tonal = false,
  }) {
    final text = Text(label, style: const TextStyle(fontSize: 26));
    final child = icon == null
        ? text
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, size: 32), const SizedBox(width: 12), text],
          );
    return SizedBox(
      height: 76,
      child: tonal
          ? FilledButton.tonal(onPressed: onPressed, child: child)
          : FilledButton(onPressed: onPressed, child: child),
    );
  }
}
