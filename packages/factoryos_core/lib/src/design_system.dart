import 'package:flutter/material.dart';

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

abstract final class FactoryTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: FactoryColors.blue,
      brightness: Brightness.light,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: FactoryColors.canvas,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.md),
          borderSide: const BorderSide(color: FactoryColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.md),
          borderSide: const BorderSide(color: FactoryColors.border),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FactoryRadius.lg),
          side: const BorderSide(color: FactoryColors.border),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
      ),
    );
  }
}
