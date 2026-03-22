import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/cari_account.dart';
import '../../../models/cari_transaction.dart';
import '../../../core/services/firebase_providers.dart';

class CariRepository {
  final FirebaseFirestore _firestore;

  CariRepository(this._firestore);

  // --- Cari Hesap (Kişi) İşlemleri ---

  Future<String> addAccount({required String fullName, String? phone, double initialBalance = 0}) async {
    final docRef = await _firestore.collection('cari_accounts').add({
      'full_name': fullName,
      'phone': phone,
      'current_balance': initialBalance,
      'created_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<List<CariAccount>> getAccounts() async {
    final snapshot = await _firestore
        .collection('cari_accounts')
        .get();

    final accounts = snapshot.docs.map((doc) {
      final json = doc.data();
      json['id'] = doc.id;
      if (json['created_at'] is Timestamp) json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
      if (json['created_at'] == null) json['created_at'] = DateTime.now().toIso8601String();
      return CariAccount.fromJson(json);
    }).toList();

    // Local sort
    accounts.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return accounts;
  }

  Future<CariAccount> getAccountById(String accountId) async {
    final doc = await _firestore.collection('cari_accounts').doc(accountId).get();
    final json = doc.data()!;
    json['id'] = doc.id;
    if (json['created_at'] is Timestamp) json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
    if (json['created_at'] == null) json['created_at'] = DateTime.now().toIso8601String();
    return CariAccount.fromJson(json);
  }

  Future<void> updateAccount(String accountId, {required String fullName, String? phone}) async {
    await _firestore.collection('cari_accounts').doc(accountId).update({
      'full_name': fullName,
      'phone': phone,
    });
  }

  Future<void> deleteAccount(String accountId) async {
    final txs = await _firestore.collection('cari_transactions').where('account_id', isEqualTo: accountId).get();
    WriteBatch batch = _firestore.batch();
    for(var doc in txs.docs) {
      batch.delete(doc.reference);
      final generalQuery = await _firestore.collection('transactions')
          .where('description', isGreaterThanOrEqualTo: '[CT#${doc.id}]')
          .where('description', isLessThan: '[CT#${doc.id}]\uf8ff')
          .get();
      for(var gDoc in generalQuery.docs) {
          batch.delete(gDoc.reference);
      }
    }
    batch.delete(_firestore.collection('cari_accounts').doc(accountId));
    await batch.commit();
  }

  // --- Cari İşlem (Transaksiyon) İşlemleri ---

  Future<void> addTransaction(CariTransaction transaction) async {
    final txData = transaction.toJson();
    txData.remove('id');
    txData['created_at'] = FieldValue.serverTimestamp();
    
    final docRef = await _firestore.collection('cari_transactions').add(txData);
    final String newId = docRef.id;
    
    if (transaction.isCollection) {
      final account = await getAccountById(transaction.accountId);
      await _firestore.collection('transactions').add({
        'type': 'income',
        'amount': transaction.amount,
        'description': '[CT#$newId] Tahsilat: ${account.fullName}${transaction.description != null ? ' - ${transaction.description}' : ''}',
        'payment_method': transaction.paymentMethod?.value ?? 'cash',
        'created_by': transaction.createdBy,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    
    await _recalculateAccountBalance(transaction.accountId);
  }

  Future<void> updateTransaction(CariTransaction transaction) async {
    final txData = transaction.toJson();
    final String id = txData.remove('id'); 
    txData.remove('created_at');
    
    await _firestore.collection('cari_transactions').doc(id).update(txData);
    
    final account = await getAccountById(transaction.accountId);
    final String tag = '[CT#$id]';
    
    if (transaction.isCollection) {
      final generalQuery = await _firestore.collection('transactions')
          .where('description', isGreaterThanOrEqualTo: tag)
          .where('description', isLessThan: '$tag\uf8ff')
          .get();
          
      if (generalQuery.docs.isNotEmpty) {
        await generalQuery.docs.first.reference.update({
          'amount': transaction.amount,
          'description': '$tag Tahsilat: ${account.fullName}${transaction.description != null ? ' - ${transaction.description}' : ''}',
          'payment_method': transaction.paymentMethod?.value ?? 'cash',
        });
      } else {
        await _firestore.collection('transactions').add({
          'type': 'income',
          'amount': transaction.amount,
          'description': '$tag Tahsilat: ${account.fullName}${transaction.description != null ? ' - ${transaction.description}' : ''}',
          'payment_method': transaction.paymentMethod?.value ?? 'cash',
          'created_by': transaction.createdBy,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    } else {
      final generalQuery = await _firestore.collection('transactions')
          .where('description', isGreaterThanOrEqualTo: tag)
          .where('description', isLessThan: '$tag\uf8ff')
          .get();
      for(var doc in generalQuery.docs) {
          await doc.reference.delete();
      }
    }

    await _recalculateAccountBalance(transaction.accountId);
  }

  Future<void> deleteTransaction(String transactionId, String accountId) async {
    final String tag = '[CT#$transactionId]';
    final generalQuery = await _firestore.collection('transactions')
        .where('description', isGreaterThanOrEqualTo: tag)
        .where('description', isLessThan: '$tag\uf8ff')
        .get();
    for(var doc in generalQuery.docs) {
        await doc.reference.delete();
    }
        
    await _firestore.collection('cari_transactions').doc(transactionId).delete();
    await _recalculateAccountBalance(accountId);
  }

  Future<List<CariTransaction>> getAccountTransactions(String accountId) async {
    final snapshot = await _firestore
        .collection('cari_transactions')
        .where('account_id', isEqualTo: accountId)
        .get();

    final transactions = snapshot.docs.map((doc) {
      final json = doc.data();
      json['id'] = doc.id;
      if (json['created_at'] is Timestamp) json['created_at'] = (json['created_at'] as Timestamp).toDate().toIso8601String();
      if (json['created_at'] == null) json['created_at'] = DateTime.now().toIso8601String();
      return CariTransaction.fromJson(json);
    }).toList();

    // Local sort
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final userIds = transactions.map((t) => t.createdBy).where((id) => id.isNotEmpty).toSet().toList();
    if (userIds.isEmpty) return transactions;

    final profileMap = <String, String>{};
    for(var uid in userIds) {
       final pDoc = await _firestore.collection('profiles').doc(uid).get();
       final data = pDoc.data();
       if (data != null) {
          profileMap[uid] = (data['full_name'] as String?) ?? (data['email'] as String?) ?? 'Bilinmeyen';
       }
    }

    return transactions.map((t) {
      if (profileMap.containsKey(t.createdBy)) {
        return t.copyWith(createdByName: profileMap[t.createdBy]);
      }
      return t;
    }).toList();
  }

  Future<void> _recalculateAccountBalance(String accountId) async {
    final transactions = await getAccountTransactions(accountId);
    double balance = 0;
    
    for (var tx in transactions) {
      if (tx.type == CariTransactionType.debt) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }

    await _firestore.collection('cari_accounts').doc(accountId).update({
      'current_balance': balance
    });
  }
}

// --- Providers ---
final cariRepositoryProvider = Provider<CariRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CariRepository(firestore);
});
