import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  bool loading = true;

  List sales = [];
  List employees = [];
  Map<String, String> employeeNames = {};

  String selectedPeriod = 'all';
  String? selectedEmployeeId;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    loadSales();
  }

  Future<void> loadSales() async {
    setState(() => loading = true);

    final employeesResponse = await Supabase.instance.client
        .from('employees')
        .select('id, full_name')
        .order('full_name');

    final names = <String, String>{};

    for (final employee in employeesResponse) {
      names[employee['id']] = employee['full_name'] ?? 'Employé inconnu';
    }

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

    var query = Supabase.instance.client
        .from('sales')
        .select()
        .eq('status', 'validated');

    if (selectedEmployeeId != null) {
      query = query.eq('employee_id', selectedEmployeeId!);
    }

    if (startDate != null) {
      query = query.gte('sale_date', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lt('sale_date', endDate.toIso8601String());
    }

    final salesResponse = await query.order('sale_date', ascending: false);

    setState(() {
      employees = employeesResponse;
      employeeNames = names;
      sales = salesResponse;
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

      loadSales();
    }
  }

  void resetFilters() {
    setState(() {
      selectedPeriod = 'all';
      selectedEmployeeId = null;
      selectedDate = null;
    });

    loadSales();
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  String employeeName(Map sale) {
    final employeeId = sale['employee_id'];

    if (employeeId == null) {
      return 'Vente produit';
    }

    return employeeNames[employeeId] ?? 'Employé inconnu';
  }

  String paymentLabel(dynamic value) {
    if (value == 'cash') return 'Espèces';
    if (value == 'mobile_money') return 'Mobile Money';
    if (value == 'card') return 'Carte';
    return value?.toString() ?? '-';
  }

  String saleDate(Map sale) {
    final rawDate = sale['sale_date'];

    if (rawDate == null) return '-';

    final date = DateTime.tryParse(rawDate.toString());

    if (date == null) return rawDate.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String selectedDateLabel() {
    if (selectedDate == null) return 'Choisir une date';

    return '${selectedDate!.day.toString().padLeft(2, '0')}/'
        '${selectedDate!.month.toString().padLeft(2, '0')}/'
        '${selectedDate!.year}';
  }

  double get totalAmount {
    double total = 0;
    for (final sale in sales) {
      total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  int get totalClients {
    int total = 0;
    for (final sale in sales) {
      total += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  double get totalCommissions {
    double total = 0;
    for (final sale in sales) {
      total += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  double get totalSalon {
    double total = 0;
    for (final sale in sales) {
      total += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  double get totalCash {
    double total = 0;
    for (final sale in sales) {
      if (sale['payment_method'] == 'cash') {
        total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  double get totalMobileMoney {
    double total = 0;
    for (final sale in sales) {
      if (sale['payment_method'] == 'mobile_money') {
        total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  double get totalCard {
    double total = 0;
    for (final sale in sales) {
      if (sale['payment_method'] == 'card') {
        total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
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
                              'Historique des ventes',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Recherchez les ventes par date, période ou employé',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: loadSales,
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
                          loadSales();
                        },
                      ),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<String>(
                          value: selectedEmployeeId,
                          decoration: const InputDecoration(
                            labelText: 'Employé',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Tous les employés'),
                            ),
                            ...employees
                                .map<DropdownMenuItem<String>>((employee) {
                              return DropdownMenuItem<String>(
                                value: employee['id'],
                                child: Text(employee['full_name'] ?? ''),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedEmployeeId = value;
                            });
                            loadSales();
                          },
                        ),
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
                  GridView.count(
                    crossAxisCount: cardColumns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.8,
                    children: [
                      _SummaryCard(
                        title: 'Total ventes',
                        value: money(totalAmount),
                        icon: Icons.payments_outlined,
                      ),
                      _SummaryCard(
                        title: 'Espèces',
                        value: money(totalCash),
                        icon: Icons.payments,
                      ),
                      _SummaryCard(
                        title: 'Mobile Money',
                        value: money(totalMobileMoney),
                        icon: Icons.phone_android,
                      ),
                      _SummaryCard(
                        title: 'Carte',
                        value: money(totalCard),
                        icon: Icons.credit_card,
                      ),
                      _SummaryCard(
                        title: 'Clients',
                        value: totalClients.toString(),
                        icon: Icons.people_outline,
                      ),
                      _SummaryCard(
                        title: 'Commissions',
                        value: money(totalCommissions),
                        icon: Icons.badge_outlined,
                      ),
                      _SummaryCard(
                        title: 'Part salon',
                        value: money(totalSalon),
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 520,
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: sales.isEmpty
                        ? const Center(
                            child: Text('Aucune vente trouvée'),
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
                                    Icons.receipt_long,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                title: Text(
                                  money(sale['total_amount']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '${employeeName(sale)} • ${paymentLabel(sale['payment_method'])} • '
                                  'Commission : ${money(sale['employee_amount'])} • '
                                  'Salon : ${money(sale['salon_amount'])}',
                                ),
                                trailing: Text(
                                  saleDate(sale),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
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
          Icon(icon, color: AppTheme.gold, size: 28),
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
          const SizedBox(height: 4),
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
