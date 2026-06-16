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
  String searchText = '';

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
    setState(() => loading = true);

    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    if (!mounted) return;
    setState(() {
      profiles = response;
      loading = false;
    });
  }

  List get filteredProfiles {
    final q = searchText.toLowerCase().trim();
    if (q.isEmpty) return profiles;
    return profiles.where((profile) {
      final name = (profile['full_name'] ?? '').toString().toLowerCase();
      final email = (profile['email'] ?? '').toString().toLowerCase();
      final role = (profile['role'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q);
    }).toList();
  }

  Future<void> showCreateUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'employee';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Créer un utilisateur'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Nom complet'),
                      ),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Mot de passe temporaire'),
                      ),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Rôle'),
                        items: roles.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(roleLabel(item)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => role = value ?? 'employee');
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      await createUser(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        role: role,
                      );
                      if (mounted) Navigator.pop(context);
                    },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nom, email et mot de passe obligatoires')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final result = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': role,
        },
      );

      final userId = result.user?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': userId,
          'full_name': name,
          'email': email,
          'role': role,
        });
      }

      await loadProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur créé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur création utilisateur : $e')),
        );
      }
    }

    if (mounted) setState(() => saving = false);
  }

  Future<void> updateRole(String profileId, String role) async {
    setState(() => saving = true);

    try {
      await Supabase.instance.client.from('profiles').update({
        'role': role,
      }).eq('id', profileId);

      await loadProfiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rôle mis à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }

    if (mounted) setState(() => saving = false);
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
      padding: const EdgeInsets.all(22),
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
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gestion des utilisateurs et des rôles',
                      style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: showCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Créer utilisateur'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher utilisateur',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchText = value),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredProfiles.isEmpty
                      ? const Center(child: Text('Aucun utilisateur trouvé'))
                      : ListView.separated(
                          itemCount: filteredProfiles.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final profile = filteredProfiles[index];

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.15),
                                child: const Icon(Icons.person,
                                    color: AppTheme.gold),
                              ),
                              title: Text(
                                profile['full_name'] ?? 'Sans nom',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                '${profile['email'] ?? profile['id']} ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 590,
                                child: DropdownButtonFormField<String>(
                                  value: roles.contains(profile['role'])
                                      ? profile['role']
                                      : 'employee',
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  items: roles.map((role) {
                                    return DropdownMenuItem<String>(
                                      value: role,
                                      child: Text(roleLabel(role)),
                                    );
                                  }).toList(),
                                  onChanged: saving
                                      ? null
                                      : (value) {
                                          if (value == null) return;
                                          updateRole(profile['id'], value);
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
