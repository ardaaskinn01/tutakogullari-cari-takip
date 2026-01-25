import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/cari_account.dart';
import '../../../models/cari_transaction.dart';
import '../../../models/transaction.dart'; // TransactionType (Sadece helper olarak, enum PaymentMethod için)
import '../../dashboard/repositories/cari_repository.dart';

// --- Providers ---

// Tüm cari hesapları getiren provider
final cariAccountsProvider = FutureProvider<List<CariAccount>>((ref) async {
  final repository = ref.watch(cariRepositoryProvider);
  return repository.getAccounts();
});

class CariAlacaklarScreen extends ConsumerWidget {
  const CariAlacaklarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(cariAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Alacaklar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.adminDashboardRoute),
        ),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.shade600),
                   const SizedBox(height: 16),
                   const Text('Kayıtlı alacak bulunamadı.'),
                   const SizedBox(height: 8),
                   const Text('Alacak eklemek için (+) butonunu kullanın.'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      account.fullName[0].toUpperCase(),
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    account.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: account.phone != null ? Text(account.phone!) : null,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Güncel Borç',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        Helpers.formatCurrency(account.currentBalance),
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: account.currentBalance > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Detay sayfasına git
                    context.push('${AppConstants.cariAccountDetailRoute}/${account.id}');
                  },
                ),
              ).animate().fadeIn(delay: (50 * index).ms).slideX();
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Tahsilat Ekle Butonu (Yeşil)
          FloatingActionButton.extended(
            heroTag: 'tahsilatBtn',
            onPressed: () => _showAddTahsilatDialog(context, ref),
            icon: const Icon(Icons.download),
            label: const Text('Tahsilat Ekle'),
            backgroundColor: Colors.green.shade700,
          ),
          const SizedBox(height: 16),
          // Alacak Ekle Butonu (Kırmızı)
          FloatingActionButton.extended(
            heroTag: 'alacakBtn',
            onPressed: () => _showAddAlacakDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Alacak Ekle'),
            backgroundColor: Colors.red.shade700,
          ),
        ],
      ),
    );
  }

  void _showAddAlacakDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const AddAlacakDialog(),
    );
  }

  void _showAddTahsilatDialog(BuildContext context, WidgetRef ref) {
    // Hesaplar yüklü mü kontrol et
    final accounts = ref.read(cariAccountsProvider).value;
    if (accounts == null || accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tahsilat yapmak için önce kayıtlı bir borçlu olmalıdır.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddTahsilatDialog(accounts: accounts),
    );
  }
}

// --- ALACAK EKLEME DİYALOGU (Mevcut) ---
class AddAlacakDialog extends ConsumerStatefulWidget {
  const AddAlacakDialog({super.key});

  @override
  ConsumerState<AddAlacakDialog> createState() => _AddAlacakDialogState();
}

class _AddAlacakDialogState extends ConsumerState<AddAlacakDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final repository = ref.read(cariRepositoryProvider);
      
      final accountId = await repository.addAccount(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        initialBalance: 0, 
      );

      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      if (amount > 0) {
        final tx = CariTransaction(
          id: '',
          accountId: accountId,
          type: CariTransactionType.debt,
          amount: amount,
          description: _descController.text.isEmpty ? 'Açılış Bakiyesi' : _descController.text,
          createdAt: DateTime.now(),
        );
        await repository.addTransaction(tx);
      }

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(cariAccountsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Alacak kaydı başarıyla oluşturuldu'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Alacak Ekle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Kişi Adı Soyadı', prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'İsim gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon No (Opsiyonel)', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Alacak Miktarı', prefixText: '₺ '),
                validator: (v) => v!.isEmpty ? 'Tutar gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Not / Açıklama', hintText: 'Örn: Ocak ayı borcu'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('İPTAL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('KAYDET'),
        ),
      ],
    );
  }
}

// --- TAHSİLAT EKLEME DİYALOGU (Yeni) ---
class AddTahsilatDialog extends ConsumerStatefulWidget {
  final List<CariAccount> accounts;

  const AddTahsilatDialog({super.key, required this.accounts});

  @override
  ConsumerState<AddTahsilatDialog> createState() => _AddTahsilatDialogState();
}

class _AddTahsilatDialogState extends ConsumerState<AddTahsilatDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _selectedAccountId;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // İlk kişiyi varsayılan seç
    if (widget.accounts.isNotEmpty) {
      _selectedAccountId = widget.accounts.first.id;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) return;
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(cariRepositoryProvider);
      
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      
      final tx = CariTransaction(
        id: '',
        accountId: _selectedAccountId!,
        type: CariTransactionType.collection, // Tahsilat
        amount: amount,
        paymentMethod: _selectedPaymentMethod, // Nakit/Kart/Çek
        description: _descController.text.isEmpty ? 'Tahsilat' : _descController.text,
        createdAt: DateTime.now(),
      );
      
      await repository.addTransaction(tx);

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(cariAccountsProvider); // Listeyi yenile
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Tahsilat başarıyla kaydedildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dropdown için kişileri mapleyelim
    final accountItems = widget.accounts.map((acc) {
      return DropdownMenuItem(
        value: acc.id,
        child: Text('${acc.fullName} (${Helpers.formatCurrency(acc.currentBalance)})'),
      );
    }).toList();

    return AlertDialog(
      title: const Text('Tahsilat Ekle', style: TextStyle(color: Colors.green)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kişi Seçimi
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                items: accountItems,
                onChanged: (val) => setState(() => _selectedAccountId = val),
                decoration: const InputDecoration(labelText: 'Kişi Seçin', prefixIcon: Icon(Icons.person)),
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              
              // Ödeme Yöntemi
              DropdownButtonFormField<PaymentMethod>(
                 value: _selectedPaymentMethod,
                 decoration: const InputDecoration(labelText: 'Ödeme Yöntemi', prefixIcon: Icon(Icons.payment)),
                 items: [
                   DropdownMenuItem(value: PaymentMethod.cash, child: const Text('Nakit')),
                   DropdownMenuItem(value: PaymentMethod.creditCard, child: const Text('Kredi Kartı')),
                   DropdownMenuItem(value: PaymentMethod.checkNote, child: const Text('Çek / Senet')),
                 ],
                 onChanged: (val) {
                   if (val != null) setState(() => _selectedPaymentMethod = val);
                 },
               ),
              const SizedBox(height: 16),

              // Tutar
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tahsilat Tutarı', prefixText: '₺ '),
                validator: (v) => v!.isEmpty ? 'Tutar gerekli' : null,
              ),
              const SizedBox(height: 16),
              
              // Açıklama
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Açıklama', hintText: 'Örn: Elden alındı'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('İPTAL')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('KAYDET'),
        ),
      ],
    );
  }
}
