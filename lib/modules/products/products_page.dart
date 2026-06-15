import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/logs/activity_logger.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    final response = await Supabase.instance.client
        .from('products')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      products = response;
      loading = false;
    });
  }

  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un produit'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(labelText: 'Nom du produit'),
                ),
                TextField(
                  controller: skuController,
                  decoration:
                      const InputDecoration(labelText: 'SKU / Référence'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Prix de vente'),
                ),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock initial'),
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
                try {
                  final price =
                      double.tryParse(priceController.text.trim()) ?? 0;
                  final stock = int.tryParse(stockController.text.trim()) ?? 0;

                  await Supabase.instance.client.from('products').insert({
                    'name': nameController.text.trim(),
                    'sku': skuController.text.trim(),
                    'sale_price': price,
                    'stock_quantity': stock,
                    'is_active': true,
                  });
                  await ActivityLogger.log(
                    action: 'PRODUIT',
                    description: 'Produit ajouté : ${nameController.text}',
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    loadProducts();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Produit ajouté avec succès'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur ajout produit : $e')),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRestockDialog(Map<String, dynamic> product) async {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController(text: 'Réapprovisionnement');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Réapprovisionner ${product['name']}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stock actuel : ${product['stock_quantity'] ?? 0}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantité reçue',
                  ),
                ),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Motif',
                  ),
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
                final quantity =
                    int.tryParse(quantityController.text.trim()) ?? 0;

                if (quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La quantité doit être supérieure à 0'),
                    ),
                  );
                  return;
                }

                final currentStock =
                    (product['stock_quantity'] as num?)?.toInt() ?? 0;
                final newStock = currentStock + quantity;

                await Supabase.instance.client
                    .from('products')
                    .update({'stock_quantity': newStock}).eq(
                  'id',
                  product['id'],
                );

                await Supabase.instance.client.from('stock_movements').insert({
                  'product_id': product['id'],
                  'movement_type': 'in',
                  'quantity': quantity,
                  'reason': reasonController.text.trim(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  loadProducts();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stock mis à jour avec succès'),
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
                      'Produits',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.black,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gérez les produits vendus au salon et leur stock',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter produit'),
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
                  : products.isEmpty
                      ? const Center(
                          child: Text('Aucun produit enregistré'),
                        )
                      : ListView.separated(
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final product = products[index];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child: const Icon(
                                  Icons.inventory_2,
                                  color: AppTheme.gold,
                                ),
                              ),
                              title: Text(
                                product['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                'SKU : ${product['sku'] ?? '-'}',
                              ),
                              trailing: SizedBox(
                                width: 210,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          money(product['sale_price']),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Stock : ${product['stock_quantity'] ?? 0}',
                                          style: TextStyle(
                                            color: (product['stock_quantity'] ??
                                                        0) <=
                                                    5
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      tooltip: 'Réapprovisionner',
                                      onPressed: () =>
                                          _showRestockDialog(product),
                                      icon: const Icon(Icons.add_box_outlined),
                                      color: AppTheme.gold,
                                    ),
                                  ],
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
