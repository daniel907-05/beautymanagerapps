import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logs/activity_logger.dart';
import '../../core/settings/salon_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';

class CaissePage extends StatefulWidget {
  const CaissePage({super.key});

  @override
  State<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends State<CaissePage> {
  List employees = [];
  List services = [];
  List products = [];

  String saleType = 'service';
  String paymentMethod = 'cash';

  String? selectedEmployeeId;
  Map<String, dynamic>? selectedService;
  Map<String, dynamic>? selectedProduct;

  final quantityController = TextEditingController(text: '1');

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final employeesResponse = await Supabase.instance.client
        .from('employees')
        .select()
        .eq('is_active', true)
        .order('full_name');

    final servicesResponse = await Supabase.instance.client
        .from('services')
        .select()
        .eq('is_active', true)
        .order('name');

    final productsResponse = await Supabase.instance.client
        .from('products')
        .select()
        .eq('is_active', true)
        .order('name');

    if (!mounted) return;

    setState(() {
      employees = employeesResponse;
      services = servicesResponse;
      products = productsResponse;
      loading = false;
    });
  }

  double getSelectedAmount() {
    if (saleType == 'service') {
      return (selectedService?['price'] as num?)?.toDouble() ?? 0;
    }

    final price = (selectedProduct?['sale_price'] as num?)?.toDouble() ?? 0;
    final quantity = int.tryParse(quantityController.text.trim()) ?? 1;

    return price * quantity;
  }

  Future<bool> isCashClosedToday() async {
    final today = DateHelper.todayDateOnly();

    final closedSession = await Supabase.instance.client
        .from('cash_sessions')
        .select()
        .eq('session_date', today)
        .eq('status', 'closed')
        .maybeSingle();

    return closedSession != null;
  }

  String employeeName() {
    if (selectedEmployeeId == null) return 'Vente produit';

    final employee = employees.firstWhere(
      (item) => item['id'] == selectedEmployeeId,
      orElse: () => {'full_name': 'Employé'},
    );

    return employee['full_name'] ?? 'Employé';
  }

  String currentItemName() {
    if (saleType == 'service') return selectedService?['name'] ?? 'Service';
    return selectedProduct?['name'] ?? 'Produit';
  }

