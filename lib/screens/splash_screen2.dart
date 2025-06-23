// Splash Screen Backup File
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// New imports
import 'package:android_path_provider/android_path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

    _initializeDownloader();
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

  Future<void> _initializeDownloader() async {
    // Initialize FlutterDownloader
    await FlutterDownloader.initialize(
      debug: true, // Set to false in production
    );

    // Register callback for download progress
    // ---- AWAL PERBAIKAN: Menambahkan tipe eksplisit pada parameter callback ----
    // Replace the current callback registration with:
    // Replace your current callback registration with this:
    FlutterDownloader.registerCallback((id, status, progress) {
      debugPrint('Download task ($id) is in status ($status) and process ($progress)');

      if (mounted) {
        setState(() {
          if (id == _downloadTaskId) {
            _downloadProgress = progress / 100;

            // Convert int status to DownloadTaskStatus enum
            final DownloadTaskStatus taskStatus = DownloadTaskStatus.values[status];

            // Now compare with the enum values
            if (taskStatus == DownloadTaskStatus.running) {
              _downloadMessage = "Mengunduh: $progress%";
            } else if (taskStatus == DownloadTaskStatus.complete) {
              _downloadMessage = "Unduhan selesai. Memulai instalasi...";
              _installApk();
            } else if (taskStatus == DownloadTaskStatus.failed) {
              _isDownloading = false;
              _downloadMessage = "Unduhan gagal. Silakan coba lagi.";
            }
            // Handle other statuses
            else if (taskStatus == DownloadTaskStatus.paused) {
              _downloadMessage = "Unduhan dijeda.";
            } else if (taskStatus == DownloadTaskStatus.canceled) {
              _isDownloading = false;
              _downloadMessage = "Unduhan dibatalkan.";
            } else if (taskStatus == DownloadTaskStatus.enqueued) {
              _downloadMessage = "Unduhan dalam antrean...";
            }
          }
        });
      }
    });
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
      debugPrint("Memeriksa pembaruan aplikasi...");

      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!snapshot.exists) {
        debugPrint("Dokumen versi tidak ditemukan di Firestore");
        return;
      }

      Map<String, dynamic>? data;
      try {
        data = snapshot.data() as Map<String, dynamic>?;
      } catch (e) {
        debugPrint("Error saat mengkonversi data: $e");
        return;
      }

      if (data == null) {
        debugPrint("Data dari Firestore adalah null");
        return;
      }

      final latestVersion = data['current_version'] as String?;
      final forceUpdate = data['force_update'] as bool?;
      final downloadUrl = data['download_url'] as String?;

      if (latestVersion == null) {
        debugPrint("current_version tidak ditemukan di Firestore");
        return;
      }
      if (downloadUrl == null) {
        debugPrint("download_url tidak ditemukan di Firestore, tidak dapat memperbarui.");
        return;
      }

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      debugPrint("Versi saat ini: $currentVersion");
      debugPrint("Versi terbaru: $latestVersion");
      debugPrint("Force update: ${forceUpdate ?? false}");
      debugPrint("Download URL: $downloadUrl");

      // Compare versions
      if (currentVersion != latestVersion) {
        _updateRequired = true;
        if (mounted) {
          _showUpdateDialog(forceUpdate ?? false, latestVersion, downloadUrl);
        }
      } else {
        debugPrint("Aplikasi sudah menggunakan versi terbaru");
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
      _downloadProgress = 0.0;
      _downloadMessage = "Mempersiapkan unduhan...";
    });

    // Request necessary permissions
    bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      dialogSetState(() {
        _isDownloading = false;
        _downloadMessage = "Izin diperlukan untuk mengunduh pembaruan.";
      });
      onDownloadCancelledOrFailed();
      return;
    }

    try {
      // Get download directory
      final String downloadPath = await _getDownloadPath();
      final Directory downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Create a unique filename with timestamp
      final String fileName = 'app-update-${DateTime.now().millisecondsSinceEpoch}.apk';

      // Start download with FlutterDownloader
      _downloadTaskId = await FlutterDownloader.enqueue(
        url: apkUrl,
        savedDir: downloadPath,
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );

      dialogSetState(() {
        _downloadMessage = "Mengunduh pembaruan...";
      });

    } catch (e) {
      dialogSetState(() {
        _isDownloading = false;
        _downloadMessage = "Error: ${e.toString()}";
      });
      debugPrint("Error saat proses unduh: $e");
      onDownloadCancelledOrFailed();
    }
  }

  Future<bool> _requestPermissions() async {
    // Check Android version
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    final int sdkVersion = androidInfo.version.sdkInt;

    // Request installation permission
    var installPermissionStatus = await Permission.requestInstallPackages.status;
    if (installPermissionStatus.isDenied) {
      installPermissionStatus = await Permission.requestInstallPackages.request();
    }
    if (!installPermissionStatus.isGranted) {
      return false;
    }

    // For Android 10 (API 29) and below, request storage permission
    if (sdkVersion < 30) {
      var storagePermissionStatus = await Permission.storage.status;
      if (storagePermissionStatus.isDenied) {
        storagePermissionStatus = await Permission.storage.request();
      }
      if (!storagePermissionStatus.isGranted) {
        return false;
      }
    }

    return true;
  }

  Future<String> _getDownloadPath() async {
    try {
      // For Android 10+ use app-specific directory
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
      // Ultimate fallback
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  Future<void> _installApk([String? taskId]) async {
    try {
      final String? idToUse = taskId ?? _downloadTaskId;
      if (idToUse == null) {
        debugPrint("No download task ID available");
        return;
      }

      final tasks = await FlutterDownloader.loadTasksWithRawQuery(
          query: "SELECT * FROM task WHERE task_id = '$idToUse'"
      );

      if (tasks == null || tasks.isEmpty) {
        debugPrint("No task found with ID: $idToUse");
        setState(() {
          _downloadMessage = "File tidak ditemukan. Silakan coba lagi.";
        });
        return;
      }

      final task = tasks.first;
      final filePath = "${task.savedDir}/${task.filename}";
      final file = File(filePath);

      debugPrint("Checking file at path: $filePath");

      if (await file.exists()) {
        debugPrint("File exists, attempting to open for installation");

        // Try direct installation first
        final result = await FlutterDownloader.open(taskId: idToUse);

        if (!result) {
          debugPrint("Failed to open with FlutterDownloader, trying alternative method");
          // Add alternative installation method if needed
          setState(() {
            _downloadMessage = "Instalasi gagal. Silakan buka file secara manual dari folder Download.";
          });
        } else {
          debugPrint("Installation process started successfully");
          setState(() {
            _downloadMessage = "Memulai instalasi...";
          });
        }
      } else {
        debugPrint("File does not exist at path: $filePath");
        setState(() {
          _downloadMessage = "File APK tidak ditemukan di lokasi yang diharapkan.";
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error during installation: $e");
      debugPrint("Stack trace: $stackTrace");
      setState(() {
        _downloadMessage = "Error saat instalasi: $e";
      });
    }
  }

  void _showUpdateDialog(bool forceUpdate, String newVersion, String apkUrl) {
    debugPrint("Menampilkan dialog update dengan force=$forceUpdate, url=$apkUrl");

    // Reset download status
    _isDownloading = false;
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
                Navigator.of(dialogContext).pop();
                _checkLoginStatus();
              } else if (forceUpdate) {
                dialogSetState(() {
                  // Message already set by download method
                });
              }
            }

            return PopScope(
              canPop: !forceUpdate && !_isDownloading,
              onPopInvokedWithResult: (bool didPop, dynamic result) {
                if (didPop) {
                  debugPrint("PopScope: Dialog di-pop, didPop: $didPop");
                  if (!_isDownloading && !forceUpdate) {
                    _checkLoginStatus();
                  }
                } else {
                  debugPrint("PopScope: Upaya pop dicegah oleh canPop=false atau alasan lain, didPop: $didPop");
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
                      Container(
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
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Pembaruan Tersedia",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Versi $newVersion",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        forceUpdate
                            ? "Anda perlu memperbarui aplikasi untuk melanjutkan."
                            : "Versi baru tersedia. Perbarui sekarang?",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Show progress if downloading
                      if (_isDownloading) ...[
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                          minHeight: 10,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _downloadMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Buttons
                      if (!_isDownloading)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!forceUpdate)
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    _checkLoginStatus();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: const Text(
                                    "Nanti",
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
                                  _downloadAndInstallUpdate(apkUrl, dialogSetState, handleNonForcedUpdateContinuation);
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
                                child: const Text(
                                  "Perbarui Sekarang",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      if (forceUpdate && !_isDownloading)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Text(
                            _downloadMessage.isNotEmpty && (_downloadMessage.contains("Gagal") || _downloadMessage.contains("Error"))
                                ? _downloadMessage
                                : "Pembaruan ini wajib untuk melanjutkan.",
                            style: TextStyle(
                              fontSize: 13,
                              color: _downloadMessage.isNotEmpty && (_downloadMessage.contains("Gagal") || _downloadMessage.contains("Error"))
                                  ? Colors.red.shade700
                                  : Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (forceUpdate && !_isDownloading && (_downloadMessage.contains("Gagal") || _downloadMessage.contains("Error")))
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: ElevatedButton(
                            onPressed: () {
                              _downloadAndInstallUpdate(apkUrl, dialogSetState, handleNonForcedUpdateContinuation);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Coba Lagi Unduh"),
                          ),
                        ),
                      if (!_isDownloading && (_downloadMessage.contains("Instalasi gagal") || _downloadMessage.contains("secara manual")))
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: ElevatedButton(
                            onPressed: () {
                              _installApk(); // Try installation again
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Coba Install Lagi"),
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
      debugPrint("Dialog update ditutup.");
      if (!forceUpdate && mounted && !_isDownloading) {
        if (_updateRequired) {
          _checkLoginStatus();
        }
      }
    }).catchError((error) {
      debugPrint("Error saat menampilkan dialog: $error");
    });
  }

  Future<void> _checkLoginStatus() async {
    if (_isDownloading) {
      debugPrint("Masih dalam proses unduhan, _checkLoginStatus ditunda.");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final userRole = prefs.getString('userRole');

    if (!mounted) return;

    if (isLoggedIn && userRole != null) {
      switch (userRole) {
        case 'admin':
          context.go('/admin');
          break;
        case 'psp':
          context.go('/psp');
          break;
        default:
          context.go('/home');
          break;
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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