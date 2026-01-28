import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final input = _emailController.text.trim();
      String email;
      
      if (input.contains('@')) {
        email = input;
      } else {
        // Kullanıcı adını temizle (boşlukları noktaya çevir, küçük harf yap)
        final username = input.toLowerCase().replaceAll(' ', '.');
        email = '$username@example.com';
      }
      
      await authService.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

    } catch (e) {
      if (mounted) {
        String message = 'Giriş yapılamadı';
        if (e.toString().contains('Invalid login credentials')) {
          message = 'Kullanıcı adı veya şifre hatalı';
        } else {
          message = 'Hata: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Logo/Title
                      Image.asset(
                        'assets/images/logohest.png',
                        height: 200,
                        width: 200,
                        fit: BoxFit.contain,
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(),
                      
                      const SizedBox(height: 24),
                      
                      Text(
                        'Hest Yapı Pen',
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms),
                      
                      const SizedBox(height: 48),
                      
                      // Username Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kullanıcı adı gerekli';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),
                      
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre gerekli';
                          }
                          if (value.length < 6) {
                            return 'Şifre en az 6 karakter olmalı';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      // Login Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Giriş Yap'),
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
