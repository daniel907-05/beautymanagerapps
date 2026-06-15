import 'package:supabase_flutter/supabase_flutter.dart';

class SalonSettings {
  static String salonName = 'BeautyManagerApps';
  static String salonPhone = '';
  static String salonEmail = '';
  static String salonAddress = '';
  static String currency = 'FCFA';
  static String receiptFooter = '';

  static Future<void> load() async {
    final response = await Supabase.instance.client
        .from('settings')
        .select()
        .limit(1)
        .maybeSingle();

    if (response == null) return;

    salonName = response['salon_name'] ?? 'BeautyManagerApps';
    salonPhone = response['salon_phone'] ?? '';
    salonEmail = response['salon_email'] ?? '';
    salonAddress = response['salon_address'] ?? '';
    currency = response['currency'] ?? 'FCFA';
    receiptFooter = response['receipt_footer'] ?? '';
  }
}
