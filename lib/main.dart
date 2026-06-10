import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'modules/auth/login_page.dart';
import 'modules/employees/employees_page.dart';

const supabaseUrl = 'https://tnysncxjbfgmwtlbdgzk.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRueXNuY3hqYmZnbXd0bGJkZ3prIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NDMyNzIsImV4cCI6MjA5NjAxOTI3Mn0.wABr-JR2XowpkWj7-z8DAfGx_4I1OkxPNyaXRYbnO-Q';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

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
