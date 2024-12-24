import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final doc = await _firestore.collection('users').doc(email).get();
      if (doc.exists && doc.data()?['password'] == password) {
        return User(email: email, role: doc.data()?['role']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    // Clear local storage or session management
  }

  Future<String?> getUserRole(String email) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(email).get();
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      return data?['role'];
    } catch (e) {
      return null;
    }
  }

  Future<void> createUserInFirestoreIfNeeded(String email, {required String role}) async {
    try {
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(email).get();
      if (!snapshot.exists) {
        await _firestore.collection('users').doc(email).set({
          'email': email,
          'role': role,
        });
      } else {
        Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
        if (data?['role'] != role) {
          await _firestore.collection('users').doc(email).update({
            'role': role,
          });
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      // Implement custom logic to reset password if required
    } catch (e) {
      // Handle error
    }
  }
}

class User {
  final String email;
  final String role;
  User({required this.email, required this.role});
}
