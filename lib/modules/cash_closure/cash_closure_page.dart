import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class CashClosurePage extends StatefulWidget {
  const CashClosurePage({super.key});

  @override
  State<CashClosurePage> createState() => _CashClosurePageState();
}

class _CashClosurePageState extends State<CashClosurePage> {
  bool loading = true;
  bool saving = false;

  String selectedPeriod = 'today';
  DateTime? selectedDate;

  double cashAmount = 0;
  double mobileMoneyAmount = 0;
  double cardAmount = 0;
  double totalSalesAmount = 0;

  final actualController = TextEditingController();

  List sessions = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  double get actualAmount => double.tryParse(actualController.text.trim()) ?? 0;

  double get expectedAmount => cashAmount;

  double get difference => actualAmount - expectedAmount;

  Future<void> loadData() async {
    setState(() => loading = true);

    await loadExpectedAmount();
    await loadSessions();

    setState(() => loading = false);
  }

  Future<void> loadExpectedAmount() async {
    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).toIso8601String();

    final sales = await Supabase.instance.client
        .from('sales')
        .select()
        .eq('status', 'validated')
        .gte('sale_date', startOfDay)
        .lt('sale_date', endOfDay);

    double cash = 0;
    double mobile = 0;
    double card = 0;
    double total = 0;

    for (final sale in sales) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final method = sale['payment_method'];

      total += amount;

      if (method == 'cash') {
        cash += amount;
      } else if (method == 'mobile_money') {
        mobile += amount;
      } else if (method == 'card') {
        card += amount;
      }
    }

    cashAmount = cash;
    mobileMoneyAmount = mobile;
    cardAmount = card;
    totalSalesAmount = total;
  }

  Future<void> loadSessions() async {
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

    var query = Supabase.instance.client.from('cash_sessions').select();

    if (startDate != null) {
      query = query.gte(
        'session_date',
        startDate.toIso8601String().split('T').first,
      );
    }

    if (endDate != null) {
      query = query.lt(
        'session_date',
        endDate.toIso8601String().split('T').first,
      );
    }

    final response = await query.order(
      'session_date',
      ascending: false,
    );

    sessions = response;
  }

  Future<void> closeCash() async {
    final actual = actualAmount;

    if (actual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saisissez le montant compté'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    final today = DateTime.now().toIso8601String().split('T').first;

    final existingSession = await Supabase.instance.client
        .from('cash_sessions')
        .select()
        .eq('session_date', today)
        .eq('status', 'closed')
        .maybeSingle();

    if (existingSession != null) {
      setState(() => saving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La caisse est déjà clôturée aujourd’hui'),
          ),
        );
      }

      return;
    }

    await Supabase.instance.client.from('cash_sessions').insert({
      'session_date': today,
      'expected_amount': expectedAmount,
      'actual_amount': actual,
      'difference': difference,
      'status': 'closed',
    });

    actualController.clear();

    await loadData();

    setState(() => saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caisse clôturée avec succès'),
        ),
      );
    }
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

      loadData();
    }
  }

  void resetFilters() {
    setState(() {
      selectedPeriod = 'today';
      selectedDate = null;
    });

    loadData();
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

  String sessionDate(Map session) {
    final raw = session['session_date'];

    if (raw == null) return '-';

    final date = DateTime.tryParse(raw.toString());

    if (date == null) return raw.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Color differenceColor(double value) {
    if (value == 0) return Colors.green;
    if (value > 0) return Colors.orange;
    return Colors.red;
  }

  Future<Uint8List> buildPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BeautyManagerApps - Cloture de caisse',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Especes attendues : ${money(cashAmount)}'),
              pw.Text('Mobile Money : ${money(mobileMoneyAmount)}'),
              pw.Text('Carte : ${money(cardAmount)}'),
              pw.Text('Total ventes : ${money(totalSalesAmount)}'),
              pw.SizedBox(height: 12),
              pw.Text('Montant compte en especes : ${money(actualAmount)}'),
              pw.Text('Difference especes : ${money(difference)}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Historique des clotures',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Attendu', 'Reel', 'Difference', 'Statut'],
                data: sessions.map((session) {
                  return [
                    sessionDate(session),
                    money(
                        (session['expected_amount'] as num?)?.toDouble() ?? 0),
                    money((session['actual_amount'] as num?)?.toDouble() ?? 0),
                    money((session['difference'] as num?)?.toDouble() ?? 0),
                    session['status'] ?? '-',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> printClosure() async {
    final pdfData = await buildPdf();

    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                              'Clôture caisse',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Contrôlez les espèces et suivez les paiements',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _CashCard(
                        title: 'Espèces attendues',
                        value: money(cashAmount),
                        icon: Icons.payments,
                        color: AppTheme.gold,
                      ),
                      _CashCard(
                        title: 'Mobile Money',
                        value: money(mobileMoneyAmount),
                        icon: Icons.phone_android,
                        color: Colors.blue,
                      ),
                      _CashCard(
                        title: 'Carte',
                        value: money(cardAmount),
                        icon: Icons.credit_card,
                        color: Colors.purple,
                      ),
                      _CashCard(
                        title: 'Total ventes',
                        value: money(totalSalesAmount),
                        icon: Icons.point_of_sale,
                        color: AppTheme.gold,
                      ),
                      _CashCard(
                        title: 'Montant compté',
                        value: money(actualAmount),
                        icon: Icons.account_balance_wallet,
                        color: AppTheme.gold,
                      ),
                      _CashCard(
                        title: 'Différence espèces',
                        value: money(difference),
                        icon: Icons.compare_arrows,
                        color: differenceColor(difference),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: actualController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Espèces réellement comptées',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: saving ? null : closeCash,
                          icon: const Icon(Icons.lock),
                          label: Text(
                            saving
                                ? 'Clôture en cours...'
                                : 'Clôturer la caisse',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: printClosure,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Exporter PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: printClosure,
                          icon: const Icon(Icons.print),
                          label: const Text('Imprimer clôture'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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

                          loadData();
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
                  const SizedBox(height: 24),
                  Container(
                    height: 430,
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: sessions.isEmpty
                        ? const Center(
                            child: Text('Aucune clôture enregistrée'),
                          )
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final diff =
                                  (session['difference'] as num?)?.toDouble() ??
                                      0;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      differenceColor(diff).withOpacity(0.15),
                                  child: Icon(
                                    Icons.lock,
                                    color: differenceColor(diff),
                                  ),
                                ),
                                title: Text(
                                  sessionDate(session),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  'Attendu espèces : ${money((session['expected_amount'] as num?)?.toDouble() ?? 0)} • '
                                  'Compté : ${money((session['actual_amount'] as num?)?.toDouble() ?? 0)}',
                                ),
                                trailing: Text(
                                  money(diff),
                                  style: TextStyle(
                                    color: differenceColor(diff),
                                    fontWeight: FontWeight.w900,
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

class _CashCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CashCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 140,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
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
              style: const TextStyle(color: AppTheme.textGrey),
            ),
          ],
        ),
      ),
    );
  }
}
