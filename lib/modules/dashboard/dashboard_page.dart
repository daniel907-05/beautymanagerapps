import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../attendance/attendance_page.dart';
import '../caisse/caisse_page.dart';
import '../employees/employees_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../services/services_page.dart';
import '../sales/sales_history_page.dart';
import '../stock/stock_history_page.dart';
import '../expenses/expenses_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedPage = 'dashboard';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          _Sidebar(
            selectedPage: selectedPage,
            onPageSelected: (page) {
              setState(() {
                selectedPage = page;
              });
            },
          ),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (selectedPage) {
      case 'attendance':
        return const AttendancePage();
      case 'employees':
        return const EmployeesPage();
      case 'caisse':
        return const CaissePage();
      case 'products':
        return const ProductsPage();
      case 'reports':
        return const ReportsPage();
      case 'services':
        return const ServicesPage();
      case 'sales_history':
        return const SalesHistoryPage();
      case 'stock_history':
        return const StockHistoryPage();
      case 'expenses':
        return const ExpensesPage();
      default:
        return const _DashboardHome();
    }
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  bool loading = true;
  String selectedPeriod = 'today';

  double chiffreTotal = 0;
  int clientsTotal = 0;
  double commissionsTotal = 0;
  double partSalonTotal = 0;

  List recentSales = [];
  List lowStockProducts = [];
  Map<String, String> employeeNames = {};

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() {
      loading = true;
    });

    final now = DateTime.now();
    DateTime? startDate;

    if (selectedPeriod == 'today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (selectedPeriod == 'week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      startDate = DateTime(monday.year, monday.month, monday.day);
    } else if (selectedPeriod == 'month') {
      startDate = DateTime(now.year, now.month, 1);
    } else {
      startDate = null;
    }

    final sales = startDate == null
        ? await Supabase.instance.client
            .from('sales')
            .select()
            .eq('status', 'validated')
            .order('sale_date', ascending: false)
        : await Supabase.instance.client
            .from('sales')
            .select()
            .eq('status', 'validated')
            .gte('sale_date', startDate.toIso8601String())
            .order('sale_date', ascending: false);

    final employees = await Supabase.instance.client
        .from('employees')
        .select('id, full_name');

    final lowStock = await Supabase.instance.client
        .from('products')
        .select()
        .eq('is_active', true)
        .lte('stock_quantity', 5)
        .order('stock_quantity');

    final Map<String, String> names = {};
    for (final employee in employees) {
      names[employee['id']] = employee['full_name'] ?? 'Employé inconnu';
    }

    double total = 0;
    int clients = 0;
    double commissions = 0;
    double salon = 0;

    for (final sale in sales) {
      total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      clients += (sale['total_clients'] as num?)?.toInt() ?? 0;
      commissions += (sale['employee_amount'] as num?)?.toDouble() ?? 0;
      salon += (sale['salon_amount'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      chiffreTotal = total;
      clientsTotal = clients;
      commissionsTotal = commissions;
      partSalonTotal = salon;
      recentSales = sales.take(5).toList();
      lowStockProducts = lowStock;
      employeeNames = names;
      loading = false;
    });
  }

  String money(double value) {
    return '${value.toStringAsFixed(0)} FCFA';
  }

  String get periodLabel {
    switch (selectedPeriod) {
      case 'today':
        return 'aujourd’hui';
      case 'week':
        return 'cette semaine';
      case 'month':
        return 'ce mois';
      case 'all':
        return 'total général';
      default:
        return '';
    }
  }

  String get cardSuffix {
    switch (selectedPeriod) {
      case 'today':
        return 'du jour';
      case 'week':
        return 'semaine';
      case 'month':
        return 'du mois';
      case 'all':
        return 'global';
      default:
        return '';
    }
  }

  String employeeNameForSale(Map sale) {
    final employeeId = sale['employee_id'];

    if (employeeId == null) {
      return 'Vente produit';
    }

    return employeeNames[employeeId] ?? 'Employé inconnu';
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
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour Daniel 👋',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.black,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Vue réelle des performances du salon',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: loadDashboardData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'today',
                      label: Text('Aujourd’hui'),
                    ),
                    ButtonSegment(
                      value: 'week',
                      label: Text('Cette semaine'),
                    ),
                    ButtonSegment(
                      value: 'month',
                      label: Text('Ce mois'),
                    ),
                    ButtonSegment(
                      value: 'all',
                      label: Text('Total général'),
                    ),
                  ],
                  selected: {selectedPeriod},
                  onSelectionChanged: (value) {
                    setState(() {
                      selectedPeriod = value.first;
                    });
                    loadDashboardData();
                  },
                ),
                const SizedBox(height: 30),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.4,
                  children: [
                    _StatCard(
                      title: 'Chiffre $cardSuffix',
                      value: money(chiffreTotal),
                      icon: Icons.payments_outlined,
                    ),
                    _StatCard(
                      title: 'Clients $cardSuffix',
                      value: clientsTotal.toString(),
                      icon: Icons.people_outline,
                    ),
                    _StatCard(
                      title: 'Commissions',
                      value: money(commissionsTotal),
                      icon: Icons.badge_outlined,
                    ),
                    _StatCard(
                      title: 'Part salon',
                      value: money(partSalonTotal),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                if (lowStockProducts.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠ Produits à réapprovisionner',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...lowStockProducts.map(
                          (product) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${product['name']}  •  Stock : ${product['stock_quantity']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ventes récentes - $periodLabel',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: recentSales.isEmpty
                              ? Center(
                                  child: Text(
                                    'Aucune vente enregistrée pour $periodLabel',
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: recentSales.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final sale = recentSales[index];
                                    final employeeName =
                                        employeeNameForSale(sale);

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            AppTheme.gold.withOpacity(0.18),
                                        child: const Icon(
                                          Icons.point_of_sale,
                                          color: AppTheme.gold,
                                        ),
                                      ),
                                      title: Text(
                                        money(
                                          (sale['total_amount'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '$employeeName • Commission : ${money((sale['employee_amount'] as num?)?.toDouble() ?? 0)} • Salon : ${money((sale['salon_amount'] as num?)?.toDouble() ?? 0)}',
                                      ),
                                      trailing: Text(
                                        sale['payment_method'] ?? 'cash',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String selectedPage;
  final Function(String) onPageSelected;

  const _Sidebar({
    required this.selectedPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppTheme.dark,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BeautyManager',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Apps Premium',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 35),
            _MenuItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              active: selectedPage == 'dashboard',
              onTap: () => onPageSelected('dashboard'),
            ),
            _MenuItem(
              icon: Icons.access_time,
              label: 'Présence',
              active: selectedPage == 'attendance',
              onTap: () => onPageSelected('attendance'),
            ),
            _MenuItem(
              icon: Icons.people_alt_outlined,
              label: 'Employés',
              active: selectedPage == 'employees',
              onTap: () => onPageSelected('employees'),
            ),
            _MenuItem(
              icon: Icons.spa_outlined,
              label: 'Services',
              active: selectedPage == 'services',
              onTap: () => onPageSelected('services'),
            ),
            _MenuItem(
              icon: Icons.inventory_2_outlined,
              label: 'Produits',
              active: selectedPage == 'products',
              onTap: () => onPageSelected('products'),
            ),
            _MenuItem(
              icon: Icons.history_outlined,
              label: 'Stock',
              active: selectedPage == 'stock_history',
              onTap: () => onPageSelected('stock_history'),
            ),
            _MenuItem(
              icon: Icons.point_of_sale_outlined,
              label: 'Caisse',
              active: selectedPage == 'caisse',
              onTap: () => onPageSelected('caisse'),
            ),
            _MenuItem(
              icon: Icons.money_off_csred_outlined,
              label: 'Dépenses',
              active: selectedPage == 'expenses',
              onTap: () => onPageSelected('expenses'),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'Historique',
              active: selectedPage == 'sales_history',
              onTap: () => onPageSelected('sales_history'),
            ),
            _MenuItem(
              icon: Icons.bar_chart_outlined,
              label: 'Rapports',
              active: selectedPage == 'reports',
              onTap: () => onPageSelected('reports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? AppTheme.black : AppTheme.gold,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTheme.black : AppTheme.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.gold, size: 32),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }
}
