import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logs/activity_logger.dart';
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
  String searchText = '';

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

    if (!mounted) return;
    setState(() {
      services = servicesResponse;
      categories = categoriesResponse;
      loading = false;
    });
  }

  List get filteredServices {
    final q = searchText.toLowerCase().trim();
    if (q.isEmpty) return services;

    return services.where((service) {
      final name = (service['name'] ?? '').toString().toLowerCase();
      final category = (service['service_categories']?['name'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(q) || category.contains(q);
    }).toList();
  }

  Future<void> showServiceDialog({Map<String, dynamic>? service}) async {
    final isEdit = service != null;
    final nameController = TextEditingController(text: service?['name'] ?? '');
    final priceController = TextEditingController(
      text: isEdit
          ? ((service['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)
          : '',
    );
    String? selectedCategoryId = service?['category_id'];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Modifier service' : 'Ajouter un service'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: categories.map<DropdownMenuItem<String>>((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['id'],
                          child: Text(cat['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCategoryId = value);
                      },
                    ),
                    TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Nom du service')),
                    TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Prix')),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Choisissez une catégorie')));
                  return;
                }

                final price = double.tryParse(priceController.text.trim()) ?? 0;

                if (isEdit) {
                  await Supabase.instance.client.from('services').update({
                    'category_id': selectedCategoryId,
                    'name': nameController.text.trim(),
                    'price': price,
                  }).eq('id', service['id']);

                  await ActivityLogger.log(
                    action: 'SERVICE',
                    description:
                        'Service modifié : ${nameController.text.trim()}',
                  );
                } else {
                  await Supabase.instance.client.from('services').insert({
                    'category_id': selectedCategoryId,
                    'name': nameController.text.trim(),
                    'price': price,
                    'is_active': true,
                  });

                  await ActivityLogger.log(
                    action: 'SERVICE',
                    description:
                        'Service ajouté : ${nameController.text.trim()}',
                  );
                }

                if (mounted) {
                  Navigator.pop(context);
                  await loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            isEdit ? 'Service modifié' : 'Service ajouté')),
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

  Future<void> toggleServiceStatus(Map<String, dynamic> service) async {
    final active = service['is_active'] == true;
    await Supabase.instance.client
        .from('services')
        .update({'is_active': !active}).eq('id', service['id']);
    await ActivityLogger.log(
      action: 'SERVICE',
      description:
          '${active ? 'Désactivation' : 'Réactivation'} service : ${service['name']}',
    );
    await loadData();
  }

  String money(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Services',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.black)),
                    SizedBox(height: 4),
                    Text('Gérez les prestations, catégories et prix du salon',
                        style:
                            TextStyle(fontSize: 14, color: AppTheme.textGrey)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => showServiceDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter service'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(
                  labelText: 'Rechercher service',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder()),
              onChanged: (value) => setState(() => searchText = value),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(18)),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredServices.isEmpty
                      ? const Center(child: Text('Aucun service enregistré'))
                      : ListView.separated(
                          itemCount: filteredServices.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final service = filteredServices[index];
                            final category = service['service_categories']
                                    ?['name'] ??
                                'Sans catégorie';
                            final active = service['is_active'] == true;

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child:
                                    const Icon(Icons.spa, color: AppTheme.gold),
                              ),
                              title: Text(service['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  '$category • ${active ? 'Actif' : 'Inactif'}'),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(money(service['price']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  IconButton(
                                    tooltip: 'Modifier',
                                    onPressed: () =>
                                        showServiceDialog(service: service),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip:
                                        active ? 'Désactiver' : 'Réactiver',
                                    onPressed: () =>
                                        toggleServiceStatus(service),
                                    icon: Icon(active
                                        ? Icons.delete_outline
                                        : Icons.restore),
                                    color: active ? Colors.red : Colors.green,
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
