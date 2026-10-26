import 'package:flutter/material.dart';

/// Quiet, high-contrast visual language for busy factory floors.
abstract final class FactoryColors {
  static const navy = Color(0xFF102A43);
  static const blue = Color(0xFF1769E0);
  static const canvas = Color(0xFFF4F7FB);
  static const border = Color(0xFFE0E8F1);
  static const muted = Color(0xFF5D6F83);
  static const softBlue = Color(0xFFE9F2FF);
  static const success = Color(0xFF147D4A);
  static const warning = Color(0xFF9B5A09);
  static const danger = Color(0xFFB42318);
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

abstract final class FactoryTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: FactoryColors.blue,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(
      primary: FactoryColors.blue,
      onPrimary: Colors.white,
      outline: FactoryColors.border,
      onSurface: FactoryColors.navy,
    );

    // Preserve every built-in Material text style; customize only the
    // hierarchy needed for operational screens.
    final baseText = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: FactoryColors.canvas,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: FactoryColors.canvas,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: FactoryColors.navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: baseText.copyWith(
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: FactoryColors.navy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: FactoryColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: FactoryColors.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: FactoryColors.navy,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FactorySpacing.md,
          vertical: FactorySpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.md),
          borderSide: const BorderSide(color: FactoryColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.md),
          borderSide: const BorderSide(color: FactoryColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.md),
          borderSide: const BorderSide(color: FactoryColors.blue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FactoryRadius.md),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: FactoryColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FactoryRadius.md),
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.lg),
          side: const BorderSide(color: FactoryColors.border),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 76,
        indicatorColor: FactoryColors.softBlue,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FactoryColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FactoryColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
