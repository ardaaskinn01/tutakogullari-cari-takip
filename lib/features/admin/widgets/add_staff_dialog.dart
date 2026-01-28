import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/services/auth_service.dart';

class AddStaffDialog extends ConsumerStatefulWidget {
  final VoidCallback? onSuccess;

  const AddStaffDialog({super.key, this.onSuccess});

  @override
  ConsumerState<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
        widget.onSuccess?.call();
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
    final bgColor = Theme.of(context).cardTheme.color;
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return AlertDialog(
      backgroundColor: bgColor,
      title: const Text('Personel Ekle', style: TextStyle(color: Colors.white)),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 600 : 400),
        child: SingleChildScrollView(
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
      ),),
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
