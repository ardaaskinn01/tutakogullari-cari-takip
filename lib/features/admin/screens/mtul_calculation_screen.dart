import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/mtul_price.dart';
import '../../dashboard/repositories/mtul_repository.dart';
import 'mtul_prices_screen.dart'; // Provider'ı kullanmak için

class MtulCalculationScreen extends ConsumerStatefulWidget {
  const MtulCalculationScreen({super.key});

  @override
  ConsumerState<MtulCalculationScreen> createState() => _MtulCalculationScreenState();
}

class _MtulCalculationScreenState extends ConsumerState<MtulCalculationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  
  String _selectedCategory = 'standard';
  
  // Girilen adetleri tutmak için Map: component_id -> quantity
  final Map<String, double> _quantities = {};
  
  bool _isSaving = false;

  // Kategori Seçenekleri
  final Map<String, String> _categories = {
    'standard': 'Standart (Beyaz)',
    'gold_oak': 'Altın Meşe',
    'anthracite': 'Antrasit Gri',
    'fly_screen': 'Sineklik',
  };

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  // Toplam Tutar Hesaplama
  double _calculateGrandTotal(List<MtulPrice> prices) {
    double total = 0;
    for (var price in prices) {
      final qty = _quantities[price.id] ?? 0;
      total += qty * price.unitPrice;
    }
    return total;
  }

  Future<void> _saveCalculation(List<MtulPrice> prices) async {
    if (!_formKey.currentState!.validate()) return;
    
    // En az 1 ürün girilmeli
    if (_calculateGrandTotal(prices) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir ürün adedi girin.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(mtulRepositoryProvider);
      
      // Hazırlanan veriler
      final List<Map<String, dynamic>> items = [];
      double grandTotal = 0;

      for (var price in prices) {
        final qty = _quantities[price.id] ?? 0;
        if (qty > 0) {
          final lineTotal = qty * price.unitPrice;
          grandTotal += lineTotal;
          
          items.add({
            'component_name': price.componentName,
            'quantity': qty,
            'unit_price': price.unitPrice,
            'total_price': lineTotal,
          });
        }
      }

      await repository.saveCalculation(
        customerName: _customerNameController.text.trim(), 
        totalPrice: grandTotal, 
        items: items,
      );

      if (mounted) {
        // Formu temizle
        _customerNameController.clear();
        setState(() => _quantities.clear());
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesaplama başarıyla kaydedildi!'), backgroundColor: Colors.green),
        );
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
    // Seçili kategoriye göre fiyatları çek (Oto-seed özelliği sayesinde veri yoksa oluşur)
    final pricesAsync = ref.watch(mtulPricesProvider(_selectedCategory));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metretül Hesapla'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.adminDashboardRoute),
        ),
        actions: [
          // Fiyatları Düzenle Butonu
          TextButton.icon(
            onPressed: () => context.push(AppConstants.mtulPricesRoute),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Fiyatlar'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
          // Geçmiş Butonu
          IconButton(
            onPressed: () => context.push(AppConstants.mtulHistoryRoute),
            icon: const Icon(Icons.history),
            tooltip: 'Geçmiş Hesaplamalar',
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Üst Form (Müşteri & Kategori) ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardTheme.color,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Müşteri Adı / Proje',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Müşteri adı gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Seçin',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.entries.map((e) {
                      return DropdownMenuItem(value: e.key, child: Text(e.value));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                           _selectedCategory = val;
                           _quantities.clear(); // Kategori değişince adetleri sıfırla
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // --- Hesaplama Listesi ---
          Expanded(
            child: pricesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Hata: $err')),
              data: (prices) {
                if (prices.isEmpty) return const Center(child: Text('Fiyat listesi boş.'));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: prices.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final price = prices[index];
                    final qty = _quantities[price.id] ?? 0;
                    final total = qty * price.unitPrice;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          // 1. Bileşen Adı ve Birim Fiyat
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(price.componentName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  'Birim: ${Helpers.formatCurrency(price.unitPrice)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),
                          
                          // 2. Adet Girişi
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: qty > 0 ? qty.toString() : '', // 0 ise boş göster
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: '0',
                                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _quantities[price.id] = double.tryParse(val.replaceAll(',', '.')) ?? 0;
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(width: 16),

                          // 3. Satır Toplamı
                          Expanded(
                            flex: 3,
                            child: Text(
                              Helpers.formatCurrency(total),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: total > 0 ? Colors.green : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // --- Alt Toplam ve Kaydet ---
          pricesAsync.when(
            data: (prices) {
              final grandTotal = _calculateGrandTotal(prices);
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.2), offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GENEL TOPLAM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            Helpers.formatCurrency(grandTotal),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => _saveCalculation(prices),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSaving 
                             ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                             : const Text('HESAPLAMAYI KAYDET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}
