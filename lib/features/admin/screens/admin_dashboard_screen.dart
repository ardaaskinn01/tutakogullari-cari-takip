import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/transaction.dart' as model;
import '../../auth/services/auth_service.dart';
import '../../dashboard/repositories/transaction_repository.dart';
import '../../dashboard/widgets/add_transaction_modal.dart';
import '../../../core/utils/refresh_utils.dart';
import '../../../core/widgets/side_menu.dart';
import '../../../core/widgets/theme_toggle_button.dart';

// Providers for dashboard state
final balanceProvider = FutureProvider<Map<String, double>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getBalance();
});

final allTransactionsProvider = FutureProvider<List<model.Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider).value;
  final isAdmin = await ref.watch(isAdminProvider.future);
  
  if (user == null) return [];
  return repository.getTransactions(userId: user!.id, isAdmin: isAdmin);
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);
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
          if (context.mounted) Navigator.of(context).pop(); // Bu genellikle kökte uygulamayı kapatır
        }
      },
      child: Scaffold(
        drawer: MediaQuery.of(context).size.width <= 900 
          ? Drawer(child: SideMenu(
              key: ValueKey(ref.watch(currentUserProvider).value?.id ?? 'admin-drawer'),
              isDrawer: true
            )) 
          : null,
        appBar: AppBar(
        title: const Text('Yönetici Paneli'),
        leading: MediaQuery.of(context).size.width <= 900 
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
        actions: [
          const ThemeToggleButton(),
          // Masaüstünde FAB yerine AppBar'da buton göster
          if (MediaQuery.of(context).size.width > 900)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: FilledButton.icon(
                onPressed: () => _showAddTransactionModal(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('İşlem Ekle'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),

      // --- BODY ---
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(balanceProvider);
          ref.invalidate(allTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hoşgeldin Mesajı
                    userProfileAsync.when(
                      data: (profile) => Text(
                        'Hoşgeldiniz, ${profile?.displayName ?? "Admin"}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      loading: () => const SizedBox(height: 28),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 32),
    
                    // Özet Kartları
                    balanceAsync.when(
                      data: (balance) => _buildSummaryCards(context, balance),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Hata: $err'),
                    ),
    
                    const SizedBox(height: 48),
    
                    // Son İşlemler Başlığı
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Son İşlemler',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        TextButton(
                          onPressed: () => context.push(AppConstants.kasaDefteriRoute),
                          child: const Text('Tümünü Gör'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
    
                    // İşlem Listesi
                    transactionsAsync.when(
                      data: (transactions) => _buildTransactionList(context, transactions),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('Hata oluştu: $err')),
                    ),
                    
                    const SizedBox(height: 80), 
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: MediaQuery.of(context).size.width <= 900 
        ? FloatingActionButton.extended(
            onPressed: () => _showAddTransactionModal(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('İşlem Ekle'),
          )
        : null,
    ));
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, double> balance) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1);
        
        if (crossAxisCount == 3) {
           return Row(
             children: [
               Expanded(
                 child: _SummaryCard(
                   title: 'Nakit Girişi',
                   amount: balance['total_income'] ?? 0,
                   icon: Icons.arrow_downward,
                   color: Colors.green,
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: _SummaryCard(
                   title: 'Nakit Çıkışı',
                   amount: balance['total_expense'] ?? 0,
                   icon: Icons.arrow_upward,
                   color: Colors.red,
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: _SummaryCard(
                   title: 'Net Kasa',
                   amount: balance['net_balance'] ?? 0,
                   icon: Icons.account_balance_wallet,
                   color: (balance['net_balance'] ?? 0) >= 0 ? Colors.blue : Colors.orange,
                 ),
               ),
             ],
           ).animate().fadeIn().slideY(begin: 0.1, end: 0);
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Nakit Girişi',
                    amount: balance['total_income'] ?? 0,
                    icon: Icons.arrow_downward,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Nakit Çıkışı',
                    amount: balance['total_expense'] ?? 0,
                    icon: Icons.arrow_upward,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              title: 'Net Kasa Durumu',
              amount: balance['net_balance'] ?? 0,
              icon: Icons.account_balance_wallet,
              color: (balance['net_balance'] ?? 0) >= 0 ? Colors.blue : Colors.orange,
              isLarge: true,
            ),
          ],
        ).animate().fadeIn().slideY(begin: 0.1, end: 0);
      }
    );
  }

  // --- Transaction List Builder ---
  Widget _buildTransactionList(BuildContext context, List<model.Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.history, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Henüz işlem bulunmuyor'),
          ],
        ),
      );
    }

    // Sadece ilk 5 işlemi göster (Dashboard olduğu için)
    final displayList = transactions.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final transaction = displayList[index];
        final isIncome = transaction.isIncome;
        
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Helpers.formatDate(transaction.createdAt)} • ${transaction.paymentMethod.displayName}',
                   style: Theme.of(context).textTheme.bodySmall,
                ),
                if (transaction.createdByName != null)
                  Text(
                    'Ekleyen: ${transaction.createdByName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            trailing: Text(
              isIncome 
                ? '+${Helpers.formatCurrency(transaction.amount)}' 
                : '-${Helpers.formatCurrency(transaction.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
      },
    );
  }

  // --- Dialogs ---


  void _showAddTransactionModal(BuildContext context, WidgetRef ref) {
    if (MediaQuery.of(context).size.width > 900) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AddTransactionModal(
                onSuccess: () {
                  RefreshUtils.invalidateAllFinancialData(ref);
                },
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddTransactionModal(
          onSuccess: () {
            RefreshUtils.invalidateAllFinancialData(ref);
          },
        ),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isLarge;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, // Tema rengi
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          SizedBox(height: isLarge ? 12 : 8),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: isLarge ? 32 : 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.displayLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
