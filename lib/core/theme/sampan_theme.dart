import 'package:flutter/material.dart';

/// Visual presentation mode for Sampan (Section 2.1 & 2.2).
enum SampanVisualMode {
  /// Default warm beach sand light mode (`#FAF8F5`).
  light,

  /// Deep maritime night mode (`#0F1416`).
  dark,

  /// One-tap Sunlight High-Contrast mode (`> 7:1` contrast ratio & bold font
  /// weights) for reading under direct tropical sunlight.
  sunlightHighContrast,
}

/// Coastal Maritime Color Palette & Playful Material Design 3 Theme
/// (Section 2 of `SAMPAN_BLUEPRINT.md`).
class SampanTheme {
  const SampanTheme._();

  // Section 2.1 Token Roles
  static const Color oceanDeepLight = Color(0xFF004D5A);
  static const Color oceanDeepDark = Color(0xFF006877);
  static const Color primaryContainerLight = Color(0xFFA1EFFF);
  static const Color primaryContainerDark = Color(0xFF002D34);

  static const Color sunsetAmberLight = Color(0xFFE08244);
  static const Color sunsetAmberDark = Color(0xFFF4A261);

  static const Color seafoamGreen = Color(0xFF2A9D8F);

  static const Color sandyDuneLight = Color(0xFFFAF8F5);
  static const Color sandyDuneDark = Color(0xFF0F1416);

  static const Color lifeguardRedLight = Color(0xFFBA1A1A);
  static const Color lifeguardRedDark = Color(0xFFFF5449);

  static ThemeData buildTheme(SampanVisualMode mode) {
    return switch (mode) {
      SampanVisualMode.light => _buildLightTheme(),
      SampanVisualMode.dark => _buildDarkTheme(),
      SampanVisualMode.sunlightHighContrast => _buildSunlightHighContrastTheme(),
    };
  }

  static ThemeData _buildLightTheme() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: oceanDeepLight,
      onPrimary: Colors.white,
      primaryContainer: primaryContainerLight,
      onPrimaryContainer: Color(0xFF001F25),
      secondary: sunsetAmberLight,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFDCC6),
      onSecondaryContainer: Color(0xFF301400),
      tertiary: seafoamGreen,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFB4F1E8),
      onTertiaryContainer: Color(0xFF00201C),
      error: lifeguardRedLight,
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: sandyDuneLight,
      onSurface: Color(0xFF171C1E),
      onSurfaceVariant: Color(0xFF3F484B),
      outline: Color(0xFF6F797B),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: sandyDuneLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: sandyDuneLight,
        foregroundColor: oceanDeepLight,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: sandyDuneLight,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryContainerLight,
      onPrimary: primaryContainerDark,
      primaryContainer: oceanDeepDark,
      onPrimaryContainer: primaryContainerLight,
      secondary: sunsetAmberDark,
      onSecondary: Color(0xFF4C2600),
      secondaryContainer: Color(0xFF6C3A0D),
      onSecondaryContainer: Color(0xFFFFDCC6),
      tertiary: Color(0xFF56D6C7),
      onTertiary: Color(0xFF003731),
      tertiaryContainer: seafoamGreen,
      onTertiaryContainer: Color(0xFFB4F1E8),
      error: lifeguardRedDark,
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: sandyDuneDark,
      onSurface: Color(0xFFE1E3E4),
      onSurfaceVariant: Color(0xFFBFC8CB),
      outline: Color(0xFF899295),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: sandyDuneDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: sandyDuneDark,
        foregroundColor: primaryContainerLight,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF182125),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  /// High-contrast outdoor beach mode (>7:1 WCAG AAA contrast ratio + bold weights)
  /// for direct tropical sunlight (Section 2.2).
  static ThemeData _buildSunlightHighContrastTheme() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF002B33),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF004D5A),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF8C3B00),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFE082),
      onSecondaryContainer: Colors.black,
      tertiary: Color(0xFF004D40),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF80CBC4),
      onTertiaryContainer: Colors.black,
      error: Color(0xFF990000),
      onError: Colors.white,
      errorContainer: Color(0xFFFFCDD2),
      onErrorContainer: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black,
      outline: Colors.black,
    );

    final TextTheme boldText = Typography.blackMountainView.apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      textTheme: boldText.copyWith(
        bodyLarge: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        bodyMedium: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        titleMedium: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
        titleLarge: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 21,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Colors.black, width: 2.5),
        ),
      ),
    );
  }
}
