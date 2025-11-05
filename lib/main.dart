import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'router.dart';
import 'services/notification_service.dart';
import 'screens/services/config_manager.dart';
import 'services/firebase_options.dart';
import 'screens/services/region_mapper_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

    // ✅ STEP 1: Initialize Firebase
    debugPrint("\n📱 STEP 1: Initializing Firebase...");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("✅ Firebase initialized successfully");

    // ✅ STEP 2: Initialize Hive
    debugPrint("\n💾 STEP 2: Initializing Hive...");
    await Hive.initFlutter();
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
      // Load dengan timeout untuk menghindari hang
      await Future.wait([
        ConfigManager.loadConfig(),
        RegionMapperService.loadMappings(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout: Gagal memuat konfigurasi dalam 15 detik');
        },
      );

      // Validasi hasil load
      if (ConfigManager.regions.isEmpty) {
        debugPrint("⚠️ WARNING: ConfigManager loaded but regions is empty!");
        debugPrint("   This might cause issues when navigating between screens.");
      } else {
        debugPrint("✅ ConfigManager loaded successfully");
        debugPrint("   📊 Total regions loaded: ${ConfigManager.regions.length}");
        // Debug: Print available regions
        ConfigManager.regions.forEach((key, value) {
          debugPrint("      - $key: $value");
        });
      }

      debugPrint("✅ RegionMapperService loaded successfully");

    } catch (configError, configStackTrace) {
      debugPrint("❌ CRITICAL ERROR loading configurations!");
      debugPrint("   Error: $configError");
      debugPrint("   Stack: $configStackTrace");

      // Jangan throw error, biarkan app tetap jalan dengan data kosong
      // User bisa retry dari dalam app
      debugPrint("⚠️ App will continue with empty configuration");
      debugPrint("   Users may need to reload from settings");
    }

    // ✅ STEP 4: Initialize Date Formatting
    debugPrint("\n📅 STEP 4: Initializing Date Formatting...");
    await initializeDateFormatting('id_ID', null);
    debugPrint("✅ Date formatting initialized");

    // ✅ STEP 5: Initialize Notification Service
    debugPrint("\n🔔 STEP 5: Initializing Notifications...");
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService().init();
    debugPrint("✅ Notification service initialized");

    // ✅ STEP 6: Request Permissions
    debugPrint("\n🔐 STEP 6: Requesting Permissions...");
    await Permission.notification.request();
    await Permission.location.request();
    debugPrint("✅ Permissions requested");

    // ✅ STEP 7: Initialize Flutter Downloader
    debugPrint("\n⬇️ STEP 7: Initializing Downloader...");
    await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
    debugPrint("✅ Downloader initialized");

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

Future<void> requestRequiredPermissions() async {
  await Permission.location.request();
  await Permission.notification.request();
}