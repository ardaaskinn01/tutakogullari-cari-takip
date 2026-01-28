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
        .order('sort_order', ascending: true);
    
    return data.map((e) => MtulPrice.fromJson(e)).toList();
  }

  // 2. Fiyat Güncelle
  Future<void> updatePrice(String id, double newPrice) async {
    await _supabase
        .from('mtul_prices')
        .update({'unit_price': newPrice})
        .eq('id', id);
  }

  // 3. Varsayılan Fiyatları Oluştur ve Düzenle
  Future<void> seedDefaultPrices(String category, List<String> components) async {
    final List<dynamic> currentData = await _supabase
        .from('mtul_prices')
        .select()
        .eq('category', category);
    
    final existingPrices = currentData.map((e) => MtulPrice.fromJson(e)).toList();
    
    // İşlem kolaylığı için mevcutları isim bazlı (küçük harf) haritaya alalım
    final Map<String, MtulPrice> existingMap = {
      for (var p in existingPrices) p.componentName.toLowerCase(): p
    };

    // 1. İstenmeyen (listede olmayan) küçük harf hatalı veya eski kayıtları temizle
    // Not: Sadece 'standard' kategorisi için bu temizliği yapmak daha güvenli olabilir
    // Ancak kullanıcı "çift kere sıralanmış" dediği için tutarsızlığı gidermeliyiz.
    final List<String> lowercaseDefaults = components.map((e) => e.toLowerCase()).toList();
    for (var existing in existingPrices) {
      if (!lowercaseDefaults.contains(existing.componentName.toLowerCase())) {
        await _supabase.from('mtul_prices').delete().eq('id', existing.id);
      }
    }

    // 2. Listeyi Güncelle veya Ekle
    for (int i = 0; i < components.length; i++) {
      final targetName = components[i];
      final lowerName = targetName.toLowerCase();
      
      if (existingMap.containsKey(lowerName)) {
        final existing = existingMap[lowerName]!;
        // Varsa ismini (casing) ve sırasını güncelle
        await _supabase.from('mtul_prices').update({
          'component_name': targetName,
          'sort_order': i,
        }).eq('id', existing.id);
      } else {
        // Yoksa ekle
        await _supabase.from('mtul_prices').insert({
          'category': category,
          'component_name': targetName,
          'unit_price': 0,
          'sort_order': i,
        });
      }
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

  // 7. Müşteri Bazlı Özet Raporu (Client-side Grouping)
  Future<List<Map<String, dynamic>>> getCustomerSummary() async {
    final calculations = await getCalculations();
    
    final Map<String, Map<String, dynamic>> summary = {};

    for (var calc in calculations) {
      if (!summary.containsKey(calc.customerName)) {
        summary[calc.customerName] = {
          'customer_name': calc.customerName,
          'total_count': 0,
          'total_amount': 0.0,
          'last_order_date': calc.createdAt,
        };
      }
      
      summary[calc.customerName]!['total_count'] += 1;
      summary[calc.customerName]!['total_amount'] += calc.totalPrice;
      
      // En son sipariş tarihini güncelle
      final lastDate = summary[calc.customerName]!['last_order_date'] as DateTime;
      if (calc.createdAt.isAfter(lastDate)) {
        summary[calc.customerName]!['last_order_date'] = calc.createdAt;
      }
    }

    return summary.values.toList();
  }
}

final mtulRepositoryProvider = Provider<MtulRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return MtulRepository(supabase);
});
