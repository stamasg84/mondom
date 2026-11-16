import 'package:flutter/material.dart';

/// The one corner radius used everywhere (chips, rows, buttons, fields), so
/// the screens read as one design instead of mixed shapes.
const kRadius = 16.0;
final kBorderRadius = BorderRadius.circular(kRadius);
final kShape = RoundedRectangleBorder(borderRadius: kBorderRadius);

/// The steel blue of the app icon's background, darkened enough for white
/// text on it (contrast > 6:1).
const _brandBlue = Color(0xFF1D5DB0);

/// Atkinson Hyperlegible Next (SIL OFL 1.1), bundled in assets/fonts.
/// Designed for low-vision readers; covers Hungarian ő/ű and Swedish å.
const _font = 'AtkinsonHyperlegibleNext';

/// Light theme: calm cool-grey base, white cards, the icon's blue as the
/// only strong colour (selected chip, Mondom button, focus).
ThemeData buildLightTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: _brandBlue,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ).copyWith(
        primary: _brandBlue,
        onPrimary: Colors.white,
        surface: const Color(0xFFF3F5F8),
        onSurface: const Color(0xFF1A1F26),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFEDF0F4),
        surfaceContainer: const Color(0xFFE8EBF0),
        surfaceContainerHigh: const Color(0xFFE2E6EC),
        surfaceContainerHighest: const Color(0xFFDCE1E8),
        outline: const Color(0xFF8A93A0),
        outlineVariant: const Color(0xFFD3D9E1),
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: _font,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: kShape,
        textStyle: const TextStyle(
          fontFamily: _font,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: kShape,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: kShape),
    ),
    chipTheme: ChipThemeData(
      shape: kShape,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primary,
    ),
    cardTheme: CardThemeData(
      shape: kShape,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: kBorderRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: kBorderRadius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kBorderRadius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
