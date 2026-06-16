import 'dart:async';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_package;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings/salon_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';

class EmployeeStats {
  final String id;
  final String name;
  double sales;
  double commissions;
  int clients;

  EmployeeStats({
    required this.id,
    required this.name,
    this.sales = 0,
    this.commissions = 0,
    this.clients = 0,
  });
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  Timer? _refreshTimer;

  bool loading = true;
  String selectedPeriod = 'today';
  DateTime? selectedDate;

  double totalSales = 0;
  double totalCash = 0;
  double totalMobileMoney = 0;
  double totalExpenses = 0;
  double netResult = 0;
  double totalCommissions = 0;
  double totalSalon = 0;

  int totalClients = 0;
  int totalTransactions = 0;

  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> employees = [];
  Map<String, String> employeeNames = {};

  @override
  void initState() {
    super.initState();
    loadReports();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        loadReports(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadReports({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

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
        .select('id, full_name')
        .order('full_name');

    final loadedSales = List<Map<String, dynamic>>.from(salesResponse as List);
    final loadedExpenses =
        List<Map<String, dynamic>>.from(expensesResponse as List);
    final loadedEmployees =
        List<Map<String, dynamic>>.from(employeesResponse as List);

    final names = <String, String>{};
    for (final employee in loadedEmployees) {
      names[employee['id'].toString()] =
          employee['full_name']?.toString() ?? 'Employé inconnu';
    }

    double salesTotal = 0;
    double cashTotal = 0;
    double mobileTotal = 0;
    double commissionsTotal = 0;
    double salonTotal = 0;
    double expensesTotal = 0;
    int clientsTotal = 0;

    for (final sale in loadedSales) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final method = sale['payment_method']?.toString();

      salesTotal += amount;

      if (method == 'cash') {
        cashTotal += amount;
      } else if (method == 'mobile_money') {
        mobileTotal += amount;
      }

      commissionsTotal += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      salonTotal += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
      clientsTotal += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }

    for (final expense in loadedExpenses) {
      expensesTotal += (expense['amount'] as num?)?.toDouble() ?? 0;
    }

    if (!mounted) return;

    setState(() {
      sales = loadedSales;
      expenses = loadedExpenses;
      employees = loadedEmployees;
      employeeNames = names;
      totalSales = salesTotal;
      totalCash = cashTotal;
      totalMobileMoney = mobileTotal;
      totalExpenses = expensesTotal;
      netResult = salesTotal - expensesTotal;
      totalCommissions = commissionsTotal;
      totalSalon = salonTotal;
      totalClients = clientsTotal;
      totalTransactions = loadedSales.length;
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
      case 'date':
        return selectedDateLabel();
      case 'all':
        return 'Total général';
      default:
        return '';
    }
  }

  String employeeName(Map<String, dynamic> sale) {
    final employeeId = sale['employee_id'];
    if (employeeId == null) {
      return 'Vente produit';
    }
    return employeeNames[employeeId.toString()] ?? 'Employé inconnu';
  }

  String paymentLabel(dynamic value) {
    if (value == 'cash') return 'Espèces';
    if (value == 'mobile_money') return 'Mobile Money';
    return value?.toString() ?? '-';
  }

  String saleDate(Map<String, dynamic> sale) {
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

  List<EmployeeStats> getEmployeeStats() {
    final stats = <String, EmployeeStats>{};

    for (final sale in sales) {
      final employeeId = sale['employee_id'];
      if (employeeId == null) continue;

      final id = employeeId.toString();
      final name = employeeNames[id] ?? 'Employé inconnu';

      stats.putIfAbsent(
        id,
        () => EmployeeStats(id: id, name: name),
      );

      stats[id]!.sales += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      stats[id]!.commissions +=
          (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      stats[id]!.clients += (sale['total_clients'] as num?)?.toInt() ?? 0;
    }

    final result = stats.values.toList();
    result.sort((a, b) => b.sales.compareTo(a.sales));
    return result;
  }

  List<EmployeeStats> getTopEmployees() {
    return getEmployeeStats().take(5).toList();
  }

  Future<Uint8List> buildPdf() async {
    await SalonSettings.load();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          return [
            pw.Text(
              '${SalonSettings.salonName} - Rapport financier',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(SalonSettings.salonPhone),
            pw.Text(SalonSettings.salonAddress),
            pw.Text(SalonSettings.salonEmail),
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
              'Top employés',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Employé', 'CA', 'Clients', 'Commissions'],
              data: getTopEmployees().map((employee) {
                return [
                  employee.name,
                  money(employee.sales),
                  employee.clients.toString(),
                  money(employee.commissions),
                ];
              }).toList(),
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
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              SalonSettings.receiptFooter,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10),
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

  Future<Uint8List> buildEmployeePaymentsPdf() async {
    await SalonSettings.load();
    final stats = getEmployeeStats();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            '${SalonSettings.salonName} - État de paiement employés',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Période : ${periodTitle()}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Employé', 'CA', 'Clients', 'À payer'],
            data: stats.map((employee) {
              return [
                employee.name,
                money(employee.sales),
                employee.clients.toString(),
                money(employee.commissions),
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

  Future<void> printEmployeePayments() async {
    final data = await buildEmployeePaymentsPdf();
    await Printing.layoutPdf(onLayout: (_) async => data);
  }

  Future<void> exportEmployeePaymentsExcel() async {
    final excel = excel_package.Excel.createExcel();
    final sheet = excel['État paiements'];

    sheet.appendRow([
      excel_package.TextCellValue('Période'),
      excel_package.TextCellValue(periodTitle()),
    ]);
    sheet.appendRow([]);
    sheet.appendRow([
      excel_package.TextCellValue('Employé'),
      excel_package.TextCellValue('CA'),
      excel_package.TextCellValue('Clients'),
      excel_package.TextCellValue('Commissions à payer'),
    ]);

    for (final employee in getEmployeeStats()) {
      sheet.appendRow([
        excel_package.TextCellValue(employee.name),
        excel_package.DoubleCellValue(employee.sales),
        excel_package.IntCellValue(employee.clients),
        excel_package.DoubleCellValue(employee.commissions),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'etat_paiement_employes_beautymanager',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
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

    final paymentSheet = excel['Paiements'];
    paymentSheet.appendRow([
      excel_package.TextCellValue('Mode de paiement'),
      excel_package.TextCellValue('Montant'),
    ]);
    paymentSheet.appendRow([
      excel_package.TextCellValue('Espèces'),
      excel_package.DoubleCellValue(totalCash),
    ]);
    paymentSheet.appendRow([
      excel_package.TextCellValue('Mobile Money'),
      excel_package.DoubleCellValue(totalMobileMoney),
    ]);
    paymentSheet.appendRow([
      excel_package.TextCellValue('Total paiements'),
      excel_package.DoubleCellValue(totalSales),
    ]);

    final topEmployeesSheet = excel['Top employés'];
    topEmployeesSheet.appendRow([
      excel_package.TextCellValue('Employé'),
      excel_package.TextCellValue('CA généré'),
      excel_package.TextCellValue('Clients'),
      excel_package.TextCellValue('Commissions'),
    ]);
    for (final employee in getTopEmployees()) {
      topEmployeesSheet.appendRow([
        excel_package.TextCellValue(employee.name),
        excel_package.DoubleCellValue(employee.sales),
        excel_package.IntCellValue(employee.clients),
        excel_package.DoubleCellValue(employee.commissions),
      ]);
    }

    final pivotSheet = excel['Tableau croisé'];
    pivotSheet.appendRow([
      excel_package.TextCellValue('Employé'),
      excel_package.TextCellValue('Paiement'),
      excel_package.TextCellValue('CA'),
      excel_package.TextCellValue('Clients'),
      excel_package.TextCellValue('Commissions'),
      excel_package.TextCellValue('Part salon'),
    ]);

    final pivotData = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final employee = employeeName(sale);
      final payment = paymentLabel(sale['payment_method']);
      final key = '$employee|$payment';

      pivotData.putIfAbsent(
        key,
        () => {
          'employee': employee,
          'payment': payment,
          'sales': 0.0,
          'clients': 0,
          'commissions': 0.0,
          'salon': 0.0,
        },
      );

      pivotData[key]!['sales'] = (pivotData[key]!['sales'] as double) +
          ((sale['total_amount'] as num?)?.toDouble() ?? 0);
      pivotData[key]!['clients'] = (pivotData[key]!['clients'] as int) +
          ((sale['total_clients'] as num?)?.toInt() ?? 0);
      pivotData[key]!['commissions'] =
          (pivotData[key]!['commissions'] as double) +
              ((sale['employee_amount'] as num?)?.toDouble() ?? 0);
      pivotData[key]!['salon'] = (pivotData[key]!['salon'] as double) +
          ((sale['salon_amount'] as num?)?.toDouble() ?? 0);
    }

    for (final row in pivotData.values) {
      pivotSheet.appendRow([
        excel_package.TextCellValue(row['employee'].toString()),
        excel_package.TextCellValue(row['payment'].toString()),
        excel_package.DoubleCellValue(row['sales'] as double),
        excel_package.IntCellValue(row['clients'] as int),
        excel_package.DoubleCellValue(row['commissions'] as double),
        excel_package.DoubleCellValue(row['salon'] as double),
      ]);
    }

    final dailySheet = excel['Croisé par jour'];
    dailySheet.appendRow([
      excel_package.TextCellValue('Date'),
      excel_package.TextCellValue('CA'),
      excel_package.TextCellValue('Espèces'),
      excel_package.TextCellValue('Mobile Money'),
      excel_package.TextCellValue('Clients'),
      excel_package.TextCellValue('Transactions'),
    ]);

    final dailyData = <String, Map<String, dynamic>>{};
    for (final sale in sales) {
      final date = saleDate(sale).split(' ').first;
      final method = sale['payment_method'];
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;

      dailyData.putIfAbsent(
        date,
        () => {
          'date': date,
          'sales': 0.0,
          'cash': 0.0,
          'mobile_money': 0.0,
          'clients': 0,
          'transactions': 0,
        },
      );

      dailyData[date]!['sales'] =
          (dailyData[date]!['sales'] as double) + amount;
      dailyData[date]!['clients'] = (dailyData[date]!['clients'] as int) +
          ((sale['total_clients'] as num?)?.toInt() ?? 0);
      dailyData[date]!['transactions'] =
          (dailyData[date]!['transactions'] as int) + 1;

      if (method == 'cash') {
        dailyData[date]!['cash'] =
            (dailyData[date]!['cash'] as double) + amount;
      } else if (method == 'mobile_money') {
        dailyData[date]!['mobile_money'] =
            (dailyData[date]!['mobile_money'] as double) + amount;
      }
    }

    for (final row in dailyData.values) {
      dailySheet.appendRow([
        excel_package.TextCellValue(row['date'].toString()),
        excel_package.DoubleCellValue(row['sales'] as double),
        excel_package.DoubleCellValue(row['cash'] as double),
        excel_package.DoubleCellValue(row['mobile_money'] as double),
        excel_package.IntCellValue(row['clients'] as int),
        excel_package.IntCellValue(row['transactions'] as int),
      ]);
    }

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
        excel_package.TextCellValue(paymentLabel(sale['payment_method'])),
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
        excel_package.TextCellValue(expense['expense_date']?.toString() ?? '-'),
        excel_package.TextCellValue(expense['category']?.toString() ?? '-'),
        excel_package.DoubleCellValue(
          (expense['amount'] as num?)?.toDouble() ?? 0,
        ),
        excel_package.TextCellValue(expense['description']?.toString() ?? '-'),
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
      padding: const EdgeInsets.all(22),
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
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Analyse du chiffre d’affaires, paiements, dépenses et résultat net',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: printReport,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: exportExcel,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: printEmployeePayments,
                        icon: const Icon(Icons.payments),
                        label: const Text('État paiement PDF'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: exportEmployeePaymentsExcel,
                        icon: const Icon(Icons.grid_on),
                        label: const Text('État paiement Excel'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                          ButtonSegment(value: 'week', label: Text('Semaine')),
                          ButtonSegment(value: 'month', label: Text('Mois')),
                          ButtonSegment(value: 'all', label: Text('Total')),
                        ],
                        selected: {
                          selectedPeriod == 'date' ? 'all' : selectedPeriod,
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
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.dark,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          color: AppTheme.gold,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Période : ${periodTitle()}',
                            style: const TextStyle(
                              color: AppTheme.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          'Résultat : ${money(netResult)}',
                          style: TextStyle(
                            color: netResult >= 0 ? Colors.green : Colors.red,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: cardColumns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.2,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top employés',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        getTopEmployees().isEmpty
                            ? const Text(
                                'Aucune performance employé pour cette période',
                                style: TextStyle(color: AppTheme.textGrey),
                              )
                            : Column(
                                children: getTopEmployees().map((employee) {
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppTheme.gold.withOpacity(0.18),
                                      child: const Icon(
                                        Icons.emoji_events,
                                        color: AppTheme.gold,
                                      ),
                                    ),
                                    title: Text(
                                      employee.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Clients : ${employee.clients} • Commission : ${money(employee.commissions)}',
                                    ),
                                    trailing: Text(
                                      money(employee.sales),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 390,
                    child: Row(
                      children: [
                        Expanded(
                          child: _ReportListCard(
                            title: 'Dernières ventes',
                            child: sales.isEmpty
                                ? const Center(
                                    child: Text('Aucune vente trouvée'))
                                : ListView.separated(
                                    itemCount: sales.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(),
                                    itemBuilder: (context, index) {
                                      final sale = sales[index];
                                      return ListTile(
                                        dense: true,
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
                        const SizedBox(width: 14),
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
                                        dense: true,
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
                                          expense['expense_date']?.toString() ??
                                              '',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: highlight
            ? Border.all(color: positive ? Colors.green : Colors.red)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
