import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool loading = true;

  double totalSales = 0;
  double totalCommissions = 0;
  double totalSalon = 0;
  int totalClients = 0;
  int totalTransactions = 0;

  List sales = [];

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final response = await Supabase.instance.client
        .from('sales')
        .select()
        .gte('sale_date', startOfDay)
        .eq('status', 'validated')
        .order('sale_date', ascending: false);

    double salesTotal = 0;
    double commissionsTotal = 0;
    double salonTotal = 0;
    int clientsTotal = 0;

    for (final sale in response) {
      salesTotal += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      commissionsTotal += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      salonTotal += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
      clientsTotal += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }

    setState(() {
      sales = response;
      totalSales = salesTotal;
      totalCommissions = commissionsTotal;
      totalSalon = salonTotal;
      totalClients = clientsTotal;
      totalTransactions = response.length;
      loading = false;
    });
  }

  String money(double value) {
    return '${value.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(30),
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
                            'Rapports',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.black,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Résumé des ventes et commissions du jour',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: loadReports,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.25,
                  children: [
                    _ReportCard(
                      title: 'Chiffre du jour',
                      value: money(totalSales),
                      icon: Icons.payments_outlined,
                    ),
                    _ReportCard(
                      title: 'Clients',
                      value: totalClients.toString(),
                      icon: Icons.people_outline,
                    ),
                    _ReportCard(
                      title: 'Transactions',
                      value: totalTransactions.toString(),
                      icon: Icons.receipt_long_outlined,
                    ),
                    _ReportCard(
                      title: 'Commissions',
                      value: money(totalCommissions),
                      icon: Icons.badge_outlined,
                    ),
                    _ReportCard(
                      title: 'Part salon',
                      value: money(totalSalon),
                      icon: Icons.account_balance_wallet_outlined,
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
                    child: sales.isEmpty
                        ? const Center(
                            child: Text('Aucune vente enregistrée aujourd’hui'),
                          )
                        : ListView.separated(
                            itemCount: sales.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final sale = sales[index];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppTheme.gold.withOpacity(0.18),
                                  child: const Icon(
                                    Icons.point_of_sale,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                title: Text(
                                  money(
                                    (sale['total_amount'] as num?)
                                            ?.toDouble() ??
                                        0,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  'Commission: ${money((sale['employee_amount'] as num?)?.toDouble() ?? 0)} • Salon: ${money((sale['salon_amount'] as num?)?.toDouble() ?? 0)}',
                                ),
                                trailing: Text(
                                  sale['payment_method'] ?? 'cash',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
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

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.gold, size: 30),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }
}
