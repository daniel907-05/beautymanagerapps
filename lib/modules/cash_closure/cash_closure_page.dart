import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/user_role.dart';
import '../../core/logs/activity_logger.dart';
import '../../core/settings/salon_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';

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
  double totalSalesAmount = 0;

  Map<String, dynamic>? todayClosedSession;
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

  String businessDateOnly() {
    final now = DateTime.now();
    final businessNow =
        now.hour < 7 ? now.subtract(const Duration(days: 1)) : now;
    return DateTime(businessNow.year, businessNow.month, businessNow.day)
        .toIso8601String()
        .split('T')
        .first;
  }

  Future<void> loadData() async {
    setState(() => loading = true);
    await loadExpectedAmount();
    await loadTodayClosedSession();
    await loadSessions();
    if (mounted) setState(() => loading = false);
  }

  Future<void> loadExpectedAmount() async {
    final startOfDay = DateHelper.startOfToday().toIso8601String();
    final endOfDay = DateHelper.endOfToday().toIso8601String();

    final sales = await Supabase.instance.client
        .from('sales')
        .select()
        .eq('status', 'validated')
        .gte('sale_date', startOfDay)
        .lt('sale_date', endOfDay);

    double cash = 0;
    double mobile = 0;
    double total = 0;

    for (final sale in sales) {
      final amount = (sale['total_amount'] as num?)?.toDouble() ?? 0;
      final method = sale['payment_method'];

      total += amount;

      if (method == 'cash') {
        cash += amount;
      } else if (method == 'mobile_money') {
        mobile += amount;
      }
    }

    cashAmount = cash;
    mobileMoneyAmount = mobile;
    totalSalesAmount = total;
  }

  Future<void> loadTodayClosedSession() async {
    final today = businessDateOnly();

    todayClosedSession = await Supabase.instance.client
        .from('cash_sessions')
        .select()
        .eq('session_date', today)
        .eq('status', 'closed')
        .maybeSingle();
  }

  Future<void> loadSessions() async {
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
      startDate =
          DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
      endDate = startDate.add(const Duration(days: 1));
    }

    var query = Supabase.instance.client.from('cash_sessions').select();

    if (startDate != null) {
      query = query.gte(
          'session_date', startDate.toIso8601String().split('T').first);
    }

    if (endDate != null) {
      query =
          query.lt('session_date', endDate.toIso8601String().split('T').first);
    }

    sessions = await query.order('session_date', ascending: false);
  }

  Future<void> closeCash() async {
    final actual = actualAmount;

    if (actual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez le montant compté')),
      );
      return;
    }

    setState(() => saving = true);

    final today = businessDateOnly();

    final existingSession = await Supabase.instance.client
        .from('cash_sessions')
        .select()
        .eq('session_date', today)
        .eq('status', 'closed')
        .maybeSingle();

    if (existingSession != null) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'La caisse est déjà clôturée. Réouverture possible seulement par manager/admin.'),
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

    await ActivityLogger.log(
      action: 'CLOTURE_CAISSE',
      description: 'Clôture caisse : ${money(actual)}',
    );

    actualController.clear();
    await loadData();

    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caisse clôturée avec succès')),
      );
    }
  }

  Future<void> reopenCash() async {
    if (!(UserRole.isAdmin || UserRole.isManager)) return;
    if (todayClosedSession == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réouvrir la clôture ?'),
        content: const Text(
            'La caisse pourra être clôturée à nouveau pour la journée courante.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Réouvrir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await Supabase.instance.client
        .from('cash_sessions')
        .update({'status': 'reopened'}).eq('id', todayClosedSession!['id']);

    await ActivityLogger.log(
      action: 'REOUVERTURE_CAISSE',
      description: 'Clôture caisse réouverte par manager/admin',
    );

    await loadData();
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

  String money(double value) => '${value.toStringAsFixed(0)} FCFA';

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
    await SalonSettings.load();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${SalonSettings.salonName} - Clôture de caisse',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(SalonSettings.salonPhone),
              pw.Text(SalonSettings.salonAddress),
              pw.Text(SalonSettings.salonEmail),
              pw.SizedBox(height: 20),
              pw.Text('Espèces attendues : ${money(cashAmount)}'),
              pw.Text('Mobile Money : ${money(mobileMoneyAmount)}'),
              pw.Text('Total ventes : ${money(totalSalesAmount)}'),
              pw.SizedBox(height: 12),
              pw.Text('Montant compté en espèces : ${money(actualAmount)}'),
              pw.Text('Différence espèces : ${money(difference)}'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Historique des clôtures',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Attendu', 'Réel', 'Différence', 'Statut'],
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
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.Text(
                SalonSettings.receiptFooter,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
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
    await Printing.layoutPdf(onLayout: (_) async => pdfData);
  }

  @override
  Widget build(BuildContext context) {
    final alreadyClosed = todayClosedSession != null;

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
                              'Clôture caisse',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Contrôlez les espèces et suivez les paiements',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (alreadyClosed &&
                          (UserRole.isAdmin || UserRole.isManager))
                        OutlinedButton.icon(
                          onPressed: reopenCash,
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Réouvrir clôture'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
                        title: 'Total ventes',
                        value: money(totalSalesAmount),
                        icon: Icons.point_of_sale,
                        color: AppTheme.gold,
                      ),
                      _CashCard(
                        title: 'Compté',
                        value: money(actualAmount),
                        icon: Icons.account_balance_wallet,
                        color: AppTheme.gold,
                      ),
                      _CashCard(
                        title: 'Différence',
                        value: money(difference),
                        icon: Icons.compare_arrows,
                        color: differenceColor(difference),
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
                          width: 240,
                          child: TextField(
                            controller: actualController,
                            enabled: !alreadyClosed,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Espèces réellement comptées',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: saving || alreadyClosed ? null : closeCash,
                          icon: const Icon(Icons.lock),
                          label: Text(
                            alreadyClosed
                                ? 'Clôture effectuée'
                                : saving
                                    ? 'Clôture en cours...'
                                    : 'Clôturer la caisse',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: printClosure,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF / Imprimer'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'today', label: Text('Aujourd’hui')),
                          ButtonSegment(value: 'week', label: Text('Semaine')),
                          ButtonSegment(value: 'month', label: Text('Mois')),
                          ButtonSegment(value: 'all', label: Text('Total')),
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
                  const SizedBox(height: 18),
                  Container(
                    height: 380,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: sessions.isEmpty
                        ? const Center(
                            child: Text('Aucune clôture enregistrée'))
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final diff =
                                  (session['difference'] as num?)?.toDouble() ??
                                      0;

                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      differenceColor(diff).withOpacity(0.15),
                                  child: Icon(Icons.lock,
                                      color: differenceColor(diff)),
                                ),
                                title: Text(
                                  sessionDate(session),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900),
                                ),
                                subtitle: Text(
                                  'Attendu espèces : ${money((session['expected_amount'] as num?)?.toDouble() ?? 0)} • Compté : ${money((session['actual_amount'] as num?)?.toDouble() ?? 0)}',
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
      width: 190,
      height: 100,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
