import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogger {
  static Future<void> log({
    required String action,
    required String description,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from('activity_logs').insert({
        'user_id': user?.id,
        'action': action,
        'description': description,
      });
    } catch (_) {}
  }
}
