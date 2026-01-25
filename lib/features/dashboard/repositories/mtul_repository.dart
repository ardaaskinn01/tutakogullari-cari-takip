import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/mtul_price.dart';
import '../../../models/mtul_calculation.dart';
import '../../auth/services/supabase_service.dart';

class MtulRepository {
  final SupabaseClient _supabase;

  MtulRepository(this._supabase);

  // --- Fiyat Yönetimi ---

  // 1. Kategoriye göre fiyatları getir
  Future<List<MtulPrice>> getPrices(String category) async {
    final List<dynamic> data = await _supabase
        .from('mtul_prices')
        .select()
        .eq('category', category)
        .order('component_name');
    
    return data.map((e) => MtulPrice.fromJson(e)).toList();
  }

  // 2. Fiyat Güncelle
  Future<void> updatePrice(String id, double newPrice) async {
    await _supabase
        .from('mtul_prices')
        .update({'unit_price': newPrice})
        .eq('id', id);
  }

  // 3. Varsayılan Fiyatları Oluştur (Eğer yoksa)
  Future<void> seedDefaultPrices(String category, List<String> components) async {
    final existingParams = await getPrices(category);
    // Hangi bileşenler eksik?
    final existingNames = existingParams.map((e) => e.componentName).toSet();
    final missing = components.where((c) => !existingNames.contains(c)).toList();

    if (missing.isNotEmpty) {
      final inserts = missing.map((name) => {
        'category': category,
        'component_name': name,
        'unit_price': 0, // Varsayılan 0
      }).toList();

      await _supabase.from('mtul_prices').insert(inserts);
    }
  }


  // --- Hesaplama Geçmişi ---

  // 4. Hesaplamayı Kaydet
  Future<void> saveCalculation({
    required String customerName,
    required double totalPrice,
    required List<Map<String, dynamic>> items, // {component_name, quantity, unit_price, total_price}
  }) async {
    
    // A. Ana kaydı oluştur
    final calcData = await _supabase.from('mtul_calculations').insert({
      'customer_name': customerName,
      'total_price': totalPrice,
    }).select().single();

    final calculationId = calcData['id'] as String;

    // B. Detayları ekle
    final itemsToInsert = items.map((item) => {
      'calculation_id': calculationId,
      ...item,
    }).toList();

    await _supabase.from('mtul_calculation_items').insert(itemsToInsert);
  }

  // 5. Geçmiş Hesaplamaları Getir
  Future<List<MtulCalculation>> getCalculations() async {
    // Join ile items'ı da çekebiliriz ama liste ekranı için sadece başlıklar yeterli
    // Detay gerekirse ayrı çekeriz. Şimdilik sadece ana tabloyu çekelim.
    final List<dynamic> data = await _supabase
        .from('mtul_calculations')
        .select()
        .order('created_at', ascending: false);

    return data.map((e) => MtulCalculation.fromJson(e)).toList();
  }

  // 6. Tek Bir Hesaplamanın Detaylarını Getir
  Future<MtulCalculation> getCalculationDetail(String id) async {
    final response = await _supabase
        .from('mtul_calculations')
        .select('*, mtul_calculation_items(*)')
        .eq('id', id)
        .single();
    
    return MtulCalculation.fromJson(response);
  }
}

final mtulRepositoryProvider = Provider<MtulRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MtulRepository(supabase);
});
