import 'package:flutter/material.dart';

class AppTheme {
  static const Color black = Color(0xFF0D0D0D);
  static const Color dark = Color(0xFF171717);
  static const Color charcoal = Color(0xFF242424);
  static const Color gold = Color(0xFFD4AF37);
  static const Color softGold = Color(0xFFF3E5AB);
  static const Color background = Color(0xFFF7F5EF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFF6B7280);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    fontFamily: 'Arial',
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.light,
      primary: gold,
      secondary: black,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: black,
        elevation: 0,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}
