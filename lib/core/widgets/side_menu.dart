import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../../features/auth/services/auth_service.dart';
import '../utils/refresh_utils.dart';

class SideMenu extends ConsumerWidget {
  final bool isDrawer;

  const SideMenu({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final isAdminAsync = ref.watch(isAdminProvider);
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
                profile?.displayName ?? 'Kullanıcı',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              loading: () => const Text('Yükleniyor...'),
              error: (_, __) => const Text('Kullanıcı'),
            ),
            accountEmail: isAdminAsync.when(
              data: (isAdmin) => Text(isAdmin ? 'Yönetim Paneli' : 'Personel Paneli'),
              loading: () => const Text(''),
              error: (_, __) => const Text(''),
            ),
          ),
          
          Expanded(
            child: isAdminAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
              data: (isAdmin) => ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _MenuItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Ana Panel',
                    isActive: currentLocation == (isAdmin ? AppConstants.adminDashboardRoute : AppConstants.userDashboardRoute),
                    onTap: () => _navigate(context, isAdmin ? AppConstants.adminDashboardRoute : AppConstants.userDashboardRoute),
                  ),
                  
                  // Admin-only menu items
                  if (isAdmin) ...[
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
                  ],
                  
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
          ),
          
          const Divider(height: 1, color: Colors.white10),
          _MenuItem(
            icon: Icons.logout,
            title: 'Çıkış Yap',
            iconColor: Colors.red,
            onTap: () async {
              RefreshUtils.clearAllUserData(ref);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final activeColor = theme.primaryColor;
    final inactiveColor = theme.textTheme.bodyMedium?.color ?? (isDark ? Colors.white70 : Colors.black87);
    final activeTextColor = isDark ? Colors.white : theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        selected: isActive,
        leading: Icon(
          icon, 
          color: iconColor ?? (isActive ? activeColor : inactiveColor),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? activeTextColor : inactiveColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        selectedTileColor: theme.primaryColor.withOpacity(0.1),
      ),
    );
  }
}
