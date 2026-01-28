import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ÖNEMLİ: Aşağıdaki provider'ların tanımlı olduğu dosyaları doğru import ettiğinden emin ol
// Örn: import '../../dashboard/providers/dashboard_providers.dart';

import '../../../core/utils/helpers.dart';
import '../../../core/widgets/data_table_wrapper.dart';
import '../../../models/transaction.dart';
import '../../dashboard/repositories/transaction_repository.dart';
import '../../dashboard/screens/user_dashboard_screen.dart';
import '../../dashboard/widgets/add_transaction_modal.dart';
import 'admin_dashboard_screen.dart';
import 'kasa_defteri_screen.dart';

// Diğer ekranlarda kullandığın ve aşağıda invalidate ettiğin provider'ları buraya import etmelisin:
// import '../../dashboard/providers/balance_provider.dart';

final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactions(
    userId: '',
    isAdmin: true,
    limit: 50,
  );
});

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    // Masaüstü build aldığında geniş ekran tespiti
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İşlem Geçmişi'),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('Kayıtlı işlem bulunamadı.'));
          }

          if (isDesktop) {
            return _buildDesktopTable(context, ref, transactions);
          }
          return _buildMobileList(context, ref, transactions);
        },
      ),
    );
  }

  // Masaüstü Tablo Görünümü
  Widget _buildDesktopTable(BuildContext context, WidgetRef ref, List<Transaction> transactions) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: DataTableWrapper(
            title: 'Son İşlemler',
            columns: const [
              DataColumn(label: Text('Tarih')),
              DataColumn(label: Text('Tür')),
              DataColumn(label: Text('Açıklama')),
              DataColumn(label: Text('Yöntem')),
              DataColumn(label: Text('Tutar'), numeric: true),
              DataColumn(label: Text('İşlemler')),
            ],
            rows: transactions.map((tx) => DataRow(
              cells: [
                DataCell(Text(DateFormat('dd.MM.yyyy HH:mm').format(tx.createdAt))),
                DataCell(Icon(
                  tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: tx.isIncome ? Colors.green : Colors.red,
                  size: 16,
                )),
                DataCell(Text(tx.description)),
                DataCell(Text(tx.paymentMethod.displayName)),
                DataCell(Text(
                  Helpers.formatCurrency(tx.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tx.isIncome ? Colors.green : Colors.red,
                  ),
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () => _showEditModal(context, ref, tx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context, ref, tx),
                    ),
                  ],
                )),
              ],
            )).toList(),
          ),
        ),
      ),
    );
  }

  // Mobil Liste Görünümü
  Widget _buildMobileList(BuildContext context, WidgetRef ref, List<Transaction> transactions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: tx.isIncome ? Colors.green : Colors.red,
            ),
            title: Text(tx.description),
            subtitle: Text(
              '${DateFormat('dd.MM.yyyy HH:mm').format(tx.createdAt)} • ${tx.paymentMethod.displayName}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Helpers.formatCurrency(tx.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tx.isIncome ? Colors.green : Colors.red,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showEditModal(context, ref, tx);
                    if (val == 'delete') _confirmDelete(context, ref, tx);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    const PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditModal(BuildContext context, WidgetRef ref, Transaction transaction) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AddTransactionModal(
                initialTransaction: transaction,
                onSuccess: () {
                  Navigator.pop(context);
                  _invalidateAll(ref);
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
          initialTransaction: transaction,
          onSuccess: () {
            Navigator.pop(context);
            _invalidateAll(ref);
          },
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Transaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlemi Sil'),
        content: const Text('Bu işlemi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL')),
          TextButton(
            onPressed: () async {
              try {
                if (transaction.id != null) {
                  await ref.read(transactionRepositoryProvider).deleteTransaction(transaction.id!);

                  // Invalidate işlemi asenkron işlem bittikten sonra yapılmalı
                  _invalidateAll(ref);

                  if (context.mounted) {
                    Navigator.pop(context); // Dialogu kapat
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('İşlem silindi')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Dialogu kapat
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(balanceProvider);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(reportDataProvider);
    ref.invalidate(userTransactionsProvider);
  }
}
