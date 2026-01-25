import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/mtul_price.dart';
import '../../dashboard/repositories/mtul_repository.dart';

// --- State Providers ---

// Kategorideki fiyatları getiren provider
final mtulPricesProvider = FutureProvider.family<List<MtulPrice>, String>((ref, category) async {
  final repository = ref.watch(mtulRepositoryProvider);
  
  // Varsayılan verileri tanımla
  List<String> defaults = [];
  if (category == 'standard') {
    defaults = [
      '60 Kasa Beyaz 1.6', '60 Kasa Beyaz 2.2',
      '70 Kasa Beyaz 1.6', '70 Kasa Beyaz 2.2',
      'Pencere Kanat 1.6', 'Pencere Kanat 2.2',
      'Kapı Kanat 1.6', 'Kapı Kanat 2.2',
      '70 Orta Kayıt 1.6', '70 Orta Kayıt 2.2',
      '60 Orta Kayıt 1.6', '60 Orta Kayıt 2.2',
      'Çift Cam Çıtası', 'Tek Cam Çıtası',
      'Lambri', 'U Kasa', 'Mermer Afyon'
    ];
  } else if (category == 'gold_oak' || category == 'anthracite') {
    defaults = [
      '70 Kasa',
      'Pencere Kanat',
      'Kapı Kanat',
      '70 Orta Kayıt',
      '60 Orta Kayıt',
      'Çift Cam Çıtası',
      'Tek Cam Çıtası'
    ];
  } else if (category == 'fly_screen') {
    defaults = [
      'Menteşeli Pencere Sineklik',
      'Menteşeli Kapı Sineklik',
      'Pileli Pencere Sineklik',
      'Pileli Kapı Sineklik'
    ];
  }

  // Önce eksik varsa tamamla (Seed)
  if (defaults.isNotEmpty) {
    await repository.seedDefaultPrices(category, defaults);
  }

  // Sonra güncel listeyi çek
  return repository.getPrices(category);
});

class MtulPricesScreen extends StatelessWidget {
  const MtulPricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Birim Fiyat Yönetimi'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Standart (Beyaz)'),
              Tab(text: 'Altın Meşe'),
              Tab(text: 'Antrasit Gri'),
              Tab(text: 'Sineklik'),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const TabBarView(
          children: [
            _PriceListTab(category: 'standard'),
            _PriceListTab(category: 'gold_oak'),
            _PriceListTab(category: 'anthracite'),
            _PriceListTab(category: 'fly_screen'),
          ],
        ),
      ),
    );
  }
}

class _PriceListTab extends ConsumerStatefulWidget {
  final String category;

  const _PriceListTab({required this.category});

  @override
  ConsumerState<_PriceListTab> createState() => _PriceListTabState();
}

class _PriceListTabState extends ConsumerState<_PriceListTab> {
  // Değişen fiyatları tutmak için geçici map
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveChanges(List<MtulPrice> prices) async {
    setState(() => _isSaving = true);
    final repository = ref.read(mtulRepositoryProvider);
    
    try {
      int updatedCount = 0;
      for (var price in prices) {
        final controller = _controllers[price.id];
        if (controller != null) {
          final newValue = double.tryParse(controller.text.replaceAll(',', '.'));
          // Eğer geçerli bir sayıysa ve değişmişse güncelle
          if (newValue != null && newValue != price.unitPrice) {
            await repository.updatePrice(price.id, newValue);
            updatedCount++;
          }
        }
      }
      
      if (mounted) {
        if (updatedCount > 0) {
          ref.invalidate(mtulPricesProvider(widget.category));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$updatedCount kayıt güncellendi'), backgroundColor: Colors.green),
          );
        } else {
             ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Değişiklik yapılmadı')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(mtulPricesProvider(widget.category));

    return pricesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (prices) {
        if (prices.isEmpty) return const Center(child: Text('Liste boş'));

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: prices.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (context, index) {
                  final price = prices[index];
                  
                  // Controller yoksa oluştur (Her satır için bir kez)
                  if (!_controllers.containsKey(price.id)) {
                    _controllers[price.id] = TextEditingController(
                      text: price.unitPrice == 0 ? '' : price.unitPrice.toStringAsFixed(2),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          price.componentName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _controllers[price.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(),
                            suffixText: 'TL',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _saveChanges(prices),
                  icon: const Icon(Icons.save),
                  label: _isSaving 
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                     : const Text('DEĞİŞİKLİKLERİ KAYDET', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
