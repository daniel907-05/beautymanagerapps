import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  List employees = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    final response = await Supabase.instance.client
        .from('employees')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      employees = response;
      loading = false;
    });
  }

  Future<void> _showAddEmployeeDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final roleController = TextEditingController(text: 'employee');
    final specialityController = TextEditingController();
    final percentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un employé'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                TextField(
                  controller: roleController,
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    helperText:
                        'Utilise employee, cashier, manager ou super_admin',
                  ),
                ),
                TextField(
                  controller: specialityController,
                  decoration: const InputDecoration(labelText: 'Spécialité'),
                ),
                TextField(
                  controller: percentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pourcentage contrat',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final insertedEmployee = await Supabase.instance.client
                      .from('employees')
                      .insert({
                        'full_name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'role': roleController.text.trim(),
                        'speciality': specialityController.text.trim(),
                        'is_active': true,
                      })
                      .select()
                      .single();

                  final employeeId = insertedEmployee['id'];
                  final percent =
                      double.tryParse(percentController.text.trim()) ?? 0;

                  await Supabase.instance.client
                      .from('employee_contracts')
                      .insert({
                    'employee_id': employeeId,
                    'commission_percent': percent,
                    'is_active': true,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    loadEmployees();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Employé ajouté avec succès'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur ajout employé : $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
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
                      'Employés',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gérez les coiffeurs, caissières et praticiens du salon',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddEmployeeDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter employé'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : employees.isEmpty
                      ? const Center(
                          child: Text('Aucun employé enregistré'),
                        )
                      : ListView.separated(
                          itemCount: employees.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final employee = employees[index];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.gold,
                                ),
                              ),
                              title: Text(
                                employee['full_name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${employee['role'] ?? ''} • ${employee['speciality'] ?? ''}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(employee['phone'] ?? ''),
                                  const SizedBox(height: 4),
                                  Text(
                                    employee['is_active'] == true
                                        ? 'Actif'
                                        : 'Inactif',
                                    style: TextStyle(
                                      color: employee['is_active'] == true
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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
