import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_providers.dart';

final allCustomerNamesProvider = FutureProvider<List<String>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  
  final mtulSnap = await firestore.collection('mtul_calculations').get();
  final glassSnap = await firestore.collection('glass_calculations').get();
  final cariSnap = await firestore.collection('cari_accounts').get();

  final Set<String> names = {};
  
  for (var doc in mtulSnap.docs) {
    final data = doc.data();
    if (data.containsKey('customer_name') && data['customer_name'] != null) {
      names.add(data['customer_name'] as String);
    }
  }
  
  for (var doc in glassSnap.docs) {
    final data = doc.data();
    if (data.containsKey('customer_name') && data['customer_name'] != null) {
      names.add(data['customer_name'] as String);
    }
  }
  
  for (var doc in cariSnap.docs) {
    final data = doc.data();
    if (data.containsKey('full_name') && data['full_name'] != null) {
      names.add(data['full_name'] as String);
    }
  }
  
  return names.toList()..sort();
});
