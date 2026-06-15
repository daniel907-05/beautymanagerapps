import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool loading = true;
  bool saving = false;

  List profiles = [];

  final roles = const [
    'admin',
    'manager',
    'cashier',
    'employee',
  ];

  @override
  void initState() {
    super.initState();
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    setState(() {
      loading = true;
    });

    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      profiles = response;
      loading = false;
    });
  }

  Future<void> updateRole(
    String profileId,
    String role,
  ) async {
    setState(() {
      saving = true;
    });

    try {
      await Supabase.instance.client.from('profiles').update({
        'role': role,
      }).eq(
        'id',
        profileId,
      );

      await loadProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rôle mis à jour'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
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

  String roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'manager':
        return 'Manager';
      case 'cashier':
        return 'Caissière';
      case 'employee':
        return 'Employé';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(30),
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
                      'Administration',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gestion des utilisateurs et des rôles',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: loadProfiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : profiles.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun utilisateur trouvé',
                          ),
                        )
                      : ListView.separated(
                          itemCount: profiles.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final profile = profiles[index];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.15),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.gold,
                                ),
                              ),
                              title: Text(
                                profile['full_name'] ?? 'Sans nom',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                profile['id'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  value: profile['role'],
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  items: roles
                                      .map(
                                        (role) => DropdownMenuItem<String>(
                                          value: role,
                                          child: Text(
                                            roleLabel(role),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: saving
                                      ? null
                                      : (value) {
                                          if (value == null) {
                                            return;
                                          }

                                          updateRole(
                                            profile['id'],
                                            value,
                                          );
                                        },
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
