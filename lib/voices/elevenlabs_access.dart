import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'elevenlabs_cache.dart';
import 'elevenlabs_client.dart';
import 'elevenlabs_engine.dart';
import 'elevenlabs_key_store.dart';

/// `shared_preferences` keys of the ElevenLabs settings.
const elevenLabsFallbackKey = 'elevenLabsFallbackVoiceId';
const elevenLabsExpressiveKey = 'elevenLabsExpressive';

/// What the picker and the setup screen need to talk to ElevenLabs: the key
/// store, a client factory (replaceable in tests) and the audio cache.
class ElevenLabsAccess {
  ElevenLabsAccess({
    required this.keyStore,
    required this.cache,
    ElevenLabsClient Function(String key)? clientFactory,
  }) : clientFactory =
           clientFactory ?? ((key) => ElevenLabsClient(http.Client(), key));

  final ElevenLabsKeyStore keyStore;
  final ElevenLabsCache cache;
  final ElevenLabsClient Function(String key) clientFactory;

  /// The model for the current "expressive" setting.
  Future<String> model() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(elevenLabsExpressiveKey) ?? false
        ? elevenLabsExpressiveModel
        : elevenLabsFlashModel;
  }

  /// A sample WAV of [text] (cache first, so it costs credits only once).
  /// Throws [ElevenLabsException] on failure or without a key.
  Future<Uint8List> sample(String voiceId, String text, String language) async {
    final model = await this.model();
    final hit = cache.lookup(voiceId, model, text);
    if (hit != null) {
      try {
        return await hit.readAsBytes();
      } catch (_) {}
    }
    final key = await keyStore.read();
    if (key == null) {
      throw const ElevenLabsException(ElevenLabsFailure.badKey);
    }
    final client = clientFactory(key);
    try {
      final wav = await client.synthesize(text, voiceId, model, language);
      await cache.put(voiceId, model, text, wav);
      return wav;
    } finally {
      client.close();
    }
  }
}
