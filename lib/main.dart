import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';

import 'router.dart';
import 'screens/services/config_manager.dart';
import 'services/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigManager.loadConfig(); // Muat konfigurasi JSON

  // Inisialisasi locale data untuk Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Hive
  await Hive.initFlutter();

  // Membuka atau membuat box yang dibutuhkan
  await Hive.openBox('vegetativeData');
  await Hive.openBox('generativeData');
  await Hive.openBox('preHarvestData');
  await Hive.openBox('harvestData');
  await Hive.openBox('pspVegetativeData');
  await Hive.openBox('pspGenerativeData');

  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,  // Ganti 'firebaseOptions' dengan 'DefaultFirebaseOptions.currentPlatform'
  );

  // Aktifkan Firebase App Check
  await FirebaseAppCheck.instance.activate();

  runApp(const MyApp());
}

// Future<bool> checkLoginStatus() async {
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
//   String? userRole = prefs.getString('userRole');
//
//   if (isLoggedIn && userRole != null) {
//     return false; // Jangan tampilkan login screen
//   } else {
//     return true;
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KroscekApp',
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
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

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  @override
  void initState() {
    super.initState();
    checkPermissions(); // Memeriksa izin saat aplikasi dimulai
  }

  Future<void> checkPermissions() async {
    // Cek izin lokasi
    if (await Permission.location.isDenied) {
      await Permission.location.request(); // Minta izin lokasi
    }

    // Cek izin notifikasi (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request(); // Minta izin notifikasi
    }

    // Cek izin selalu di latar belakang (Opsional untuk GPS)
    if (await Permission.locationAlways.isDenied) {
      await Permission.locationAlways.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: const Center(
        child: Text('Izin telah diperiksa!'),
      ),
    );
  }
}

Future<void> requestNotificationPermission() async {
  var status = await Permission.notification.status;
  if (!status.isGranted) {
    await Permission.notification.request();
  }
}
