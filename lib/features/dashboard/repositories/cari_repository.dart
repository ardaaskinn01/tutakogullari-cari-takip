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


  // --- Cari İşlem (Transaksiyon) İşlemleri ---

  // 4. İşlem Ekle (Borç veya Tahsilat) ve Bakiyeyi Güncelle
  Future<void> addTransaction(CariTransaction transaction) async {
    // A. İşlemi Kaydet
    final txData = transaction.toJson();
    txData.remove('id'); // ID otomatik oluşacak
    
    await _supabase.from('cari_transactions').insert(txData);

    // B. Cari Hesap Bakiyesini Güncelle
    // Mantık: Borç ise bakiye artar, Tahsilat ise bakiye azalır.
    
    // Önce mevcut bakiyeyi çekelim (Hata riskine karşı en güncel veriyi almak iyidir)
    final account = await getAccountById(transaction.accountId);
    double newBalance = account.currentBalance;

    if (transaction.type == CariTransactionType.debt) {
      newBalance += transaction.amount;
    } else {
      newBalance -= transaction.amount;
    }

    // Yeni bakiyeyi güncelle
    await _supabase.from('cari_accounts').update({
      'current_balance': newBalance
    }).eq('id', transaction.accountId);
  }

  // 5. Bir Hesabın İşlem Geçmişini Getir (Ekstre)
  Future<List<CariTransaction>> getAccountTransactions(String accountId) async {
    final List<dynamic> data = await _supabase
        .from('cari_transactions')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false); // En yeniden eskiye

    return data.map((json) => CariTransaction.fromJson(json)).toList();
  }
}

// --- Providers ---

final cariRepositoryProvider = Provider<CariRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return CariRepository(supabase);
});
