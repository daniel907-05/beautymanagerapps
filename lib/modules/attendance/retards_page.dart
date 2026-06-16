import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logs/activity_logger.dart';
import '../../core/settings/salon_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';

class RetardsPage extends StatefulWidget {
  const RetardsPage({super.key});

  @override
  State<RetardsPage> createState() => _RetardsPageState();
}

class _RetardsPageState extends State<RetardsPage> {
  bool loading = true;
  bool saving = false;

  List employees = [];
  List retards = [];

  String? selectedEmployeeId;
  final plannedTimeController = TextEditingController(text: '08:00');
  final arrivalTimeController = TextEditingController();
  final reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => loading = true);

    final employeesResponse = await Supabase.instance.client
        .from('employees')
        .select('id, full_name')
        .eq('is_active', true)
        .order('full_name');

    final retardsResponse = await Supabase.instance.client
        .from('retards')
        .select()
        .order('created_at', ascending: false)
        .limit(100);

    if (!mounted) return;
    setState(() {
      employees = employeesResponse;
      retards = retardsResponse;
      loading = false;
    });
  }

  String employeeName(String? employeeId) {
    final employee = employees.firstWhere(
      (item) => item['id'] == employeeId,
      orElse: () => {'full_name': 'Employé'},
    );
    return employee['full_name'] ?? 'Employé';
  }

  int minutesBetween(String planned, String arrival) {
    try {
      final p = planned.split(':');
      final a = arrival.split(':');
      final plannedMinutes = int.parse(p[0]) * 60 + int.parse(p[1]);
      final arrivalMinutes = int.parse(a[0]) * 60 + int.parse(a[1]);
      final diff = arrivalMinutes - plannedMinutes;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveRetard() async {
    if (selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un employé')),
      );
      return;
    }

    if (arrivalTimeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez l’heure d’arrivée')),
      );
      return;
    }

    setState(() => saving = true);

    final employee = employeeName(selectedEmployeeId);
    final planned = plannedTimeController.text.trim();
    final arrival = arrivalTimeController.text.trim();
    final delayMinutes = minutesBetween(planned, arrival);

    try {
      await Supabase.instance.client.from('retards').insert({
        'employee_id': selectedEmployeeId,
        'employee_name': employee,
        'retard_date': DateHelper.todayDateOnly(),
        'planned_time': planned,
        'arrival_time': arrival,
        'delay_minutes': delayMinutes,
        'reason': reasonController.text.trim(),
      });

      await ActivityLogger.log(
        action: 'RETARD',
        description: '$employee en retard de $delayMinutes minutes',
      );

      selectedEmployeeId = null;
      arrivalTimeController.clear();
      reasonController.clear();

      await loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Retard enregistré')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur retard : $e')),
        );
      }
    }

    if (mounted) setState(() => saving = false);
  }

  Future<Uint8List> buildPdf() async {
    await SalonSettings.load();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            '${SalonSettings.salonName} - Retards',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(SalonSettings.salonPhone),
          pw.Text(SalonSettings.salonAddress),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Employé',
              'Prévue',
              'Arrivée',
              'Minutes',
              'Motif'
            ],
            data: retards.map((retard) {
              return [
                retard['retard_date'] ?? '-',
                retard['employee_name'] ?? '-',
                retard['planned_time'] ?? '-',
                retard['arrival_time'] ?? '-',
                '${retard['delay_minutes'] ?? 0}',
                retard['reason'] ?? '-',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text(SalonSettings.receiptFooter),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> printRetards() async {
    final pdfData = await buildPdf();
    await Printing.layoutPdf(onLayout: (_) async => pdfData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(22),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Retards',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enregistrez et imprimez les retards du personnel',
                            style: TextStyle(
                                fontSize: 14, color: AppTheme.textGrey),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: printRetards,
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          value: selectedEmployeeId,
                          decoration: const InputDecoration(
                              labelText: 'Employé',
                              border: OutlineInputBorder()),
                          items: employees
                              .map<DropdownMenuItem<String>>((employee) {
                            return DropdownMenuItem<String>(
                              value: employee['id'],
                              child: Text(employee['full_name']),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedEmployeeId = value),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: plannedTimeController,
                          decoration: const InputDecoration(
                              labelText: 'Heure prévue',
                              border: OutlineInputBorder()),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: arrivalTimeController,
                          decoration: const InputDecoration(
                              labelText: 'Heure arrivée',
                              border: OutlineInputBorder()),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: reasonController,
                          decoration: const InputDecoration(
                              labelText: 'Motif', border: OutlineInputBorder()),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: saving ? null : saveRetard,
                        icon: const Icon(Icons.save),
                        label:
                            Text(saving ? 'Enregistrement...' : 'Enregistrer'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: retards.isEmpty
                        ? const Center(child: Text('Aucun retard enregistré'))
                        : ListView.separated(
                            itemCount: retards.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final retard = retards[index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.gold.withOpacity(0.18),
                                  child: const Icon(Icons.access_time,
                                      color: AppTheme.gold),
                                ),
                                title: Text(
                                  retard['employee_name'] ?? '-',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  '${retard['retard_date'] ?? '-'} • Prévue : ${retard['planned_time']} • Arrivée : ${retard['arrival_time']} • Motif : ${retard['reason'] ?? '-'}',
                                ),
                                trailing: Text(
                                  '${retard['delay_minutes'] ?? 0} min',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.red),
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
