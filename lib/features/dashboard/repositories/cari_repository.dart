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
    txData.remove('id'); // ID otomatik oluşacak
    
    await _supabase.from('cari_transactions').insert(txData);
    await _recalculateAccountBalance(transaction.accountId);
  }

  // 5. İşlemi Güncelle
  Future<void> updateTransaction(CariTransaction transaction) async {
    final txData = transaction.toJson();
    final String id = txData.remove('id'); // update için ID lazım ama gövdede olmasın

    await _supabase.from('cari_transactions').update(txData).eq('id', id);
    await _recalculateAccountBalance(transaction.accountId);
  }

  // 6. İşlemi Sil
  Future<void> deleteTransaction(String transactionId, String accountId) async {
    await _supabase.from('cari_transactions').delete().eq('id', transactionId);
    await _recalculateAccountBalance(accountId);
  }

  // 7. Bir Hesabın İşlem Geçmişini Getir (Ekstre)
  Future<List<CariTransaction>> getAccountTransactions(String accountId) async {
    final List<dynamic> data = await _supabase
        .from('cari_transactions')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false); // En yeniden eskiye

    return data.map((json) => CariTransaction.fromJson(json)).toList();
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
