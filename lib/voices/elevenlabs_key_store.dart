import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the user's ElevenLabs API key lives. Never `shared_preferences`, the
/// backup zip, logs or error messages.
abstract class ElevenLabsKeyStore {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> clear();
}

/// Android Keystore-backed storage (excluded from auto-backup, see the
/// manifest's backup rules).
class SecureElevenLabsKeyStore implements ElevenLabsKeyStore {
  SecureElevenLabsKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _name = 'elevenlabs_api_key';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    final v = await _storage.read(key: _name);
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> write(String key) => _storage.write(key: _name, value: key);

  @override
  Future<void> clear() => _storage.delete(key: _name);
}

/// For tests.
class InMemoryElevenLabsKeyStore implements ElevenLabsKeyStore {
  InMemoryElevenLabsKeyStore([this._key]);
  String? _key;

  @override
  Future<String?> read() async => _key;

  @override
  Future<void> write(String key) async => _key = key;

  @override
  Future<void> clear() async => _key = null;
}
