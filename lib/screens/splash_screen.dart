import 'package:flutter/material.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:isolate';
import 'dart:ui';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:open_file/open_file.dart';

// New imports
import 'package:android_path_provider/android_path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

// LANGKAH 1: Pindahkan downloadCallback ke luar kelas (menjadi top-level function).
// Anotasi @pragma('vm:entry-point') penting agar Flutter tahu fungsi ini bisa dijalankan di background.
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  debugPrint("DOWNLOAD_CALLBACK: Task id=$id, status=$status, progress=$progress%");

  // Cari port komunikasi yang sudah kita daftarkan di main isolate.
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  if (send != null) {
    // Kirim data (id, status, progress) kembali ke main isolate.
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  String _version = 'Loading...';
  bool _updateRequired = false;

  // Download state variables
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadMessage = "";
  String? _downloadTaskId;
  bool _installationInitiated = false;
  final ReceivePort _port = ReceivePort();
  bool _isPortInitialized = false;

  final ValueNotifier<double> _downloadProgressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> _downloadMessageNotifier = ValueNotifier("");

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.decelerate,
      ),
    );

    // LANGKAH 2: Panggil fungsi inisialisasi yang sudah digabungkan.
    _initializeAndSetupDownloader();

    _controller.forward();
    _fetchVersion();

    _checkForUpdate().then((_) {
      if (!_updateRequired && mounted) {
        Timer(const Duration(seconds: 4), () {
          if (mounted) _checkLoginStatus();
        });
      }
    });
  }

  // LANGKAH 3: Gabungkan _initializeDownloader dan _setupPortListener menjadi satu fungsi.
  Future<void> _initializeAndSetupDownloader() async {
    try {
      // 1. Inisialisasi FlutterDownloader
      // `ignoreSsl: true` berguna saat development jika server download
      // tidak memiliki sertifikat SSL yang valid. Hati-hati saat production.
      await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

      // 2. Daftarkan callback top-level kita.
      FlutterDownloader.registerCallback(downloadCallback);

      // 3. Siapkan port untuk komunikasi antar isolate (hanya jika belum diinisialisasi).
      if (!_isPortInitialized) {
        IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
        _isPortInitialized = true;

        // 4. Dengarkan data yang dikirim dari `downloadCallback`.
        _port.listen((dynamic data) {
          if (data is List && data.length >= 3) {
            String id = data[0] as String;
            DownloadTaskStatus status = DownloadTaskStatus.fromInt(data[1] as int);
            int progress = data[2] as int;

            debugPrint('NOTIFIER CALLBACK: id=$id, status=$status, progress=$progress');

            // Pastikan update UI hanya untuk task download yang sedang aktif.
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
        setState(() => _version = 'Updated Version ${packageInfo.version}');
      }
    } catch (e) {
      if (mounted) setState(() => _version = 'Development Version');
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      debugPrint("Checking for app updates...");

      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!snapshot.exists) {
        debugPrint("Version document not found in Firestore");
        return;
      }

      Map<String, dynamic>? data;
      try {
        data = snapshot.data() as Map<String, dynamic>?;
      } catch (e) {
        debugPrint("Error converting data: $e");
        return;
      }

      if (data == null) {
        debugPrint("Data from Firestore is null");
        return;
      }

      final latestVersion = data['current_version'] as String?;
      final forceUpdate = data['force_update'] as bool?;
      final downloadUrl = data['download_url'] as String?;

      if (latestVersion == null) {
        debugPrint("current_version not found in Firestore");
        return;
      }
      if (downloadUrl == null) {
        debugPrint("download_url not found in Firestore, cannot update.");
        return;
      }

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      debugPrint("Current version: $currentVersion");
      debugPrint("Latest version: $latestVersion");
      debugPrint("Force update: ${forceUpdate ?? false}");
      debugPrint("Download URL: $downloadUrl");

      if (currentVersion != latestVersion) {
        _updateRequired = true;
        if (mounted) {
          _showUpdateDialog(forceUpdate ?? false, latestVersion, downloadUrl);
        }
      } else {
        debugPrint("App is up to date");
      }
    } catch (e, stackTrace) {
      debugPrint("Error checking for update: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  Future<void> _downloadAndInstallUpdate(
      String apkUrl, StateSetter dialogSetState, VoidCallback onDownloadCancelledOrFailed) async {

    dialogSetState(() {
      _isDownloading = true;
      _installationInitiated = false;
      _downloadProgress = 0.0;
      _downloadMessage = "Preparing download...";
    });

    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      dialogSetState(() {
        _isDownloading = false;
        _downloadMessage = "Permissions required to download update.";
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

      final String fileName = 'app-update-${DateTime.now().millisecondsSinceEpoch}.apk';

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
        _downloadMessage = "Download starting...";
      });

    } catch (e) {
      dialogSetState(() {
        _isDownloading = false;
        _downloadMessage = "Error during download: ${e.toString()}";
      });
      debugPrint("Error during download process: $e");
      onDownloadCancelledOrFailed();
    }
  }

  // Sisa kode di bawah ini tetap sama, tidak perlu diubah.
  // ... (sisa kode dari _requestPermissions hingga akhir file tidak berubah)
  // ...

  Future<bool> _requestPermissions() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    final int sdkVersion = androidInfo.version.sdkInt;

    // Request install permission
    var installPermissionStatus = await Permission.requestInstallPackages.status;
    if (!installPermissionStatus.isGranted) {
      installPermissionStatus = await Permission.requestInstallPackages.request();
    }
    if (!installPermissionStatus.isGranted) {
      debugPrint("Request install packages permission denied.");
      return false;
    }

    // Storage permission for older Android versions
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
    // For Android 13+ (API 33), Notification permission might be needed for downloader notification
    if (sdkVersion >= 33) {
      var notificationPermission = await Permission.notification.status;
      if (!notificationPermission.isGranted) {
        notificationPermission = await Permission.notification.request();
      }
      // Not strictly required for download/install logic, but good for UX
      if (!notificationPermission.isGranted) {
        debugPrint("Notification permission denied (optional).");
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
        // For Android 11+, use app-specific directory
        final directory = await getExternalStorageDirectory();
        path = directory?.path ?? (await getApplicationDocumentsDirectory()).path;
      } else {
        // For older versions, use Downloads directory
        try {
          path = await AndroidPathProvider.downloadsPath;
        } catch (e) {
          // Fallback to app's external storage
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
      _downloadMessage = "Opening APK file for installation...";
      _installationInitiated = false;
    });

    try {
      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id = '$taskId'"
      );

      if (tasks == null || tasks.isEmpty) {
        debugPrint("No task found with ID: $taskId");
        setState(() {
          _downloadMessage = "Downloaded file not found. Please try again.";
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
              _downloadMessage = "Installation started. Please follow the system prompts.";
              _installationInitiated = true;
            });
          } catch (intentError) {
            debugPrint("Error launching intent: $intentError");

            try {
              final openAnyResult = await OpenFile.open(filePath);
              debugPrint("OpenFile result: ${openAnyResult.message}");

              setState(() {
                _downloadMessage = "Installation started. Please follow the system prompts.";
                _installationInitiated = true;
              });
            } catch (openError) {
              debugPrint("Error opening file: $openError");
              setState(() {
                _downloadMessage = "Could not open the APK file. Please install manually from: $filePath";
                _isDownloading = false;
              });
            }
          }
        } else {
          debugPrint("FlutterDownloader.open succeeded");
          setState(() {
            _downloadMessage = "Installation started. Please follow the system prompts.";
            _installationInitiated = true;
          });
        }
      } else {
        debugPrint("File does not exist at path: $filePath");
        setState(() {
          _downloadMessage = "Downloaded APK file not found at the expected location.";
          _isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint("Error during installation attempt: $e");
      setState(() {
        _downloadMessage = "Error during installation: ${e.toString()}";
        _isDownloading = false;
      });
    }
  }

  void _showUpdateDialog(bool forceUpdate, String newVersion, String apkUrl) {
    debugPrint("Showing update dialog: force=$forceUpdate, url=$apkUrl");

    _isDownloading = false;
    _installationInitiated = false;
    _downloadProgress = 0.0;
    _downloadMessage = "";
    _downloadTaskId = null;

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate && !_isDownloading,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, StateSetter dialogSetState) {
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
                debugPrint("Update Dialog PopScope: didPop=$didPop, canPop=${!forceUpdate && !_isDownloading && !_installationInitiated}");
                if (didPop && !forceUpdate) {
                  debugPrint("Dialog popped (non-forced), proceeding with app flow.");
                  _checkLoginStatus();
                }
              },
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10.0,
                        offset: Offset(0.0, 10.0),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isDownloading || _installationInitiated
                          ? _buildProgressHeader(dialogSetState)
                          : _buildUpdateHeader(),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Version $newVersion",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (!_isDownloading && !_installationInitiated)
                        Text(
                          forceUpdate
                              ? "You need to update the app to continue."
                              : "A new version is available. Update now?",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),

                      if (_isDownloading || _installationInitiated) ...[
                        const SizedBox(height: 25),
                        _buildProgressIndicator(),
                      ],

                      const SizedBox(height: 25),

                      if (!_isDownloading && !_installationInitiated) ...[
                        _buildActionButtons(forceUpdate, apkUrl, dialogSetState, handleNonForcedUpdateContinuation),
                      ],

                      if (_installationInitiated)
                        Padding(
                          padding: const EdgeInsets.only(top: 15.0),
                          child: Text(
                            "Follow system prompts to complete the installation. The app might close automatically after update.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade700),
                          ),
                        ),
                    ],
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
        debugPrint("Dialog closed callback: Proceeding with app flow if needed.");
        _checkLoginStatus();
      }
    }).catchError((error) {
      debugPrint("Error showing/handling dialog: $error");
      if (!forceUpdate && mounted) {
        _checkLoginStatus();
      }
    });
  }

  Widget _buildUpdateHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.system_update,
        color: Colors.green.shade700,
        size: 40,
      ),
    );
  }

  Widget _buildProgressHeader(StateSetter setState) {
    IconData icon;
    Color color;

    if (_installationInitiated) {
      icon = Icons.android;
      color = Colors.green.shade700;
    } else if (_downloadProgress >= 1.0) {
      icon = Icons.check_circle;
      color = Colors.green.shade700;
    } else {
      icon = Icons.download;
      color = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 40,
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return ValueListenableBuilder<double>(
      valueListenable: _downloadProgressNotifier,
      builder: (context, progress, _) {
        return ValueListenableBuilder<String>(
          valueListenable: _downloadMessageNotifier,
          builder: (context, message, _) {
            return Column(
              children: [
                if (_isDownloading && !_installationInitiated) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.green.shade600 : Colors.blue.shade600
                          ),
                          strokeWidth: 8,
                        ),
                      ),
                      Text(
                        "${(progress * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: progress >= 1.0 ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                Padding(
                  padding: const EdgeInsets.only(top: 10.0, left: 16.0, right: 16.0),
                  child: Text(
                    "Proses download sedang berlangsung, cek di bilah notifikasi...\n*Jika download selesai, cek apk di folder download(file manager).",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.blueGrey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                if (message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: _getStatusColor(message).withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(message),
                          color: _getStatusColor(message),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(message),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String message) {
    if (message.contains("failed") || message.contains("Error") || message.contains("Gagal")) {
      return Colors.red.shade700;
    } else if (message.contains("complete") || message.contains("Installation started")) {
      return Colors.green.shade700;
    } else if (message.contains("paused")) {
      return Colors.orange.shade700;
    } else {
      return Colors.blue.shade700;
    }
  }

  IconData _getStatusIcon(String message) {
    if (message.contains("failed") || message.contains("Error") || message.contains("Gagal")) {
      return Icons.error_outline;
    } else if (message.contains("complete") || message.contains("Installation started")) {
      return Icons.check_circle_outline;
    } else if (message.contains("paused")) {
      return Icons.pause_circle_outline;
    } else if (message.contains("Preparing")) {
      return Icons.settings;
    } else {
      return Icons.info_outline;
    }
  }

  Widget _buildActionButtons(bool forceUpdate, String apkUrl, StateSetter setState, VoidCallback onCancelCallback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!forceUpdate)
          Expanded(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: const Text(
                "Later",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (!forceUpdate) const SizedBox(width: 15),

        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _downloadAndInstallUpdate(apkUrl, setState, onCancelCallback);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _downloadMessage.contains("failed") || _downloadMessage.contains("Error") || _downloadMessage.contains("Gagal")
                  ? "Retry Download"
                  : "Update Now",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _checkLoginStatus() async {
    if (_isDownloading || _installationInitiated) {
      debugPrint("Update process active, _checkLoginStatus deferred.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userRole = prefs.getString('userRole');

    if (!mounted) return;

    debugPrint("Checking login status: isLoggedIn=$isLoggedIn, userRole=$userRole");

    if (isLoggedIn && userRole != null) {
      switch (userRole) {
        case 'admin':
          context.go('/admin');
          break;
        case 'psp':
          context.go('/psp');
          break;
        case 'hsp':
          context.go('/hsp');
          break;
        default:
          context.go('/qa');
          break;
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();

    if (_isPortInitialized) {
      IsolateNameServer.removePortNameMapping('downloader_send_port');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final white200 = Colors.white.withAlpha(200);
    final white150 = Colors.white.withAlpha(150);

    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 35),
                      Text(
                        'Crop Inspection\nand Check Result',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      SizedBox(height: size.height * 0.1),
                      Column(
                        children: [
                          Text(
                            '© ${DateTime.now().year} Tim Cengoh, Ahli Huru-Hara',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: white200,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _version,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: white150,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}