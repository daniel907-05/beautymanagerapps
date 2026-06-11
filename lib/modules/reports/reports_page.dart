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

  String selectedPeriod = 'today';
  DateTime? selectedDate;

  double totalSales = 0;
  double totalExpenses = 0;
  double netResult = 0;
  double totalCommissions = 0;
  double totalSalon = 0;
  int totalClients = 0;
  int totalTransactions = 0;

  List sales = [];
  List expenses = [];

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    setState(() => loading = true);

    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    if (selectedPeriod == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = startDate.add(const Duration(days: 1));
    } else if (selectedPeriod == 'week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(monday.year, monday.month, monday.day);
      endDate = startDate.add(const Duration(days: 7));
    } else if (selectedPeriod == 'month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 1);
    } else if (selectedPeriod == 'date' && selectedDate != null) {
      startDate = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
      );
      endDate = startDate.add(const Duration(days: 1));
    }

    var salesQuery = Supabase.instance.client
        .from('sales')
        .select()
        .eq('status', 'validated');

    var expensesQuery = Supabase.instance.client
        .from('expenses')
        .select()
        .eq('include_in_reports', true);

    if (startDate != null) {
      salesQuery = salesQuery.gte('sale_date', startDate.toIso8601String());
      expensesQuery = expensesQuery.gte(
        'expense_date',
        startDate.toIso8601String().split('T').first,
      );
    }

    if (endDate != null) {
      salesQuery = salesQuery.lt('sale_date', endDate.toIso8601String());
      expensesQuery = expensesQuery.lt(
        'expense_date',
        endDate.toIso8601String().split('T').first,
      );
    }

    final salesResponse = await salesQuery.order('sale_date', ascending: false);

    final expensesResponse =
        await expensesQuery.order('expense_date', ascending: false);

    double salesTotal = 0;
    double commissionsTotal = 0;
    double salonTotal = 0;
    int clientsTotal = 0;

    for (final sale in salesResponse) {
      salesTotal += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      commissionsTotal += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      salonTotal += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
      clientsTotal += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }

    double expensesTotal = 0;

    for (final expense in expensesResponse) {
      expensesTotal += (expense['amount'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      sales = salesResponse;
      expenses = expensesResponse;
      totalSales = salesTotal;
      totalExpenses = expensesTotal;
      netResult = salesTotal - expensesTotal;
      totalCommissions = commissionsTotal;
      totalSalon = salonTotal;
      totalClients = clientsTotal;
      totalTransactions = salesResponse.length;
      loading = false;
    });
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
        selectedPeriod = 'date';
      });

      loadReports();
    }
  }

  void resetFilters() {
    setState(() {
      selectedPeriod = 'today';
      selectedDate = null;
    });

    loadReports();
  }

  String money(double value) {
    return '${value.toStringAsFixed(0)} FCFA';
  }

  String selectedDateLabel() {
    if (selectedDate == null) return 'Choisir une date';

    return '${selectedDate!.day.toString().padLeft(2, '0')}/'
        '${selectedDate!.month.toString().padLeft(2, '0')}/'
        '${selectedDate!.year}';
  }

  String periodTitle() {
    switch (selectedPeriod) {
      case 'today':
        return 'Aujourd’hui';
      case 'week':
        return 'Cette semaine';
      case 'month':
        return 'Ce mois';
      case 'all':
        return 'Total général';
      case 'date':
        return selectedDateLabel();
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardColumns = screenWidth > 1500 ? 4 : 2;

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
                              'Rapports financiers',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Analyse du chiffre d’affaires, dépenses et résultat net',
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
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'today',
                            label: Text('Aujourd’hui'),
                          ),
                          ButtonSegment(
                            value: 'week',
                            label: Text('Semaine'),
                          ),
                          ButtonSegment(
                            value: 'month',
                            label: Text('Mois'),
                          ),
                          ButtonSegment(
                            value: 'all',
                            label: Text('Total'),
                          ),
                        ],
                        selected: {
                          selectedPeriod == 'date' ? 'all' : selectedPeriod
                        },
                        onSelectionChanged: (value) {
                          setState(() {
                            selectedPeriod = value.first;
                            selectedDate = null;
                          });
                          loadReports();
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(selectedDateLabel()),
                      ),
                      TextButton.icon(
                        onPressed: resetFilters,
                        icon: const Icon(Icons.clear),
                        label: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Période : ${periodTitle()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: cardColumns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.8,
                    children: [
                      _ReportCard(
                        title: 'Chiffre d’affaires',
                        value: money(totalSales),
                        icon: Icons.payments_outlined,
                      ),
                      _ReportCard(
                        title: 'Dépenses',
                        value: money(totalExpenses),
                        icon: Icons.money_off_csred_outlined,
                      ),
                      _ReportCard(
                        title: 'Résultat net',
                        value: money(netResult),
                        icon: Icons.trending_up,
                        highlight: true,
                        positive: netResult >= 0,
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
                        title: 'Part salon brute',
                        value: money(totalSalon),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      _ReportCard(
                        title: 'Charges incluses',
                        value: expenses.length.toString(),
                        icon: Icons.list_alt_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 430,
                    child: Row(
                      children: [
                        Expanded(
                          child: _ReportListCard(
                            title: 'Dernières ventes',
                            child: sales.isEmpty
                                ? const Center(
                                    child: Text('Aucune vente trouvée'),
                                  )
                                : ListView.separated(
                                    itemCount: sales.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(),
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
                                          'Commission : ${money((sale['employee_amount'] as num?)?.toDouble() ?? 0)} • Salon : ${money((sale['salon_amount'] as num?)?.toDouble() ?? 0)}',
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
                        const SizedBox(width: 18),
                        Expanded(
                          child: _ReportListCard(
                            title: 'Dépenses incluses',
                            child: expenses.isEmpty
                                ? const Center(
                                    child: Text('Aucune dépense trouvée'),
                                  )
                                : ListView.separated(
                                    itemCount: expenses.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(),
                                    itemBuilder: (context, index) {
                                      final expense = expenses[index];

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.red.withOpacity(0.12),
                                          child: const Icon(
                                            Icons.money_off,
                                            color: Colors.red,
                                          ),
                                        ),
                                        title: Text(
                                          money(
                                            (expense['amount'] as num?)
                                                    ?.toDouble() ??
                                                0,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${expense['category']} • ${expense['description'] ?? '-'}',
                                        ),
                                        trailing: Text(
                                          expense['expense_date'] ?? '',
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
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReportListCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportListCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool highlight;
  final bool positive;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = highlight
        ? (positive ? Colors.green.shade50 : Colors.red.shade50)
        : AppTheme.white;

    final iconColor =
        highlight ? (positive ? Colors.green : Colors.red) : AppTheme.gold;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: highlight
            ? Border.all(color: positive ? Colors.green : Colors.red)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
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
    );
  }
}
