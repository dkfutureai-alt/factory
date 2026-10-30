import 'package:flutter/material.dart';

/// Shared industrial design tokens. Avoid per-screen color or spacing forks.
abstract final class FactoryColors {
  static const navy = Color(0xFF0A2A43);
  static const blue = Color(0xFF0B6FFB);
  static const canvas = Color(0xFFF5F8FC);
  static const border = Color(0xFFDCE5EF);
  static const success = Color(0xFF168A45);
  static const warning = Color(0xFFB86A00);
  static const danger = Color(0xFFBA1A1A);
}

abstract final class FactorySpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class FactoryRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
}

/// A visual palette only. Authorized tenant branding is intentionally supplied
/// by a caller after server-side membership/branding validation; this class
/// never loads data or grants access to a factory.
class FactoryBrandPalette {
  const FactoryBrandPalette({this.primaryColor = FactoryColors.blue});

  final Color primaryColor;
}

abstract final class FactoryMotion {
  static const micro = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 220);

  /// Accessibility settings take precedence over decorative motion.
  static Duration effective(BuildContext context, Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
          ? Duration.zero
          : duration;
}

abstract final class FactoryLayout {
  /// Prefer one readable column on very small phones and with large text.
  static int metricColumns(BuildContext context, double width) {
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.5 || width < 420) {
      return 1;
    }
    if (width < 700) return 2;
    if (width < 1060) return 3;
    return 4;
  }
}

abstract final class FactoryTheme {
  static ThemeData light({
    FactoryBrandPalette brand = const FactoryBrandPalette(),
  }) => _build(brightness: Brightness.light, brand: brand);

  static ThemeData dark({
    FactoryBrandPalette brand = const FactoryBrandPalette(),
  }) => _build(brightness: Brightness.dark, brand: brand);

  static ThemeData _build({
    required Brightness brightness,
    required FactoryBrandPalette brand,
  }) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF14212D) : Colors.white;
    final canvas = dark ? const Color(0xFF0D1822) : FactoryColors.canvas;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand.primaryColor,
      brightness: brightness,
      surface: surface,
    );
    final outline = dark ? const Color(0xFF354758) : FactoryColors.border;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(FactoryRadius.md),
      borderSide: BorderSide(color: outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FactorySpacing.md,
          vertical: FactorySpacing.md,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FactoryRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FactoryRadius.md),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }
}
