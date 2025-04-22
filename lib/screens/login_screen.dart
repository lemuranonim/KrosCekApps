import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/google_sign_in_service.dart';
import '../services/auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final GoogleSignInService _googleSignInService = GoogleSignInService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isAdmin = false;
  bool _isUser = false;
  bool _isPsp = false;
  String _errorMessage = '';

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

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
      // Tentukan role berdasarkan input pengguna
      String? selectedRole;
      if (_isAdmin) selectedRole = 'admin';
      if (_isPsp) selectedRole = 'psp';
      if (_isUser) selectedRole = 'user';

      if (selectedRole == null) {
        setState(() {
          _errorMessage = "Pilih salah satu role sebelum login.";
        });
        return;
      }

      await _redirectUserBasedOnRole(email, selectedRole);
    } else {
      setState(() {
        _errorMessage = "Login gagal! Cek email dan password.";
      });
    }
  }

  Future<void> _loginWithGoogle() async {
    final user = await _googleSignInService.signInWithGoogle(forceSignIn: true);
    if (user != null) {
      String? selectedRole;

      if (_isAdmin) {
        selectedRole = 'admin';
      } else if (_isPsp) {
        selectedRole = 'psp';
      } else if (_isUser) {
        selectedRole = 'user';
      }

      if (selectedRole == null) {
        setState(() {
          _errorMessage = "Pilih role sebelum login.";
        });
        return;
      }

      await _auth.createUserInFirestoreIfNeeded(user.email, role: selectedRole);
      await _redirectUserBasedOnRole(user.email, selectedRole);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userEmail', user.email);
      await prefs.setString('userName', user.email);

      setState(() {
        userEmail = user.email;
        userName = user.email;
      });
    } else {
      setState(() {
        _errorMessage = "Google Sign-In gagal!";
      });
    }
  }

  Future<void> _loginWithApple() async {
    try {
      // Meminta kredensial Apple ID
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Mengambil email dan nama lengkap
      final email = appleCredential.email ?? "Tidak diketahui";
      final fullName =
          appleCredential.givenName ?? "Pengguna"; // Nama pertama jika tersedia

      if (!mounted) return;
      setState(() {
        userEmail = email;
        userName = fullName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Berhasil login sebagai $userName ($userEmail)"),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Ups! Login gagal: Hape kamu bukan iPhone";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ups! Login gagal: Hape kamu bukan iPhone"),
        ),
      );
    }
  }


  Future<void> _redirectUserBasedOnRole(String email, String selectedRole) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);

      // Ambil data role dari Firestore
      final roleData = await FirebaseFirestore.instance.collection('roles').get();
      final adminEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'adminEmails')
          .data()['emails'] as List<dynamic>;
      final pspEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'pspEmails')
          .data()['emails'] as List<dynamic>;
      final userEmails = roleData.docs
          .firstWhere((doc) => doc.id == 'userEmails')
          .data()['emails'] as List<dynamic>;

      if (selectedRole == 'admin' && adminEmails.contains(email)) {
        await prefs.setString('userRole', 'admin');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        }
      } else if (selectedRole == 'psp' && pspEmails.contains(email)) {
        await prefs.setString('userRole', 'psp');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/psp_dashboard');
        }
      } else if (selectedRole == 'user' && userEmails.contains(email)) {
        await prefs.setString('userRole', 'user');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Login gagal! Email tidak cocok dengan role yang dipilih.";
          });
        }
        _auth.signOut();
      }
    } catch (e) {
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
          content: const Text('Masukkan email Anda untuk reset password.'),
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
            color: Colors.white.withAlpha((0.5 * 255).toInt()),
          ),
          SingleChildScrollView(  // Konten dapat di-scroll
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 130),
                // Image.asset(  // Gambar logo
                //   'assets/icon.png',
                //   height: 100,
                // ),
                const SizedBox(height: 20),
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: Text(
                    'Login sebagai Admin',
                    style: TextStyle(
                      color: Colors.black, // Warna hijau
                      fontWeight: FontWeight.bold, // Teks tebal
                    ),
                  ),
                  value: _isAdmin,
                  onChanged: (value) {
                    setState(() {
                      _isAdmin = value ?? false;
                      if (_isAdmin) {
                        _isUser = false;
                        _isPsp = false;
                      }
                    });
                  },
                  activeColor: Colors.green, // Warna checkbox saat dicentang
                  checkColor: Colors.white, // Warna centang di dalam checkbox
                ),

                CheckboxListTile(
                  title: const Text('Login sebagai User HSP',
                    style: TextStyle(
                      color: Colors.black, // Warna hijau
                      fontWeight: FontWeight.bold, // Teks tebal
                    ),
                  ),
                  value: _isUser,
                  onChanged: (value) {
                    setState(() {
                      _isUser = value ?? false;
                      if (_isUser) {
                        _isAdmin = false;
                        _isPsp = false;
                      }
                    });
                  },
                  activeColor: Colors.green, // Warna checkbox saat dicentang
                  checkColor: Colors.white, // Warna centang di dalam checkbox
                ),
                CheckboxListTile(
                  title: const Text('Login sebagai User PSP',
                    style: TextStyle(
                      color: Colors.black, // Warna hijau
                      fontWeight: FontWeight.bold, // Teks tebal
                    ),
                  ),
                  value: _isPsp,
                  onChanged: (value) {
                    setState(() {
                      _isPsp = value ?? false;
                      if (_isPsp) {
                        _isAdmin = false;
                        _isUser = false;
                      }
                    });
                  },
                  activeColor: Colors.green, // Warna checkbox saat dicentang
                  checkColor: Colors.white, // Warna centang di dalam checkbox
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(
                      color: Colors.green, // Warna teks label
                      fontWeight: FontWeight.bold, // Membuat teks label menjadi bold
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.green, // Warna garis ketika fokus
                        width: 2.0, // Ketebalan garis ketika fokus
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey, // Warna garis ketika tidak fokus
                        width: 1.0, // Ketebalan garis ketika tidak fokus
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _isPasswordHidden,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(
                      color: Colors.green, // Warna teks label
                      fontWeight: FontWeight.bold, // Membuat teks label menjadi bold
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.green, // Warna garis ketika fokus
                        width: 2.0, // Ketebalan garis ketika fokus
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey, // Warna garis ketika tidak fokus
                        width: 1.0, // Ketebalan garis ketika tidak fokus
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                        color: Colors.green, // Warna ikon
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordHidden = !_isPasswordHidden;
                        });
                      },
                    ),
                  ),
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
                FloatingActionButton.extended(
                  onPressed: _loginWithApple,
                  icon: Icon(Icons.apple, color: Colors.white),
                  label: const Text('SIGN IN WITH APPLE'),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _showResetPasswordDialog,
                  child: const Text('Lupa Password?',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold, // Teks tebal
                    ),
                  ),
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