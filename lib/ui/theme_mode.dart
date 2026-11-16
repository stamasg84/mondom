import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeModeKey = 'themeMode';

/// Light / dark / follow the phone. Settings writes it, the app listens.
final themeModeSetting = ValueNotifier<ThemeMode>(ThemeMode.system);

/// Reads the saved choice (before the first frame, so there is no flash).
Future<void> loadThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(themeModeKey);
    themeModeSetting.value = ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  } catch (_) {}
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeSetting.value = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode.name);
  } catch (_) {}
}
