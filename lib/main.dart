import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/login_page.dart';

void main() {
  runApp(const BeautyManagerApp());
}

class BeautyManagerApp extends StatelessWidget {
  const BeautyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeautyManager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}