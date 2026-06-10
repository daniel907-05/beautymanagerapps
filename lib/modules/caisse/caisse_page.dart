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

  String? selectedEmployeeId;
  Map<String, dynamic>? selectedService;

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

    setState(() {
      employees = employeesResponse;
      services = servicesResponse;
      loading = false;
    });
  }

  Future<void> saveSale() async {
    if (selectedEmployeeId == null || selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un employé et un service')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final contract = await Supabase.instance.client
          .from('employee_contracts')
          .select()
          .eq('employee_id', selectedEmployeeId!)
          .eq('is_active', true)
          .maybeSingle();

      final commissionPercent = contract == null
          ? 0.0
          : (contract['commission_percent'] as num).toDouble();

      final totalAmount = (selectedService!['price'] as num).toDouble();
      final employeeAmount = totalAmount * commissionPercent / 100;
      final salonAmount = totalAmount - employeeAmount;

      final sale = await Supabase.instance.client
          .from('sales')
          .insert({
            'employee_id': selectedEmployeeId,
            'total_clients': 1,
            'total_amount': totalAmount,
            'commission_percent_snapshot': commissionPercent,
            'employee_amount': employeeAmount,
            'salon_amount': salonAmount,
            'payment_method': 'cash',
            'status': 'validated',
          })
          .select()
          .single();

      await Supabase.instance.client.from('sale_items').insert({
        'sale_id': sale['id'],
        'item_type': 'service',
        'service_id': selectedService!['id'],
        'quantity': 1,
        'unit_price': totalAmount,
        'total_price': totalAmount,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vente enregistrée avec succès')),
        );

        setState(() {
          selectedEmployeeId = null;
          selectedService = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vente : $e')),
        );
      }
    }

    setState(() => saving = false);
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
                  'Enregistrez une vente pour un client',
                  style: TextStyle(fontSize: 16, color: AppTheme.textGrey),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 520,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedEmployeeId,
                        decoration: const InputDecoration(labelText: 'Employé'),
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
                        decoration: const InputDecoration(labelText: 'Service'),
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
                      const SizedBox(height: 24),
                      if (selectedService != null)
                        Text(
                          'Montant à payer : ${selectedService!['price']} FCFA',
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
