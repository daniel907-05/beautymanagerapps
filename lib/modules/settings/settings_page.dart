import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool loading = true;
  bool saving = false;

  String? settingsId;

  final salonNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final currencyController = TextEditingController();
  final footerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    setState(() {
      loading = true;
    });

    final response = await Supabase.instance.client
        .from('settings')
        .select()
        .limit(1)
        .maybeSingle();

    if (response != null) {
      settingsId = response['id'];

      salonNameController.text = response['salon_name'] ?? '';

      phoneController.text = response['salon_phone'] ?? '';

      emailController.text = response['salon_email'] ?? '';

      addressController.text = response['salon_address'] ?? '';

      currencyController.text = response['currency'] ?? 'FCFA';

      footerController.text = response['receipt_footer'] ?? '';
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> saveSettings() async {
    setState(() {
      saving = true;
    });

    try {
      if (settingsId == null) {
        final result = await Supabase.instance.client
            .from('settings')
            .insert({
              'salon_name': salonNameController.text.trim(),
              'salon_phone': phoneController.text.trim(),
              'salon_email': emailController.text.trim(),
              'salon_address': addressController.text.trim(),
              'currency': currencyController.text.trim(),
              'receipt_footer': footerController.text.trim(),
            })
            .select()
            .single();

        settingsId = result['id'];
      } else {
        await Supabase.instance.client.from('settings').update({
          'salon_name': salonNameController.text.trim(),
          'salon_phone': phoneController.text.trim(),
          'salon_email': emailController.text.trim(),
          'salon_address': addressController.text.trim(),
          'currency': currencyController.text.trim(),
          'receipt_footer': footerController.text.trim(),
        }).eq(
          'id',
          settingsId!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Paramètres enregistrés',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur : $e',
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(30),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paramètres salon',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Informations générales utilisées dans les rapports et reçus',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: saving ? null : saveSettings,
                        icon: const Icon(Icons.save),
                        label: Text(
                          saving ? 'Enregistrement...' : 'Enregistrer',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        _SettingField(
                          width: 360,
                          controller: salonNameController,
                          label: 'Nom du salon',
                          icon: Icons.storefront,
                        ),
                        _SettingField(
                          width: 260,
                          controller: phoneController,
                          label: 'Téléphone',
                          icon: Icons.phone,
                        ),
                        _SettingField(
                          width: 320,
                          controller: emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                        ),
                        _SettingField(
                          width: 220,
                          controller: currencyController,
                          label: 'Devise',
                          icon: Icons.payments_outlined,
                        ),
                        _SettingField(
                          width: 520,
                          controller: addressController,
                          label: 'Adresse',
                          icon: Icons.location_on_outlined,
                        ),
                        _SettingField(
                          width: 520,
                          controller: footerController,
                          label: 'Texte bas de reçu / PDF',
                          icon: Icons.notes_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.dark,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.gold,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Le logo et les informations du salon seront ensuite utilisés automatiquement dans les PDF, impressions et rapports.',
                            style: TextStyle(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SettingField extends StatelessWidget {
  final double width;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  const _SettingField({
    required this.width,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
