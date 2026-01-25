import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/mtul_calculation.dart';
import '../../dashboard/repositories/mtul_repository.dart';

// --- Family Provider ---
// Tek bir hesaplamanın detayını çekmek için
final calculationDetailProvider = FutureProvider.family<MtulCalculation, String>((ref, id) async {
  final repository = ref.read(mtulRepositoryProvider);
  return repository.getCalculationDetail(id);
});

// Tüm geçmişi çeken provider
final mtulHistoryProvider = FutureProvider<List<MtulCalculation>>((ref) async {
  final repository = ref.watch(mtulRepositoryProvider);
  return repository.getCalculations();
});

class MtulHistoryScreen extends ConsumerWidget {
  const MtulHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(mtulHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesaplama Geçmişi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
        data: (calculations) {
          if (calculations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade600),
                   const SizedBox(height: 16),
                   const Text('Kayıtlı hesaplama yok.'),
                ],
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
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    child: const Icon(Icons.description, color: Colors.blueAccent),
                  ),
                  title: Text(calc.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(Helpers.formatDateTime(calc.createdAt)),
                  trailing: Text(
                    Helpers.formatCurrency(calc.totalPrice),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                  onTap: () => _showDetailDialog(context, ref, calc.id),
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX();
            },
          );
        },
      ),
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
          return SizedBox(
            width: double.maxFinite,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text('${item.quantity} x ${item.componentName}'),
                          ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('KAPAT'),
        ),
      ],
    );
  }
}
