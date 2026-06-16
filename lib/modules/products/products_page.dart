import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logs/activity_logger.dart';
import '../../core/theme/app_theme.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List products = [];
  bool loading = true;
  String searchText = '';

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

    if (!mounted) return;
    setState(() {
      products = response;
      loading = false;
    });
  }

  List get filteredProducts {
    final q = searchText.toLowerCase().trim();
    if (q.isEmpty) return products;

    return products.where((product) {
      final name = (product['name'] ?? '').toString().toLowerCase();
      final sku = (product['sku'] ?? '').toString().toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();
  }

  Future<void> showProductDialog({Map<String, dynamic>? product}) async {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?['name'] ?? '');
    final skuController = TextEditingController(text: product?['sku'] ?? '');
    final priceController = TextEditingController(
      text: isEdit
          ? ((product['sale_price'] as num?)?.toDouble() ?? 0)
              .toStringAsFixed(0)
          : '',
    );
    final stockController = TextEditingController(
      text: isEdit
          ? ((product['stock_quantity'] as num?)?.toInt() ?? 0).toString()
          : '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Modifier produit' : 'Ajouter un produit'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Nom du produit')),
                TextField(
                    controller: skuController,
                    decoration:
                        const InputDecoration(labelText: 'SKU / Référence')),
                TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Prix de vente')),
                TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final price =
                      double.tryParse(priceController.text.trim()) ?? 0;
                  final stock = int.tryParse(stockController.text.trim()) ?? 0;

                  if (isEdit) {
                    await Supabase.instance.client.from('products').update({
                      'name': nameController.text.trim(),
                      'sku': skuController.text.trim(),
                      'sale_price': price,
                      'stock_quantity': stock,
                    }).eq('id', product['id']);

                    await ActivityLogger.log(
                      action: 'PRODUIT',
                      description:
                          'Produit modifié : ${nameController.text.trim()}',
                    );
                  } else {
                    await Supabase.instance.client.from('products').insert({
                      'name': nameController.text.trim(),
                      'sku': skuController.text.trim(),
                      'sale_price': price,
                      'stock_quantity': stock,
                      'is_active': true,
                    });

                    await ActivityLogger.log(
                      action: 'PRODUIT',
                      description:
                          'Produit ajouté : ${nameController.text.trim()}',
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    await loadProducts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              isEdit ? 'Produit modifié' : 'Produit ajouté')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur produit : $e')),
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

  Future<void> showRestockDialog(Map<String, dynamic> product) async {
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
                Text('Stock actuel : ${product['stock_quantity'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantité reçue')),
                TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Motif')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final quantity =
                    int.tryParse(quantityController.text.trim()) ?? 0;
                if (quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('La quantité doit être supérieure à 0')));
                  return;
                }

                final currentStock =
                    (product['stock_quantity'] as num?)?.toInt() ?? 0;
                final newStock = currentStock + quantity;

                await Supabase.instance.client.from('products').update(
                    {'stock_quantity': newStock}).eq('id', product['id']);
                await Supabase.instance.client.from('stock_movements').insert({
                  'product_id': product['id'],
                  'movement_type': 'in',
                  'quantity': quantity,
                  'reason': reasonController.text.trim(),
                });

                await ActivityLogger.log(
                  action: 'STOCK',
                  description:
                      'Réapprovisionnement ${product['name']} : +$quantity',
                );

                if (mounted) {
                  Navigator.pop(context);
                  await loadProducts();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stock mis à jour')));
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> toggleProductStatus(Map<String, dynamic> product) async {
    final active = product['is_active'] == true;
    await Supabase.instance.client
        .from('products')
        .update({'is_active': !active}).eq('id', product['id']);
    await ActivityLogger.log(
      action: 'PRODUIT',
      description:
          '${active ? 'Désactivation' : 'Réactivation'} produit : ${product['name']}',
    );
    await loadProducts();
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
                    Text('Produits',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.black)),
                    SizedBox(height: 4),
                    Text('Gérez les produits vendus au salon et leur stock',
                        style:
                            TextStyle(fontSize: 14, color: AppTheme.textGrey)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => showProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter produit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(
                  labelText: 'Rechercher produit',
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
                  : filteredProducts.isEmpty
                      ? const Center(child: Text('Aucun produit enregistré'))
                      : ListView.separated(
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            final stock =
                                (product['stock_quantity'] as num?)?.toInt() ??
                                    0;
                            final active = product['is_active'] == true;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.gold.withOpacity(0.18),
                                child: const Icon(Icons.inventory_2,
                                    color: AppTheme.gold),
                              ),
                              title: Text(product['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  'SKU : ${product['sku'] ?? '-'} • ${active ? 'Actif' : 'Inactif'}'),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(money(product['sale_price']),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                        'Stock : $stock',
                                        style: TextStyle(
                                          color: stock <= 5
                                              ? Colors.red
                                              : Colors.green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    tooltip: 'Modifier',
                                    onPressed: () =>
                                        showProductDialog(product: product),
                                    icon: const Icon(Icons.edit),
                                  ),
                                  IconButton(
                                    tooltip: 'Réapprovisionner',
                                    onPressed: () => showRestockDialog(product),
                                    icon: const Icon(Icons.add_box_outlined),
                                    color: AppTheme.gold,
                                  ),
                                  IconButton(
                                    tooltip:
                                        active ? 'Désactiver' : 'Réactiver',
                                    onPressed: () =>
                                        toggleProductStatus(product),
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
