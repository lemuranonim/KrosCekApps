import 'package:flutter/material.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:isolate';
import 'dart:ui';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:open_file/open_file.dart';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../services/session_manager.dart';

// ── IMPORT TEMA PUSAT ────────────────────────────────
import '../theme/app_theme.dart';

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  debugPrint("DOWNLOAD_CALLBACK: Task id=$id, status=$status, progress=$progress%");
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  if (send != null) {
    send.send([id, status, progress]);
  } else {
    debugPrint("DOWNLOAD_CALLBACK_ERROR: Port 'downloader_send_port' tidak ditemukan!");
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animation Controllers ─────────────────────────
  late AnimationController _masterController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  late Animation<double>  _logoFade;
  late Animation<double>  _logoScale;
  late Animation<Offset>  _logoSlide;
  late Animation<double>  _taglineFade;
  late Animation<Offset>  _taglineSlide;
  late Animation<double>  _dividerWidth;
  late Animation<double>  _footerFade;
  late Animation<double>  _shimmer;

  String _version        = 'Loading...';
  bool   _updateRequired = false;

  // ── Download state ────────────────────────────────
  bool   _isDownloading         = false;
  String? _downloadTaskId;
  bool   _installationInitiated = false;
  final ReceivePort _port       = ReceivePort();
  bool   _isPortInitialized     = false;

  final ValueNotifier<double> _downloadProgressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> _downloadMessageNotifier  = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAndSetupDownloader();

    _masterController.forward();
    _shimmerController.repeat();
    _pulseController.repeat(reverse: true);

    _fetchVersion();

    // Jalankan cek update dan animasi minimum secara paralel agar login
    // tidak selalu tertahan oleh delay splash penuh.
    _continueAfterStartupChecks();
  }

  void _setupAnimations() {
    // Master: 3.0s total
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync  : this,
    );

    // Shimmer for gold line
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync  : this,
    );

    // Pulse for loading indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync  : this,
    );

    // Logo animations
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic)),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic)),
    );

    // Tagline
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.35, 0.70, curve: Curves.easeOut)),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic)),
    );

    // Gold divider
    _dividerWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.55, 0.80, curve: Curves.easeOutCubic)),
    );

    // Footer
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _masterController, curve: const Interval(0.70, 1.0, curve: Curves.easeOut)),
    );

    // Shimmer & Pulse
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  // ── Downloader ────────────────────────────────────
  Future<void> _initializeAndSetupDownloader() async {
    try {
      await FlutterDownloader.initialize(debug: true, ignoreSsl: true);
      FlutterDownloader.registerCallback(downloadCallback);

      if (!_isPortInitialized) {
        IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
        _isPortInitialized = true;

        _port.listen((dynamic data) {
          if (data is List && data.length >= 3) {
            String id = data[0] as String;
            DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1] as int);
            int progress = data[2] as int;

            debugPrint('NOTIFIER CALLBACK: id=$id, status=$status, progress=$progress');

            if (mounted && id == _downloadTaskId) {
              if (status == DownloadTaskStatus.running) {
                _downloadProgressNotifier.value = progress / 100.0;
                _downloadMessageNotifier.value = "Mendownload pembaruan: $progress%";
              } else if (status == DownloadTaskStatus.complete) {
                _downloadProgressNotifier.value = 1.0;
                _downloadMessageNotifier.value = "Download selesai. Mempersiapkan instalasi...";
                Future.delayed(const Duration(seconds: 1), () {
                  if (mounted && id == _downloadTaskId) {
                    _installApk(id);
                  }
                });
              } else if (status == DownloadTaskStatus.failed) {
                _isDownloading = false;
                _downloadMessageNotifier.value = "Download gagal. Silakan coba lagi.";
              } else if (status == DownloadTaskStatus.enqueued) {
                _isDownloading = true;
                _downloadMessageNotifier.value = "Download sedang dalam antrean...";
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error initializing FlutterDownloader: $e");
    }
  }

  Future<void> _fetchVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = packageInfo.version);
      }
    } catch (e) {
      if (mounted) setState(() => _version = 'Dev');
    }
  }

  Future<void> _continueAfterStartupChecks() async {
    await Future.wait<void>([
      _checkForUpdate(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);

    if (!_updateRequired && mounted) {
      _checkLoginStatus();
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final response = await Supabase.instance.client
          .from('app_config')
          .select()
          .eq('id', 'kroscek')
          .single()
          .timeout(const Duration(seconds: 3));

      final latestVersion = response['latest_version'] as String?;
      final forceUpdate   = response['force_update'] as bool? ?? false;
      final downloadUrl   = response['apk_url'] as String?;

      if (latestVersion == null || downloadUrl == null) return;

      final packageInfo    = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (currentVersion != latestVersion) {
        _updateRequired = true;
        if (mounted) {
          _showUpdateDialog(forceUpdate, latestVersion, downloadUrl);
        }
      }
    } catch (_) {
      // Gagal cek update → lanjut saja
    }
  }

  Future<void> _downloadAndInstallUpdate(
      String apkUrl, StateSetter dialogSetState, VoidCallback onDownloadCancelledOrFailed) async {

    dialogSetState(() {
      _isDownloading = true;
      _installationInitiated = false;
    });

    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      dialogSetState(() {
        _isDownloading = false;
      });
      onDownloadCancelledOrFailed();
      return;
    }

    try {
      final String downloadPath = await _getDownloadPath();
      final Directory downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final String fileName = 'kroscek-update-${DateTime.now().millisecondsSinceEpoch}.apk';

      final taskId = await FlutterDownloader.enqueue(
        url: apkUrl,
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
      );

      if (taskId == null) {
        throw Exception("Failed to enqueue download task.");
      }

      _downloadTaskId = taskId;

      dialogSetState(() {
      });

    } catch (e) {
      dialogSetState(() {
        _isDownloading = false;
      });
      debugPrint("Error during download process: $e");
      onDownloadCancelledOrFailed();
    }
  }

  Future<bool> _requestPermissions() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    final int sdkVersion = androidInfo.version.sdkInt;

    var installPermissionStatus = await Permission.requestInstallPackages.status;
    if (!installPermissionStatus.isGranted) {
      installPermissionStatus = await Permission.requestInstallPackages.request();
    }
    if (!installPermissionStatus.isGranted) {
      debugPrint("Request install packages permission denied.");
      return false;
    }

    if (sdkVersion < 30) {
      var storagePermissionStatus = await Permission.storage.status;
      if (!storagePermissionStatus.isGranted) {
        storagePermissionStatus = await Permission.storage.request();
      }
      if (!storagePermissionStatus.isGranted) {
        debugPrint("Storage permission denied.");
        return false;
      }
    }

    if (sdkVersion >= 33) {
      var notificationPermission = await Permission.notification.status;
      if (!notificationPermission.isGranted) {
        notificationPermission = await Permission.notification.request();
      }
    }

    return true;
  }

  Future<String> _getDownloadPath() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      final int sdkVersion = androidInfo.version.sdkInt;

      String path;
      if (sdkVersion >= 30) {
        final directory = await getExternalStorageDirectory();
        path = directory?.path ?? (await getApplicationDocumentsDirectory()).path;
      } else {
        try {
          path = await AndroidPathProvider.downloadsPath;
        } catch (e) {
          final directory = await getExternalStorageDirectory();
          path = directory?.path ?? (await getApplicationDocumentsDirectory()).path;
        }
      }
      debugPrint("Using download path: $path");
      return path;
    } catch (e) {
      debugPrint("Error getting download path: $e");
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> _installApk(String taskId) async {
    if (!mounted) return;

    setState(() {
      _installationInitiated = false;
    });

    try {
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id = '$taskId'"
      );

      if (tasks == null || tasks.isEmpty) {
        debugPrint("No task found with ID: $taskId");
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      final task = tasks.first;
      final filePath = "${task.savedDir}/${task.filename}";
      final file = File(filePath);

      debugPrint("Checking file at path: $filePath");

      if (await file.exists()) {
        debugPrint("File exists, attempting installation");

        bool openResult = false;
        try {
          openResult = await FlutterDownloader.open(taskId: taskId);
          debugPrint("FlutterDownloader.open result: $openResult");
        } catch (e) {
          debugPrint("Error with FlutterDownloader.open: $e");
        }

        if (!openResult) {
          debugPrint("FlutterDownloader.open failed, trying direct file installation");

          try {
            final intent = AndroidIntent(
              action: 'android.intent.action.VIEW',
              data: 'file://$filePath',
              type: 'application/vnd.android.package-archive',
              flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            );
            await intent.launch();
            debugPrint("Intent launched for installation");

            setState(() {
              _installationInitiated = true;
            });
          } catch (intentError) {
            debugPrint("Error launching intent: $intentError");

            try {
              final openAnyResult = await OpenFile.open(filePath);
              debugPrint("OpenFile result: ${openAnyResult.message}");

              setState(() {
                _installationInitiated = true;
              });
            } catch (openError) {
              debugPrint("Error opening file: $openError");
              setState(() {
                _isDownloading = false;
              });
            }
          }
        } else {
          debugPrint("FlutterDownloader.open succeeded");
          setState(() {
            _installationInitiated = true;
          });
        }
      } else {
        debugPrint("File does not exist at path: $filePath");
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint("Error during installation attempt: $e");
      setState(() {
        _isDownloading = false;
      });
    }
  }

  // ── INI FUNGSI KRUSIAL: Pengecekan status login via SessionManager ────────
  Future<void> _checkLoginStatus() async {
    if (_isDownloading || _installationInitiated) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final session      = await SessionManager.instance.getActiveSession();

    // Kedua-duanya harus valid — Supabase session + local session
    final isLoggedIn = supabaseUser != null && session != null;
    final userRole   = session?.role;

    if (!mounted) return;

    if (isLoggedIn && userRole != null) {
      switch (userRole.toLowerCase()) {
        case 'admin':
          context.go('/admin');
          break;
        case 'psp':
          context.go('/psp');
          break;
        case 'hsp':
          context.go('/hsp');
          break;
        case 'psphsp':
          context.go('/psphsp');
          break;
        case 'pi':
          context.go('/pi');
          break;
      // FI, SPV, Dev, Manager, QA → /qa
        default:
          context.go('/qa');
          break;
      }
    } else {
      context.go('/login');
    }
  }

  // ── Update Dialog (UI Baru, Logika Lama) ────────────────────────────────
  void _showUpdateDialog(bool forceUpdate, String newVersion, String apkUrl) {
    debugPrint("Showing update dialog: force=$forceUpdate, url=$apkUrl");

    _isDownloading        = false;
    _installationInitiated = false;
    _downloadTaskId       = null;

    showDialog(
      context          : context,
      barrierDismissible: !forceUpdate && !_isDownloading,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (ctx, StateSetter dialogSetState) {

            // Menggunakan logic handle lanjutan dari yang lama
            void handleNonForcedUpdateContinuation() {
              if (!forceUpdate && mounted) {
                debugPrint("Non-forced update cancelled or failed, closing dialog and proceeding.");
                Navigator.of(dialogContext).pop();
                _checkLoginStatus();
              } else if (forceUpdate) {
                debugPrint("Forced update failed, staying in dialog.");
              }
            }

            return PopScope(
              canPop: !forceUpdate && !_isDownloading && !_installationInitiated,
              onPopInvokedWithResult: (bool didPop, dynamic result) {
                debugPrint("Update Dialog PopScope: didPop=$didPop");
                if (didPop && !forceUpdate) {
                  debugPrint("Dialog popped (non-forced), proceeding with app flow.");
                  _checkLoginStatus();
                }
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Dialog(
                  shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation      : 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding   : const EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      color       : AdvantaColors.cream,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow   : [
                        BoxShadow(
                          color     : AdvantaColors.deepForest.withAlpha(80),
                          blurRadius: 40,
                          offset    : const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children    : [
                        // Header strip
                        Container(
                          padding     : const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          decoration  : const BoxDecoration(
                            color       : AdvantaColors.primaryGreen,
                            borderRadius: BorderRadius.only(
                              topLeft : Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding   : const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color       : AdvantaColors.gold.withAlpha(40),
                                  borderRadius: BorderRadius.circular(10),
                                  border      : Border.all(color: AdvantaColors.gold.withAlpha(100)),
                                ),
                                child: const Icon(Icons.system_update_rounded, color: AdvantaColors.goldLight, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pembaruan Tersedia',
                                      style: TextStyle(
                                        color     : Colors.white,
                                        fontSize  : 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      'Versi $newVersion',
                                      style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (forceUpdate)
                                Container(
                                  padding   : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color       : AdvantaColors.gold,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'WAJIB',
                                    style: TextStyle(
                                      color     : AdvantaColors.charcoal,
                                      fontSize  : 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Body
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                forceUpdate
                                    ? 'Pembaruan wajib dipasang untuk melanjutkan penggunaan aplikasi.'
                                    : 'Versi terbaru tersedia. Disarankan untuk memperbarui agar mendapatkan fitur terkini.',
                                style: const TextStyle(
                                  color : AdvantaColors.charcoal,
                                  fontSize: 14,
                                  height  : 1.55,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Download progress
                              ValueListenableBuilder<double>(
                                valueListenable: _downloadProgressNotifier,
                                builder: (_, prog, __) {
                                  if (!_isDownloading) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value          : prog,
                                          minHeight      : 6,
                                          backgroundColor: AdvantaColors.primaryGreen.withAlpha(30),
                                          valueColor     : const AlwaysStoppedAnimation<Color>(AdvantaColors.gold),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ValueListenableBuilder<String>(
                                        valueListenable: _downloadMessageNotifier,
                                        builder: (_, msg, __) => Text(
                                          msg,
                                          style: const TextStyle(
                                            color   : AdvantaColors.primaryGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  );
                                },
                              ),

                              // Buttons
                              Row(
                                children: [
                                  if (!forceUpdate && !_isDownloading) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: handleNonForcedUpdateContinuation,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          side   : const BorderSide(color: AdvantaColors.midGreen),
                                        ),
                                        child: const Text(
                                          'Nanti',
                                          style: TextStyle(color: AdvantaColors.primaryGreen, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: _isDownloading
                                          ? null
                                          : () => _downloadAndInstallUpdate(apkUrl, dialogSetState, handleNonForcedUpdateContinuation),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AdvantaColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: AdvantaColors.primaryGreen.withAlpha(100),
                                        padding  : const EdgeInsets.symmetric(vertical: 14),
                                        shape    : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      child: _isDownloading
                                          ? const SizedBox(
                                        width : 18,
                                        height: 18,
                                        child : CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color      : Colors.white,
                                        ),
                                      )
                                          : const Text(
                                        'Unduh & Pasang',
                                        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      debugPrint("Update dialog closed.");
      if (!forceUpdate && mounted && !_isDownloading && !_installationInitiated) {
        _checkLoginStatus();
      }
    }).catchError((error) {
      debugPrint("Error showing/handling dialog: $error");
      if (!forceUpdate && mounted) {
        _checkLoginStatus();
      }
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();

    if (_isPortInitialized) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
    }
    _port.close();
    _downloadProgressNotifier.dispose();
    _downloadMessageNotifier.dispose();
    super.dispose();
  }

  // ── BUILD (TERINTEGRASI DENGAN THEME) ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Warna adaptif untuk Background Splash
    final bgColors = isDark
        ? [AdvantaColors.deepForest, const Color(0xFF112E20), const Color(0xFF0A2318)] // Corporate Luxury
        : [AdvantaColors.cream, AdvantaColors.softGrey, const Color(0xFFE0E3E0)]; // High Readability Light Mode

    // Warna adaptif untuk teks
    final mainTextColor = isDark ? Colors.white : AdvantaColors.deepForest;
    final subTextColor = isDark ? Colors.white.withAlpha(170) : AdvantaColors.midGreen;
    final accentLineColor = isDark ? AdvantaColors.gold : AdvantaColors.primaryGreen;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── 1. Background Dinamis ─────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: bgColors,
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // ── 2. Subtle geometric pattern ─
          Positioned.fill(
            child: CustomPaint(painter: _HexPatternPainter(isDark)),
          ),

          // ── 3. Accent arc top-right ──────────
          Positioned(
            top: -size.width * 0.35,
            right: -size.width * 0.35,
            child: Container(
              width: size.width * 0.9,
              height: size.width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentLineColor.withAlpha(isDark ? 25 : 15),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // ── 5. Main Content ───────────────────────
          SafeArea(
            child: AnimatedBuilder(
              animation: _masterController,
              builder: (_, __) {
                return Column(
                  children: [
                    SizedBox(height: size.height * 0.10),
                    Opacity(
                      opacity: _logoFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _logoSlide.value.dy * 60),
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: _buildLogoBlock(mainTextColor, subTextColor, isDark),
                        ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.045),
                    _buildAnimatedDivider(accentLineColor),
                    SizedBox(height: size.height * 0.04),
                    Opacity(
                      opacity: _taglineFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _taglineSlide.value.dy * 40),
                        child: _buildTagline(isDark),
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: _footerFade.value,
                      child: _buildLoadingSection(accentLineColor, mainTextColor),
                    ),
                    SizedBox(height: size.height * 0.07),
                    Opacity(
                      opacity: _footerFade.value,
                      child: _buildFooter(mainTextColor, accentLineColor),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoBlock(Color mainText, Color subText, bool isDark) {
    return Column(
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: (isDark ? AdvantaColors.gold : AdvantaColors.primaryGreen).withAlpha(60), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AdvantaColors.primaryGreen, AdvantaColors.deepForest],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AdvantaColors.lightGreen.withAlpha(isDark ? 60 : 20),
                    blurRadius: 24, spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: SvgPicture.asset(
                  'assets/logo_kc.svg',
                  placeholderBuilder: (_) => const Icon(Icons.agriculture_rounded, color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('KROSCEK', style: TextStyle(color: mainText, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6)),
        const SizedBox(height: 8),
        Text('Crop Inspection and Check Result', style: TextStyle(color: subText, fontSize: 13, letterSpacing: 2.5)),
      ],
    );
  }

  Widget _buildAnimatedDivider(Color accentColor) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: SizedBox(
            height: 2,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final w = constraints.maxWidth * _dividerWidth.value;
                return Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.transparent,
                        accentColor,
                        AdvantaColors.goldLight,
                        accentColor,
                        Colors.transparent,
                      ],
                      stops: [
                        0.0,
                        (_shimmer.value - 0.3).clamp(0.0, 1.0),
                        _shimmer.value.clamp(0.0, 1.0),
                        (_shimmer.value + 0.3).clamp(0.0, 1.0),
                        1.0,
                      ],
                    ).createShader(bounds),
                    child: Container(width: w, height: 2, color: Colors.white),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagline(bool isDark) {
    final badgeColor = isDark ? AdvantaColors.gold : AdvantaColors.primaryGreen;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: badgeColor.withAlpha(80)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text('INSPECTIONS APP', style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.0)),
              const SizedBox(width: 10),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Solusi Audit Lahan\nBerbasis Data Real-Time',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white.withAlpha(200) : AdvantaColors.charcoal, fontSize: 15, height: 1.7),
        ),
      ],
    );
  }

  Widget _buildLoadingSection(Color accentColor, Color textColor) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final delay = i * 0.33;
                final t = ((_pulseController.value - delay) % 1.0).abs();
                final opacity = Curves.easeInOut.transform((t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0));
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: accentColor.withAlpha((opacity * 255).round()), shape: BoxShape.circle),
                );
              }),
            ),
            const SizedBox(height: 14),
            Text('Memuat sistem...', style: TextStyle(color: textColor.withAlpha(120), fontSize: 12, letterSpacing: 1.5)),
          ],
        );
      },
    );
  }

  Widget _buildFooter(Color textColor, Color accentColor) {
    return Column(
      children: [
        Container(width: 48, height: 1, color: accentColor.withAlpha(60)),
        const SizedBox(height: 14),
        Text('© 2024-${DateTime.now().year} Advanta Seeds Indonesia', style: TextStyle(color: textColor.withAlpha(100), fontSize: 11)),
        const SizedBox(height: 6),
        if (_version.isNotEmpty)
          Text('v$_version', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// Tambahkan penyesuaian parameter warna ke HexPatternPainter
class _HexPatternPainter extends CustomPainter {
  final bool isDark;
  _HexPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0x06FFFFFF) : const Color(0x06000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const r   = 28.0;
    const h   = r * 1.732; // sqrt(3) * r
    const col = r * 1.5;

    int row = 0;
    for (double y = -h; y < size.height + h; y += h) {
      final offset = (row % 2 == 0) ? 0.0 : col;
      for (double x = -col + offset; x < size.width + col; x += col * 2) {
        _drawHex(canvas, paint, Offset(x, y), r);
      }
      row++;
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.14159 / 180;
      final px    = center.dx + r * _cos(angle);
      final py    = center.dy + r * _sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  static double _cos(double x) {
    x = x % (2 * 3.14159265);
    return 1 - x * x / 2 + x * x * x * x / 24;
  }

  static double _sin(double x) {
    x = x % (2 * 3.14159265);
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
