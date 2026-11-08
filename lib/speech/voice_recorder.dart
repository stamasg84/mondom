import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// Longest single take; the recording screen stops by itself then.
const maxRecordingLength = Duration(seconds: 60);

/// Microphone recording, abstracted so the recording screen can be tested
/// with a fake. Takes are WAV, 44100 Hz, mono, 16-bit.
abstract class VoiceRecorder {
  /// Asks for the microphone permission if needed; false = denied.
  Future<bool> requestPermission();

  /// Starts recording into the WAV file at [path].
  Future<void> start(String path);

  /// Stops and returns the finished file's path (null if nothing recorded).
  Future<String?> stop();

  /// Live input level, 0..1, while recording.
  Stream<double> get levels;

  Future<void> dispose();
}

/// [VoiceRecorder] backed by the `record` package. Auto gain, echo
/// cancellation and noise suppression are off: they pump the level and
/// smear speech, and the cleanup happens on playback anyway.
class RecordPackageRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 44100,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 80))
      // -60 dBFS (or lower) → empty bar, 0 dBFS → full.
      .map((a) => math.max(0.0, math.min(1.0, (a.current + 60) / 60)));

  @override
  Future<void> dispose() => _recorder.dispose();
}

const _settingsChannel = MethodChannel('mondom/app_settings');

/// Opens this app's page in Android settings.
Future<void> openAppSettings() async {
  try {
    await _settingsChannel.invokeMethod<bool>('open');
  } catch (_) {}
}
