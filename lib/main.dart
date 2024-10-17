import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Inisialisasi aplikasi setelah mengecek status login
  bool showLoginScreen = await checkLoginStatus();

  runApp(MyApp(showLoginScreen: showLoginScreen));
}

Future<bool> checkLoginStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? userRole = prefs.getString('userRole');

  if (isLoggedIn && userRole != null) {
    return false; // Jangan tampilkan login screen
  } else {
    return true;
  }
}

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
      initialRoute: showLoginScreen ? '/login' : '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/admin_dashboard': (context) => const AdminDashboard(),
      },
    );
  }
}

// Aplikasi alternatif yang ditampilkan ketika tidak ada koneksi internet
class NoInternetApp extends StatelessWidget {
  const NoInternetApp({super.key}); // Menambahkan 'key' parameter

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
