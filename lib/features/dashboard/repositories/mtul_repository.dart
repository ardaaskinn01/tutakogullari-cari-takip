import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/mtul_price.dart';
import '../../../models/mtul_calculation.dart';
import '../../../core/services/firebase_providers.dart';

class MtulRepository {
  final FirebaseFirestore _firestore;

  MtulRepository(this._firestore);

  Future<List<MtulPrice>> getPrices(String category) async {
    final snapshot = await _firestore
        .collection('mtul_prices')
        .where('category', isEqualTo: category)
        .get();

    final prices = snapshot.docs.map((doc) {
      final json = doc.data();
      json['id'] = doc.id;
      if (json['created_at'] is Timestamp) {
         json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
      } else if (json['created_at'] == null) {
         json['created_at'] = DateTime.now().toIso8601String();
      }
      return MtulPrice.fromJson(json);
    }).toList();

    // Local sort to avoid composite index
    prices.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return prices;
  }

  Future<void> updatePrice(String id, double newPrice) async {
    await _firestore
        .collection('mtul_prices')
        .doc(id)
        .update({'unit_price': newPrice});
  }

  Future<void> seedDefaultPrices(String category, List<String> components) async {
    final snapshot = await _firestore
        .collection('mtul_prices')
        .where('category', isEqualTo: category)
        .get();
    
    final existingPrices = snapshot.docs.map((doc) {
       final json = doc.data();
       json['id'] = doc.id;
       if (json['created_at'] is Timestamp) {
         json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
       } else if (json['created_at'] == null) {
         json['created_at'] = DateTime.now().toIso8601String();
       }
       return MtulPrice.fromJson(json);
    }).toList();
    
    final Map<String, MtulPrice> existingMap = {
      for (var p in existingPrices) p.componentName.toLowerCase(): p
    };

    final List<String> lowercaseDefaults = components.map((e) => e.toLowerCase()).toList();
    for (var existing in existingPrices) {
      if (!lowercaseDefaults.contains(existing.componentName.toLowerCase())) {
        await _firestore.collection('mtul_prices').doc(existing.id).delete();
      }
    }

    for (int i = 0; i < components.length; i++) {
      final targetName = components[i];
      final lowerName = targetName.toLowerCase();
      
      if (existingMap.containsKey(lowerName)) {
        final existing = existingMap[lowerName]!;
        await _firestore.collection('mtul_prices').doc(existing.id).update({
          'component_name': targetName,
          'sort_order': i,
        });
      } else {
        await _firestore.collection('mtul_prices').add({
          'category': category,
          'component_name': targetName,
          'unit_price': 0.0,
          'sort_order': i,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }


  Future<void> saveCalculation({
    required String customerName,
    required double totalPrice,
    required List<Map<String, dynamic>> items,
  }) async {
    final docRef = await _firestore.collection('mtul_calculations').add({
      'customer_name': customerName,
      'total_price': totalPrice,
      'created_at': FieldValue.serverTimestamp(),
    });

    final calculationId = docRef.id;

    WriteBatch batch = _firestore.batch();
    for(var item in items) {
       final itemRef = _firestore.collection('mtul_calculation_items').doc();
       final itemData = {
         'calculation_id': calculationId,
         ...item,
       };
       batch.set(itemRef, itemData);
    }
    await batch.commit();
  }

  Future<List<MtulCalculation>> getCalculations() async {
    final snapshot = await _firestore
        .collection('mtul_calculations')
        .get();

    final calculations = snapshot.docs.map((doc) {
       final json = doc.data();
       json['id'] = doc.id;
       if (json['created_at'] is Timestamp) {
         json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
       } else if (json['created_at'] == null) {
         json['created_at'] = DateTime.now().toIso8601String();
       }
       return MtulCalculation.fromJson(json);
    }).toList();

    // Local sort
    calculations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return calculations;
  }

  Future<MtulCalculation> getCalculationDetail(String id) async {
    final calcDoc = await _firestore.collection('mtul_calculations').doc(id).get();
    if (!calcDoc.exists) {
      throw Exception('Hesaplama bulunamadı');
    }

    final calcData = calcDoc.data()!;
    calcData['id'] = calcDoc.id;
    if (calcData['created_at'] is Timestamp) {
       calcData['created_at'] = (calcData['created_at'] as Timestamp).toDate().toIso8601String();
    } else if (calcData['created_at'] == null) {
       calcData['created_at'] = DateTime.now().toIso8601String();
    }

    final itemsSnapshot = await _firestore
       .collection('mtul_calculation_items')
       .where('calculation_id', isEqualTo: id)
       .get();

    final itemsList = itemsSnapshot.docs.map((doc) {
       final d = doc.data();
       d['id'] = doc.id;
       return d;
    }).toList();

    calcData['mtul_calculation_items'] = itemsList;

    return MtulCalculation.fromJson(calcData);
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
          'last_order_date': calc.createdAt,
        };
      }
      
      summary[calc.customerName]!['total_count'] += 1;
      summary[calc.customerName]!['total_amount'] += calc.totalPrice;
      
      final lastDate = summary[calc.customerName]!['last_order_date'] as DateTime;
      if (calc.createdAt.isAfter(lastDate)) {
        summary[calc.customerName]!['last_order_date'] = calc.createdAt;
      }
    }

    return summary.values.toList();
  }

  Future<void> deleteCalculations(List<String> ids) async {
    WriteBatch batch = _firestore.batch();
    for (var id in ids) {
       batch.delete(_firestore.collection('mtul_calculations').doc(id));
       final itemsSnap = await _firestore.collection('mtul_calculation_items').where('calculation_id', isEqualTo: id).get();
       for(var doc in itemsSnap.docs) {
          batch.delete(doc.reference);
       }
    }
    await batch.commit();
  }
}

final mtulRepositoryProvider = Provider<MtulRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return MtulRepository(firestore);
});