  Future<Uint8List> buildTicketPdf(Map sale) async {
    await SalonSettings.load();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                SalonSettings.salonName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(SalonSettings.salonPhone),
              pw.Text(SalonSettings.salonAddress),
              pw.SizedBox(height: 12),
              pw.Text(
                'Ticket de vente',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Date : ${DateTime.now()}'),
              pw.Text('Employé : ${employeeName()}'),
              pw.Text('Article : ${currentItemName()}'),
              pw.Text('Paiement : ${paymentLabel(paymentMethod)}'),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total : ${money((sale['total_amount'] as num?)?.toDouble() ?? getSelectedAmount())}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 18),
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

  Future<void> printTicket(Map sale) async {
    final pdfData = await buildTicketPdf(sale);
    await Printing.layoutPdf(onLayout: (_) async => pdfData);
  }

  Future<void> saveSale() async {
    final closed = await isCashClosedToday();

    if (closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’enregistrer une vente : la caisse est déjà clôturée aujourd’hui',
          ),
        ),
      );
      return;
    }

    if (saleType == 'service') {
      if (selectedEmployeeId == null || selectedService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisissez un employé et un service')),
        );
        return;
      }
    }

    if (saleType == 'product') {
      if (selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisissez un produit')),
        );
        return;
      }

      final quantity = int.tryParse(quantityController.text.trim()) ?? 0;

      if (quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La quantité doit être supérieure à 0')),
        );
        return;
      }
    }

    setState(() => saving = true);

    try {
      double commissionPercent = 0;
      double employeeAmount = 0;
      double salonAmount = 0;
      final totalAmount = getSelectedAmount();

      if (saleType == 'service') {
        final contract = await Supabase.instance.client
            .from('employee_contracts')
            .select()
            .eq('employee_id', selectedEmployeeId!)
            .eq('is_active', true)
            .maybeSingle();

        commissionPercent = contract == null
            ? 0
            : (contract['commission_percent'] as num).toDouble();

        employeeAmount = totalAmount * commissionPercent / 100;
        salonAmount = totalAmount - employeeAmount;
      } else {
        salonAmount = totalAmount;
      }

      final sale = await Supabase.instance.client
          .from('sales')
          .insert({
            'employee_id': saleType == 'service' ? selectedEmployeeId : null,
            'total_clients': saleType == 'service' ? 1 : 0,
            'total_amount': totalAmount,
            'commission_percent_snapshot': commissionPercent,
            'employee_amount': employeeAmount,
            'salon_amount': salonAmount,
            'payment_method': paymentMethod,
            'status': 'validated',
            'sale_date': DateHelper.localIsoNow(),
          })
          .select()
          .single();

      if (saleType == 'service') {
        await Supabase.instance.client.from('sale_items').insert({
          'sale_id': sale['id'],
          'item_type': 'service',
          'service_id': selectedService!['id'],
          'quantity': 1,
          'unit_price': totalAmount,
          'total_price': totalAmount,
        });
      } else {
        final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
        final unitPrice =
            (selectedProduct!['sale_price'] as num?)?.toDouble() ?? 0;
        final currentStock =
            (selectedProduct!['stock_quantity'] as num?)?.toInt() ?? 0;
        final newStock = currentStock - quantity;

        if (newStock < 0) throw Exception('Stock insuffisant');

        await Supabase.instance.client.from('sale_items').insert({
          'sale_id': sale['id'],
          'item_type': 'product',
          'product_id': selectedProduct!['id'],
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_price': unitPrice * quantity,
        });

        await Supabase.instance.client.from('products').update(
            {'stock_quantity': newStock}).eq('id', selectedProduct!['id']);

        await Supabase.instance.client.from('stock_movements').insert({
          'product_id': selectedProduct!['id'],
          'movement_type': 'out',
          'quantity': quantity,
          'reason': 'Vente produit',
        });
      }

      await ActivityLogger.log(
        action: 'VENTE',
        description: 'Nouvelle vente de ${money(totalAmount)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vente enregistrée avec succès')),
        );

        await printTicket(sale);

        setState(() {
          selectedEmployeeId = null;
          selectedService = null;
          selectedProduct = null;
          quantityController.text = '1';
          paymentMethod = 'cash';
        });

        await loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vente : $e')),
        );
      }
    }

    if (mounted) setState(() => saving = false);
  }

  String money(double value) => '${value.toStringAsFixed(0)} FCFA';

  String paymentLabel(String value) {
    switch (value) {
      case 'cash':
        return 'Espèces';
      case 'mobile_money':
        return 'Mobile Money';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(22),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caisse',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enregistrez une vente service ou produit',
                    style: TextStyle(fontSize: 14, color: AppTheme.textGrey),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 480,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'service',
                              label: Text('Service'),
                              icon: Icon(Icons.spa),
                            ),
                            ButtonSegment(
                              value: 'product',
                              label: Text('Produit'),
                              icon: Icon(Icons.inventory_2),
                            ),
                          ],
                          selected: {saleType},
                          onSelectionChanged: (value) {
                            setState(() {
                              saleType = value.first;
                              selectedService = null;
                              selectedProduct = null;
                              quantityController.text = '1';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        if (saleType == 'service') ...[
                          DropdownButtonFormField<String>(
                            value: selectedEmployeeId,
                            decoration:
                                const InputDecoration(labelText: 'Employé'),
                            items: employees.map<DropdownMenuItem<String>>((e) {
                              return DropdownMenuItem<String>(
                                value: e['id'],
                                child: Text(e['full_name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedEmployeeId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: selectedService,
                            decoration:
                                const InputDecoration(labelText: 'Service'),
                            items: services
                                .map<DropdownMenuItem<Map<String, dynamic>>>(
                                    (s) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: s,
                                child:
                                    Text('${s['name']} - ${s['price']} FCFA'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedService = value);
                            },
                          ),
                        ],
                        if (saleType == 'product') ...[
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: selectedProduct,
                            decoration:
                                const InputDecoration(labelText: 'Produit'),
                            items: products
                                .map<DropdownMenuItem<Map<String, dynamic>>>(
                                    (p) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: p,
                                child: Text(
                                  '${p['name']} - ${p['sale_price']} FCFA | Stock: ${p['stock_quantity']}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedProduct = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Quantité'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          decoration: const InputDecoration(
                              labelText: 'Mode de paiement'),
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Espèces')),
                            DropdownMenuItem(
                                value: 'mobile_money',
                                child: Text('Mobile Money')),
                          ],
                          onChanged: (value) {
                            setState(() => paymentMethod = value ?? 'cash');
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Montant : ${money(getSelectedAmount())}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: saving ? null : saveSale,
                            icon: const Icon(Icons.point_of_sale),
                            label: Text(saving
                                ? 'Enregistrement...'
                                : 'Valider et imprimer'),
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
