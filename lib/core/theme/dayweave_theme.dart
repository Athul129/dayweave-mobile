import 'package:flutter/material.dart';

abstract final class DayweaveColors {
  static const ink = Color(0xFF1D2D35);
  static const inkSoft = Color(0xFF53636A);
  static const paper = Color(0xFFF6F3EB);
  static const bluePaper = Color(0xFFDCE9E9);
  static const card = Color(0xFFFFFDF7);
  static const marigold = Color(0xFFE8A229);
  static const sage = Color(0xFFC8D8C4);
  static const coral = Color(0xFFE69878);
  static const line = Color(0xFFD9DED8);
}

abstract final class DayweaveSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class DayweaveRadii {
  static const sm = BorderRadius.all(Radius.circular(7));
  static const md = BorderRadius.all(Radius.circular(10));
  static const lg = BorderRadius.all(Radius.circular(16));
}

abstract final class DayweaveTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: DayweaveColors.marigold,
      brightness: Brightness.light,
      surface: DayweaveColors.paper,
    ).copyWith(
      primary: DayweaveColors.ink,
      onPrimary: Colors.white,
      surface: DayweaveColors.paper,
      onSurface: DayweaveColors.ink,
      secondary: DayweaveColors.marigold,
      outline: DayweaveColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DayweaveColors.paper,
      fontFamily: 'DM Sans',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, color: DayweaveColors.ink),
        displayMedium: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, color: DayweaveColors.ink),
        headlineSmall: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, color: DayweaveColors.ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: DayweaveColors.ink),
        bodyLarge: TextStyle(color: DayweaveColors.inkSoft),
        bodyMedium: TextStyle(color: DayweaveColors.inkSoft),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DayweaveColors.paper,
        foregroundColor: DayweaveColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: DayweaveColors.card,
        elevation: 2,
        shadowColor: Color(0x14243B32),
        shape: RoundedRectangleBorder(borderRadius: DayweaveRadii.md),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: DayweaveColors.card,
        border: OutlineInputBorder(borderRadius: DayweaveRadii.sm, borderSide: BorderSide(color: DayweaveColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: DayweaveRadii.sm, borderSide: BorderSide(color: DayweaveColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: DayweaveRadii.sm, borderSide: BorderSide(color: DayweaveColors.marigold, width: 1.5)),
        contentPadding: EdgeInsets.symmetric(horizontal: DayweaveSpacing.lg, vertical: DayweaveSpacing.md),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DayweaveColors.card,
        indicatorColor: DayweaveColors.sage.withValues(alpha: .65),
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
