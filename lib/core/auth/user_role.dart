import 'package:supabase_flutter/supabase_flutter.dart';

class UserRole {
  static String? currentRole;

  static Future<void> loadRole() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    currentRole = profile?['role'];
  }

  static bool get isAdmin => currentRole == 'admin';

  static bool get isManager => currentRole == 'manager';

  static bool get isCashier => currentRole == 'cashier';

  static bool get isEmployee => currentRole == 'employee';
}
