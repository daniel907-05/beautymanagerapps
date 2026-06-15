import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logs/activity_logger.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  bool loading = true;
  List expenses = [];

  String selectedPeriod = 'all';
  String? selectedCategory;
  String selectedIncludeFilter = 'all';
  DateTime? selectedDate;

  final categories = const [
    'Produits',
    'Eau',
    'Électricité',
    'Internet',
    'Loyer',
    'Salaires',
    'Transport',
    'Divers',
  ];

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
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

    var query = Supabase.instance.client.from('expenses').select();

    if (selectedCategory != null) {
      query = query.eq('category', selectedCategory!);
    }

    if (selectedIncludeFilter == 'included') {
      query = query.eq('include_in_reports', true);
    } else if (selectedIncludeFilter == 'excluded') {
      query = query.eq('include_in_reports', false);
    }

    if (startDate != null) {
      query = query.gte(
          'expense_date', startDate.toIso8601String().split('T').first);
    }

    if (endDate != null) {
      query =
          query.lt('expense_date', endDate.toIso8601String().split('T').first);
    }

    final response = await query.order('expense_date', ascending: false);

    setState(() {
      expenses = response;
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

      loadExpenses();
    }
  }

  void resetFilters() {
    setState(() {
      selectedPeriod = 'all';
      selectedCategory = null;
      selectedIncludeFilter = 'all';
      selectedDate = null;
    });

    loadExpenses();
  }

  Future<void> _showAddExpenseDialog() async {
    String selectedNewCategory = categories.first;
    bool includeInReports = true;

    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ajouter une dépense'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedNewCategory,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedNewCategory = value ?? categories.first;
                        });
                      },
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Montant'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: includeInReports,
                      title: const Text('Inclure dans les rapports'),
                      onChanged: (value) {
                        setDialogState(() {
                          includeInReports = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0;

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Le montant doit être supérieur à 0'),
                        ),
                      );
                      return;
                    }

                    await Supabase.instance.client.from('expenses').insert({
                      'category': selectedNewCategory,
                      'amount': amount,
                      'description': descriptionController.text.trim(),
                      'include_in_reports': includeInReports,
                    });
                    await ActivityLogger.log(
                      action: 'DEPENSE',
                      description: 'Dépense : ${amountController.text}',
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      loadExpenses();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dépense ajoutée avec succès'),
                        ),
                      );
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  String expenseDate(Map expense) {
    final rawDate = expense['expense_date'];

    if (rawDate == null) return '-';

    final date = DateTime.tryParse(rawDate.toString());

    if (date == null) return rawDate.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String selectedDateLabel() {
    if (selectedDate == null) return 'Choisir une date';

    return '${selectedDate!.day.toString().padLeft(2, '0')}/'
        '${selectedDate!.month.toString().padLeft(2, '0')}/'
        '${selectedDate!.year}';
  }

  double get totalIncluded {
    double total = 0;

    for (final expense in expenses) {
      if (expense['include_in_reports'] == true) {
        total += (expense['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return total;
  }

  double get totalAll {
    double total = 0;

    for (final expense in expenses) {
      total += (expense['amount'] as num?)?.toDouble() ?? 0;
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
                      'Dépenses',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Historique et suivi des charges du salon',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter dépense'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: loadExpenses,
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
                  ButtonSegment(value: 'today', label: Text('Aujourd’hui')),
                  ButtonSegment(value: 'week', label: Text('Semaine')),
                  ButtonSegment(value: 'month', label: Text('Mois')),
                  ButtonSegment(value: 'all', label: Text('Total')),
                ],
                selected: {selectedPeriod == 'date' ? 'all' : selectedPeriod},
                onSelectionChanged: (value) {
                  setState(() {
                    selectedPeriod = value.first;
                    selectedDate = null;
                  });
                  loadExpenses();
                },
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Toutes'),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value;
                    });
                    loadExpenses();
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: selectedIncludeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Rapports',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Toutes')),
                    DropdownMenuItem(
                        value: 'included', child: Text('Incluses')),
                    DropdownMenuItem(
                        value: 'excluded', child: Text('Non incluses')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedIncludeFilter = value ?? 'all';
                    });
                    loadExpenses();
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
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              _ExpenseSummaryCard(
                title: 'Dépenses incluses',
                value: money(totalIncluded),
                icon: Icons.account_balance_wallet_outlined,
              ),
              _ExpenseSummaryCard(
                title: 'Toutes les dépenses',
                value: money(totalAll),
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                  : expenses.isEmpty
                      ? const Center(child: Text('Aucune dépense trouvée'))
                      : ListView.separated(
                          itemCount: expenses.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final expense = expenses[index];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child: const Icon(
                                  Icons.payments_outlined,
                                  color: AppTheme.gold,
                                ),
                              ),
                              title: Text(
                                money(expense['amount']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${expense['category']} • ${expense['description'] ?? '-'}',
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    expenseDate(expense),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    expense['include_in_reports'] == true
                                        ? 'Incluse'
                                        : 'Non incluse',
                                    style: TextStyle(
                                      color:
                                          expense['include_in_reports'] == true
                                              ? Colors.green
                                              : Colors.orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
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

class _ExpenseSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ExpenseSummaryCard({
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
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold, size: 32),
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
