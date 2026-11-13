/// Result of one synthesis: WAV path plus timings.
class SynthResult {
  const SynthResult(this.path, this.synthMs, this.audioMs);

  final String path;
  final int synthMs;
  final int audioMs;

  double get rtf => audioMs == 0 ? 0 : synthMs / audioMs;
}

/// Everything above the voice layer (UI, tiles) uses only this.
abstract class VoiceEngine {
  /// Duration of the last [load] call in ms.
  int get loadMs;

  bool get isLoaded;

  Future<void> load();

  /// Synthesizes [text] into a WAV file and returns its path and timings.
  /// [urgent] (alarm rows) must never wait on the network; only the
  /// ElevenLabs engine cares, the others ignore it.
  Future<SynthResult> synthesizeToWav(String text, {bool urgent = false});

  void dispose();
}
