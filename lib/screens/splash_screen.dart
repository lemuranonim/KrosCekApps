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
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _initializeAndSetupDownloader();

    _controller.forward();
    _fetchVersion();

    _checkForUpdate().then((_) {
      if (!_updateRequired && mounted) {
        Timer(const Duration(milliseconds: 3500), () {
          if (mounted) _checkLoginStatus();
        });
      }
    });
  }

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

      if (latestVersion == null || downloadUrl == null) {
        debugPrint("Version or download URL not found");
        return;
      }

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      debugPrint("Current version: $currentVersion");
      debugPrint("Latest version: $latestVersion");

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
                debugPrint("Update Dialog PopScope: didPop=$didPop");
                if (didPop && !forceUpdate) {
                  debugPrint("Dialog popped (non-forced), proceeding with app flow.");
                  _checkLoginStatus();
                }
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.green.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha(60),
                          blurRadius: 30,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade400, Colors.green.shade600],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withAlpha(60),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            "Version $newVersion",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (!_isDownloading && !_installationInitiated)
                          Text(
                            forceUpdate
                                ? "Pembaruan diperlukan untuk melanjutkan"
                                : "Versi baru tersedia. Update sekarang?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
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
                              "Ikuti petunjuk sistem untuk menyelesaikan instalasi",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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

  Widget _buildUpdateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(100),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(
        Icons.system_update_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  Widget _buildProgressHeader(StateSetter setState) {
    IconData icon;
    List<Color> colors;

    if (_installationInitiated) {
      icon = Icons.android_rounded;
      colors = [Colors.green.shade400, Colors.green.shade600];
    } else if (_downloadProgress >= 1.0) {
      icon = Icons.check_circle_rounded;
      colors = [Colors.green.shade400, Colors.green.shade600];
    } else {
      icon = Icons.download_rounded;
      colors = [Colors.blue.shade400, Colors.blue.shade600];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors[0].withAlpha(100),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 48,
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
                        height: 100,
                        width: 100,
                        child: CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.green.shade600 : Colors.blue.shade600
                          ),
                          strokeWidth: 10,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          "${(progress * 100).toInt()}%",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: progress >= 1.0 ? Colors.green.shade800 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "Proses download sedang berlangsung, cek di bilah notifikasi.\n*Jika download selesai, cek apk di folder download (file manager).",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade800,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(message).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(message).withAlpha(76),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(message),
                          color: _getStatusColor(message),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
      return Icons.error_outline_rounded;
    } else if (message.contains("complete") || message.contains("Installation started")) {
      return Icons.check_circle_outline_rounded;
    } else if (message.contains("paused")) {
      return Icons.pause_circle_outline_rounded;
    } else if (message.contains("Preparing")) {
      return Icons.settings_rounded;
    } else {
      return Icons.info_outline_rounded;
    }
  }

  Widget _buildActionButtons(bool forceUpdate, String apkUrl, StateSetter setState, VoidCallback onCancelCallback) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!forceUpdate)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey.shade300, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  "Nanti",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        if (!forceUpdate) const SizedBox(width: 15),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                _downloadAndInstallUpdate(apkUrl, setState, onCancelCallback);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _downloadMessage.contains("failed") || _downloadMessage.contains("Error") || _downloadMessage.contains("Gagal")
                    ? "Coba Lagi"
                    : "Update Sekarang",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
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
        case 'psphsp':
          context.go('/psphsp');
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

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade700,
              Colors.green.shade800,
              Colors.green.shade900,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative Background Circles
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(12),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -120,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(7),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.3,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(5),
                ),
              ),
            ),

            // Main Content
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo dengan Multiple Animations
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withAlpha(76),
                                    Colors.white.withAlpha(25),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(76),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: Colors.green.shade100,
                                  backgroundImage: const AssetImage('assets/logo.png'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.05),

                      // App Title dengan Gradient Text Effect
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withAlpha(229),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Crop Inspection',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Subtitle
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withAlpha(76),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'and Check Result',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withAlpha(229),
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: size.height * 0.15),

                      // Loading Indicator dengan Premium Style
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(51),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white.withAlpha(76),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Ngrantos sekedap...',
                              style: TextStyle(
                                color: Colors.white.withAlpha(204),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: size.height * 0.08),

                      // Footer Information
                      Opacity(
                        opacity: _opacityAnimation.value,
                        child: Column(
                          children: [
                            Container(
                              width: 180,
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withAlpha(102),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '© 2024 Tim Cengoh',
                              style: TextStyle(
                                color: Colors.white.withAlpha(204),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ahli Huru-Hara',
                              style: TextStyle(
                                color: Colors.white.withAlpha(153),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withAlpha(51),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: Colors.white.withAlpha(204),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Version $_version',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(204),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}