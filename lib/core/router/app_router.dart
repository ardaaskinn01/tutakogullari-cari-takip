import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/kasa_defteri_screen.dart';
import '../../features/admin/screens/staff_list_screen.dart';
import '../../features/admin/screens/cari_alacaklar_screen.dart';
import '../../features/admin/screens/cari_account_detail_screen.dart';
import '../../features/admin/screens/mtul_prices_screen.dart';
import '../../features/admin/screens/mtul_calculation_screen.dart';
import '../../features/admin/screens/mtul_history_screen.dart';
import '../../features/admin/screens/glass_calculation_screen.dart';
import '../../features/admin/screens/glass_history_screen.dart';
import '../../features/dashboard/screens/user_dashboard_screen.dart';
import '../../core/constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: AppConstants.loginRoute,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges), // DİKKAT: Bu satır eklendi
    redirect: (context, state) async {
      final user = authService.currentUser;
      final isLoginRoute = state.matchedLocation == AppConstants.loginRoute;

      // If user is not logged in and not on login page, redirect to login
      if (user == null && !isLoginRoute) {
        return AppConstants.loginRoute;
      }

      // If user is logged in and on login page, redirect based on role
      if (user != null && isLoginRoute) {
        // Rol kontrolü asenkron olduğu için bir bekleme olabilir.
        // Ancak router redirect içinde async işlem risklidir, genellikle splash screen önerilir.
        // Şimdilik hızlı çözüm olarak bekliyoruz.
        final isAdmin = await authService.isAdmin();
        return isAdmin 
            ? AppConstants.adminDashboardRoute 
            : AppConstants.userDashboardRoute;
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: AppConstants.loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppConstants.adminDashboardRoute,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppConstants.userDashboardRoute,
        builder: (context, state) => const UserDashboardScreen(),
      ),
      GoRoute(
        path: AppConstants.kasaDefteriRoute,
        builder: (context, state) => const KasaDefteriScreen(),
      ),
      GoRoute(
        path: AppConstants.staffListRoute,
        builder: (context, state) => const StaffListScreen(),
      ),
      GoRoute(
        path: AppConstants.cariHomeRoute,
        builder: (context, state) => const CariAlacaklarScreen(),
      ),
      GoRoute(
        path: '${AppConstants.cariAccountDetailRoute}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CariAccountDetailScreen(accountId: id);
        },
      ),
      GoRoute(
        path: AppConstants.mtulCalcRoute,
        builder: (context, state) => const MtulCalculationScreen(),
      ),
      GoRoute(
        path: AppConstants.mtulPricesRoute,
        builder: (context, state) => const MtulPricesScreen(),
      ),
      GoRoute(
        path: AppConstants.mtulHistoryRoute,
        builder: (context, state) => const MtulHistoryScreen(),
      ),
      GoRoute(
        path: AppConstants.glassCalcRoute,
        builder: (context, state) => const GlassCalculationScreen(),
      ),
      GoRoute(
        path: AppConstants.glassHistoryRoute,
        builder: (context, state) => const GlassHistoryScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Sayfa bulunamadı',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.loginRoute),
              child: const Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      ),
    ),
  );
});


class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
