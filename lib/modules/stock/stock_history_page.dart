import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class StockHistoryPage extends StatefulWidget {
  const StockHistoryPage({super.key});

  @override
  State<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends State<StockHistoryPage> {
  bool loading = true;

  List movements = [];
  List products = [];
  Map<String, String> productNames = {};

  String selectedPeriod = 'all';
  String? selectedProductId;
  String? selectedMovementType;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    loadMovements();
  }

  Future<void> loadMovements() async {
    setState(() {
      loading = true;
    });

    final productsResponse = await Supabase.instance.client
        .from('products')
        .select('id, name')
        .order('name');

    final names = <String, String>{};

    for (final product in productsResponse) {
      names[product['id']] = product['name'] ?? 'Produit inconnu';
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

    var query = Supabase.instance.client.from('stock_movements').select();

    if (selectedProductId != null) {
      query = query.eq('product_id', selectedProductId!);
    }

    if (selectedMovementType != null) {
      query = query.eq('movement_type', selectedMovementType!);
    }

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lt('created_at', endDate.toIso8601String());
    }

    final movementsResponse = await query.order('created_at', ascending: false);

    setState(() {
      products = productsResponse;
      productNames = names;
      movements = movementsResponse;
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

      loadMovements();
    }
  }

  void resetFilters() {
    setState(() {
      selectedPeriod = 'all';
      selectedProductId = null;
      selectedMovementType = null;
      selectedDate = null;
    });

    loadMovements();
  }

  String movementLabel(String? type) {
    switch (type) {
      case 'in':
        return 'Entrée';
      case 'out':
        return 'Sortie';
      case 'adjustment':
        return 'Ajustement';
      default:
        return 'Mouvement';
    }
  }

  Color movementColor(String? type) {
    switch (type) {
      case 'in':
        return Colors.green;
      case 'out':
        return Colors.red;
      case 'adjustment':
        return Colors.orange;
      default:
        return AppTheme.textGrey;
    }
  }

  String productName(Map movement) {
    final productId = movement['product_id'];
    return productNames[productId] ?? 'Produit inconnu';
  }

  String movementDate(Map movement) {
    final rawDate = movement['created_at'];

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

  int get totalIn {
    int total = 0;
    for (final movement in movements) {
      if (movement['movement_type'] == 'in') {
        total += (movement['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  int get totalOut {
    int total = 0;
    for (final movement in movements) {
      if (movement['movement_type'] == 'out') {
        total += (movement['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  int get totalAdjustments {
    int total = 0;
    for (final movement in movements) {
      if (movement['movement_type'] == 'adjustment') {
        total += (movement['quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(30),
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
                      'Historique du stock',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Recherchez les entrées, sorties et ajustements de stock',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: loadMovements,
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
                selected: {selectedPeriod == 'date' ? 'all' : selectedPeriod},
                onSelectionChanged: (value) {
                  setState(() {
                    selectedPeriod = value.first;
                    selectedDate = null;
                  });
                  loadMovements();
                },
              ),
              SizedBox(
                width: 250,
                child: DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Produit',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tous les produits'),
                    ),
                    ...products.map<DropdownMenuItem<String>>((product) {
                      return DropdownMenuItem<String>(
                        value: product['id'],
                        child: Text(product['name'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedProductId = value;
                    });
                    loadMovements();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: selectedMovementType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tous les types'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'in',
                      child: Text('Entrées'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'out',
                      child: Text('Sorties'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'adjustment',
                      child: Text('Ajustements'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedMovementType = value;
                    });
                    loadMovements();
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
            crossAxisCount: 3,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _StockSummaryCard(
                title: 'Entrées',
                value: totalIn.toString(),
                icon: Icons.add_circle_outline,
                color: Colors.green,
              ),
              _StockSummaryCard(
                title: 'Sorties',
                value: totalOut.toString(),
                icon: Icons.remove_circle_outline,
                color: Colors.red,
              ),
              _StockSummaryCard(
                title: 'Ajustements',
                value: totalAdjustments.toString(),
                icon: Icons.sync_alt,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : movements.isEmpty
                      ? const Center(
                          child: Text('Aucun mouvement de stock trouvé'),
                        )
                      : ListView.separated(
                          itemCount: movements.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final movement = movements[index];
                            final type = movement['movement_type'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    movementColor(type).withOpacity(0.15),
                                child: Icon(
                                  type == 'in'
                                      ? Icons.add
                                      : type == 'out'
                                          ? Icons.remove
                                          : Icons.sync_alt,
                                  color: movementColor(type),
                                ),
                              ),
                              title: Text(
                                productName(movement),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${movementLabel(type)} • Quantité : ${movement['quantity']} • ${movement['reason'] ?? '-'}',
                              ),
                              trailing: Text(
                                movementDate(movement),
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
    );
  }
}

class _StockSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StockSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.black,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: AppTheme.textGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
