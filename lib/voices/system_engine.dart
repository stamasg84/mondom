import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../speech/loudness.dart';
import 'voice.dart';
import 'voice_engine.dart';

/// Android system TTS, rendered to a WAV file so playback works like Piper.
class SystemEngine implements VoiceEngine {
  SystemEngine(this.voice);

  final Voice voice;
  final _tts = FlutterTts();
  bool _loaded = false;
  int _counter = 0;

  @override
  int loadMs = 0;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> load() async {
    final sw = Stopwatch()..start();
    // Make synthesizeToFile's future complete when the file is written.
    await _tts.awaitSynthCompletion(true);
    await _tts.setLanguage(voice.languageCode);
    _loaded = true;
    loadMs = sw.elapsedMilliseconds;
    debugPrint('System TTS load: $loadMs ms');
  }

  @override
  Future<SynthResult> synthesizeToWav(
    String text, {
    bool urgent = false,
    double speed = 1.0,
  }) async {
    if (!_loaded) throw StateError('TTS not loaded');
    final tmp = await getTemporaryDirectory();
    final path = '${tmp.path}/sys_${_counter++}.wav';
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    // flutter_tts on Android maps 0.5 to the normal rate 1.0.
    await _tts.setSpeechRate(speed / 2);
    final sw = Stopwatch()..start();
    // isFullPath: true writes to the given path (app cache, no permission).
    final result = await _tts.synthesizeToFile(text, path, true);
    final synthMs = sw.elapsedMilliseconds;
    if (result != 1 || !file.existsSync() || file.lengthSync() <= 44) {
      throw FileSystemException('System TTS produced no audio', path);
    }
    if (await speechBoostEnabled()) boostWavFile(path);
    final audioMs = _wavDurationMs(file);
    debugPrint('System TTS synth: $synthMs ms for $audioMs ms of audio');
    return SynthResult(path, synthMs, audioMs);
  }

  /// Duration from the WAV header (byte rate at offset 28, PCM data after
  /// the 44-byte header; good enough for timing display).
  int _wavDurationMs(File f) {
    final bytes = f.readAsBytesSync();
    if (bytes.length < 44) return 0;
    final byteRate = ByteData.sublistView(bytes).getUint32(28, Endian.little);
    if (byteRate == 0) return 0;
    return (bytes.length - 44) * 1000 ~/ byteRate;
  }

  @override
  void dispose() {
    _tts.stop();
    _loaded = false;
  }
}
