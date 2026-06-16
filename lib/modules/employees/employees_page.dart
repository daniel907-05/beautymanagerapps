import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logs/activity_logger.dart';
import '../../core/theme/app_theme.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  List employees = [];
  bool loading = true;
  String searchText = '';

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

    if (!mounted) return;
    setState(() {
      employees = response;
      loading = false;
    });
  }

  List get filteredEmployees {
    final q = searchText.toLowerCase().trim();
    if (q.isEmpty) return employees;

    return employees.where((employee) {
      final name = (employee['full_name'] ?? '').toString().toLowerCase();
      final phone = (employee['phone'] ?? '').toString().toLowerCase();
      final role = (employee['role'] ?? '').toString().toLowerCase();
      final speciality =
          (employee['speciality'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          role.contains(q) ||
          speciality.contains(q);
    }).toList();
  }

  Future<void> showEmployeeDialog({Map<String, dynamic>? employee}) async {
    final isEdit = employee != null;

    final nameController =
        TextEditingController(text: employee?['full_name'] ?? '');
    final phoneController =
        TextEditingController(text: employee?['phone'] ?? '');
    final roleController =
        TextEditingController(text: employee?['role'] ?? 'employee');
    final specialityController =
        TextEditingController(text: employee?['speciality'] ?? '');
    final percentController = TextEditingController();

    if (isEdit) {
      final contract = await Supabase.instance.client
          .from('employee_contracts')
          .select()
          .eq('employee_id', employee['id'])
          .eq('is_active', true)
          .maybeSingle();

      percentController.text =
          ((contract?['commission_percent'] as num?)?.toDouble() ?? 0)
              .toStringAsFixed(0);
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Modifier employé' : 'Ajouter un employé'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
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
                      helperText: 'employee, cashier ou manager',
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
                        labelText: 'Pourcentage commission'),
                  ),
                ],
              ),
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
                  final percent =
                      double.tryParse(percentController.text.trim()) ?? 0;

                  if (isEdit) {
                    await Supabase.instance.client.from('employees').update({
                      'full_name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'role': roleController.text.trim(),
                      'speciality': specialityController.text.trim(),
                    }).eq('id', employee['id']);

                    await Supabase.instance.client
                        .from('employee_contracts')
                        .update({'is_active': false}).eq(
                            'employee_id', employee['id']);

                    await Supabase.instance.client
                        .from('employee_contracts')
                        .insert({
                      'employee_id': employee['id'],
                      'commission_percent': percent,
                      'is_active': true,
                    });

                    await ActivityLogger.log(
                      action: 'EMPLOYE',
                      description:
                          'Employé modifié : ${nameController.text.trim()}',
                    );
                  } else {
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

                    await Supabase.instance.client
                        .from('employee_contracts')
                        .insert({
                      'employee_id': insertedEmployee['id'],
                      'commission_percent': percent,
                      'is_active': true,
                    });

                    await ActivityLogger.log(
                      action: 'EMPLOYE',
                      description:
                          'Employé ajouté : ${nameController.text.trim()}',
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    await loadEmployees();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              isEdit ? 'Employé modifié' : 'Employé ajouté')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur employé : $e')),
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

  Future<void> toggleEmployeeStatus(Map<String, dynamic> employee) async {
    final active = employee['is_active'] == true;
    final newValue = !active;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newValue ? 'Réactiver employé ?' : 'Désactiver employé ?'),
        content: Text(
          newValue
              ? 'Cet employé sera de nouveau disponible dans les ventes.'
              : 'Cet employé ne sera plus proposé dans les ventes, mais l’historique restera conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(newValue ? 'Réactiver' : 'Désactiver'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await Supabase.instance.client
        .from('employees')
        .update({'is_active': newValue}).eq('id', employee['id']);

    await ActivityLogger.log(
      action: 'EMPLOYE',
      description:
          '${newValue ? 'Réactivation' : 'Désactivation'} : ${employee['full_name']}',
    );

    await loadEmployees();
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
                      'Employés',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.black),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gérez les employés, caissières et commissions',
                      style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => showEmployeeDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter employé'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher employé',
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
                  borderRadius: BorderRadius.circular(18)),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredEmployees.isEmpty
                      ? const Center(child: Text('Aucun employé enregistré'))
                      : ListView.separated(
                          itemCount: filteredEmployees.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final employee = filteredEmployees[index];
                            final active = employee['is_active'] == true;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child: const Icon(Icons.person,
                                    color: AppTheme.gold),
                              ),
                              title: Text(
                                employee['full_name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                  '${employee['role'] ?? ''} • ${employee['speciality'] ?? ''}'),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(employee['phone'] ?? ''),
                                  Text(
                                    active ? 'Actif' : 'Inactif',
                                    style: TextStyle(
                                      color: active ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        showEmployeeDialog(employee: employee),
                                  ),
                                  IconButton(
                                    tooltip:
                                        active ? 'Désactiver' : 'Réactiver',
                                    icon: Icon(active
                                        ? Icons.delete_outline
                                        : Icons.restore),
                                    color: active ? Colors.red : Colors.green,
                                    onPressed: () =>
                                        toggleEmployeeStatus(employee),
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
