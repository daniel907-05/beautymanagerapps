import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List employees = [];
  Map<String, Map<String, bool>> attendance = {};
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    final response = await Supabase.instance.client
        .from('employees')
        .select()
        .eq('is_active', true)
        .order('full_name');

    setState(() {
      employees = response;
      attendance = {
        for (final employee in response)
          employee['id']: {
            'morning': false,
            'midday': false,
            'evening': false,
          }
      };
      loading = false;
    });
  }

  Future<void> saveAttendance() async {
    setState(() {
      saving = true;
    });

    final today = DateTime.now().toIso8601String().split('T').first;

    final rows = employees.map((employee) {
      final employeeId = employee['id'];
      final values = attendance[employeeId]!;

      return {
        'employee_id': employeeId,
        'attendance_date': today,
        'morning': values['morning'],
        'midday': values['midday'],
        'evening': values['evening'],
      };
    }).toList();

    await Supabase.instance.client.from('attendance').upsert(
          rows,
          onConflict: 'employee_id,attendance_date',
        );

    setState(() {
      saving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Présence enregistrée avec succès'),
        ),
      );
    }
  }

  void updateAttendance(String employeeId, String period, bool value) {
    setState(() {
      attendance[employeeId]![period] = value;
    });
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
                      'Présence',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Cochez les présences du matin, midi et soir',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: saving ? null : saveAttendance,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
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
                      ? const Center(child: Text('Aucun employé actif'))
                      : ListView.separated(
                          itemCount: employees.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final employee = employees[index];
                            final employeeId = employee['id'];
                            final values = attendance[employeeId]!;

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
                              subtitle: Text(employee['speciality'] ?? ''),
                              trailing: SizedBox(
                                width: 330,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _PresenceCheck(
                                      label: 'Matin',
                                      value: values['morning']!,
                                      onChanged: (value) => updateAttendance(
                                        employeeId,
                                        'morning',
                                        value ?? false,
                                      ),
                                    ),
                                    _PresenceCheck(
                                      label: 'Midi',
                                      value: values['midday']!,
                                      onChanged: (value) => updateAttendance(
                                        employeeId,
                                        'midday',
                                        value ?? false,
                                      ),
                                    ),
                                    _PresenceCheck(
                                      label: 'Soir',
                                      value: values['evening']!,
                                      onChanged: (value) => updateAttendance(
                                        employeeId,
                                        'evening',
                                        value ?? false,
                                      ),
                                    ),
                                  ],
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

class _PresenceCheck extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _PresenceCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.gold,
        ),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
