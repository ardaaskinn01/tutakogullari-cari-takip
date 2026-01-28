import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/glass_calculation.dart';
import '../../dashboard/repositories/glass_repository.dart';
import '../../../core/widgets/customer_autocomplete.dart';
import '../../../core/services/customer_service.dart';
import '../../../core/utils/keyboard_shortcuts.dart';
import '../../../core/utils/refresh_utils.dart';
import 'glass_history_screen.dart';

class GlassCalculationScreen extends ConsumerStatefulWidget {
  const GlassCalculationScreen({super.key});

  @override
  ConsumerState<GlassCalculationScreen> createState() => _GlassCalculationScreenState();
}

class _GlassCalculationScreenState extends ConsumerState<GlassCalculationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _widthController = TextEditingController(); // m
  final _heightController = TextEditingController(); // m
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController(); // Birim fiyat

  // Calculated Values
  double _singleM2 = 0;
  double _totalM2 = 0;
  double _totalPrice = 0;
  
  bool _isSaving = false;

  void _calculate() {
    final width = double.tryParse(_widthController.text.replaceAll(',', '.')) ?? 0;
    final height = double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 0;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0;

    setState(() {
      _singleM2 = width * height;
      _totalM2 = _singleM2 * qty;
      _totalPrice = _totalM2 * unitPrice;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Veritabanına kaydet
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(glassRepositoryProvider);
      
      final calc = GlassCalculation(
        id: '', // Otomatik
        customerName: _nameController.text.trim(),
        width: double.parse(_widthController.text.replaceAll(',', '.')),
        height: double.parse(_heightController.text.replaceAll(',', '.')),
        m2: _singleM2,
        quantity: int.parse(_quantityController.text),
        totalM2: _totalM2,
        unitPrice: double.parse(_priceController.text.replaceAll(',', '.')),
        totalPrice: _totalPrice,
        createdAt: DateTime.now(),
      );

      await repository.saveCalculation(calc);

      if (mounted) {
        // Tüm cam verilerini ve detaylarını yenile
        RefreshUtils.invalidateGlassData(ref, _nameController.text.trim());
        
        // Formu temizle (Müşteri adı ve birim fiyat kalabilir kolaylık olsun diye)
        _widthController.clear();
        _heightController.clear();
        _calculate(); // Değerleri sıfırla

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesaplama kaydedildi!'), backgroundColor: Colors.green),
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
  void dispose() {
    _nameController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppConstants.adminDashboardRoute);
      },
      child: Scaffold(
        appBar: AppBar(
        title: const Text('Cam m² Hesaplama'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.adminDashboardRoute),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppConstants.glassHistoryRoute),
            icon: const Icon(Icons.history),
            tooltip: 'Geçmiş',
          ),
        ],
      ),
      body: KeyboardShortcuts(
        onSave: _save,
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              onChanged: _calculate, // Her değişiklikte hesapla
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // MÜŞTERİ BİLGİSİ
                  CustomerAutocomplete(
                    controller: _nameController,
                    validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                  ),
                  const SizedBox(height: 24),
                  
                  // ÖLÇÜLER VE ADET (RESPONSIVE GRID)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _widthController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'En (Metre)',
                                    suffixText: 'm',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _heightController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Boy (Metre)',
                                    suffixText: 'm',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Adet',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'm² Birim Fiyatı',
                                    suffixText: '₺',
                                    border: OutlineInputBorder(),
                                  ),
                                   validator: (v) => v!.isEmpty ? 'Gerekli' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // SONUÇ KARTI
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        _ResultRow(label: 'Tekil m²', value: '${_singleM2.toStringAsFixed(2)} m²'),
                        const Divider(height: 24),
                        _ResultRow(label: 'Toplam m² (x${_quantityController.text})', value: '${_totalM2.toStringAsFixed(2)} m²', isBold: true),
                        const Divider(height: 24),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOPLAM TUTAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              Helpers.formatCurrency(_totalPrice),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save, size: 24, color: Colors.white),
                      label: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('HESABI KAYDET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )));
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ResultRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16)),
        ],
      ),
    );
  }
}
