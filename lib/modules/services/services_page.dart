import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  List services = [];
  List categories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final servicesResponse = await Supabase.instance.client
        .from('services')
        .select('*, service_categories(name)')
        .order('created_at', ascending: false);

    final categoriesResponse = await Supabase.instance.client
        .from('service_categories')
        .select()
        .eq('is_active', true)
        .order('name');

    setState(() {
      services = servicesResponse;
      categories = categoriesResponse;
      loading = false;
    });
  }

  Future<void> _showAddServiceDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String? selectedCategoryId;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un service'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                      ),
                      items: categories.map<DropdownMenuItem<String>>((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['id'],
                          child: Text(cat['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryId = value;
                        });
                      },
                    ),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du service',
                      ),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Choisissez une catégorie'),
                    ),
                  );
                  return;
                }

                final price = double.tryParse(priceController.text.trim()) ?? 0;

                await Supabase.instance.client.from('services').insert({
                  'category_id': selectedCategoryId,
                  'name': nameController.text.trim(),
                  'price': price,
                  'is_active': true,
                });

                if (mounted) {
                  Navigator.pop(context);
                  loadData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service ajouté avec succès'),
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
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(0)} FCFA';
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
                      'Services',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gérez les prestations, catégories et prix du salon',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddServiceDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter service'),
              ),
            ],
          ),
          const SizedBox(height: 28),
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
                  : services.isEmpty
                      ? const Center(
                          child: Text('Aucun service enregistré'),
                        )
                      : ListView.separated(
                          itemCount: services.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final category = service['service_categories']
                                    ?['name'] ??
                                'Sans catégorie';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child: const Icon(
                                  Icons.spa,
                                  color: AppTheme.gold,
                                ),
                              ),
                              title: Text(
                                service['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(category),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    money(service['price']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    service['is_active'] == true
                                        ? 'Actif'
                                        : 'Inactif',
                                    style: TextStyle(
                                      color: service['is_active'] == true
                                          ? Colors.green
                                          : Colors.red,
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
