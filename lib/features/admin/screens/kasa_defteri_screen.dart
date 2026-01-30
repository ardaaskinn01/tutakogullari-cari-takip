import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/data_table_wrapper.dart';
import '../../../models/transaction.dart';
import '../../dashboard/repositories/transaction_repository.dart';

// --- Providers ---
final reportTypeProvider = StateProvider<String>((ref) => 'daily');
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final reportDataProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final type = ref.watch(reportTypeProvider);
  final date = ref.watch(selectedDateProvider);

  DateTime startDate;
  DateTime endDate;

  if (type == 'daily') {
    startDate = DateTime(date.year, date.month, date.day);
    endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
  } else if (type == 'monthly') {
    startDate = DateTime(date.year, date.month, 1);
    endDate = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  } else {
    startDate = DateTime(date.year, 1, 1);
    endDate = DateTime(date.year, 12, 31, 23, 59, 59);
  }

  return repository.getTransactions(
    userId: '', 
    isAdmin: true,
    startDate: startDate,
    endDate: endDate,
  );
});

class KasaDefteriScreen extends ConsumerWidget {
  const KasaDefteriScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportType = ref.watch(reportTypeProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final reportDataAsync = ref.watch(reportDataProvider);
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppConstants.adminDashboardRoute);
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Kasa Raporları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.adminDashboardRoute);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppConstants.transactionHistoryRoute),
            tooltip: 'İşlem Geçmişi (Düzenle/Sil)',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Filtreler
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardTheme.color,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'daily', label: Text('GÜNLÜK')),
                        ButtonSegment(value: 'monthly', label: Text('AYLIK')),
                        ButtonSegment(value: 'yearly', label: Text('YILLIK')),
                      ],
                      selected: {reportType},
                      onSelectionChanged: (Set<String> newSelection) {
                        ref.read(reportTypeProvider.notifier).state = newSelection.first;
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context, ref, reportType, selectedDate),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _formatDateRange(reportType, selectedDate),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. İçerik
          Expanded(
            child: reportDataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Hata: $err')),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('Bu dönemde kayıtlı işlem yok.'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        children: [
                          // Özet Tabloları (Masaüstünde Yan Yana)
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildReportSummary(context, 'GELİRLER (GİRİŞ)', transactions, true)),
                                const SizedBox(width: 24),
                                Expanded(child: _buildReportSummary(context, 'GİDERLER (ÇIKIŞ)', transactions, false)),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildReportSummary(context, 'GELİRLER (GİRİŞ)', transactions, true),
                                const SizedBox(height: 16),
                                _buildReportSummary(context, 'GİDERLER (ÇIKIŞ)', transactions, false),
                              ],
                            ),

                          const SizedBox(height: 48),

                          // Tüm İşlemler Tablosu
                          if (isDesktop)
                            DataTableWrapper(
                              title: 'İşlem Detayları',
                              columns: const [
                                DataColumn(label: Text('Tarih')),
                                DataColumn(label: Text('Tür')),
                                DataColumn(label: Text('Açıklama')),
                                DataColumn(label: Text('Yöntem')),
                                DataColumn(label: Text('Ekleyen')),
                                DataColumn(label: Text('Tutar'), numeric: true),
                              ],
                              rows: transactions.map((tx) => DataRow(
                                cells: [
                                  DataCell(Text(DateFormat('dd.MM.yyyy HH:mm').format(tx.createdAt))),
                                  DataCell(Icon(
                                    tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: tx.isIncome ? Colors.green : Colors.red,
                                    size: 16,
                                  )),
                                  DataCell(Text(Helpers.cleanDescription(tx.description))),
                                  DataCell(Text(tx.paymentMethod.displayName)),
                                  DataCell(Text(tx.createdByName ?? '-')),
                                  DataCell(Text(
                                    Helpers.formatCurrency(tx.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: tx.isIncome ? Colors.green : Colors.red,
                                    ),
                                  )),
                                ],
                              )).toList(),
                            )
                          else
                            _buildMobileTransactionList(context, transactions),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildMobileTransactionList(BuildContext context, List<Transaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            'İşlem Detayları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final color = tx.isIncome ? Colors.green : Colors.red;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(
                    tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: color,
                    size: 20,
                  ),
                ),
                title: Text(
                  Helpers.cleanDescription(tx.description),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd.MM.yyyy HH:mm').format(tx.createdAt)} • ${tx.paymentMethod.displayName}${tx.createdByName != null ? ' • ${tx.createdByName}' : ''}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
                trailing: Text(
                  Helpers.formatCurrency(tx.amount),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportSummary(BuildContext context, String title, List<Transaction> allTransactions, bool isIncome) {
    final filtered = allTransactions.where((t) => isIncome ? t.isIncome : t.isExpense).toList();
    double cash = 0, card = 0, check = 0;

    for (var tx in filtered) {
      if (tx.paymentMethod == PaymentMethod.cash) cash += tx.amount;
      if (tx.paymentMethod == PaymentMethod.creditCard) card += tx.amount;
      if (tx.paymentMethod == PaymentMethod.checkNote) check += tx.amount;
    }
    
    final total = cash + card + check;
    final color = isIncome ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            _buildSummaryRow(context, 'Nakit', cash),
            Divider(color: Theme.of(context).dividerColor),
            _buildSummaryRow(context, 'Kredi Kartı', card),
            Divider(color: Theme.of(context).dividerColor),
            _buildSummaryRow(context, 'Çek / Senet', check),
            Divider(color: Theme.of(context).dividerColor, thickness: 1.5),
            _buildSummaryRow(context, 'TOPLAM', total, isBold: true, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, double amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isBold ? null : Theme.of(context).textTheme.bodyMedium?.color),
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(String type, DateTime date) {
    if (type == 'daily') return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    if (type == 'monthly') return DateFormat('MMMM yyyy', 'tr_TR').format(date);
    return '${date.year}';
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref, String type, DateTime currentDate) async {
    if (type == 'daily') {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('tr', 'TR'),
      );
      if (picked != null) ref.read(selectedDateProvider.notifier).state = picked;
    } else if (type == 'monthly') {
      // Ay ve Yıl için dropdown içeren dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            int selectedMonth = currentDate.month;
            int selectedYear = currentDate.year;
            
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Ay Seçin'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(labelText: 'Yıl'),
                        items: List.generate(11, (index) => 2020 + index)
                            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                            .toList(),
                        onChanged: (y) {
                          if (y != null) setDialogState(() => selectedYear = y);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedMonth,
                        decoration: const InputDecoration(labelText: 'Ay'),
                        items: List.generate(12, (index) => index + 1)
                            .map((m) => DropdownMenuItem(
                                  value: m, 
                                  child: Text(DateFormat('MMMM', 'tr_TR').format(DateTime(2024, m))),
                                ))
                            .toList(),
                        onChanged: (m) {
                          if (m != null) setDialogState(() => selectedMonth = m);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL')),
                    TextButton(
                      onPressed: () {
                        ref.read(selectedDateProvider.notifier).state = DateTime(selectedYear, selectedMonth, 1);
                        Navigator.pop(context);
                      },
                      child: const Text('TAMAM'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    } else {
      // Yıllık seçim (Year Picker Dropdown)
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            int selectedYear = currentDate.year;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Yıl Seçin'),
                  content: DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: 'Yıl'),
                    items: List.generate(31, (index) => 2020 + index)
                        .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                        .toList(),
                    onChanged: (y) {
                      if (y != null) setDialogState(() => selectedYear = y);
                    },
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL')),
                    TextButton(
                      onPressed: () {
                        ref.read(selectedDateProvider.notifier).state = DateTime(selectedYear, 1, 1);
                        Navigator.pop(context);
                      },
                      child: const Text('TAMAM'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    }
  }
}
