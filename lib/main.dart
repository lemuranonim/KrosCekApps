import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart'; // <-- Ditambahkan untuk 'kIsWeb'
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'router.dart';
import 'services/notification_service.dart';
import 'screens/services/config_manager.dart';
import 'services/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase diinisialisasi di dalam handler ini
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- MULAI PERUBAHAN DI SINI ---

  // Karena kita mengirim "Pesan Data", ambil title dan body dari message.data
  final String title = message.data['title'] ?? 'Notifikasi Baru';
  final String body = message.data['body'] ?? 'Anda memiliki pesan baru.';

  // Panggil service untuk menampilkan notifikasi lokal
  await NotificationService().showNotification(title, body);

  // --- SELESAI PERUBAHAN ---

  debugPrint("Handling a background message: ${message.messageId}");
}

// Pindahkan widget ErrorApp ke filenya sendiri nanti, misal 'widgets/error_app.dart'
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Gagal memulai aplikasi.\n\nError: $errorMessage'),
          ),
        ),
      ),
    );
  }
}

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Muat konfigurasi & data lokal
    await ConfigManager.loadConfig();
    await initializeDateFormatting('id_ID', null);

    // Inisialisasi Hive
    await Hive.initFlutter();
    await Hive.openBox('vegetativeData');
    await Hive.openBox('generativeData');
    await Hive.openBox('preHarvestData');
    await Hive.openBox('harvestData');
    await Hive.openBox('pspVegetativeData');
    await Hive.openBox('pspGenerativeData');

    // Inisialisasi Firebase & Notifikasi
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService().init();

    // Minta izin yang dibutuhkan saat startup
    await Permission.notification.request();
    await Permission.location.request();

    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

    runApp(const MyApp());

  } catch (e) {
    debugPrint("Initialization error: $e");
    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

// Fungsi untuk menangani semua permintaan izin di satu tempat
Future<void> requestRequiredPermissions() async {
  await Permission.location.request();
  await Permission.notification.request();
  // Anda bisa menambahkan izin lain di sini
}