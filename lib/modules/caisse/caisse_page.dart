import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

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

  Future<void> saveSale() async {
    if (saleType == 'service') {
      if (selectedEmployeeId == null || selectedService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choisissez un employé et un service'),
          ),
        );
        return;
      }
    }

    if (saleType == 'product') {
      if (selectedProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choisissez un produit'),
          ),
        );
        return;
      }
    }

    setState(() => saving = true);

    try {
      double commissionPercent = 0;
      double employeeAmount = 0;
      double salonAmount = 0;
      double totalAmount = getSelectedAmount();

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
            'payment_method': 'cash',
            'status': 'validated',
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

        if (newStock < 0) {
          throw Exception('Stock insuffisant');
        }

        await Supabase.instance.client.from('sale_items').insert({
          'sale_id': sale['id'],
          'item_type': 'product',
          'product_id': selectedProduct!['id'],
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_price': unitPrice * quantity,
        });

        await Supabase.instance.client
            .from('products')
            .update({'stock_quantity': newStock}).eq(
          'id',
          selectedProduct!['id'],
        );

        await Supabase.instance.client.from('stock_movements').insert({
          'product_id': selectedProduct!['id'],
          'movement_type': 'out',
          'quantity': quantity,
          'reason': 'Vente produit',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vente enregistrée avec succès')),
        );

        setState(() {
          selectedEmployeeId = null;
          selectedService = null;
          selectedProduct = null;
          quantityController.text = '1';
        });

        loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vente : $e')),
        );
      }
    }

    if (mounted) {
      setState(() => saving = false);
    }
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
                const Text(
                  'Caisse',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enregistrez une vente service ou produit',
                  style: TextStyle(fontSize: 16, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 560,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(24),
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
                      const SizedBox(height: 22),
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
                        const SizedBox(height: 18),
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedService,
                          decoration:
                              const InputDecoration(labelText: 'Service'),
                          items: services
                              .map<DropdownMenuItem<Map<String, dynamic>>>((s) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: s,
                              child: Text('${s['name']} - ${s['price']} FCFA'),
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
                              .map<DropdownMenuItem<Map<String, dynamic>>>((p) {
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
                        const SizedBox(height: 18),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantité'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Montant à payer : ${money(getSelectedAmount())}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: saving ? null : saveSale,
                          icon: const Icon(Icons.point_of_sale),
                          label: Text(
                            saving ? 'Enregistrement...' : 'Valider la vente',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
