import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/cari_account.dart';
import '../../../models/cari_transaction.dart';
import '../../dashboard/repositories/cari_repository.dart';

// --- Providers ---

// Hesap detayını (güncel bakiye vs.) getiren provider
final cariAccountProvider = FutureProvider.family<CariAccount, String>((ref, id) async {
  final repository = ref.read(cariRepositoryProvider);
  return repository.getAccountById(id);
});

// İşlem geçmişini getiren provider
final cariTransactionsProvider = FutureProvider.family<List<CariTransaction>, String>((ref, id) async {
  final repository = ref.read(cariRepositoryProvider);
  return repository.getAccountTransactions(id);
});

class CariAccountDetailScreen extends ConsumerWidget {
  final String accountId;

  const CariAccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(cariAccountProvider(accountId));
    final transactionsAsync = ref.watch(cariTransactionsProvider(accountId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Detayı'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
        data: (account) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Üst Bilgi Kartı (İsim ve Bakiye)
                _buildHeaderCard(context, account),
                
                const SizedBox(height: 24),

                // 2. İşlem Geçmişi Listesi
                Text(
                  'İşlem Geçmişi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                transactionsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, stack) => Text('Geçmiş yüklenemedi: $err'),
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('Henüz işlem kaydı yok.'),
                        ),
                      );
                    }
                    
                    // Özet İstatistikleri
                    double totalDebt = 0;
                    double totalCollection = 0;
                    for(var t in transactions) {
                      if (t.isDebt) totalDebt += t.amount;
                      if (t.isCollection) totalCollection += t.amount;
                    }

                    return Column(
                      children: [
                        // İstatistik Tablosu
                        Row(
                          children: [
                            Expanded(child: _buildStatCard(context, 'Toplam Alacak', totalDebt, Colors.red)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard(context, 'Toplam Tahsilat', totalCollection, Colors.green)),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Liste
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return _buildTransactionItem(context, tx, index);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, CariAccount account) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(
              account.fullName[0].toUpperCase(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            account.fullName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          if (account.phone != null)
            Text(account.phone!, style: const TextStyle(color: Colors.white70)),
            
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          
          const Text('GÜNCEL BORÇ', style: TextStyle(color: Colors.white60, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(
            Helpers.formatCurrency(account.currentBalance),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStatCard(BuildContext context, String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(title, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
           const SizedBox(height: 4),
           Text(
             Helpers.formatCurrency(amount),
             style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
           ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, CariTransaction tx, int index) {
    final isDebt = tx.isDebt;
    final color = isDebt ? Colors.red : Colors.green;
    final icon = isDebt ? Icons.arrow_outward : Icons.arrow_downward; // Borç artıyor (out), Tahsilat düşüyor (down/in)

    return Card(
      elevation: 0,
       margin: const EdgeInsets.only(bottom: 12),
       color: Theme.of(context).cardTheme.color,
       shape: RoundedRectangleBorder(
         side: BorderSide(color: Colors.grey.shade800),
         borderRadius: BorderRadius.circular(12),
       ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          isDebt ? 'Borç Eklendi' : 'Tahsilat (${tx.paymentMethod?.displayName ?? "Nakit"})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tx.description != null && tx.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(tx.description!),
              ),
            const SizedBox(height: 4),
            Text(Helpers.formatDateTime(tx.createdAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ],
        ),
        trailing: Text(
          isDebt ? '+${Helpers.formatCurrency(tx.amount)}' : '-${Helpers.formatCurrency(tx.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    ).animate().fadeIn(delay: (50 * index).ms).slideX();
  }
}
