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
ThemeData buildLightTheme() => _build(
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
  ),
);

/// Dark theme: the same layout in near-black blue-grey. Cards
/// (surfaceContainerLowest, as in light) are a step lighter than the
/// background, and the brand blue is lightened so text and icons in it stay
/// readable on dark (the Mondom button gets dark text).
ThemeData buildDarkTheme() => _build(
  ColorScheme.fromSeed(
    seedColor: _brandBlue,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: const Color(0xFF9DC3FF),
    onPrimary: const Color(0xFF0B2A52),
    surface: const Color(0xFF111418),
    onSurface: const Color(0xFFE4E8ED),
    onSurfaceVariant: const Color(0xFFAAB3BF),
    surfaceContainerLowest: const Color(0xFF1B1F25),
    surfaceContainerLow: const Color(0xFF181B20),
    surfaceContainer: const Color(0xFF20252C),
    surfaceContainerHigh: const Color(0xFF282D35),
    surfaceContainerHighest: const Color(0xFF30363F),
    outline: const Color(0xFF7A8492),
    outlineVariant: const Color(0xFF323944),
  ),
);

ThemeData _build(ColorScheme scheme) {
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
          fontSize: 18,
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
      style: TextButton.styleFrom(
        shape: kShape,
        textStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
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
    // Dialogs: card-coloured like the sheets, a bold title, readable body.
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 18,
        height: 1.35,
        color: scheme.onSurface,
      ),
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
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
    ),
  );
}
