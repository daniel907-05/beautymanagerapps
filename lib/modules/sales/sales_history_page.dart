import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/user_role.dart';
import '../../core/logs/activity_logger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  bool loading = true;
  bool cancelling = false;

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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        loadSales(); // ou loadSales(), loadDashboardData(), loadData()
      }
    });
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
      startDate = DateHelper.startOfToday();
      endDate = DateHelper.endOfToday();
    } else if (selectedPeriod == 'week') {
      startDate = DateHelper.startOfWeek();
      endDate = DateHelper.endOfWeek();
    } else if (selectedPeriod == 'month') {
      startDate = DateHelper.startOfMonth();
      endDate = DateHelper.endOfMonth();
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

  Future<List> loadSaleItems(String saleId) async {
    return await Supabase.instance.client
        .from('sale_items')
        .select()
        .eq('sale_id', saleId);
  }

  Future<String> itemName(Map item) async {
    try {
      if (item['item_type'] == 'service' && item['service_id'] != null) {
        final service = await Supabase.instance.client
            .from('services')
            .select('name')
            .eq('id', item['service_id'])
            .maybeSingle();

        return service?['name'] ?? 'Service';
      }

      if (item['item_type'] == 'product' && item['product_id'] != null) {
        final product = await Supabase.instance.client
            .from('products')
            .select('name')
            .eq('id', item['product_id'])
            .maybeSingle();

        return product?['name'] ?? 'Produit';
      }
    } catch (_) {}

    return item['item_type'] ?? '-';
  }

  Future<void> showSaleDetails(Map sale) async {
    final items = await loadSaleItems(sale['id']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Détail de la vente'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DetailLine(label: 'Date', value: saleDate(sale)),
                  _DetailLine(label: 'Employé', value: employeeName(sale)),
                  _DetailLine(
                    label: 'Paiement',
                    value: paymentLabel(sale['payment_method']),
                  ),
                  _DetailLine(
                    label: 'Montant total',
                    value: money(sale['total_amount']),
                  ),
                  _DetailLine(
                    label: 'Commission',
                    value: money(sale['employee_amount']),
                  ),
                  _DetailLine(
                    label: 'Part salon',
                    value: money(sale['salon_amount']),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Articles / services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    const Text('Aucun détail trouvé')
                  else
                    ...items.map((item) {
                      return FutureBuilder<String>(
                        future: itemName(item),
                        builder: (context, snapshot) {
                          final name = snapshot.data ?? 'Chargement...';

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              'Quantité : ${item['quantity']} • Prix : ${money(item['unit_price'])}',
                            ),
                            trailing: Text(
                              money(item['total_price']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            if (UserRole.isAdmin)
              ElevatedButton.icon(
                onPressed: cancelling
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await confirmCancelSale(sale);
                      },
                icon: const Icon(Icons.cancel),
                label: const Text('Annuler la vente'),
              ),
          ],
        );
      },
    );
  }

  Future<void> confirmCancelSale(Map sale) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Annuler la vente ?'),
          content: const Text(
            'Cette action annulera la vente et remettra le stock des produits concernés. Elle est réservée à l’administrateur.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui, annuler'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await cancelSale(sale);
  }

  Future<void> cancelSale(Map sale) async {
    if (!UserRole.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seul l’administrateur peut annuler une vente'),
        ),
      );
      return;
    }

    setState(() => cancelling = true);

    try {
      final items = await loadSaleItems(sale['id']);

      for (final item in items) {
        if (item['item_type'] == 'product' && item['product_id'] != null) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

          final product = await Supabase.instance.client
              .from('products')
              .select('stock_quantity')
              .eq('id', item['product_id'])
              .maybeSingle();

          final currentStock =
              (product?['stock_quantity'] as num?)?.toInt() ?? 0;

          await Supabase.instance.client.from('products').update({
            'stock_quantity': currentStock + quantity,
          }).eq('id', item['product_id']);

          await Supabase.instance.client.from('stock_movements').insert({
            'product_id': item['product_id'],
            'movement_type': 'in',
            'quantity': quantity,
            'reason': 'Annulation vente',
          });
        }
      }

      await Supabase.instance.client.from('sales').update({
        'status': 'cancelled',
      }).eq('id', sale['id']);

      await ActivityLogger.log(
        action: 'ANNULATION_VENTE',
        description: 'Vente annulée : ${money(sale['total_amount'])}',
      );

      await loadSales();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vente annulée avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur annulation : $e')),
        );
      }
    }

    if (mounted) {
      setState(() => cancelling = false);
    }
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
                              'Recherchez, consultez et contrôlez les ventes',
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
                    height: 540,
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
                                onTap: () => showSaleDetails(sale),
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
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      saleDate(sale),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Voir détail',
                                      style: TextStyle(
                                        color: AppTheme.textGrey,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textGrey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
