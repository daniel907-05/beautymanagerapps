import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Arial',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C3AED),
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F7FB),
  );
}