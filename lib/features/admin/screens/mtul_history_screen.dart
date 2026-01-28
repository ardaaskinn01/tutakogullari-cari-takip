import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/data_table_wrapper.dart';
import '../../../models/mtul_calculation.dart';
import '../../dashboard/repositories/mtul_repository.dart';

final mtulSummaryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(mtulRepositoryProvider);
  return repository.getCustomerSummary();
});

final customerCalculationsProvider = FutureProvider.family<List<MtulCalculation>, String>((ref, customerName) async {
  final repository = ref.watch(mtulRepositoryProvider);
  final all = await repository.getCalculations();
  return all.where((c) => c.customerName == customerName).toList();
});

final calculationDetailProvider = FutureProvider.family<MtulCalculation, String>((ref, id) async {
  final repository = ref.read(mtulRepositoryProvider);
  return repository.getCalculationDetail(id);
});

class MtulHistoryScreen extends ConsumerStatefulWidget {
  const MtulHistoryScreen({super.key});

  @override
  ConsumerState<MtulHistoryScreen> createState() => _MtulHistoryScreenState();
}

class _MtulHistoryScreenState extends ConsumerState<MtulHistoryScreen> {
  String? _selectedCustomer;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return PopScope(
      canPop: _selectedCustomer == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedCustomer != null) {
          setState(() => _selectedCustomer = null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_selectedCustomer == null ? 'Müşteri Özeti' : '$_selectedCustomer - Geçmiş'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedCustomer != null) {
                setState(() => _selectedCustomer = null);
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppConstants.adminDashboardRoute);
              }
            },
          ),
        ),
        body: _selectedCustomer == null 
            ? _buildCustomerSummary(isDesktop) 
            : _buildCustomerDetailList(_selectedCustomer!, isDesktop),
      ),
    );
  }

  Widget _buildCustomerSummary(bool isDesktop) {
    final summaryAsync = ref.watch(mtulSummaryProvider);

    return summaryAsync.when(
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
                  title: 'Müşteri Bazlı Metretül Özeti',
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
                    onSelectChanged: (_) => setState(() => _selectedCustomer = item['customer_name']),
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
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: Text(
                    (item['customer_name'] as String)[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ),
                title: Text(item['customer_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('${item['total_count']} Sipariş • Son: ${Helpers.formatDate(item['last_order_date'])}'),
                trailing: Text(
                  Helpers.formatCurrency(item['total_amount']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                ),
                onTap: () => setState(() => _selectedCustomer = item['customer_name']),
              ),
            ).animate().fadeIn(delay: (50 * index).ms).slideX();
          },
        );
      },
    );
  }

  Widget _buildCustomerDetailList(String customerName, bool isDesktop) {
    final historyAsync = ref.watch(customerCalculationsProvider(customerName));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (calculations) {
        if (isDesktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: DataTableWrapper(
                  title: '$customerName - Hesaplama Geçmişi',
                  columns: const [
                    DataColumn(label: Text('Tarih')),
                    DataColumn(label: Text('Toplam Tutar'), numeric: true),
                    DataColumn(label: Text('')),
                  ],
                  rows: calculations.map((calc) => DataRow(
                    cells: [
                      DataCell(Text(Helpers.formatDateTime(calc.createdAt))),
                      DataCell(Text(
                        Helpers.formatCurrency(calc.totalPrice),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      )),
                      DataCell(const Icon(Icons.chevron_right)),
                    ],
                    onSelectChanged: (_) => _showDetailDialog(context, ref, calc.id),
                  )).toList(),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: calculations.length,
          itemBuilder: (context, index) {
            final calc = calculations[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(Helpers.formatDateTime(calc.createdAt), style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Text(
                  Helpers.formatCurrency(calc.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                ),
                onTap: () => _showDetailDialog(context, ref, calc.id),
              ),
            ).animate().fadeIn(delay: (30 * index).ms).slideX();
          },
        );
      },
    );
  }

  void _showDetailDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => _DetailDialog(calculationId: id),
    );
  }
}

class _DetailDialog extends ConsumerWidget {
  final String calculationId;
  const _DetailDialog({required this.calculationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(calculationDetailProvider(calculationId));

    return AlertDialog(
      title: const Text('Hesaplama Detayı'),
      content: detailAsync.when(
        loading: () => const SizedBox(height: 200, width: 300, child: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Text('Hata: $err'),
        data: (calc) {
          final items = calc.items ?? [];
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Müşteri: ${calc.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Tarih: ${Helpers.formatDateTime(calc.createdAt)}', style: TextStyle(color: Colors.grey.shade400)),
                const Divider(height: 32),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Row(
                        children: [
                          Expanded(flex: 3, child: Text('${item.quantity} x ${item.componentName}')),
                          Expanded(
                            flex: 2,
                            child: Text(
                              Helpers.formatCurrency(item.totalPrice),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      Helpers.formatCurrency(calc.totalPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT')),
      ],
    );
  }
}
