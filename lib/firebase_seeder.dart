import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> seedFirebaseCollections() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    debugPrint("Firebase koleksiyon tohumlama işlemi başlatılıyor...");

    // 1. mtul_prices verilerini ekle
    final pricesRef = firestore.collection('mtul_prices');
    final pricesSnapshot = await pricesRef.limit(1).get();
    if (pricesSnapshot.docs.isEmpty) {
      debugPrint("'mtul_prices' boş, varsayılan veriler ekleniyor...");
      await seedMtulItems();
    }

    // 2. Diğer koleksiyonlar için Dummy Dökümanları (Firebase Console'da görünmesi için)
    final collectionsToInit = [
      'profiles',
      'transactions',
      'cari_accounts',
      'cari_transactions',
      'glass_calculations',
      'mtul_calculations',
      'mtul_calculation_items'
    ];

    for (var col in collectionsToInit) {
      final docRef = firestore.collection(col).doc('DUMMY_SCHEMA_DOC');
      
      Map<String, dynamic> dummyData = {};
      switch (col) {
        case 'profiles':
          dummyData = {
            'email': 'dummy@example.com',
            'full_name': 'Dummy User',
            'role': 'admin',
            'created_at': FieldValue.serverTimestamp(),
          };
          break;
        case 'transactions':
          dummyData = {
            'amount': 0.0,
            'type': 'income',
            'payment_method': 'cash',
            'description': 'Dummy transaction',
            'created_by': 'dummy_uid',
            'created_at': FieldValue.serverTimestamp(),
          };
          break;
        case 'cari_accounts':
          dummyData = {
            'full_name': 'Dummy Cari',
            'phone': '05555555555',
            'current_balance': 0.0,
            'created_at': FieldValue.serverTimestamp(),
          };
          break;
        case 'cari_transactions':
          dummyData = {
            'account_id': 'dummy_account_id',
            'amount': 0.0,
            'type': 'debt',
            'payment_method': 'cash',
            'description': 'Dummy cari transaction',
            'created_by': 'dummy_uid',
            'created_at': FieldValue.serverTimestamp(),
          };
          break;
        case 'glass_calculations':
          dummyData = {
            'customer_name': 'Dummy Customer',
            'width': 100.0,
            'height': 100.0,
            'm2': 1.0,
            'quantity': 1,
            'total_m2': 1.0,
            'unit_price': 500.0,
            'total_price': 500.0,
            'created_at': FieldValue.serverTimestamp(),
          };
          break;
        case 'mtul_calculations':
          dummyData = {
            'customer_name': 'Dummy Customer',
            'total_price': 1000.0,
            'created_at': FieldValue.serverTimestamp(),
          };
          break;
        case 'mtul_calculation_items':
          dummyData = {
            'calculation_id': 'dummy_calc_id',
            'component_name': 'Kasa Profili',
            'quantity': 1,
            'unit_price': 100.0,
            'total_price': 100.0,
          };
          break;
      }
      await docRef.set(dummyData);
    }

    debugPrint("Firebase koleksiyon tohumlama tamamlandı!");
  } catch (e) {
    debugPrint("Firebase tohumlama hatası: $e");
  }
}

Future<void> seedMtulItems() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // Arayüzdeki kategori anahtarları (standard, gold_oak, anthracite, fly_screen)
  final Map<String, List<String>> categories = {
    'standard': [
      "60 Kasa Beyaz 1.6", "60 Kasa Beyaz 2.2", "70 Kasa Beyaz 1.6", "70 Kasa Beyaz 2.2",
      "Pencere Kanat 1.6", "Pencere Kanat 2.2", "Kapı Kanat 1.6", "Kapı Kanat 2.2",
      "70 Orta Kayıt 1.6", "70 Orta Kayıt 2.2", "60 Orta Kayıt 1.6", "60 Orta Kayıt 2.2",
      "Çift Cam Çıtası", "Tek Cam Çıtası", "Lambri", "U Kasa", "Mermer Afyon"
    ],
    'gold_oak': [
      "70 Kasa", "Pencere Kanat", "Kapı Kanat", "70 Orta Kayıt",
      "60 Orta Kayıt", "Çift Cam Çıtası", "Tek Cam Çıtası"
    ],
    'anthracite': [
      "70 Kasa", "Pencere Kanat", "Kapı Kanat", "70 Orta Kayıt",
      "60 Orta Kayıt", "Çift Cam Çıtası", "Tek Cam Çıtası"
    ],
    'fly_screen': [
      "Menteşeli Pencere Sineklik", "Menteşeli Kapı Sineklik",
      "Pileli Pencere Sineklik", "Pileli Kapı Sineklik"
    ]
  };

  try {
    debugPrint("MTUL Item tohumlama işlemi başlatılıyor...");
    final pricesRef = firestore.collection('mtul_prices');
    
    // Eski verileri temizle
    final existingSnapshot = await pricesRef.get();
    for (var doc in existingSnapshot.docs) {
      await doc.reference.delete();
    }

    for (var category in categories.entries) {
      final categoryName = category.key; 
      final items = category.value;
      for (int i = 0; i < items.length; i++) {
        await pricesRef.add({
          'category': categoryName,
          'component_name': items[i].trim(),
          'unit_price': 0.0,
          'sort_order': i,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }
    debugPrint("MTUL Item tohumlama tamamlandı!");
  } catch (e) {
    debugPrint("MTUL tohumlama hatası: $e");
  }
}
