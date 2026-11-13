import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../speech/loudness.dart';
import 'elevenlabs_cache.dart';
import 'elevenlabs_client.dart';
import 'voice.dart';
import 'voice_engine.dart';

const elevenLabsFlashModel = 'eleven_flash_v2_5';
const elevenLabsExpressiveModel = 'eleven_v3';

/// An ElevenLabs voice that never leaves the user silent: a cache hit plays
/// offline; otherwise one request is made, and any failure (or an urgent
/// alarm row) is spoken by [fallback] instead, with the reason in
/// [lastFallback]. `load()` loads only the fallback (no network).
class ElevenLabsEngine implements VoiceEngine {
  ElevenLabsEngine({
    required this.voice,
    required this.client,
    required this.fallback,
    required this.fallbackVoice,
    required this.cache,
    this.modelId = defaultModel,
    this.tempDir,
  });

  static Future<String> defaultModel() async => elevenLabsFlashModel;

  final Voice voice;

  /// Null when no API key is stored: every utterance falls back (`badKey`).
  final ElevenLabsClient? client;
  final VoiceEngine fallback;

  /// What [fallback] speaks with, for the status dialog.
  final Voice fallbackVoice;
  final ElevenLabsCache cache;

  /// Resolved on every utterance, so the "expressive" switch applies at once.
  final Future<String> Function() modelId;

  /// Where playable copies are written (default: the system temp dir).
  final Directory? tempDir;

  /// Why the last utterance was spoken by the fallback; null after an
  /// ElevenLabs or cache utterance.
  ElevenLabsFailure? lastFallback;

  int _counter = 0;
  bool _disposed = false;

  @override
  int get loadMs => fallback.loadMs;

  @override
  bool get isLoaded => fallback.isLoaded;

  @override
  Future<void> load() => fallback.load();

  @override
  Future<SynthResult> synthesizeToWav(
    String text, {
    bool urgent = false,
  }) async {
    final sw = Stopwatch()..start();
    final model = await modelId();
    final id = voice.elevenLabsVoiceId;

    final hit = cache.lookup(id, model, text);
    if (hit != null) {
      try {
        final bytes = await hit.readAsBytes();
        final result = await _playable(bytes, sw);
        lastFallback = null;
        return result;
      } catch (_) {
        // Unreadable entry: treat as a miss.
      }
    }
    // An alarm never waits on the network.
    if (urgent) return fallback.synthesizeToWav(text, urgent: true);

    final c = client;
    if (c == null) return _fallBack(text, ElevenLabsFailure.badKey);
    final Uint8List wav;
    try {
      wav = await c.synthesize(text, id, model, voice.languageCode);
    } on ElevenLabsException catch (e) {
      return _fallBack(text, e.reason);
    } catch (_) {
      return _fallBack(text, ElevenLabsFailure.server);
    }
    await cache.put(id, model, text, wav);
    unawaited(cache.evict());
    try {
      final result = await _playable(wav, sw);
      lastFallback = null;
      return result;
    } catch (_) {
      return _fallBack(text, ElevenLabsFailure.server);
    }
  }

  Future<SynthResult> _fallBack(String text, ElevenLabsFailure why) async {
    final result = await fallback.synthesizeToWav(text);
    lastFallback = why;
    return result;
  }

  /// Writes [wav] to a fresh temp file (never the cache file), boosted when
  /// Hangosítás is on.
  Future<SynthResult> _playable(Uint8List wav, Stopwatch sw) async {
    final dir = tempDir ?? await getTemporaryDirectory();
    final path =
        '${dir.path}/eleven_${_counter++}_'
        '${DateTime.now().microsecondsSinceEpoch}.wav';
    await File(path).writeAsBytes(wav, flush: true);
    if (await speechBoostEnabled()) boostWavFile(path);
    final audioMs = wav.length <= 44 ? 0 : (wav.length - 44) * 1000 ~/ 44100;
    debugPrint('ElevenLabs synth: ${sw.elapsedMilliseconds} ms');
    return SynthResult(path, sw.elapsedMilliseconds, audioMs);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    fallback.dispose();
    client?.close();
  }
}
