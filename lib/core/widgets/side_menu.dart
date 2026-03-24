import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../../features/auth/services/auth_service.dart';
import '../utils/refresh_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

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
                    _MenuItem(
                      icon: Icons.web,
                      title: 'Web Sitesini Düzenle',
                      iconColor: Colors.purpleAccent,
                      onTap: () => _openWebAdminPanel(context),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(color: Colors.white10),
                    ),
                    _MenuItem(
                      icon: Icons.password,
                      title: 'Şifrenizi Değiştirin',
                      iconColor: Colors.amber,
                      onTap: () {
                        if (isDrawer) Navigator.pop(context);
                        final passwordController = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Şifre Değiştir'),
                            content: TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Yeni Şifre',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('İptal'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final p = passwordController.text.trim();
                                  if (p.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre en az 6 karakter olmalı.')));
                                    return;
                                  }
                                  try {
                                    debugPrint('SideMenu: Şifre güncellemesi tetiklendi. Şifre uzunluğu: ${p.length}');
                                    await ref.read(authServiceProvider).updatePassword(p);
                                    debugPrint('SideMenu: Şifre güncelleme başarılı!');
                                    
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreniz başarıyla güncellendi.', style: TextStyle(color: Colors.green))));
                                    }
                                  } catch(e) {
                                    debugPrint('SideMenu: Şifre değiştirme hatası yakalandı -> $e');
                                    final errorMessage = e.toString().replaceFirst('Exception: ', '');
                                    // Dialog kapatılmasın, sadece hata mesajı gösterilsin, fakat ctx üzerinden yapalım ki görünsün
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(errorMessage, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                                    }
                                  }
                                },
                                child: const Text('Güncelle'),
                              ),
                            ],
                          ),
                        );
                      },
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

  Future<void> _openWebAdminPanel(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum bilgisi alınamadı.')),
      );
      return;
    }

    final accessToken = await user.getIdToken();
    final refreshToken = ''; // Refresh token is not directly exposed in the same way in Firebase.

    // Web sitesindeki admin paneline token ile yönlendir
    final Uri url = Uri.parse(
      'https://penceredunyasi43.com/yonetim/panel?access_token=$accessToken&refresh_token=$refreshToken',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Web sitesi açılamadı.')),
        );
      }
    }
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
