import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/transaction.dart';
import '../../dashboard/repositories/transaction_repository.dart';

// --- Providers ---

// Rapor Türü
final reportTypeProvider = StateProvider<String>((ref) => 'daily'); // daily, monthly, yearly

// Seçili Tarih (Varsayılan bugün)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Veri Provider'ı (Seçili tarih aralığına göre verileri çeker)
final reportDataProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final type = ref.watch(reportTypeProvider);
  final date = ref.watch(selectedDateProvider);

  DateTime startDate;
  DateTime endDate;

  if (type == 'daily') {
    // Günün başlangıcı ve bitişi
    startDate = DateTime(date.year, date.month, date.day);
    endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
  } else if (type == 'monthly') {
    // Ayın başı ve sonu
    startDate = DateTime(date.year, date.month, 1);
    // Bir sonraki ayın ilk gününden 1 saniye öncesi = bu ayın sonu
    endDate = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  } else {
    // Yıllık
    startDate = DateTime(date.year, 1, 1);
    endDate = DateTime(date.year, 12, 31, 23, 59, 59);
  }

  // Tüm verileri çek, filtrelemeyi client-side yapacağız (daha esnek tablo için)
  return repository.getTransactions(
    userId: '', 
    isAdmin: true,
    startDate: startDate,
    endDate: endDate,
  );
});

// --- Ekran ---

class KasaDefteriScreen extends ConsumerWidget {
  const KasaDefteriScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportType = ref.watch(reportTypeProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final reportDataAsync = ref.watch(reportDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasa Raporları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // 1. Filtreler ve Tarih Seçimi
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardTheme.color,
            child: Column(
              children: [
                // Rapor Türü Seçimi
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
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (Set<WidgetState> states) {
                         if (states.contains(WidgetState.selected)) {
                           return Theme.of(context).primaryColor;
                         }
                         return null;
                      },
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                      (Set<WidgetState> states) {
                         if (states.contains(WidgetState.selected)) {
                           return Colors.white;
                         }
                         return Colors.grey;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tarih Seçici
                InkWell(
                  onTap: () => _selectDate(context, ref, reportType, selectedDate),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade600),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateRange(reportType, selectedDate),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Rapor Tabloları ve Liste
          Expanded(
            child: reportDataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Hata: $err')),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('Bu dönemde kayıtlı işlem yok.'));
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // GELİR TABLOSU
                      _buildReportTable(context, 'GELİRLER (GİRİŞ)', transactions, true),
                      const SizedBox(height: 24),
                      
                      // GİDER TABLOSU
                      _buildReportTable(context, 'GİDERLER (ÇIKIŞ)', transactions, false),

                      const SizedBox(height: 32),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 16),

                      Text('İşlem Detayları', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      
                      // İşlem Listesi
                       ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                color: tx.isIncome ? Colors.green : Colors.red,
                              ),
                              title: Text(tx.description),
                              subtitle: Text(
                                '${Helpers.formatDateTime(tx.createdAt)} • ${tx.paymentMethod.displayName}',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                              trailing: Text(
                                Helpers.formatCurrency(tx.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: tx.isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tarih Formatlayıcı
  String _formatDateRange(String type, DateTime date) {
    if (type == 'daily') {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    } else if (type == 'monthly') {
      return DateFormat('MMMM yyyy', 'tr_TR').format(date);
    } else {
      return '${date.year}';
    }
  }

  // Tarih Seçim Mantığı
  Future<void> _selectDate(BuildContext context, WidgetRef ref, String type, DateTime currentDate) async {
    DateTime? picked;
    
    if (type == 'daily') {
      picked = await showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('tr', 'TR'),
      );
    } else if (type == 'monthly') {
      // Basit bir Yıl/Ay seçimi için yine DatePicker kullanabiliriz ama sadece Ay/Yıl görseli için kütüphane gerekir.
      // Şimdilik standart date picker açıp gününü 1 sayacağız.
      // Kullanıcı deneyimi için "Ayın herhangi bir gününü seçin" diyebiliriz.
      picked = await showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        helpText: 'Görüntülemek istediğiniz ayı seçin',
        locale: const Locale('tr', 'TR'),
      );
      if (picked != null) picked = DateTime(picked.year, picked.month, 1);
    } else {
      // Yıllık seçim (Year Picker)
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Yıl Seçin"),
            content: SizedBox(
              width: 300,
              height: 300,
              child: YearPicker(
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                selectedDate: currentDate,
                onChanged: (DateTime dateTime) {
                  ref.read(selectedDateProvider.notifier).state = dateTime;
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      );
      return;
    }

    if (picked != null) {
      ref.read(selectedDateProvider.notifier).state = picked;
    }
  }

  // Tablo Oluşturucu
  Widget _buildReportTable(BuildContext context, String title, List<Transaction> allTransactions, bool isIncome) {
    // Verileri Filtrele
    final filtered = allTransactions.where((t) => isIncome ? t.isIncome : t.isExpense).toList();
    
    // Toplamları Hesapla
    double cash = 0;
    double card = 0;
    double check = 0;

    for (var tx in filtered) {
      if (tx.paymentMethod == PaymentMethod.cash) cash += tx.amount;
      if (tx.paymentMethod == PaymentMethod.creditCard) card += tx.amount;
      if (tx.paymentMethod == PaymentMethod.checkNote) check += tx.amount;
    }
    
    final total = cash + card + check;
    final color = isIncome ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title, 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildRow('Nakit', cash, color),
          const Divider(color: Colors.white10),
          _buildRow('Kredi Kartı', card, color),
          const Divider(color: Colors.white10),
          _buildRow('Çek / Senet', check, color),
          const Divider(color: Colors.white24, thickness: 1),
          _buildRow('TOPLAM', total, color, isBold: true),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double amount, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: Colors.white70,
            ),
          ),
          Text(
            Helpers.formatCurrency(amount), 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: isBold ? color : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
