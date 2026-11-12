import 'package:flutter/material.dart';

/// Visual presentation mode for Sampan.
enum SampanVisualMode {
  /// Default airy lavender & electric violet Material 3 Expressive light mode.
  light,

  /// Deep cosmic violet Material 3 Expressive dark mode.
  dark,

  /// One-tap Sunlight High-Contrast mode (`> 7:1` contrast ratio & bold font
  /// weights) for reading under direct outdoor sunlight.
  sunlightHighContrast,
}

/// Material Design 3 Expressive Token System (`ui-ux-pro-max` Three-Layer
/// Architecture: Primitive → Semantic → Component).
///
/// Built around the official Sampan brand palette:
/// - Electric Violet (`#6755EF`)
/// - Acid Lime / Chartreuse (`#F4FF90`)
/// - Soft Lavender Containers (`#DDD4FF` / `#EFEAFF` / `#F7F5FF`)
class SampanTheme {
  const SampanTheme._();

  // ===========================================================================
  // Layer 1: Primitive Tokens (Raw Brand & Palette Values)
  // ===========================================================================
  static const Color brandViolet = Color(0xFF6755EF);
  static const Color brandLime = Color(0xFFF4FF90);

  static const Color violet700 = Color(0xFF4F3CD6);
  static const Color violet300 = Color(0xFFB9AEFF);
  static const Color violet900 = Color(0xFF1B1145);
  static const Color violet950 = Color(0xFF0E0A1F);

  static const Color lavender50 = Color(0xFFF7F5FF);
  static const Color lavender100 = Color(0xFFEFEAFF);
  static const Color lavender200 = Color(0xFFDDD4FF);
  static const Color lavender300 = Color(0xFFC8B9FF);

  static const Color darkSurfaceCard = Color(0xFF1A1433);
  static const Color darkSurfaceHigh = Color(0xFF261E4A);

  static const Color limeInk = Color(0xFF1F2400);
  static const Color limeContainerLight = Color(0xFFF4FF90);
  static const Color limeContainerDark = Color(0xFFDCE868);

  static const Color alertRedLight = Color(0xFFBA1A1A);
  static const Color alertRedDark = Color(0xFFFF5449);

  // ===========================================================================
  // Layer 2: Semantic Spacing & Shape Tokens (Material Design 3 Expressive)
  // ===========================================================================
  static const double spaceXs = 6.0;
  static const double spaceSm = 10.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  static const double radiusSm = 16.0;
  static const double radiusMd = 24.0;
  static const double radiusLg = 32.0;
  static const double radiusPill = 999.0;

  // Backward-compatible semantic aliases
  static const Color oceanDeepLight = brandViolet;
  static const Color oceanDeepDark = violet700;
  static const Color primaryContainerLight = lavender200;
  static const Color primaryContainerDark = darkSurfaceHigh;
  static const Color sunsetAmberLight = brandLime;
  static const Color sunsetAmberDark = brandLime;
  static const Color seafoamGreen = Color(0xFF00A896);
  static const Color sandyDuneLight = lavender50;
  static const Color sandyDuneDark = violet950;
  static const Color lifeguardRedLight = alertRedLight;
  static const Color lifeguardRedDark = alertRedDark;

  static ThemeData buildTheme(SampanVisualMode mode) {
    return switch (mode) {
      SampanVisualMode.light => _buildLightTheme(),
      SampanVisualMode.dark => _buildDarkTheme(),
      SampanVisualMode.sunlightHighContrast =>
        _buildSunlightHighContrastTheme(),
    };
  }

  // ===========================================================================
  // Layer 3: Component Themes (Light, Dark & Sunlight High-Contrast)
  // ===========================================================================
  static ThemeData _buildLightTheme() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: brandViolet,
      onPrimary: Colors.white,
      primaryContainer: lavender200,
      onPrimaryContainer: violet900,
      secondary: violet700,
      onSecondary: Colors.white,
      secondaryContainer: brandLime,
      onSecondaryContainer: limeInk,
      tertiary: limeInk,
      onTertiary: brandLime,
      tertiaryContainer: brandLime,
      onTertiaryContainer: limeInk,
      error: alertRedLight,
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: lavender50,
      onSurface: violet900,
      surfaceContainerHighest: lavender100,
      onSurfaceVariant: Color(0xFF564C7A),
      outline: Color(0xFFB5A9E0),
      outlineVariant: Color(0xFFE2DCFA),
    );

    return _applyComponentTokens(
      scheme: scheme,
      scaffoldBg: lavender50,
      cardBg: lavender100,
      sheetBg: lavender50,
      navIndicator: lavender200,
    );
  }

  static ThemeData _buildDarkTheme() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brandViolet,
      onPrimary: Colors.white,
      primaryContainer: darkSurfaceHigh,
      onPrimaryContainer: lavender200,
      secondary: brandLime,
      onSecondary: limeInk,
      secondaryContainer: Color(0xFF332966),
      onSecondaryContainer: brandLime,
      tertiary: brandLime,
      onTertiary: limeInk,
      tertiaryContainer: brandLime,
      onTertiaryContainer: limeInk,
      error: alertRedDark,
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: violet950,
      onSurface: Color(0xFFF3F0FF),
      surfaceContainerHighest: darkSurfaceCard,
      onSurfaceVariant: Color(0xFFBDB3E6),
      outline: Color(0xFF4B3F78),
      outlineVariant: Color(0xFF2B224D),
    );

    return _applyComponentTokens(
      scheme: scheme,
      scaffoldBg: violet950,
      cardBg: darkSurfaceCard,
      sheetBg: darkSurfaceCard,
      navIndicator: darkSurfaceHigh,
    );
  }

  static ThemeData _buildSunlightHighContrastTheme() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF28157A),
      onPrimary: Colors.white,
      primaryContainer: brandLime,
      onPrimaryContainer: Colors.black,
      secondary: Colors.black,
      onSecondary: brandLime,
      secondaryContainer: brandLime,
      onSecondaryContainer: Colors.black,
      tertiary: Colors.black,
      onTertiary: brandLime,
      tertiaryContainer: brandLime,
      onTertiaryContainer: Colors.black,
      error: Color(0xFF990000),
      onError: Colors.white,
      errorContainer: Color(0xFFFFCDD2),
      onErrorContainer: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      surfaceContainerHighest: Color(0xFFF0EEFF),
      onSurfaceVariant: Colors.black,
      outline: Colors.black,
      outlineVariant: Colors.black,
    );

    final TextTheme boldText = Typography.blackMountainView.apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
    );

    final ThemeData base = _applyComponentTokens(
      scheme: scheme,
      scaffoldBg: Colors.white,
      cardBg: const Color(0xFFF2EFFF),
      sheetBg: Colors.white,
      navIndicator: brandLime,
    );

    return base.copyWith(
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
          fontSize: 22,
        ),
      ),
    );
  }

  static ThemeData _applyComponentTokens({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color cardBg,
    required Color sheetBg,
    required Color navIndicator,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: spaceMd,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: navIndicator,
        height: 70,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBg,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: scheme.onPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }
}
