import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

class GoogleSignInService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;

      // Sinkronisasi data pengguna di Firestore jika diperlukan
      if (user != null) {
        final AuthService authService = AuthService();
        final role = 'user'; // Atau peran lain sesuai pilihan pengguna
        await authService.createUserInFirestoreIfNeeded(user, role: role);
      }

      return user;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      // No action required
    }
  }
}
