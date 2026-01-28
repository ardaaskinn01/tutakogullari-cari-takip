import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/data_table_wrapper.dart';
import '../../dashboard/repositories/glass_repository.dart';

final glassSummaryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(glassRepositoryProvider);
  return repository.getCustomerSummary();
});

class GlassHistoryScreen extends ConsumerWidget {
  const GlassHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(glassSummaryProvider);
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri Özeti'),
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
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
        data: (summaryList) {
          if (summaryList.isEmpty) {
            return const Center(child: Text('Henüz kayıtlı hesaplama yok.'));
          }
          
          summaryList.sort((a, b) => (b['last_order_date'] as DateTime).compareTo(a['last_order_date'] as DateTime));

          if (isDesktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: DataTableWrapper(
                    title: 'Müşteri Bazlı Cam m² Özeti',
                    columns: const [
                      DataColumn(label: Text('Müşteri Adı')),
                      DataColumn(label: Text('Toplam Sipariş'), numeric: true),
                      DataColumn(label: Text('Son Sipariş')),
                      DataColumn(label: Text('Toplam Ciro'), numeric: true),
                    ],
                    rows: summaryList.map((item) => DataRow(
                      cells: [
                        DataCell(Text(item['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(item['total_count'].toString())),
                        DataCell(Text(Helpers.formatDate(item['last_order_date']))),
                        DataCell(Text(
                          Helpers.formatCurrency(item['total_amount']),
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        )),
                      ],
                    )).toList(),
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: summaryList.length,
            itemBuilder: (context, index) {
              final item = summaryList[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigoAccent.withOpacity(0.2),
                    child: Text(
                      (item['customer_name'] as String)[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                    ),
                  ),
                  title: Text(
                    item['customer_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${item['total_count']} Sipariş • Son: ${Helpers.formatDate(item['last_order_date'])}',
                  ),
                  trailing: Text(
                    Helpers.formatCurrency(item['total_amount']),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX();
            },
          );
        },
      ),
    );
  }
}
