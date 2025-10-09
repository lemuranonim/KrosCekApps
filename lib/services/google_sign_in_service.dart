// lib/services/google_sign_in_service.dart

import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

class GoogleSignInService {
  // FIX: Menggunakan konstruktor default GoogleSignIn()
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<User?> signInWithGoogle({bool forceSignIn = false}) async {
    try {
      if (forceSignIn) {
        await _googleSignIn.signOut();
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Google Sign-In dibatalkan oleh user, tidak perlu tindakan lebih lanjut.
        return null;
      }

      final String email = googleUser.email;
      final String role = 'user'; // Default role atau disesuaikan dengan pilihan pengguna

      // Sinkronisasi data pengguna di Firestore jika diperlukan
      final AuthService authService = AuthService();
      await authService.createUserInFirestoreIfNeeded(email, role: role);

      return User(email: email, role: role);
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // No action required
    }
  }
}

// Pastikan Anda memiliki class User yang sesuai, contoh:
class User {
  final String email;
  final String role;
  User({required this.email, required this.role});
}