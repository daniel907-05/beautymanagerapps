import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class EmployeeDetailPage extends StatefulWidget {
  final Map<String, dynamic> employee;

  const EmployeeDetailPage({
    super.key,
    required this.employee,
  });

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  bool loading = true;

  double totalSales = 0;
  double totalCommission = 0;
  double totalSalon = 0;
  int totalClients = 0;
  double commissionPercent = 0;

  Map<String, dynamic>? attendance;

  @override
  void initState() {
    super.initState();
    loadEmployeeStats();
  }

  Future<void> loadEmployeeStats() async {
    setState(() {
      loading = true;
    });

    final employeeId = widget.employee['id'];
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .split('T')
        .first;

    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final sales = await Supabase.instance.client
        .from('sales')
        .select()
        .eq('employee_id', employeeId)
        .eq('status', 'validated')
        .gte('sale_date', startOfDay);

    final contract = await Supabase.instance.client
        .from('employee_contracts')
        .select()
        .eq('employee_id', employeeId)
        .eq('is_active', true)
        .maybeSingle();

    final attendanceResponse = await Supabase.instance.client
        .from('attendance')
        .select()
        .eq('employee_id', employeeId)
        .eq('attendance_date', today)
        .maybeSingle();

    double salesTotal = 0;
    double commissionTotal = 0;
    double salonTotal = 0;
    int clientsTotal = 0;

    for (final sale in sales) {
      salesTotal += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      commissionTotal += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      salonTotal += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
      clientsTotal += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }

    setState(() {
      totalSales = salesTotal;
      totalCommission = commissionTotal;
      totalSalon = salonTotal;
      totalClients = clientsTotal;
      commissionPercent = contract == null
          ? 0
          : (contract['commission_percent'] as num).toDouble();
      attendance = attendanceResponse;
      loading = false;
    });
  }

  String money(double value) => '${value.toStringAsFixed(0)} FCFA';

  bool present(String key) {
    if (attendance == null) return false;
    return attendance![key] == true;
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

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
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          employee['full_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.black,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: loadEmployeeStats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${employee['role'] ?? ''} • ${employee['speciality'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textGrey,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _InfoCard(
                        title: 'Clients aujourd’hui',
                        value: totalClients.toString(),
                        icon: Icons.people_outline,
                      ),
                      _InfoCard(
                        title: 'CA généré',
                        value: money(totalSales),
                        icon: Icons.payments_outlined,
                      ),
                      _InfoCard(
                        title: 'Commission à payer',
                        value: money(totalCommission),
                        icon: Icons.badge_outlined,
                      ),
                      _InfoCard(
                        title: 'Part salon',
                        value: money(totalSalon),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      _SectionCard(
                        title: 'Contrat',
                        child: Text(
                          'Pourcentage actuel : ${commissionPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _SectionCard(
                        title: 'Présence du jour',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _PresenceStatus(
                              label: 'Matin',
                              active: present('morning'),
                            ),
                            _PresenceStatus(
                              label: 'Midi',
                              active: present('midday'),
                            ),
                            _PresenceStatus(
                              label: 'Soir',
                              active: present('evening'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 150,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.gold, size: 28),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      height: 160,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _PresenceStatus extends StatelessWidget {
  final String label;
  final bool active;

  const _PresenceStatus({
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          active ? Icons.check_circle : Icons.cancel,
          color: active ? Colors.green : Colors.red,
          size: 30,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
