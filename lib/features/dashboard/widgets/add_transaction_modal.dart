import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/transaction.dart';
import '../../auth/services/auth_service.dart';
import '../repositories/transaction_repository.dart';

class AddTransactionModal extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;
  final VoidCallback onSuccess;

  const AddTransactionModal({
    super.key, 
    this.initialTransaction,
    required this.onSuccess
  });

  @override
  ConsumerState<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends ConsumerState<AddTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  
  TransactionType _selectedType = TransactionType.income;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      _amountController.text = widget.initialTransaction!.amount.toString();
      _descController.text = widget.initialTransaction!.description;
      _selectedType = widget.initialTransaction!.type;
      _selectedPaymentMethod = widget.initialTransaction!.paymentMethod;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(transactionRepositoryProvider);
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('Kullanıcı oturumu bulunamadı');

      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      
      final transaction = Transaction(
        id: widget.initialTransaction?.id ?? '',
        type: _selectedType,
        paymentMethod: _selectedPaymentMethod,
        amount: amount,
        description: _descController.text,
        createdBy: widget.initialTransaction?.createdBy ?? user!.id,
        createdAt: widget.initialTransaction?.createdAt ?? DateTime.now(),
      );

      if (widget.initialTransaction != null && widget.initialTransaction!.id != null) {
        await repository.updateTransaction(widget.initialTransaction!.id!, transaction);
      } else {
        await repository.addTransaction(transaction);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(widget.initialTransaction != null 
               ? 'Kayıt güncellendi' 
               : '${_selectedType.displayName} başarıyla eklendi'), 
             backgroundColor: Colors.green
           ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Koyu tema uyumluluğu için renkler
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    final cardColor = Theme.of(context).cardTheme.color;

    return Container(
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: isDesktop ? BorderRadius.circular(20) : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: isDesktop ? 24 : MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialTransaction != null ? 'Kaydı Düzenle' : 'Yeni Kayıt Ekle',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // 1. İşlem Tipi Seçimi (Gelir / Gider)
            Text('İşlem Türü', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TransactionType>(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                     return Colors.white;
                  }
                  return Colors.grey.shade400;
                }),
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                side: WidgetStateProperty.all(BorderSide(color: Colors.grey.shade700)),
              ),
              segments: const [
                ButtonSegment(
                  value: TransactionType.income, 
                  label: Text('GELİR (Giriş)'),
                  icon: Icon(Icons.arrow_downward, color: Colors.green),
                ),
                ButtonSegment(
                  value: TransactionType.expense, 
                  label: Text('GİDER (Çıkış)'),
                  icon: Icon(Icons.arrow_upward, color: Colors.red),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _selectedType = newSelection.first;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // 2. Ödeme Yöntemi Seçimi (Nakit / Kart / Çek)
             Text('Ödeme Yöntemi', style: Theme.of(context).textTheme.labelLarge),
             const SizedBox(height: 8),
             DropdownButtonFormField<PaymentMethod>(
               value: _selectedPaymentMethod,
               decoration: const InputDecoration(
                 border: OutlineInputBorder(),
                 contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               ),
               dropdownColor: const Color(0xFF334155),
               items: PaymentMethod.values.map((method) {
                 IconData icon;
                 switch(method) {
                   case PaymentMethod.cash: icon = Icons.payments_outlined; break;
                   case PaymentMethod.creditCard: icon = Icons.credit_card; break;
                   case PaymentMethod.checkNote: icon = Icons.receipt_long; break;
                 }
                 return DropdownMenuItem(
                   value: method,
                   child: Row(
                     children: [
                       Icon(icon, size: 20, color: Colors.white70),
                       const SizedBox(width: 8),
                       Text(method.displayName),
                     ],
                   ),
                 );
               }).toList(),
               onChanged: (PaymentMethod? newValue) {
                 if (newValue != null) {
                   setState(() => _selectedPaymentMethod = newValue);
                 }
               },
             ),

            const SizedBox(height: 24),

            // Tutar
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tutar',
                prefixText: '₺ ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Tutar gerekli';
                if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçersiz tutar';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Açıklama gerekli';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Kaydet Butonu
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _selectedType == TransactionType.income 
                    ? Colors.green.shade700 
                    : Colors.red.shade700,
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('KAYDET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
