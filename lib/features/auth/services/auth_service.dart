import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/user_profile.dart';
import '../../../core/services/firebase_providers.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService(this._auth, this._firestore);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user role from profiles table
  Future<String?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('profiles').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user role: $e');
      return null;
    }
  }

  // Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('profiles').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        
        // Firestore timestamps explicitly into strings if model needs it, but UserProfile.fromJson might fail if it relies on string.
        // Convert timestamp to Iso8601String
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        return UserProfile.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
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
      final snapshot = await _firestore
          .collection('profiles')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
        } else {
          data['created_at'] = DateTime.now().toIso8601String();
        }
        return UserProfile.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting all profiles: $e');
      return [];
    }
  }

  // Delete profile (Admin only)
  Future<void> deleteProfile(String profileId) async {
    await _firestore.collection('profiles').doc(profileId).delete();
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
    
    // OTURUMUN KAYMAMASI İÇİN: Geçici bir Firebase App oluşturuyoruz.
    FirebaseApp tempApp = await Firebase.initializeApp(
      name: 'Temporary',
      options: Firebase.app().options,
    );

    try {
      // 1. Create the Auth User (on temp app so it doesn't log them in on the main app)
      UserCredential result = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // 2. Profile kaydı oluştur (Main client üzerinden, admin yetkisiyle)
        await _firestore.collection('profiles').doc(result.user!.uid).set({
          'email': email,
          'full_name': fullName,
          'password': password,
          'role': 'user',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } finally {
      // Geçici istemciyi temizle
      await tempApp.delete();
    }
  }

  // Change Password
  Future<void> updatePassword(String newPassword) async {
    if (currentUser != null) {
      // 1. Update password in Authentication
      await currentUser!.updatePassword(newPassword);
    }
  }
}

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return AuthService(auth, firestore);
});

// Current user provider
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current user profile provider
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return null;
  
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUserProfile();
});

// Is admin provider
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return false;
  
  final authService = ref.watch(authServiceProvider);
  return await authService.isAdmin();
});
