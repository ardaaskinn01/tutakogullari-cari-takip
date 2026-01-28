import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/cari_alacaklar_screen.dart';
import '../../features/admin/screens/kasa_defteri_screen.dart';
import '../../features/admin/screens/transaction_history_screen.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/dashboard/screens/user_dashboard_screen.dart';
import '../../features/admin/screens/mtul_history_screen.dart';
import '../../features/admin/screens/glass_history_screen.dart';
import '../../core/services/customer_service.dart';

class RefreshUtils {
  /// Uygulama genelindeki tüm finansal verileri (kasa, cari, bakiye vb.) yeniler.
  static void invalidateAllFinancialData(WidgetRef ref) {
    // İşlem Listeleri ve Bakiyeler
    ref.invalidate(balanceProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(userTransactionsProvider);
    ref.invalidate(reportDataProvider);
    
    // Cari Hesaplar
    ref.invalidate(cariAccountsProvider);
  }

  /// Tüm kullanıcı verilerini ve yetkilerini sıfırlar (Çıkış yaparken kullanılır)
  static void clearAllUserData(WidgetRef ref) {
    ref.invalidate(currentUserProfileProvider);
    ref.invalidate(isAdminProvider);
    ref.invalidate(currentUserProvider);
    invalidateAllFinancialData(ref);
  }

  /// Tüm metretül hesaplama verilerini yeniler.
  static void invalidateMtulData(WidgetRef ref, [String? customerName]) {
    ref.invalidate(mtulSummaryProvider);
    ref.invalidate(allCustomerNamesProvider);
    if (customerName != null) {
      ref.invalidate(customerCalculationsProvider(customerName));
    }
  }

  /// Tüm cam m2 hesaplama verilerini yeniler.
  static void invalidateGlassData(WidgetRef ref, [String? customerName]) {
    ref.invalidate(glassSummaryProvider);
    ref.invalidate(allCustomerNamesProvider);
    if (customerName != null) {
      ref.invalidate(customerGlassCalculationsProvider(customerName));
    }
  }
}
