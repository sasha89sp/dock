import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF0D1220);
  static const panel = Color(0xFF171F30);
  static const elevated = Color(0xFF202B40);
  static const accent = Color(0xFF63B3FF);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: panel,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(color: panel, elevation: 0),
        sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.always),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: elevated,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      );
}
