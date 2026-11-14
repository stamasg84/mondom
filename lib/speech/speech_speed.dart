import 'package:shared_preferences/shared_preferences.dart';

const speechSpeedMin = 0.7;
const speechSpeedMax = 1.3;
const speechSpeedStep = 0.05;

/// Speech speed is stored per voice (some voices talk faster than others).
String speechSpeedKey(String voiceId) => 'speechSpeed:$voiceId';

/// The stored speed of [voiceId] (1.0 by default), clamped to the slider range.
Future<double> speechSpeed(String voiceId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(speechSpeedKey(voiceId)) ?? 1.0;
    return v.clamp(speechSpeedMin, speechSpeedMax).toDouble();
  } catch (_) {
    return 1.0;
  }
}

/// Stores [speed] for [voiceId]; 1.0 removes the entry.
Future<void> setSpeechSpeed(String voiceId, double speed) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if ((speed - 1.0).abs() < 0.001) {
      await prefs.remove(speechSpeedKey(voiceId));
    } else {
      await prefs.setDouble(speechSpeedKey(voiceId), speed);
    }
  } catch (_) {}
}
