import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../speech/loudness.dart';
import 'voice_engine.dart';

/// Wraps sherpa-onnx OfflineTts for one Piper voice directory.
///
/// The `OfflineTts` (FFI pointers) lives in a long-lived background isolate,
/// so neither model loading nor synthesis blocks the UI. Requests are handled
/// in order by the isolate, so a request sent while the model is still
/// loading simply waits for the load to finish.
class PiperEngine implements VoiceEngine {
  PiperEngine({
    required this.voiceDir,
    required this.espeakDataDir,
    required this.modelFile,
    this.lengthScale = 1.2,
  });

  /// Installed voice directory (model, tokens.txt) and the shared
  /// espeak-ng-data directory, see `VoiceInstaller`.
  final String voiceDir;
  final String espeakDataDir;
  final String modelFile;

  /// 1.2 sounds best for imre (see measurements.md).
  final double lengthScale;

  Isolate? _isolate;
  SendPort? _toIsolate;
  ReceivePort? _fromIsolate;
  Completer<void>? _ready;
  final _pending = <int, Completer<SynthResult>>{};
  int _nextId = 0;
  String? _tmpDir;
  bool _loaded = false;
  bool _disposed = false;

  @override
  int loadMs = 0;

  @override
  bool get isLoaded => _loaded;

  /// Spawns the isolate and loads the model there. Completes when the model
  /// is ready; throws if loading failed.
  @override
  Future<void> load() async {
    if (_disposed) throw StateError('Engine disposed');
    final existing = _ready;
    if (existing != null) return existing.future;
    final ready = _ready = Completer<void>();
    try {
      _tmpDir = (await getTemporaryDirectory()).path;
      final receive = _fromIsolate = ReceivePort();
      receive.listen(_onMessage);
      _isolate = await Isolate.spawn(
        _isolateMain,
        _InitMessage(
          reply: receive.sendPort,
          modelPath: '$voiceDir/$modelFile',
          tokensPath: '$voiceDir/tokens.txt',
          espeakDataDir: espeakDataDir,
          lengthScale: lengthScale,
        ),
      );
    } catch (e, st) {
      if (!ready.isCompleted) ready.completeError(e, st);
    }
    return ready.future;
  }

  void _onMessage(dynamic msg) {
    switch (msg) {
      case SendPort port:
        _toIsolate = port;
      case _LoadedMessage m:
        loadMs = m.loadMs;
        _loaded = true;
        debugPrint('TTS load (background): $loadMs ms');
        _ready?.complete();
      case _LoadFailedMessage m:
        _ready?.completeError(StateError(m.error));
      case _SynthDone m:
        _pending
            .remove(m.id)
            ?.complete(SynthResult(m.path, m.synthMs, m.audioMs));
        debugPrint(
          'TTS synth: ${m.synthMs} ms for ${m.audioMs} ms of audio '
          '(RTF ${(m.synthMs / (m.audioMs == 0 ? 1 : m.audioMs)).toStringAsFixed(2)})',
        );
      case _SynthFailed m:
        _pending.remove(m.id)?.completeError(StateError(m.error));
    }
  }

  @override
  Future<SynthResult> synthesizeToWav(
    String text, {
    bool urgent = false,
    double speed = 1.0,
  }) async {
    if (_disposed || _ready == null) throw StateError('TTS not loaded');
    // Wait for the load (requests arriving mid-load wait here).
    await _ready!.future;
    final port = _toIsolate;
    if (_disposed || port == null) throw StateError('TTS not loaded');
    final boost = await speechBoostEnabled();
    if (_disposed) throw StateError('TTS not loaded');
    final id = _nextId++;
    final completer = _pending[id] = Completer<SynthResult>();
    port.send(_SynthRequest(id, text, '$_tmpDir/tts_$id.wav', boost, speed));
    return completer.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _loaded = false;
    // Ask the isolate to free the native model and exit; kill as a fallback
    // if it never got as far as listening.
    _toIsolate?.send(const _DisposeRequest());
    if (_toIsolate == null) _isolate?.kill(priority: Isolate.immediate);
    _fromIsolate?.close();
    _fromIsolate = null;
    for (final c in _pending.values) {
      c.completeError(StateError('Engine disposed'));
    }
    _pending.clear();
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('Engine disposed'));
    }
  }
}

// ---- Messages between the UI isolate and the TTS isolate ----

class _InitMessage {
  const _InitMessage({
    required this.reply,
    required this.modelPath,
    required this.tokensPath,
    required this.espeakDataDir,
    required this.lengthScale,
  });
  final SendPort reply;
  final String modelPath;
  final String tokensPath;
  final String espeakDataDir;
  final double lengthScale;
}

class _LoadedMessage {
  const _LoadedMessage(this.loadMs);
  final int loadMs;
}

class _LoadFailedMessage {
  const _LoadFailedMessage(this.error);
  final String error;
}

class _SynthRequest {
  const _SynthRequest(this.id, this.text, this.path, this.boost, this.speed);
  final int id;
  final bool boost;
  final double speed;
  final String text;
  final String path;
}

class _SynthDone {
  const _SynthDone(this.id, this.path, this.synthMs, this.audioMs);
  final int id;
  final String path;
  final int synthMs;
  final int audioMs;
}

class _SynthFailed {
  const _SynthFailed(this.id, this.error);
  final int id;
  final String error;
}

class _DisposeRequest {
  const _DisposeRequest();
}

/// Entry point of the TTS isolate: owns the `OfflineTts` for its lifetime.
void _isolateMain(_InitMessage init) {
  final commands = ReceivePort();
  // Handshake first so the UI can queue requests while the model loads;
  // they are delivered to [commands] and handled after the load below.
  init.reply.send(commands.sendPort);

  sherpa.OfflineTts? tts;
  try {
    final sw = Stopwatch()..start();
    sherpa.initBindings();
    tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: init.modelPath,
            tokens: init.tokensPath,
            dataDir: init.espeakDataDir,
            lengthScale: init.lengthScale,
          ),
          numThreads: 2,
          debug: false,
        ),
      ),
    );
    init.reply.send(_LoadedMessage(sw.elapsedMilliseconds));
  } catch (e) {
    init.reply.send(_LoadFailedMessage('$e'));
    commands.close();
    return;
  }

  commands.listen((msg) {
    if (msg is _SynthRequest) {
      try {
        final sw = Stopwatch()..start();
        final audio = tts!.generate(text: msg.text, sid: 0, speed: msg.speed);
        final synthMs = sw.elapsedMilliseconds;
        final ok = sherpa.writeWave(
          filename: msg.path,
          samples: msg.boost
              ? boostLoudness(audio.samples, sampleRate: audio.sampleRate)
              : audio.samples,
          sampleRate: audio.sampleRate,
        );
        if (!ok) throw FileSystemException('Failed to write WAV', msg.path);
        final audioMs = audio.samples.length * 1000 ~/ audio.sampleRate;
        init.reply.send(_SynthDone(msg.id, msg.path, synthMs, audioMs));
      } catch (e) {
        init.reply.send(_SynthFailed(msg.id, '$e'));
      }
    } else if (msg is _DisposeRequest) {
      tts?.free();
      tts = null;
      commands.close();
    }
  });
}
