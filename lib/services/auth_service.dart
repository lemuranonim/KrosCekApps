import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      return;
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(uid).get();
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      return data?['role'];
    } catch (e) {
      return null;
    }
  }

  Future<void> createUserInFirestoreIfNeeded(User user, {required String role}) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': role,
        });
      } else {
        Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
        if (data?['role'] != role) {
          await _firestore.collection('users').doc(user.uid).update({
            'role': role,
          });
        }
      }
    } catch (e) {
      // No action required
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      // No action required
    }
  }
}
