import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:connectivity_plus/connectivity_plus.dart'; // Import untuk memeriksa koneksi internet
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: firebaseOptions,
  );

  // Aktifkan Firebase App Check
  await FirebaseAppCheck.instance.activate();

  // Periksa koneksi internet sebelum memeriksa status login
  //bool isConnected = await checkInternetConnection();
  //if (!isConnected) {
  //  runApp(NoInternetApp()); // Aplikasi sederhana yang menampilkan pesan tanpa koneksi
  //  return;
  //}

  // Inisialisasi aplikasi setelah mengecek status login
  bool showLoginScreen = await checkLoginStatus();

  runApp(MyApp(showLoginScreen: showLoginScreen));
}

Future<bool> checkLoginStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? userRole = prefs.getString('userRole');

  if (isLoggedIn && userRole != null) {
    // Jika pengguna sudah login dan ada peran yang disimpan
    return false; // Jangan tampilkan login screen
  } else {
    // Jika belum login, tampilkan login screen
    return true;
  }
}

// Fungsi untuk memeriksa koneksi internet
// Future<bool> checkInternetConnection() async {
//  var connectivityResult = await (Connectivity().checkConnectivity());
//  return connectivityResult == ConnectivityResult.mobile ||
//      connectivityResult == ConnectivityResult.wifi;
//}

class MyApp extends StatelessWidget {
  final bool showLoginScreen;

  const MyApp({super.key, required this.showLoginScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KroscekApp',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      initialRoute: showLoginScreen ? '/login' : '/', // Ubah initial route sesuai status login
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(), // HomeScreen untuk User
        '/admin_dashboard': (context) => const AdminDashboard(), // Dashboard untuk Admin
      },
    );
  }
}

// Aplikasi alternatif yang ditampilkan ketika tidak ada koneksi internet
class NoInternetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'No Internet Connection',
      home: Scaffold(
        appBar: AppBar(
          title: Text('No Connection'),
        ),
        body: Center(
          child: Text('Tidak ada koneksi internet. Harap periksa koneksi Anda.'),
        ),
      ),
    );
  }
}
