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
      print(e.toString());
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return;
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      print("Mendapatkan role untuk UID: $uid");
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(uid).get();
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      print("Data dari Firestore: ${data.toString()}");  // Log untuk data
      return data?['role'];
    } catch (e) {
      print("Error mendapatkan role: $e");
      return null;
    }
  }

  Future<void> createUserInFirestoreIfNeeded(User user, {required String role}) async {// Modifikasi di AuthService
      try {
        DocumentSnapshot snapshot = await _firestore.collection('users').doc(user.uid).get();
        if (!snapshot.exists) {
          print("User belum ada di Firestore, menambahkan user baru dengan role: $role.");
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'role': role,  // Gunakan role yang dipilih (admin/user)
          });
        } else {
          print("User sudah ada di Firestore.");
          // Periksa dan perbarui role jika berbeda
          Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
          if (data?['role'] != role) {
            print("Role user di Firestore berbeda. Memperbarui role ke: $role.");
            await _firestore.collection('users').doc(user.uid).update({
              'role': role,
            });
          }
        }
      } catch (e) {
        print("Error saat menambahkan atau memperbarui user ke Firestore: $e");
      }
    }

    // Tambahkan metode ini ke dalam AuthService
    Future<void> resetPassword(String email) async {
      try {
        await _auth.sendPasswordResetEmail(email: email);
        print("Email reset password terkirim ke: $email.");
      } catch (e) {
        print("Error saat mengirim email reset password: $e");
      }
    }
  }

