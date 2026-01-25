import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Add this import
import '../../../core/utils/helpers.dart';
import '../../../models/transaction.dart';
import '../../auth/services/auth_service.dart';
import '../repositories/transaction_repository.dart';
import '../widgets/add_transaction_modal.dart';

// Sadece oturum açan kullanıcının işlemlerini getirir
final userTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider).value;
  
  // Kullanıcı yoksa boş dön
  if (user == null) return [];
  
  // isAdmin = false göndererek sadece kendi işlemlerini çekmesini sağlıyoruz
  return repository.getTransactions(userId: user.id, isAdmin: false);
});

class UserDashboardScreen extends ConsumerWidget {
  const UserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(userTransactionsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Paneli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
               // Hoşgeldin Mesajı
              userProfileAsync.when(
                data: (profile) => Text(
                  'Merhaba, ${profile?.displayName ?? "Personel"}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                loading: () => const SizedBox(height: 32),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 8),
              Text(
                'Eklediğiniz işlemler aşağıdadır.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
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
                // İşlem eklenince listeyi yenile
                ref.invalidate(userTransactionsProvider);
              },
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('İşlem Ekle'),
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 80, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text(
              'Henüz işlem eklemediniz.',
              style: TextStyle(color: Colors.grey.shade500),
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
              transaction.description,
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
