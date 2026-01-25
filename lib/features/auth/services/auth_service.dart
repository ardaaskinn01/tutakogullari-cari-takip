import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/user_profile.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign in with email and password
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user role from profiles table
  Future<String?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      return response['role'] as String?;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Check if current user is admin
  Future<bool> isAdmin() async {
    final role = await getCurrentUserRole();
    return role == 'admin';
  }

  // Get all profiles (Admin only)
  Future<List<UserProfile>> getAllProfiles() async {
    try {
      final List<dynamic> data = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      return data.map((json) => UserProfile.fromJson(json)).toList();
    } catch (e) {
      print('Error getting all profiles: $e');
      return [];
    }
  }

  // Delete profile (Admin only)
  Future<void> deleteProfile(String profileId) async {
    await _supabase
        .from('profiles')
        .delete()
        .eq('id', profileId);
  }

  // Register new staff (Admin creates for them)
  Future<void> registerStaff({
    required String username,
    required String password,
    required String fullName,
  }) async {
    // Kullanıcı adını e-posta formatına uygun hale getiriyoruz
    final sanitizedUsername = username.trim().toLowerCase().replaceAll(' ', '.');
    final email = '$sanitizedUsername@example.com';
    
    // OTURUMUN KAYMAMASI İÇİN: Geçici bir Supabase istemcisi oluşturuyoruz.
    // persistSession: false yaparak PKCE / Storage hatalarını engelliyoruz.
    final tempSupabase = SupabaseClient(
      AppConstants.supabaseUrl, 
      AppConstants.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit, // PKCE yerine implicit kullan (Storage gerektirmez)
      ),
    );
    
    // 1. Create the Auth User (on temp client)
    final response = await tempSupabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // 2. Profile kaydı oluştur veya güncelle (Main client üzerinden, admin yetkisiyle)
      await _supabase.from('profiles').upsert({
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
        'password': password,
        'role': 'user',
      });
      
      // Geçici istemciyi temizle
      await tempSupabase.dispose();
    }
  }
}

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthService(supabase);
});

// Current user provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((state) => state.session?.user);
});

// Current user profile provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUserProfile();
});

// Is admin provider
final isAdminProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isAdmin();
});
