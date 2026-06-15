import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  bool loading = true;
  List logs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    setState(() => loading = true);

    final response = await Supabase.instance.client
        .from('activity_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(100);

    setState(() {
      logs = response;
      loading = false;
    });
  }

  String formatDate(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  IconData actionIcon(String? action) {
    switch (action) {
      case 'VENTE':
        return Icons.point_of_sale;
      case 'CLOTURE_CAISSE':
        return Icons.lock;
      case 'PRODUIT':
        return Icons.inventory_2;
      case 'DEPENSE':
        return Icons.money_off;
      default:
        return Icons.history;
    }
  }

  Color actionColor(String? action) {
    switch (action) {
      case 'VENTE':
        return AppTheme.gold;
      case 'CLOTURE_CAISSE':
        return Colors.green;
      case 'PRODUIT':
        return Colors.blue;
      case 'DEPENSE':
        return Colors.red;
      default:
        return AppTheme.textGrey;
    }
  }

  String actionLabel(String? action) {
    switch (action) {
      case 'VENTE':
        return 'Vente';
      case 'CLOTURE_CAISSE':
        return 'Clôture caisse';
      case 'PRODUIT':
        return 'Produit';
      case 'DEPENSE':
        return 'Dépense';
      default:
        return action ?? '-';
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
                      'Journal d’activité',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Suivi des actions importantes dans le salon',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: loadLogs,
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
                  ? const Center(child: CircularProgressIndicator())
                  : logs.isEmpty
                      ? const Center(
                          child: Text('Aucune activité enregistrée'),
                        )
                      : ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            final action = log['action'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    actionColor(action).withOpacity(0.15),
                                child: Icon(
                                  actionIcon(action),
                                  color: actionColor(action),
                                ),
                              ),
                              title: Text(
                                actionLabel(action),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                log['description'] ?? '-',
                              ),
                              trailing: Text(
                                formatDate(log['created_at']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textGrey,
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
