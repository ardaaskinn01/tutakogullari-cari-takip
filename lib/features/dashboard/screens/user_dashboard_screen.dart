import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/transaction.dart';
import '../../auth/services/auth_service.dart';
import '../repositories/transaction_repository.dart';
import '../widgets/add_transaction_modal.dart';
import '../../../core/utils/refresh_utils.dart';
import '../../../core/widgets/side_menu.dart';
import '../../../core/widgets/theme_toggle_button.dart';

// Sadece oturum açan kullanıcının işlemlerini getirir
final userTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider).value;
  
  // Kullanıcı yoksa boş dön
  if (user == null) return [];
  
  // isAdmin = false göndererek sadece kendi işlemlerini çekmesini sağlıyoruz
  return repository.getTransactions(userId: user!.id, isAdmin: false);
});

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(userTransactionsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Uygulamadan Çık'),
            content: const Text('Uygulamayı kapatmak istediğinize emin misiniz?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('HAYIR')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('EVET')),
            ],
          ),
        );

        if (shouldExit == true) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        drawer: MediaQuery.of(context).size.width <= 900 
          ? Drawer(child: SideMenu(
              key: ValueKey(ref.watch(currentUserProvider).value?.id ?? 'user-drawer'),
              isDrawer: true
            )) 
          : null,
        appBar: AppBar(
        title: const Text('Personel Paneli'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              RefreshUtils.clearAllUserData(ref);
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userTransactionsProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Text(
                'İşlemlerim',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Eklediğiniz işlemler aşağıdadır.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              
              // Liste
              Expanded(
                child: transactionsAsync.when(
                  data: (transactions) => _buildTransactionList(context, transactions),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Hata: $err')),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddTransactionModal(
              onSuccess: () {
                // İşlem eklenince tüm finansal verileri yenile
                RefreshUtils.invalidateAllFinancialData(ref);
              },
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('İşlem Ekle'),
      ),
    ));
  }

  Widget _buildTransactionList(BuildContext context, List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 80, color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              'Henüz işlem eklemediniz.',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isIncome = transaction.isIncome;

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              Helpers.cleanDescription(transaction.description),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Helpers.formatDateTime(transaction.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isIncome 
                    ? '+${Helpers.formatCurrency(transaction.amount)}' 
                    : '-${Helpers.formatCurrency(transaction.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  transaction.type.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
      },
    );
  }
}
