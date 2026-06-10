import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../employees/employees_page.dart';

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
          Expanded(
            child: _buildPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (selectedPage) {
      case 'employees':
        return const EmployeesPage();
      default:
        return const _DashboardHome();
    }
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bonjour Daniel 👋',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bienvenue sur BeautyManagerApps',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textGrey,
            ),
          ),
          const SizedBox(height: 30),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 1.4,
            children: const [
              _StatCard(
                title: 'Chiffre du jour',
                value: '0 FCFA',
                icon: Icons.payments_outlined,
              ),
              _StatCard(
                title: 'Clients du jour',
                value: '0',
                icon: Icons.people_outline,
              ),
              _StatCard(
                title: 'Employés présents',
                value: '0',
                icon: Icons.badge_outlined,
              ),
              _StatCard(
                title: 'Produits vendus',
                value: '0',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 25),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Activité récente',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
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
            active: false,
            onTap: () {},
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
            active: false,
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.inventory_2_outlined,
            label: 'Produits',
            active: false,
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.point_of_sale_outlined,
            label: 'Caisse',
            active: false,
            onTap: () {},
          ),
          _MenuItem(
            icon: Icons.bar_chart_outlined,
            label: 'Rapports',
            active: false,
            onTap: () {},
          ),
        ],
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
