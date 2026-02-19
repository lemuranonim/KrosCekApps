import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 1. Import Deteksi Web
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // [TAMBAHKAN INI]

import 'router.dart';
import 'services/notification_service.dart';
import 'screens/services/config_manager.dart';
import 'services/firebase_options.dart';
import 'screens/services/region_mapper_service.dart';
import 'screens/web_splash_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler biasanya tidak diperlukan atau berbeda config-nya di Web
  // Kita skip jika di Web untuk mencegah error worker
  if (kIsWeb) return;

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final String title = message.data['title'] ?? 'Notifikasi Baru';
  final String body = message.data['body'] ?? 'Anda memiliki pesan baru.';
  await NotificationService().showNotification(title, body);
  debugPrint("Handling a background message: ${message.messageId}");
}

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Gagal Memulai Aplikasi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
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
    // --- 3. LOGIKA PEMISAH WEB DAN MOBILE ---

    // JIKA WEB: Langsung buka WorkloadMapScreen (bypass login/router)
    if (kIsWeb) {
      return MaterialApp(
        title: 'KroscekApp Web',
        theme: ThemeData(
          primarySwatch: Colors.green,
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: const WebSplashScreen(), // Langsung ke Peta
      );
    }

    // JIKA MOBILE: Gunakan Router seperti biasa (Login, Admin, dll)
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
    debugPrint("═══════════════════════════════════════════");
    debugPrint("🚀 Starting KroscekApp Initialization...");
    debugPrint("═══════════════════════════════════════════");

    debugPrint("\n⚡ STEP 0: Initializing Supabase...");

    // GANTI 'URL_SUPABASE' dan 'ANON_KEY' dengan milikmu dari Dashboard Supabase
    await Supabase.initialize(
      url: 'https://bstxdyyglxrrfqgohllz.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzdHhkeXlnbHhycmZxZ29obGx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MzIwMjcsImV4cCI6MjA3MzEwODAyN30.3eB08aX-Nltd8DPqk7sIWH6b8r4clPbgmIeEdyCV5Uk',
    );
    debugPrint("✅ Supabase initialized successfully");

    // ✅ STEP 1: Initialize Firebase
    debugPrint("\n📱 STEP 1: Initializing Firebase...");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("✅ Firebase initialized successfully");

    // ✅ STEP 2: Initialize Hive
    debugPrint("\n💾 STEP 2: Initializing Hive...");
    await Hive.initFlutter();
    // Hive box opening is fine on web (uses IndexedDB)
    await Hive.openBox('vegetativeData');
    await Hive.openBox('generativeData');
    await Hive.openBox('preHarvestData');
    await Hive.openBox('harvestData');
    await Hive.openBox('pspVegetativeData');
    await Hive.openBox('pspGenerativeData');
    debugPrint("✅ Hive initialized successfully");

    // ✅ STEP 3: Load ConfigManager & RegionMapperService
    debugPrint("\n⚙️ STEP 3: Loading App Configurations...");

    try {
      await Future.wait([
        ConfigManager.loadConfig(),
        RegionMapperService.loadMappings(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout: Gagal memuat konfigurasi dalam 15 detik');
        },
      );

      if (ConfigManager.regions.isEmpty) {
        debugPrint("⚠️ WARNING: ConfigManager loaded but regions is empty!");
      } else {
        debugPrint("✅ ConfigManager loaded successfully");
        debugPrint("   📊 Total regions loaded: ${ConfigManager.regions.length}");
      }
      debugPrint("✅ RegionMapperService loaded successfully");

    } catch (configError) {
      debugPrint("❌ CRITICAL ERROR loading configurations!");
      debugPrint("   Error: $configError");
      debugPrint("⚠️ App will continue with empty configuration");
    }

    // ✅ STEP 4: Initialize Date Formatting
    debugPrint("\n📅 STEP 4: Initializing Date Formatting...");
    await initializeDateFormatting('id_ID', null);
    debugPrint("✅ Date formatting initialized");

    // --- 4. INIT FITUR MOBILE SAJA ---
    // Fitur di bawah ini sering error di Web atau butuh konfigurasi khusus.
    // Kita jalankan HANYA jika TIDAK di Web (!kIsWeb)

    if (!kIsWeb) {
      // ✅ STEP 5: Initialize Notification Service (Mobile Only)
      debugPrint("\n🔔 STEP 5: Initializing Notifications (Mobile)...");
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await NotificationService().init();
      debugPrint("✅ Notification service initialized");

      // ✅ STEP 6: Request Permissions (Mobile Only)
      debugPrint("\n🔐 STEP 6: Requesting Permissions (Mobile)...");
      await Permission.notification.request();
      await Permission.location.request();
      debugPrint("✅ Permissions requested");

      // ✅ STEP 7: Initialize Flutter Downloader (Mobile Only)
      debugPrint("\n⬇️ STEP 7: Initializing Downloader (Mobile)...");
      // Downloader plugin often crashes on web or doesn't support it
      await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
      debugPrint("✅ Downloader initialized");
    } else {
      debugPrint("\n🌐 Web Mode Detected: Skipping Mobile-only initializations (Notifications, Downloader)");
    }

    debugPrint("\n═══════════════════════════════════════════");
    debugPrint("🎉 App Initialization Completed Successfully!");
    debugPrint("═══════════════════════════════════════════\n");

    runApp(const MyApp());

  } catch (e, stackTrace) {
    debugPrint("\n═══════════════════════════════════════════");
    debugPrint("💥 FATAL ERROR During Initialization");
    debugPrint("═══════════════════════════════════════════");
    debugPrint("Error: $e");
    debugPrint("Stack trace: $stackTrace");
    debugPrint("═══════════════════════════════════════════\n");

    runApp(ErrorApp(errorMessage: e.toString()));
  }
}

// Helper permission function (kept for reference, strictly mobile)
Future<void> requestRequiredPermissions() async {
  if (!kIsWeb) {
    await Permission.location.request();
    await Permission.notification.request();
  }
}