import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/glass_calculation.dart';
import '../../auth/services/supabase_service.dart';

class GlassRepository {
  final SupabaseClient _supabase;

  GlassRepository(this._supabase);

  // 1. Hesaplama Kaydet
  Future<void> saveCalculation(GlassCalculation calculation) async {
    final data = calculation.toJson();
    data.remove('id'); // ID otomatik oluşacak
    
    await _supabase.from('glass_calculations').insert(data);
  }

  // 2. Tüm Hesaplamaları Getir (Tarihe göre sıralı)
  Future<List<GlassCalculation>> getCalculations() async {
    final List<dynamic> data = await _supabase
        .from('glass_calculations')
        .select()
        .order('created_at', ascending: false);

    return data.map((json) => GlassCalculation.fromJson(json)).toList();
  }

  // 3. Müşteri Bazlı Özet Raporu (Client-side Grouping)
  // SQL'de GROUP BY yapmak yerine esneklik için tüm veriyi çekip burada grupluyoruz.
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

final glassRepositoryProvider = Provider<GlassRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return GlassRepository(supabase);
});
