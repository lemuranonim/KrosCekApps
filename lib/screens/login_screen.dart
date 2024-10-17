import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/google_sign_in_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    print("Proses login dengan email dan password dimulai.");
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Email dan password tidak boleh kosong!";
      });
      print("Email atau password kosong.");
      return;
    }

    final user = await _auth.signInWithEmailAndPassword(email, password);
    if (user != null) {
      print("Login berhasil. UID: ${user.uid}");
      await _handleRoleRedirection(user.uid, email);
    } else {
      setState(() {
        _errorMessage = "Login gagal! Cek email dan password.";
      });
      print("Login gagal untuk email: $email.");
    }
  }

  Future<void> _loginWithGoogle() async {
    print("Proses login dengan Google Sign-In dimulai.");
    final user = await _googleSignInService.signInWithGoogle(forceSignIn: true);
    if (user != null) {
      print("Google Sign-In berhasil. UID: ${user.uid}");
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
      print("Google Sign-In gagal atau dibatalkan.");
    }
  }

  Future<void> _handleRoleRedirection(String uid, String email) async {
    print("Memeriksa role untuk UID: $uid, Email: $email.");
    // Daftar email untuk admin dan user
    List<String> adminEmails = [
      'krisnabagus09@gmail.com',
      'ludtanza@gmail.com',
      'adityangutsamarwaka@gmail.com',
    ];

    List<String> userEmails = [
      'kristantodedi9@gmail.com',
      'aarsymajid@gmail.com',
      'anandaariadiwibowo@gmail.com',
      'mardi.sabawana1945@gmail.com',
      'aliridlo157@gmail.com',
      'anggisetyawan55@gmail.com',
      'masdukirais03@gmail.com',
      'adelfoantonio80@gmail.com',
      'teddyfahru1@gmail.com',
      'chreznaruby@gmail.com',
      'citrasyh93@gmail.com',
      'dikyferyirawan6@gmail.com',
      'lestaputri364@gmail.com',
      'gayuhdisro91@gmail.com',
      'aripeno3@gmail.com',
      'charismafauzi.saputra1@gmail.com',
      'tiyanas.ta97@gmail.com',
      'witovanhart88@gmail.com',
      'fifialeyda923@gmail.com',
      'dwiferdiansyahaldi@gmail.com',
      'muhammadhadi.syarifuddin@gmail.com',
      'edoaldiansyah28@gmail.com',
      'arrohmaan14@gmail.com',
      'ekosishadi11@gmail.com',
      'irfansayfudin414@gmail.com',
      'mvickybachruddin15@gmail.com',
      'ahmaddenijulioanggoro@gmail.com',
      'nanaasna28@gmail.com',
      'bagussskrisna@gmail.com'
    ];
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', email);

    if (adminEmails.contains(email)) {
      await prefs.setString('userRole', 'admin');
      if (!_isAdmin) {  // Jika switch tidak sesuai
        setState(() {
          _errorMessage = "Kamu bukan User!";
        });
        print("Kamu bukan User.");
        _auth.signOut();  // Keluar jika role tidak sesuai
      } else {
        print("User dengan role admin ditemukan. Navigasi ke admin dashboard.");
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      }
    } else if (userEmails.contains(email)) {
      await prefs.setString('userRole', 'user');
      if (_isAdmin) {  // Jika switch tidak sesuai
        setState(() {
          _errorMessage = "Kamu bukan Admin!";
        });
        print("Kamu bukan Admin.");
        _auth.signOut();  // Keluar jika role tidak sesuai
      } else {
        print("User dengan role user ditemukan. Navigasi ke home.");
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _errorMessage = "Akses tidak diizinkan! Email tidak terdaftar.";
      });
      print("Email tidak ditemukan dalam daftar admin atau user.");
      _auth.signOut();  // Keluar jika email tidak terdaftar
    }
  }

  void _resetPassword() async {
    print("Proses reset password dimulai.");
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Mohon masukkan email!";
      });
      print("Email kosong saat reset password.");
      return;
    }

    await _auth.resetPassword(email);
    print("Email reset password terkirim ke: $email.");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email reset password terkirim')),
    );
  }

  void _showResetPasswordDialog() {
    print("Dialog reset password ditampilkan.");
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
                print("Dialog reset password ditutup (batal).");
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                _resetPassword();
                Navigator.of(context).pop();
                print("Proses reset password dikonfirmasi.");
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
                      print("Role yang dipilih: ${_isAdmin ? 'admin' : 'user'}");
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
