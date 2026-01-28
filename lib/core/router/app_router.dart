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
import '../../features/admin/screens/transaction_history_screen.dart';
import '../../features/dashboard/screens/user_dashboard_screen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/adaptive_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: AppConstants.loginRoute,
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    redirect: (context, state) async {
      final user = authService.currentUser;
      final isLoginRoute = state.matchedLocation == AppConstants.loginRoute;

      // Kullanıcı yoksa login'e yönlendir
      if (user == null && !isLoginRoute) {
        return AppConstants.loginRoute;
      }

      // Kullanıcı varsa ve login sayfasındaysa dashboard'a yönlendir
      if (user != null && isLoginRoute) {
        final isAdmin = await authService.isAdmin();
        return isAdmin 
            ? AppConstants.adminDashboardRoute 
            : AppConstants.userDashboardRoute;
      }

      // Admin olmayan kullanıcıların admin sayfalarına erişimini engelle
      if (user != null) {
        final isAdmin = await authService.isAdmin();
        final adminOnlyRoutes = [
          AppConstants.adminDashboardRoute,
          AppConstants.kasaDefteriRoute,
          AppConstants.cariHomeRoute,
          AppConstants.staffListRoute,
          AppConstants.transactionHistoryRoute,
          AppConstants.mtulPricesRoute,
        ];

        // Admin olmayan biri admin sayfasına gitmeye çalışıyorsa user dashboard'a yönlendir
        if (!isAdmin && adminOnlyRoutes.any((route) => state.matchedLocation.startsWith(route))) {
          return AppConstants.userDashboardRoute;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppConstants.loginRoute,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdaptiveShell(child: child),
        routes: [
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
          GoRoute(
            path: AppConstants.transactionHistoryRoute,
            builder: (context, state) => const TransactionHistoryScreen(),
          ),
        ],
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
