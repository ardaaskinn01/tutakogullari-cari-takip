import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/services/supabase_service.dart';

final allCustomerNamesProvider = FutureProvider<List<String>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  
  // 1. Fetch from mtul_calculations
  final mtulData = await supabase
      .from('mtul_calculations')
      .select('customer_name');
  
  // 2. Fetch from glass_calculations
  final glassData = await supabase
      .from('glass_calculations')
      .select('customer_name');
      
  // 3. Fetch from cari_accounts
  final cariData = await supabase
      .from('cari_accounts')
      .select('full_name');

  final Set<String> names = {};
  
  for (var row in mtulData) {
    names.add(row['customer_name'] as String);
  }
  
  for (var row in glassData) {
    names.add(row['customer_name'] as String);
  }
  
  for (var row in cariData) {
    names.add(row['full_name'] as String);
  }
  
  return names.toList()..sort();
});
