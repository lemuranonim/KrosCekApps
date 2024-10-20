import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final GoogleSignInService _googleSignInService = GoogleSignInService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isAdmin = false;  // Default role sebagai User

  // Tambahkan variabel untuk email dan nama pengguna
  String userEmail = 'Fetching...';
  String userName = 'Fetching...';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Fungsi untuk mengambil email dan nama dari SharedPreferences
  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Email dan password tidak boleh kosong!";
      });
      return;
    }

    final user = await _auth.signInWithEmailAndPassword(email, password);
    if (user != null) {
      await _handleRoleRedirection(user.uid, email);
    } else {
      setState(() {
        _errorMessage = "Login gagal! Cek email dan password.";
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    final user = await _googleSignInService.signInWithGoogle(forceSignIn: true);
    if (user != null) {
      final selectedRole = _isAdmin ? 'admin' : 'user';
      await _auth.createUserInFirestoreIfNeeded(user, role: selectedRole);
      await _handleRoleRedirection(user.uid, user.email ?? "Unknown Email");

      // Simpan email dan nama pengguna ke SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', user.email ?? "Unknown Email");
      await prefs.setString('userName', user.displayName ?? "Pengguna");

      // Update state untuk memastikan data diperbarui di UI
      setState(() {
        userEmail = user.email ?? "Unknown Email";
        userName = user.displayName ?? "Pengguna";
      });
    } else {
      setState(() {
        _errorMessage = "Google Sign-In gagal!";
      });
    }
  }

  Future<void> _handleRoleRedirection(String uid, String email) async {
    try {
      // Ambil data dari Firestore
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance.collection('roles').doc('adminEmails').get();
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('roles').doc('userEmails').get();

      // Pastikan data di-cast ke Map<String, dynamic> sebelum mengaksesnya
      Map<String, dynamic>? adminData = adminDoc.data() as Map<String, dynamic>?;
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      List<String> adminEmails = adminData != null && adminData.containsKey('emails')
          ? List<String>.from(adminData['emails'])
          : [];

      List<String> userEmails = userData != null && userData.containsKey('emails')
          ? List<String>.from(userData['emails'])
          : [];

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);

      // Pastikan widget masih mounted sebelum menggunakan BuildContext atau setState
      if (!mounted) return;

      if (adminEmails.contains(email)) {
        await prefs.setString('userRole', 'admin');
        if (!_isAdmin) {
          // Periksa `mounted` sebelum menggunakan setState
          if (mounted) {
            setState(() {
              _errorMessage = "Kamu bukan User!";
            });
          }
          _auth.signOut();
        } else {
          // Periksa `mounted` sebelum navigasi
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/admin_dashboard');
          }
        }
      } else if (userEmails.contains(email)) {
        await prefs.setString('userRole', 'user');
        if (_isAdmin) {
          // Periksa `mounted` sebelum menggunakan setState
          if (mounted) {
            setState(() {
              _errorMessage = "Kamu bukan Admin!";
            });
          }
          _auth.signOut();
        } else {
          // Periksa `mounted` sebelum navigasi
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        // Periksa `mounted` sebelum menggunakan setState
        if (mounted) {
          setState(() {
            _errorMessage = "Akses tidak diizinkan! Email tidak terdaftar.";
          });
        }
        _auth.signOut();
      }
    } catch (e) {
      // Periksa `mounted` sebelum menggunakan setState
      if (mounted) {
        setState(() {
          _errorMessage = "Terjadi kesalahan. Silakan coba lagi.";
        });
      }
    }
  }

  void _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = "Mohon masukkan email!";
        });
      }
      return;
    }

    await _auth.resetPassword(email);

    // Pastikan widget masih mounted sebelum menggunakan BuildContext
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email reset password terkirim')),
      );
    }
  }


  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: const Text('Masukkan alamat email Anda untuk mereset password.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                _resetPassword();
                Navigator.of(context).pop();
              },
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(  // Menggunakan Stack untuk menempatkan background di belakang
        fit: StackFit.expand,
        children: [
          Image.asset(  // Gambar background tetap memenuhi layar
            'assets/login_background.png',
            fit: BoxFit.cover,
          ),
          Container(  // Lapisan transparan di atas background
            color: Colors.white.withOpacity(0.5),
          ),
          SingleChildScrollView(  // Konten dapat di-scroll
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(  // Gambar logo
                  'assets/logo.png',
                  height: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  'KrosCekApp',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: Text(
                    _isAdmin ? 'Login sebagai Admin' : 'Login sebagai User',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,  // Mengubah fontWeight sesuai role
                      color: _isAdmin ? Colors.red : Colors.green,  // Warna berbeda untuk Admin dan User
                    ),
                  ),
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('LOGIN'),
                ),
                const SizedBox(height: 20),
                FloatingActionButton.extended(
                  onPressed: _loginWithGoogle,
                  icon: SvgPicture.asset(
                    'assets/google_logo.svg',
                    height: 24,
                    width: 24,
                  ),
                  label: const Text('SIGN IN WITH GOOGLE'),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _showResetPasswordDialog,
                  child: const Text('Lupa Password?'),
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
