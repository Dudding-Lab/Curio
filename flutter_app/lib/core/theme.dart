import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Kovunela's first shared Material 3 theme for mobile and web.
/// Contrast values and visual polish will be reviewed before release.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: KovunelaColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: dark
          ? scheme
          : scheme.copyWith(
              primary: KovunelaColors.primary,
              onPrimary: Colors.white,
              secondary: KovunelaColors.secondary,
              surface: KovunelaColors.warmSurface,
              onSurface: KovunelaColors.onLight,
            ),
      scaffoldBackgroundColor:
          dark ? scheme.surface : KovunelaColors.background,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KovunelaRadii.medium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovunelaRadii.small),
        ),
      ),
    );
  }
}
