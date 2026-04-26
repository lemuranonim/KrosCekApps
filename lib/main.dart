import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'services/notification_service.dart';
import 'screens/services/config_manager.dart';
import 'services/firebase_options.dart';
import 'screens/services/region_mapper_service.dart';
import 'screens/web_splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final String title = message.data['title'] ?? 'Notifikasi Baru';
  final String body = message.data['body'] ?? 'Anda memiliki pesan baru.';
  await NotificationService().showNotification(title, body);
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeProvider);

    if (kIsWeb) {
      return MaterialApp(
        title: 'KroscekApp Web',
        theme: AdvantaTheme.light(),
        darkTheme: AdvantaTheme.dark(),
        themeMode: currentThemeMode,
        debugShowCheckedModeBanner: false,
        home: const WebSplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'KroscekApp',
      theme: AdvantaTheme.light(),
      darkTheme: AdvantaTheme.dark(),
      themeMode: currentThemeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    await Hive.initFlutter();
    await Hive.openBox('vegetativeData');
    await Hive.openBox('generativeData');
    await Hive.openBox('preHarvestData');
    await Hive.openBox('harvestData');
    await Hive.openBox('pspVegetativeData');
    await Hive.openBox('pspGenerativeData');

    await Future.wait([
      ConfigManager.loadConfig(),
      RegionMapperService.loadMappings(),
    ]).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('Timeout: Gagal memuat konfigurasi dalam 15 detik');
      },
    );

    await initializeDateFormatting('id_ID', null);

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await NotificationService().init();
      await Permission.notification.request();
      await Permission.location.request();
      await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
    }

    runApp(const ProviderScope(child: MyApp()));

  } catch (e) {
    runApp(ProviderScope(child: ErrorApp(errorMessage: e.toString())));
  }
}

Future<void> requestRequiredPermissions() async {
  if (!kIsWeb) {
    await Permission.location.request();
    await Permission.notification.request();
  }
}