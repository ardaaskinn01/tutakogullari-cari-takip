import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../../features/auth/services/auth_service.dart';

class SideMenu extends ConsumerWidget {
  final bool isDrawer;

  const SideMenu({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 280,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            accountName: userProfileAsync.when(
              data: (profile) => Text(
                profile?.displayName ?? 'Yönetici',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              loading: () => const Text('Yükleniyor...'),
              error: (_, __) => const Text('Yönetici'),
            ),
            accountEmail: const Text('Yönetim Paneli'),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _MenuItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Ana Panel',
                  isActive: currentLocation == AppConstants.adminDashboardRoute,
                  onTap: () => _navigate(context, AppConstants.adminDashboardRoute),
                ),
                _MenuItem(
                  icon: Icons.book_outlined,
                  title: 'Kasa Defteri',
                  isActive: currentLocation == AppConstants.kasaDefteriRoute,
                  onTap: () => _navigate(context, AppConstants.kasaDefteriRoute),
                ),
                _MenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Cari Alacaklar',
                  iconColor: Colors.orange,
                  isActive: currentLocation.startsWith(AppConstants.cariHomeRoute),
                  onTap: () => _navigate(context, AppConstants.cariHomeRoute),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white10),
                ),
                _MenuItem(
                  icon: Icons.people_outline,
                  title: 'Personel Listesi',
                  isActive: currentLocation == AppConstants.staffListRoute,
                  onTap: () => _navigate(context, AppConstants.staffListRoute),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: Colors.white10),
                ),
                _MenuItem(
                  icon: Icons.calculate_outlined,
                  title: 'Metretül Hesaplama',
                  iconColor: Colors.blueAccent,
                  isActive: currentLocation == AppConstants.mtulCalcRoute,
                  onTap: () => _navigate(context, AppConstants.mtulCalcRoute),
                ),
                _MenuItem(
                  icon: Icons.grid_on_outlined,
                  title: 'Cam m² Hesabı',
                  iconColor: Colors.indigoAccent,
                  isActive: currentLocation == AppConstants.glassCalcRoute,
                  onTap: () => _navigate(context, AppConstants.glassCalcRoute),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Colors.white10),
          _MenuItem(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            iconColor: Colors.red,
            onTap: () async {
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (isDrawer) Navigator.pop(context);
    context.go(route);
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isActive;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isActive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        selected: isActive,
        leading: Icon(icon, color: iconColor ?? (isActive ? Theme.of(context).primaryColor : Colors.white70)),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
    );
  }
}
