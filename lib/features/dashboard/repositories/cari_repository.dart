import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/cari_account.dart';
import '../../../models/cari_transaction.dart';
import '../../auth/services/supabase_service.dart';

class CariRepository {
  final SupabaseClient _supabase;

  CariRepository(this._supabase);

  // --- Cari Hesap (Kişi) İşlemleri ---

  // 1. Yeni Cari Hesap Oluştur
  Future<String> addAccount({required String fullName, String? phone, double initialBalance = 0}) async {
    final response = await _supabase.from('cari_accounts').insert({
      'full_name': fullName,
      'phone': phone,
      'current_balance': initialBalance,
    }).select().single();
    
    return response['id'] as String;
  }

  // 2. Tüm Cari Hesapları Listele (Bakiyeleriyle Birlikte)
  Future<List<CariAccount>> getAccounts() async {
    final List<dynamic> data = await _supabase
        .from('cari_accounts')
        .select()
        .order('full_name', ascending: true); // İsme göre alfabetik

    return data.map((json) => CariAccount.fromJson(json)).toList();
  }

  // 3. Tek Bir Hesabı Getir
  Future<CariAccount> getAccountById(String accountId) async {
    final response = await _supabase
        .from('cari_accounts')
        .select()
        .eq('id', accountId)
        .single();
    
    return CariAccount.fromJson(response);
  }

  // 4. Hesabı Güncelle
  Future<void> updateAccount(String accountId, {required String fullName, String? phone}) async {
    await _supabase.from('cari_accounts').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', accountId);
  }

  // 5. Hesabı Sil
  Future<void> deleteAccount(String accountId) async {
    // RLS ve Foreign Key kısıtlamalarına dikkat (Transactions otomatik silinebilir cascade ise)
    await _supabase.from('cari_accounts').delete().eq('id', accountId);
  }


  // --- Cari İşlem (Transaksiyon) İşlemleri ---

  // 4. İşlem Ekle (Borç veya Tahsilat) ve Bakiyeyi Güncelle
  Future<void> addTransaction(CariTransaction transaction) async {
    // A. İşlemi Kaydet
    final txData = transaction.toJson();
    final String? originalId = txData.remove('id');
    
    final response = await _supabase.from('cari_transactions').insert(txData).select().single();
    final String newId = response['id'];
    
    // B. Eğer tahsilat ise, genel kasaya (gelir olarak) işle
    if (transaction.isCollection) {
      final account = await getAccountById(transaction.accountId);
      await _supabase.from('transactions').insert({
        'type': 'income',
        'amount': transaction.amount,
        'description': '[CT#$newId] Tahsilat: ${account.fullName}${transaction.description != null ? ' - ${transaction.description}' : ''}',
        'payment_method': transaction.paymentMethod?.value ?? 'cash',
        'created_by': transaction.createdBy,
        'created_at': transaction.createdAt.toIso8601String(),
      });
    }
    
    await _recalculateAccountBalance(transaction.accountId);
  }

  // 5. İşlemi Güncelle
  Future<void> updateTransaction(CariTransaction transaction) async {
    final txData = transaction.toJson();
    final String id = txData.remove('id'); 

    // Önce eski halini kontrol et (sync için lazım olabilir)
    // Ancak basitlik adına doğrudan update/delete deneyeceğiz
    
    await _supabase.from('cari_transactions').update(txData).eq('id', id);
    
    // Genel işlem kaydını güncelle veya oluştur (Eğer tahsilat ise)
    final account = await getAccountById(transaction.accountId);
    final String tag = '[CT#$id]';
    
    if (transaction.isCollection) {
      // Önce var mı diye bak (Daha önce borç olup şimdi tahsilata çevrilmiş olabilir)
      final existing = await _supabase.from('transactions')
          .select('id')
          .ilike('description', '$tag%');
      
      if (existing.isNotEmpty) {
        // Varsa güncelle
        await _supabase.from('transactions').update({
          'amount': transaction.amount,
          'description': '$tag Tahsilat: ${account.fullName}${transaction.description != null ? ' - ${transaction.description}' : ''}',
          'payment_method': transaction.paymentMethod?.value ?? 'cash',
        }).eq('id', existing.first['id']);
      } else {
        // Yoksa yeni oluştur
        await _supabase.from('transactions').insert({
          'type': 'income',
          'amount': transaction.amount,
          'description': '$tag Tahsilat: ${account.fullName}${transaction.description != null ? ' - ${transaction.description}' : ''}',
          'payment_method': transaction.paymentMethod?.value ?? 'cash',
          'created_by': transaction.createdBy,
          'created_at': transaction.createdAt.toIso8601String(),
        });
      }
    } else {
      // Eğer artık tahsilat değilse (borca çevrildiyse) varsa sildirelim
      await _supabase.from('transactions')
          .delete()
          .ilike('description', '[CT#$id]%');
    }

    await _recalculateAccountBalance(transaction.accountId);
  }

  // 6. İşlemi Sil
  Future<void> deleteTransaction(String transactionId, String accountId) async {
    // Genel işlem kaydını da sil
    await _supabase.from('transactions')
        .delete()
        .ilike('description', '[CT#$transactionId]%');
        
    await _supabase.from('cari_transactions').delete().eq('id', transactionId);
    await _recalculateAccountBalance(accountId);
  }

  // 7. Bir Hesabın İşlem Geçmişini Getir (Ekstre)
  Future<List<CariTransaction>> getAccountTransactions(String accountId) async {
    // 1. İşlemleri çek
    final List<dynamic> data = await _supabase
        .from('cari_transactions')
        .select() // profiles join'ini kaldırdık çünkü FK ilişkisi yok
        .eq('account_id', accountId)
        .order('created_at', ascending: false);

    final transactions = data.map((json) => CariTransaction.fromJson(json)).toList();

    // 2. İşlemleri yapanların ID'lerini topla
    final userIds = transactions.map((t) => t.createdBy).where((id) => id.isNotEmpty).toSet().toList();
    
    if (userIds.isEmpty) return transactions;

    // 3. Bu ID'lere sahip profilleri çek
    final List<dynamic> profileData = await _supabase
        .from('profiles')
        .select('id, full_name, email')
        .filter('id', 'in', userIds);

    // 4. Profil bilgilerini bir Map'e koy (Hızlı erişim için)
    final profileMap = {
      for (var p in profileData) 
        p['id'] as String: p['full_name'] as String? ?? p['email'] as String?
    };

    // 5. İşlemlere isimleri ata (copyWith ile)
    return transactions.map((t) {
      if (profileMap.containsKey(t.createdBy)) {
        return t.copyWith(createdByName: profileMap[t.createdBy]);
      }
      return t;
    }).toList();
  }

  // Hesap Bakiyesini Tüm İşlemlere Göre Yeniden Hesapla
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

    await _supabase.from('cari_accounts').update({
      'current_balance': balance
    }).eq('id', accountId);
  }
}

// --- Providers ---

final cariRepositoryProvider = Provider<CariRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CariRepository(supabase);
});
