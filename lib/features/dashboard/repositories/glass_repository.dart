import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/glass_calculation.dart';
import '../../../core/services/firebase_providers.dart';

class GlassRepository {
  final FirebaseFirestore _firestore;

  GlassRepository(this._firestore);

  Future<void> saveCalculation(GlassCalculation calculation) async {
    final data = calculation.toJson();
    data.remove('id');
    data['created_at'] = FieldValue.serverTimestamp();
    
    await _firestore.collection('glass_calculations').add(data);
  }

  Future<List<GlassCalculation>> getCalculations() async {
    final snapshot = await _firestore
        .collection('glass_calculations')
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final json = doc.data();
      json['id'] = doc.id;
      if (json['created_at'] is Timestamp) {
         json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
      } else if (json['created_at'] == null) {
         json['created_at'] = DateTime.now().toIso8601String();
      }
      return GlassCalculation.fromJson(json);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomerSummary() async {
    final calculations = await getCalculations();
    
    final Map<String, Map<String, dynamic>> summary = {};

    for (var calc in calculations) {
      if (!summary.containsKey(calc.customerName)) {
        summary[calc.customerName] = {
          'customer_name': calc.customerName,
          'total_count': 0,
          'total_amount': 0.0,
          'total_m2': 0.0,
          'last_order_date': calc.createdAt,
        };
      }
      
      summary[calc.customerName]!['total_count'] += 1;
      summary[calc.customerName]!['total_amount'] += calc.totalPrice;
      summary[calc.customerName]!['total_m2'] += calc.totalM2;
      
      final lastDate = summary[calc.customerName]!['last_order_date'] as DateTime;
      if (calc.createdAt.isAfter(lastDate)) {
        summary[calc.customerName]!['last_order_date'] = calc.createdAt;
      }
    }

    return summary.values.toList();
  }

  Future<void> deleteCalculations(List<String> ids) async {
    WriteBatch batch = _firestore.batch();
    for(var id in ids) {
       batch.delete(_firestore.collection('glass_calculations').doc(id));
    }
    await batch.commit();
  }
}

final glassRepositoryProvider = Provider<GlassRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return GlassRepository(firestore);
});
