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
        print("Google Sign-In dibatalkan oleh user.");
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print("Access Token: ${googleAuth.accessToken}");
      print("ID Token: ${googleAuth.idToken}");

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;
      print("Google Sign-In berhasil, User UID: ${user?.uid}");

      // Sinkronisasi data pengguna di Firestore jika diperlukan
      if (user != null) {
        final AuthService authService = AuthService();
        final role = 'user'; // Atau peran lain sesuai pilihan pengguna
        await authService.createUserInFirestoreIfNeeded(user, role: role);
      }

      return user;
    } catch (e) {
      print("Error saat Google Sign-In: $e");
      return null;
    }
  }


  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print(e.toString());
    }
  }
}
