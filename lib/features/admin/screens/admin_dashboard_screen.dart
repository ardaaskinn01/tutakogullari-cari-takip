import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/helpers.dart';
import '../../../models/transaction.dart' as model;
import '../../auth/services/auth_service.dart';
import '../../dashboard/repositories/transaction_repository.dart';
import '../../dashboard/widgets/add_transaction_modal.dart';

// Providers for dashboard state
final balanceProvider = FutureProvider<Map<String, double>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getBalance();
});

final allTransactionsProvider = FutureProvider<List<model.Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  final user = ref.watch(currentUserProvider).value;
  final isAdmin = await ref.watch(isAdminProvider.future);
  
  if (user == null) return [];
  return repository.getTransactions(userId: user.id, isAdmin: isAdmin);
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(balanceProvider);
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      // --- DRAWER (YAN MENÜ) ---
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              accountName: userProfileAsync.when(
                data: (profile) => Text(
                  profile?.displayName ?? 'Yönetici',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                loading: () => const Text('Yükleniyor...'),
                error: (_, __) => const Text('Yönetici'),
              ),
              accountEmail: const Text('Yönetim Paneli'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.security, color: Colors.blue),
              ),
            ),
            
            // Menu Items
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Ana Panel'),
              onTap: () => Navigator.pop(context), // Zaten buradayız
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: const Text('Kasa Defteri'),
              onTap: () {
                Navigator.pop(context); // Drawer kapat
                context.push(AppConstants.kasaDefteriRoute);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.orange), // Yeni Modül
              title: const Text('Cari Alacaklar'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.cariHomeRoute); // Birazdan rotayı ekleyeceğiz
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Personel Listesi'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.staffListRoute);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calculate_outlined, color: Colors.blueAccent),
              title: const Text('Metretül Hesaplama'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.mtulCalcRoute);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined, color: Colors.indigoAccent),
              title: const Text('Cam m² Hesabı'),
              onTap: () {
                Navigator.pop(context);
                context.push(AppConstants.glassCalcRoute);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
              onTap: () async {
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      // --- APP BAR ---
      appBar: AppBar(
        title: const Text('Yönetici'),
        // leading: Otomatik olarak hamburger menü ikonu gelecek
        actions: [
          // Hızlı Personel Ekleme (Burada kalabilir)
          IconButton(
            onPressed: () => _showAddStaffDialog(context),
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Personel Ekle',
            color: Colors.white,
          ),
        ],
      ),

      // --- BODY ---
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(balanceProvider);
          ref.invalidate(allTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hoşgeldin Mesajı
                userProfileAsync.when(
                  data: (profile) => Text(
                    'Hoşgeldiniz, ${profile?.displayName ?? "Admin"}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  loading: () => const SizedBox(height: 28),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 24),

                // Özet Kartları
                balanceAsync.when(
                  data: (balance) => _buildSummaryCards(context, balance),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('Hata: $err'),
                ),

                const SizedBox(height: 32),

                // Son İşlemler Başlığı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Son İşlemler',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push(AppConstants.kasaDefteriRoute),
                      child: const Text('Tümünü Gör'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // İşlem Listesi
                transactionsAsync.when(
                  data: (transactions) => _buildTransactionList(context, transactions),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Hata oluştu: $err')),
                ),
                
                // Bottom padding for FAB
                const SizedBox(height: 80), 
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionModal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('İşlem Ekle'),
      ),
    );
  }

  // ... (Geri kalan widget metodları _buildSummaryCards, _buildTransactionList, dialogs aynı şekilde devam ediyor)
  
  Widget _buildSummaryCards(BuildContext context, Map<String, double> balance) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Bu Ay Nakit Girişi',
                amount: balance['total_income'] ?? 0, // Güncellendi
                icon: Icons.arrow_downward,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Bu Ay Nakit Çıkışı',
                amount: balance['total_expense'] ?? 0, // Güncellendi
                icon: Icons.arrow_upward,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Net Kasa Durumu',
          amount: balance['net_balance'] ?? 0, // Güncellendi
          icon: Icons.account_balance_wallet,
          color: (balance['net_balance'] ?? 0) >= 0 ? Colors.blue : Colors.orange,
          isLarge: true,
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  // --- Transaction List Builder ---
  Widget _buildTransactionList(BuildContext context, List<model.Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.history, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Henüz işlem bulunmuyor'),
          ],
        ),
      );
    }

    // Sadece ilk 5 işlemi göster (Dashboard olduğu için)
    final displayList = transactions.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final transaction = displayList[index];
        final isIncome = transaction.isIncome;
        
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
                size: 20,
              ),
            ),
            title: Text(
              transaction.description,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Helpers.formatDate(transaction.createdAt)} • ${transaction.paymentMethod.displayName}',
                   style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Text(
              isIncome 
                ? '+${Helpers.formatCurrency(transaction.amount)}' 
                : '-${Helpers.formatCurrency(transaction.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
          ),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
      },
    );
  }

  // --- Dialogs ---
  void _showAddStaffDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddStaffDialog(),
    );
  }

  void _showAddTransactionModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionModal(
        onSuccess: () {
          ref.invalidate(allTransactionsProvider);
          ref.invalidate(balanceProvider);
        },
      ),
    );
  }
}

// ... _SummaryCard ve AddStaffDialog sınıfları aynı, kod tekrarını önlemek için buraya yazmıyorum, 
// ancak dosya içeriği tamamen değiştiği için onları da eklemem gerekir mantıken. 
// Aşağıya mevcut _SummaryCard ve AddStaffDialog'u da ekliyorum.

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isLarge;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, // Tema rengi
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          SizedBox(height: isLarge ? 12 : 8),
          Text(
            Helpers.formatCurrency(amount),
            style: TextStyle(
              fontSize: isLarge ? 32 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class AddStaffDialog extends ConsumerStatefulWidget {
  const AddStaffDialog({super.key});

  @override
  ConsumerState<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).registerStaff(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Personel başarıyla oluşturuldu!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors for dialog
    final bgColor = Theme.of(context).cardTheme.color;

    return AlertDialog(
      backgroundColor: bgColor,
      title: const Text('Personel Ekle', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Ad soyad gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v!.isEmpty ? 'Kullanıcı adı gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => v!.length < 6 ? 'En az 6 karakter' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Ekle'),
        ),
      ],
    );
  }
}
