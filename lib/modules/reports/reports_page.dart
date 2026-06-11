import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_package;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  double totalCash = 0;
  double totalMobileMoney = 0;
  double totalCard = 0;
  double totalExpenses = 0;
  double netResult = 0;
  double totalCommissions = 0;
  double totalSalon = 0;

  int totalClients = 0;
  int totalTransactions = 0;

  List sales = [];
  List expenses = [];
  List employees = [];
  Map<String, String> employeeNames = {};

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

    final salesResponse = await salesQuery.order(
      'sale_date',
      ascending: false,
    );

    final expensesResponse = await expensesQuery.order(
      'expense_date',
      ascending: false,
    );

    final employeesResponse = await Supabase.instance.client
        .from('employees')
        .select('id, full_name');

    final names = <String, String>{};

    for (final employee in employeesResponse) {
      names[employee['id']] = employee['full_name'] ?? 'Employé inconnu';
    }

    double salesTotal = 0;
    double cashTotal = 0;
    double mobileTotal = 0;
    double cardTotal = 0;
    double commissionsTotal = 0;
    double salonTotal = 0;
    int clientsTotal = 0;

    for (final sale in salesResponse) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final method = sale['payment_method'];

      salesTotal += amount;

      if (method == 'cash') {
        cashTotal += amount;
      } else if (method == 'mobile_money') {
        mobileTotal += amount;
      } else if (method == 'card') {
        cardTotal += amount;
      }

      commissionsTotal += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      salonTotal += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
      clientsTotal += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }

    double expensesTotal = 0;

    for (final expense in expensesResponse) {
      expensesTotal += (expense['amount'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      employees = employeesResponse;
      employeeNames = names;

      sales = salesResponse;
      expenses = expensesResponse;

      totalSales = salesTotal;
      totalCash = cashTotal;
      totalMobileMoney = mobileTotal;
      totalCard = cardTotal;

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
    final raw = sale['sale_date'];

    if (raw == null) return '-';

    final date = DateTime.tryParse(raw.toString());

    if (date == null) return raw.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<Uint8List> buildPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              'BeautyManagerApps - Rapport financier',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Période : ${periodTitle()}'),
            pw.SizedBox(height: 20),
            pw.Text(
              'Résumé',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Indicateur', 'Valeur'],
              data: [
                ['Espèces', money(totalCash)],
                ['Mobile Money', money(totalMobileMoney)],
                ['Carte', money(totalCard)],
                ['Total ventes', money(totalSales)],
                ['Dépenses incluses', money(totalExpenses)],
                ['Résultat net', money(netResult)],
                ['Clients', totalClients.toString()],
                ['Transactions', totalTransactions.toString()],
                ['Commissions', money(totalCommissions)],
                ['Part salon brute', money(totalSalon)],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Ventes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Employé',
                'Montant',
                'Paiement',
                'Commission',
                'Salon',
              ],
              data: sales.map((sale) {
                return [
                  saleDate(sale),
                  employeeName(sale),
                  money((sale['total_amount'] as num?)?.toDouble() ?? 0),
                  paymentLabel(sale['payment_method']),
                  money((sale['employee_amount'] as num?)?.toDouble() ?? 0),
                  money((sale['salon_amount'] as num?)?.toDouble() ?? 0),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Dépenses incluses',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Catégorie', 'Montant', 'Description'],
              data: expenses.map((expense) {
                return [
                  expense['expense_date'] ?? '-',
                  expense['category'] ?? '-',
                  money((expense['amount'] as num?)?.toDouble() ?? 0),
                  expense['description'] ?? '-',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printReport() async {
    final data = await buildPdf();
    await Printing.layoutPdf(onLayout: (_) async => data);
  }

  Future<void> exportExcel() async {
    final excel = excel_package.Excel.createExcel();

    final summarySheet = excel['Résumé'];

    summarySheet.appendRow([
      excel_package.TextCellValue('Indicateur'),
      excel_package.TextCellValue('Valeur'),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Période'),
      excel_package.TextCellValue(periodTitle()),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Espèces'),
      excel_package.DoubleCellValue(totalCash),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Mobile Money'),
      excel_package.DoubleCellValue(totalMobileMoney),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Carte'),
      excel_package.DoubleCellValue(totalCard),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Total ventes'),
      excel_package.DoubleCellValue(totalSales),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Dépenses incluses'),
      excel_package.DoubleCellValue(totalExpenses),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Résultat net'),
      excel_package.DoubleCellValue(netResult),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Clients'),
      excel_package.IntCellValue(totalClients),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Transactions'),
      excel_package.IntCellValue(totalTransactions),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Commissions'),
      excel_package.DoubleCellValue(totalCommissions),
    ]);

    summarySheet.appendRow([
      excel_package.TextCellValue('Part salon brute'),
      excel_package.DoubleCellValue(totalSalon),
    ]);

    final salesSheet = excel['Ventes'];

    salesSheet.appendRow([
      excel_package.TextCellValue('Date'),
      excel_package.TextCellValue('Employé'),
      excel_package.TextCellValue('Montant'),
      excel_package.TextCellValue('Paiement'),
      excel_package.TextCellValue('Commission'),
      excel_package.TextCellValue('Part salon'),
    ]);

    for (final sale in sales) {
      salesSheet.appendRow([
        excel_package.TextCellValue(saleDate(sale)),
        excel_package.TextCellValue(employeeName(sale)),
        excel_package.DoubleCellValue(
          (sale['total_amount'] as num?)?.toDouble() ?? 0,
        ),
        excel_package.TextCellValue(
          paymentLabel(sale['payment_method']),
        ),
        excel_package.DoubleCellValue(
          (sale['employee_amount'] as num?)?.toDouble() ?? 0,
        ),
        excel_package.DoubleCellValue(
          (sale['salon_amount'] as num?)?.toDouble() ?? 0,
        ),
      ]);
    }

    final expensesSheet = excel['Dépenses'];

    expensesSheet.appendRow([
      excel_package.TextCellValue('Date'),
      excel_package.TextCellValue('Catégorie'),
      excel_package.TextCellValue('Montant'),
      excel_package.TextCellValue('Description'),
    ]);

    for (final expense in expenses) {
      expensesSheet.appendRow([
        excel_package.TextCellValue(expense['expense_date'] ?? '-'),
        excel_package.TextCellValue(expense['category'] ?? '-'),
        excel_package.DoubleCellValue(
          (expense['amount'] as num?)?.toDouble() ?? 0,
        ),
        excel_package.TextCellValue(expense['description'] ?? '-'),
      ]);
    }

    final bytes = excel.encode();

    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'rapport_financier_beautymanager',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
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
                              'Analyse premium du chiffre d’affaires, paiements, dépenses et résultat net',
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
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: printReport,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF / Imprimer'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: exportExcel,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel'),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.dark,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          color: AppTheme.gold,
                          size: 34,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Période analysée : ${periodTitle()}',
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          'Résultat net : ${money(netResult)}',
                          style: TextStyle(
                            color: netResult >= 0 ? Colors.green : Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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
                        title: 'Espèces',
                        value: money(totalCash),
                        icon: Icons.payments,
                      ),
                      _ReportCard(
                        title: 'Mobile Money',
                        value: money(totalMobileMoney),
                        icon: Icons.phone_android,
                      ),
                      _ReportCard(
                        title: 'Carte',
                        value: money(totalCard),
                        icon: Icons.credit_card,
                      ),
                      _ReportCard(
                        title: 'Total ventes',
                        value: money(totalSales),
                        icon: Icons.point_of_sale,
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
                                          '${employeeName(sale)} • '
                                          '${paymentLabel(sale['payment_method'])} • '
                                          'Commission : ${money((sale['employee_amount'] as num?)?.toDouble() ?? 0)} • '
                                          'Salon : ${money((sale['salon_amount'] as num?)?.toDouble() ?? 0)}',
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
