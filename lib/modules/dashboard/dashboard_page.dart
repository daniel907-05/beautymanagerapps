import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/user_role.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helper.dart';
import '../admin/activity_logs_page.dart';
import '../admin/admin_page.dart';
import '../attendance/retards_page.dart';
import '../auth/login_page.dart';
import '../caisse/caisse_page.dart';
import '../cash_closure/cash_closure_page.dart';
import '../employees/employees_page.dart';
import '../expenses/expenses_page.dart';
import '../products/products_page.dart';
import '../reports/reports_page.dart';
import '../sales/sales_history_page.dart';
import '../services/services_page.dart';
import '../settings/settings_page.dart';
import '../stock/stock_history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String selectedPage = 'dashboard';
  bool loadingRole = true;

  @override
  void initState() {
    super.initState();
    loadRole();
  }

  Future<void> loadRole() async {
    await UserRole.loadRole();
    if (!mounted) return;
    setState(() => loadingRole = false);
  }

  bool get canAccessBusinessPages => UserRole.isAdmin || UserRole.isManager;
  bool get canAccessCashierPages =>
      UserRole.isAdmin || UserRole.isManager || UserRole.isCashier;
  bool get canAccessRetards =>
      UserRole.isAdmin ||
      UserRole.isManager ||
      UserRole.isCashier ||
      UserRole.isEmployee;

  @override
  Widget build(BuildContext context) {
    if (loadingRole) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          _Sidebar(
            selectedPage: selectedPage,
            onPageSelected: (page) {
              setState(() => selectedPage = page);
            },
          ),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (selectedPage) {
      case 'employees':
        return canAccessBusinessPages
            ? const EmployeesPage()
            : const _AccessDeniedPage();
      case 'caisse':
        return canAccessCashierPages
            ? const CaissePage()
            : const _AccessDeniedPage();
      case 'products':
        return (canAccessBusinessPages || UserRole.isCashier)
            ? const ProductsPage()
            : const _AccessDeniedPage();
      case 'reports':
        return canAccessBusinessPages
            ? const ReportsPage()
            : const _AccessDeniedPage();
      case 'services':
        return (canAccessBusinessPages || UserRole.isCashier)
            ? const ServicesPage()
            : const _AccessDeniedPage();
      case 'sales_history':
        return (canAccessCashierPages || UserRole.isEmployee)
            ? const SalesHistoryPage()
            : const _AccessDeniedPage();
      case 'stock_history':
        return canAccessBusinessPages
            ? const StockHistoryPage()
            : const _AccessDeniedPage();
      case 'expenses':
        return canAccessBusinessPages
            ? const ExpensesPage()
            : const _AccessDeniedPage();
      case 'cash_closure':
        return canAccessCashierPages
            ? const CashClosurePage()
            : const _AccessDeniedPage();
      case 'settings':
        return canAccessBusinessPages
            ? const SettingsPage()
            : const _AccessDeniedPage();
      case 'admin':
        return UserRole.isAdmin ? const AdminPage() : const _AccessDeniedPage();
      case 'activity_logs':
        return canAccessBusinessPages
            ? const ActivityLogsPage()
            : const _AccessDeniedPage();
      case 'retards':
        return canAccessRetards
            ? const RetardsPage()
            : const _AccessDeniedPage();
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
  Timer? _refreshTimer;
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) loadDashboardData(showLoader: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadDashboardData({bool showLoader = true}) async {
    if (showLoader) setState(() => loading = true);

    DateTime? startDate;
    if (selectedPeriod == 'today') {
      startDate = DateHelper.startOfToday();
    } else if (selectedPeriod == 'week') {
      startDate = DateHelper.startOfWeek();
    } else if (selectedPeriod == 'month') {
      startDate = DateHelper.startOfMonth();
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

    final names = <String, String>{};
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

    if (!mounted) return;
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

  String money(double value) => '${value.toStringAsFixed(0)} FCFA';

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
    if (employeeId == null) return 'Vente produit';
    return employeeNames[employeeId] ?? 'Employé inconnu';
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
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour Daniel 👋',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Vue réelle des performances du salon',
                              style: TextStyle(
                                  fontSize: 14, color: AppTheme.textGrey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'today', label: Text('Aujourd’hui')),
                      ButtonSegment(value: 'week', label: Text('Semaine')),
                      ButtonSegment(value: 'month', label: Text('Mois')),
                      ButtonSegment(value: 'all', label: Text('Total')),
                    ],
                    selected: {selectedPeriod},
                    onSelectionChanged: (value) {
                      setState(() => selectedPeriod = value.first);
                      loadDashboardData();
                    },
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 1500 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3.2,
                    children: [
                      _StatCard(
                          title: 'Chiffre $cardSuffix',
                          value: money(chiffreTotal),
                          icon: Icons.payments_outlined),
                      _StatCard(
                          title: 'Clients $cardSuffix',
                          value: clientsTotal.toString(),
                          icon: Icons.people_outline),
                      _StatCard(
                          title: 'Commissions',
                          value: money(commissionsTotal),
                          icon: Icons.badge_outlined),
                      _StatCard(
                          title: 'Part salon',
                          value: money(partSalonTotal),
                          icon: Icons.account_balance_wallet_outlined),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (lowStockProducts.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠ Produits à réapprovisionner',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          ...lowStockProducts.map(
                            (product) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                '${product['name']} • Stock : ${product['stock_quantity']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    height: 380,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ventes récentes - $periodLabel',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: recentSales.isEmpty
                              ? Center(
                                  child: Text(
                                      'Aucune vente enregistrée pour $periodLabel'))
                              : ListView.separated(
                                  itemCount: recentSales.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final sale = recentSales[index];
                                    final employeeName =
                                        employeeNameForSale(sale);
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            AppTheme.gold.withOpacity(0.18),
                                        child: const Icon(Icons.point_of_sale,
                                            color: AppTheme.gold),
                                      ),
                                      title: Text(
                                        money((sale['total_amount'] as num?)
                                                ?.toDouble() ??
                                            0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800),
                                      ),
                                      subtitle: Text(
                                        '$employeeName • Commission : ${money((sale['employee_amount'] as num?)?.toDouble() ?? 0)} • Salon : ${money((sale['salon_amount'] as num?)?.toDouble() ?? 0)}',
                                      ),
                                      trailing: Text(
                                        sale['payment_method'] ?? 'cash',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                    );
                                  },
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

class _Sidebar extends StatelessWidget {
  final String selectedPage;
  final Function(String) onPageSelected;

  const _Sidebar({
    required this.selectedPage,
    required this.onPageSelected,
  });

  bool get canSeeBusinessMenus => UserRole.isAdmin || UserRole.isManager;
  bool get canSeeCashierMenus =>
      UserRole.isAdmin || UserRole.isManager || UserRole.isCashier;
  bool get canSeeRetards =>
      UserRole.isAdmin ||
      UserRole.isManager ||
      UserRole.isCashier ||
      UserRole.isEmployee;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppTheme.dark,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BeautyManager',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Apps Premium', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 28),
            _MenuItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              active: selectedPage == 'dashboard',
              onTap: () => onPageSelected('dashboard'),
            ),
            if (canSeeCashierMenus)
              _MenuItem(
                icon: Icons.point_of_sale_outlined,
                label: 'Caisse',
                active: selectedPage == 'caisse',
                onTap: () => onPageSelected('caisse'),
              ),
            if (canSeeCashierMenus || UserRole.isEmployee)
              _MenuItem(
                icon: Icons.receipt_long_outlined,
                label: 'Historique ventes',
                active: selectedPage == 'sales_history',
                onTap: () => onPageSelected('sales_history'),
              ),
            if (canSeeCashierMenus)
              _MenuItem(
                icon: Icons.lock_outline,
                label: 'Clôture caisse',
                active: selectedPage == 'cash_closure',
                onTap: () => onPageSelected('cash_closure'),
              ),
            if (canSeeBusinessMenus || UserRole.isCashier)
              _MenuItem(
                icon: Icons.inventory_2_outlined,
                label: 'Produits',
                active: selectedPage == 'products',
                onTap: () => onPageSelected('products'),
              ),
            if (canSeeBusinessMenus || UserRole.isCashier)
              _MenuItem(
                icon: Icons.spa_outlined,
                label: 'Services',
                active: selectedPage == 'services',
                onTap: () => onPageSelected('services'),
              ),
            if (canSeeBusinessMenus)
              _MenuItem(
                icon: Icons.people_alt_outlined,
                label: 'Employés',
                active: selectedPage == 'employees',
                onTap: () => onPageSelected('employees'),
              ),
            if (canSeeRetards)
              _MenuItem(
                icon: Icons.access_time,
                label: 'Retards',
                active: selectedPage == 'retards',
                onTap: () => onPageSelected('retards'),
              ),
            if (canSeeBusinessMenus)
              _MenuItem(
                icon: Icons.history_outlined,
                label: 'Stock',
                active: selectedPage == 'stock_history',
                onTap: () => onPageSelected('stock_history'),
              ),
            if (canSeeBusinessMenus)
              _MenuItem(
                icon: Icons.money_off_csred_outlined,
                label: 'Dépenses',
                active: selectedPage == 'expenses',
                onTap: () => onPageSelected('expenses'),
              ),
            if (canSeeBusinessMenus)
              _MenuItem(
                icon: Icons.bar_chart_outlined,
                label: 'Rapports',
                active: selectedPage == 'reports',
                onTap: () => onPageSelected('reports'),
              ),
            if (canSeeBusinessMenus)
              _MenuItem(
                icon: Icons.history_toggle_off_outlined,
                label: 'Activités',
                active: selectedPage == 'activity_logs',
                onTap: () => onPageSelected('activity_logs'),
              ),
            if (canSeeBusinessMenus)
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'Paramètres',
                active: selectedPage == 'settings',
                onTap: () => onPageSelected('settings'),
              ),
            if (UserRole.isAdmin)
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Administration',
                active: selectedPage == 'admin',
                onTap: () => onPageSelected('admin'),
              ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.logout,
              label: 'Déconnexion',
              active: false,
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: const Center(
        child: Text(
          'Accès non autorisé',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppTheme.black,
          ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: active ? AppTheme.black : AppTheme.gold, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? AppTheme.black : AppTheme.white,
                    fontWeight: FontWeight.w700,
                  ),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.gold, size: 20),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
