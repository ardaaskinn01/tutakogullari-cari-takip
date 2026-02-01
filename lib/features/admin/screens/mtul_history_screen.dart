import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/data_table_wrapper.dart';
import '../../../models/mtul_calculation.dart';
import '../../dashboard/repositories/mtul_repository.dart';
import '../../../core/utils/pdf_generator.dart';

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
  final Set<String> _selectedItems = {};
  bool _isSelectionMode = false;

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
                setState(() {
                  _selectedCustomer = null;
                  _isSelectionMode = false;
                  _selectedItems.clear();
                });
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppConstants.adminDashboardRoute);
              }
            },
          ),
          actions: [
            if (_selectedCustomer != null)
              IconButton(
                icon: Icon(_isSelectionMode ? Icons.close : Icons.picture_as_pdf),
                tooltip: _isSelectionMode ? 'İptal' : 'PDF Oluştur',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = !_isSelectionMode;
                    _selectedItems.clear();
                  });
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
      body: _selectedCustomer == null 
          ? _buildCustomerSummary(isDesktop) 
          : _buildCustomerDetailList(_selectedCustomer!, isDesktop),
      floatingActionButton: _isSelectionMode && _selectedItems.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(left: 32.0), // Sol hizalama için padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'print_btn',
                    onPressed: () => _printSelected(context, ref, isShare: false),
                    label: Text('Yazdır (${_selectedItems.length})'),
                    icon: const Icon(Icons.print),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton.extended(
                    heroTag: 'share_btn',
                    onPressed: () => _printSelected(context, ref, isShare: true),
                    label: const Text('Paylaş'),
                    icon: const Icon(Icons.share),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            )
          : null,
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
                    rows: calculations.map((calc) {
                      final isSelected = _selectedItems.contains(calc.id);
                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: (val) {
                          if (_isSelectionMode) {
                            setState(() {
                              if (val == true) {
                                _selectedItems.add(calc.id);
                              } else {
                                _selectedItems.remove(calc.id);
                              }
                            });
                          } else {
                            _showDetailDialog(context, ref, calc.id);
                          }
                        },
                        cells: [
                          DataCell(Text(Helpers.formatDateTime(calc.createdAt))),
                          DataCell(Text(
                            Helpers.formatCurrency(calc.totalPrice),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          )),
                          DataCell(Icon(
                            _isSelectionMode 
                                ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                                : Icons.chevron_right,
                            color: _isSelectionMode ? (isSelected ? Colors.blue : Colors.grey) : Colors.grey,
                          )),
                        ],
                      );
                    }).toList(),
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
                onTap: () {
                   if (_isSelectionMode) {
                     setState(() {
                       if (_selectedItems.contains(calc.id)) {
                         _selectedItems.remove(calc.id);
                       } else {
                         _selectedItems.add(calc.id);
                       }
                     });
                   } else {
                     _showDetailDialog(context, ref, calc.id);
                   }
                },
                leading: _isSelectionMode 
                    ? Checkbox(
                        value: _selectedItems.contains(calc.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedItems.add(calc.id);
                            } else {
                              _selectedItems.remove(calc.id);
                            }
                          });
                        },
                      )
                    : null,
              ),
            ).animate().fadeIn(delay: (30 * index).ms).slideX();
          },
        );
      },
    );
  }

  Future<void> _printSelected(BuildContext context, WidgetRef ref, {required bool isShare}) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final repository = ref.read(mtulRepositoryProvider);
      
      // Fetch details for all selected items
      final List<MtulCalculation> detailedList = [];
      for (final id in _selectedItems) {
        final detail = await repository.getCalculationDetail(id);
        detailedList.add(detail);
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        
        if (isShare) {
          await PdfGenerator.shareMtulPdf(
            _selectedCustomer ?? 'Müşteri',
            detailedList,
          );
        } else {
          await PdfGenerator.generateMtulPdf(
            _selectedCustomer ?? 'Müşteri',
            detailedList,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem Başarısız: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
