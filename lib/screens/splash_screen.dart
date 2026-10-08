import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/full_update_service.dart';
import '../services/session_manager.dart';

// ── IMPORT TEMA PUSAT ────────────────────────────────
import '../theme/app_theme.dart';

const _splashWallpaperAsset = 'assets/splash_wallpaper.jpg';

enum _UpdatePhase {
  idle,
  preparing,
  pending,
  downloading,
  paused,
  readyToInstall,
  installing,
  failed,
}

class _UpdateUiState {
  const _UpdateUiState({
    this.phase = _UpdatePhase.idle,
    this.message = '',
    this.progress,
  });

  final _UpdatePhase phase;
  final String message;
  final double? progress;

  bool get isBusy => switch (phase) {
    _UpdatePhase.preparing ||
    _UpdatePhase.pending ||
    _UpdatePhase.downloading ||
    _UpdatePhase.paused ||
    _UpdatePhase.installing => true,
    _ => false,
  };

  bool get showsStatus => phase != _UpdatePhase.idle;

  bool get canInstall => phase == _UpdatePhase.readyToInstall;

  bool get canRetry => phase == _UpdatePhase.failed;
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Animation Controllers ─────────────────────────
  late AnimationController _masterController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _dividerWidth;
  late Animation<double> _footerFade;
  late Animation<double> _shimmer;

  String _version = 'Loading...';
  bool _updateRequired = false;

  // ── Full update state ─────────────────────────────
  static const _downloadIdKey = 'full_update_download_id';
  static const _downloadFileKey = 'full_update_download_file';
  static const _downloadVersionKey = 'full_update_download_version';
  static const _downloadUrlKey = 'full_update_download_url';

  final FullUpdateService _fullUpdateService = const FullUpdateService();
  final ValueNotifier<_UpdateUiState> _updateState = ValueNotifier(
    const _UpdateUiState(),
  );
  Timer? _downloadPollTimer;
  int? _downloadTaskId;
  String? _downloadFileName;
  String? _activeUpdateVersion;
  String? _activeApkUrl;
  bool _pollInFlight = false;
  bool _updateDialogVisible = false;
  bool _waitingForInstallerResult = false;
  bool _installerLaunchInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();

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
      vsync: this,
    );

    // Shimmer for gold line
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Pulse for loading indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Logo animations
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _masterController,
            curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
          ),
        );

    // Tagline
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _masterController,
            curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic),
          ),
        );

    // Gold divider
    _dividerWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.55, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // Footer
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
      ),
    );

    // Shimmer & Pulse
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  // ── Android DownloadManager ───────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    if (_waitingForInstallerResult) {
      _waitingForInstallerResult = false;
      _installerLaunchInProgress = false;
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.readyToInstall,
          progress: 1,
          message: 'APK siap dipasang. Ketuk Pasang jika installer tertutup.',
        ),
      );
    }

    if (_downloadTaskId != null) {
      unawaited(_pollDownload(allowAutomaticInstall: false));
    }
  }

  void _setUpdateState(_UpdateUiState state) {
    if (!mounted) return;
    _updateState.value = state;
  }

  void _startDownloadPolling() {
    _downloadPollTimer?.cancel();
    _downloadPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollDownload());
    });
    unawaited(_pollDownload());
  }

  Future<void> _pollDownload({bool allowAutomaticInstall = true}) async {
    final taskId = _downloadTaskId;
    if (taskId == null || _pollInFlight) return;

    _pollInFlight = true;
    try {
      final snapshot = await _fullUpdateService.query(taskId);
      if (!mounted || taskId != _downloadTaskId) return;
      await _applyDownloadSnapshot(
        snapshot,
        allowAutomaticInstall: allowAutomaticInstall,
      );
    } catch (error) {
      debugPrint('Gagal membaca status update penuh: $error');
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.paused,
          message: 'Menunggu layanan unduhan Android...',
        ),
      );
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _applyDownloadSnapshot(
    FullUpdateDownloadSnapshot snapshot, {
    required bool allowAutomaticInstall,
  }) async {
    switch (snapshot.status) {
      case FullUpdateDownloadStatus.pending:
        _setUpdateState(
          const _UpdateUiState(
            phase: _UpdatePhase.pending,
            message: 'Download sedang dalam antrean Android...',
          ),
        );
        break;
      case FullUpdateDownloadStatus.running:
        final progress = snapshot.progress;
        final percent = progress == null ? null : (progress * 100).round();
        _setUpdateState(
          _UpdateUiState(
            phase: _UpdatePhase.downloading,
            progress: progress,
            message: percent == null
                ? 'Mengunduh pembaruan...'
                : 'Mengunduh pembaruan: $percent%',
          ),
        );
        break;
      case FullUpdateDownloadStatus.paused:
        _setUpdateState(
          _UpdateUiState(
            phase: _UpdatePhase.paused,
            progress: snapshot.progress,
            message: _pausedDownloadMessage(snapshot.reason),
          ),
        );
        break;
      case FullUpdateDownloadStatus.successful:
        _downloadPollTimer?.cancel();
        _setUpdateState(
          const _UpdateUiState(
            phase: _UpdatePhase.readyToInstall,
            progress: 1,
            message: 'Download selesai. Mempersiapkan installer...',
          ),
        );
        if (allowAutomaticInstall &&
            _updateDialogVisible &&
            !_waitingForInstallerResult) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted && _updateDialogVisible && !_waitingForInstallerResult) {
            await _launchInstaller();
          }
        }
        break;
      case FullUpdateDownloadStatus.failed:
        _downloadPollTimer?.cancel();
        _setUpdateState(
          _UpdateUiState(
            phase: _UpdatePhase.failed,
            message: _failedDownloadMessage(snapshot.reason),
          ),
        );
        break;
      case FullUpdateDownloadStatus.missing:
        _downloadPollTimer?.cancel();
        await _clearPersistedDownload();
        _setUpdateState(
          const _UpdateUiState(
            phase: _UpdatePhase.failed,
            message: 'Unduhan tidak ditemukan. Silakan coba lagi.',
          ),
        );
        break;
    }
  }

  String _pausedDownloadMessage(int reason) {
    return switch (reason) {
      1 => 'Koneksi bermasalah. Android akan mencoba lagi otomatis...',
      2 => 'Menunggu koneksi internet tersedia...',
      3 => 'Menunggu jaringan Wi-Fi...',
      _ => 'Download dijeda Android dan akan dilanjutkan otomatis...',
    };
  }

  String _failedDownloadMessage(int reason) {
    return switch (reason) {
      1006 => 'Ruang penyimpanan tidak cukup untuk mengunduh pembaruan.',
      1008 => 'Download tidak dapat dilanjutkan. Silakan coba lagi.',
      1001 => 'File update tidak dapat disimpan di perangkat ini.',
      1002 ||
      1004 ||
      1005 => 'Server update tidak dapat dihubungi. Silakan coba lagi.',
      _ => 'Download gagal (kode $reason). Silakan coba lagi.',
    };
  }

  Future<void> _persistDownload() async {
    final taskId = _downloadTaskId;
    final fileName = _downloadFileName;
    final version = _activeUpdateVersion;
    final url = _activeApkUrl;
    if (taskId == null || fileName == null || version == null || url == null) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await Future.wait<bool>([
      preferences.setInt(_downloadIdKey, taskId),
      preferences.setString(_downloadFileKey, fileName),
      preferences.setString(_downloadVersionKey, version),
      preferences.setString(_downloadUrlKey, url),
    ]);
  }

  Future<void> _restorePendingDownload(String version, String apkUrl) async {
    final preferences = await SharedPreferences.getInstance();
    final taskId = preferences.getInt(_downloadIdKey);
    final fileName = preferences.getString(_downloadFileKey);
    final savedVersion = preferences.getString(_downloadVersionKey);
    final savedUrl = preferences.getString(_downloadUrlKey);

    if (taskId == null ||
        fileName == null ||
        savedVersion != version ||
        savedUrl != apkUrl) {
      if (taskId != null ||
          fileName != null ||
          savedVersion != null ||
          savedUrl != null) {
        await _clearPersistedDownload(
          downloadId: taskId,
          removeNative: taskId != null,
        );
      }
      _setUpdateState(const _UpdateUiState());
      return;
    }

    _downloadTaskId = taskId;
    _downloadFileName = fileName;
    _activeUpdateVersion = version;
    _activeApkUrl = apkUrl;
    _setUpdateState(
      const _UpdateUiState(
        phase: _UpdatePhase.pending,
        message: 'Memulihkan download pembaruan...',
      ),
    );
    _startDownloadPolling();
  }

  Future<void> _clearPersistedDownload({
    int? downloadId,
    bool removeNative = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final taskId =
        downloadId ?? _downloadTaskId ?? preferences.getInt(_downloadIdKey);
    if (removeNative && taskId != null) {
      try {
        await _fullUpdateService.remove(taskId);
      } catch (error) {
        debugPrint('Gagal membersihkan unduhan update lama: $error');
      }
    }

    await Future.wait<bool>([
      preferences.remove(_downloadIdKey),
      preferences.remove(_downloadFileKey),
      preferences.remove(_downloadVersionKey),
      preferences.remove(_downloadUrlKey),
    ]);
    if (taskId == _downloadTaskId) {
      _downloadTaskId = null;
      _downloadFileName = null;
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
      final forceUpdate = response['force_update'] as bool? ?? false;
      final downloadUrl = response['apk_url'] as String?;

      if (latestVersion == null || downloadUrl == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (currentVersion != latestVersion) {
        _updateRequired = true;
        if (mounted) {
          _showUpdateDialog(forceUpdate, latestVersion, downloadUrl);
        }
      } else {
        // Instalasi berhasil pada proses sebelumnya. Hapus APK dan record lama.
        await _clearPersistedDownload(removeNative: true);
      }
    } catch (error) {
      debugPrint('Gagal memeriksa update penuh: $error');
      // Gagal cek update → lanjut saja
    }
  }

  Future<void> _downloadAndInstallUpdate(String apkUrl, String version) async {
    _downloadPollTimer?.cancel();
    _setUpdateState(
      const _UpdateUiState(
        phase: _UpdatePhase.preparing,
        message: 'Menyiapkan download pembaruan...',
      ),
    );
    try {
      final previousTaskId = _downloadTaskId;
      if (previousTaskId != null) {
        await _clearPersistedDownload(
          downloadId: previousTaskId,
          removeNative: true,
        );
      }

      // Izin notifikasi tidak boleh menggagalkan download. DownloadManager
      // tetap dapat bekerja saat izin ditolak.
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        await Permission.notification.request();
      }

      final safeVersion = version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
      final fileName =
          'kroscek-$safeVersion-${DateTime.now().millisecondsSinceEpoch}.apk';
      final taskId = await _fullUpdateService.enqueue(
        url: apkUrl,
        fileName: fileName,
        version: version,
      );

      _downloadTaskId = taskId;
      _downloadFileName = fileName;
      _activeUpdateVersion = version;
      _activeApkUrl = apkUrl;
      try {
        await _persistDownload();
      } catch (error) {
        // Download tetap dipantau pada sesi ini walaupun penyimpanan metadata
        // gagal. Jangan membiarkan task Android berjalan tanpa UI.
        debugPrint('Gagal menyimpan metadata update penuh: $error');
      }
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.pending,
          message: 'Download diserahkan ke Android...',
        ),
      );
      _startDownloadPolling();
    } catch (error) {
      debugPrint('Gagal memulai update penuh: $error');
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.failed,
          message: 'Download tidak dapat dimulai. Silakan coba lagi.',
        ),
      );
    }
  }

  Future<void> _launchInstaller() async {
    final fileName = _downloadFileName;
    if (fileName == null || _installerLaunchInProgress) return;
    _installerLaunchInProgress = true;

    late PermissionStatus installPermission;
    try {
      installPermission = await Permission.requestInstallPackages.status;
      if (!installPermission.isGranted) {
        installPermission = await Permission.requestInstallPackages.request();
      }
    } catch (error) {
      _installerLaunchInProgress = false;
      debugPrint('Gagal meminta izin instalasi update: $error');
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.readyToInstall,
          progress: 1,
          message: 'Izin instalasi tidak dapat diperiksa. Ketuk Pasang untuk mencoba lagi.',
        ),
      );
      return;
    }
    if (!installPermission.isGranted) {
      _installerLaunchInProgress = false;
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.readyToInstall,
          progress: 1,
          message: 'Izinkan KC memasang aplikasi dari sumber ini, lalu ketuk Pasang.',
        ),
      );
      return;
    }

    _setUpdateState(
      const _UpdateUiState(
        phase: _UpdatePhase.installing,
        progress: 1,
        message: 'Membuka installer Android...',
      ),
    );
    try {
      _waitingForInstallerResult = true;
      await _fullUpdateService.openInstaller(fileName);
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!mounted ||
              !_waitingForInstallerResult ||
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed) {
            return;
          }
          _waitingForInstallerResult = false;
          _installerLaunchInProgress = false;
          _setUpdateState(
            const _UpdateUiState(
              phase: _UpdatePhase.readyToInstall,
              progress: 1,
              message: 'APK siap dipasang. Ketuk Pasang jika installer tidak tampil.',
            ),
          );
        }),
      );
    } catch (error) {
      _waitingForInstallerResult = false;
      _installerLaunchInProgress = false;
      debugPrint('Gagal membuka installer update: $error');
      _setUpdateState(
        const _UpdateUiState(
          phase: _UpdatePhase.readyToInstall,
          progress: 1,
          message:
              'Installer tidak dapat dibuka. Ketuk Pasang untuk mencoba lagi.',
        ),
      );
    }
  }

  // ── INI FUNGSI KRUSIAL: Pengecekan status login via SessionManager ────────
  Future<void> _checkLoginStatus() async {
    if (_updateState.value.isBusy) return;

    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final session = await SessionManager.instance.getActiveSession();

    // Kedua-duanya harus valid — Supabase session + local session
    final isLoggedIn = supabaseUser != null && session != null;
    final userRole = session?.role;

    if (!mounted) return;

    if (isLoggedIn && userRole != null) {
      context.go('/qa');
    } else {
      context.go('/login');
    }
  }

  // ── Full update dialog ──────────────────────────────────────────────────
  void _showUpdateDialog(bool forceUpdate, String newVersion, String apkUrl) {
    debugPrint('Showing update dialog: force=$forceUpdate, url=$apkUrl');
    _activeUpdateVersion = newVersion;
    _activeApkUrl = apkUrl;
    _updateDialogVisible = true;
    _updateState.value = const _UpdateUiState(
      phase: _UpdatePhase.preparing,
      message: 'Memeriksa download pembaruan sebelumnya...',
    );

    final dialogFuture = showDialog<void>(
      context: context,
      // Hindari dialog tertutup tanpa sengaja ketika DownloadManager aktif.
      // Update opsional tetap dapat ditutup melalui tombol Nanti/back.
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ValueListenableBuilder<_UpdateUiState>(
          valueListenable: _updateState,
          builder: (context, updateState, _) {
            return PopScope(
              canPop: !forceUpdate && !updateState.isBusy,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: AdvantaColors.cream,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AdvantaColors.deepForest.withAlpha(80),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 24,
                          ),
                          decoration: const BoxDecoration(
                            color: AdvantaColors.primaryGreen,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AdvantaColors.gold.withAlpha(40),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AdvantaColors.gold.withAlpha(100),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.system_update_rounded,
                                  color: AdvantaColors.goldLight,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pembaruan Tersedia',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      'Versi $newVersion',
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(180),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (forceUpdate)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AdvantaColors.gold,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'WAJIB',
                                    style: TextStyle(
                                      color: AdvantaColors.charcoal,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
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
                                  color: AdvantaColors.charcoal,
                                  fontSize: 14,
                                  height: 1.55,
                                ),
                              ),
                              if (updateState.showsStatus) ...[
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: updateState.progress,
                                    minHeight: 6,
                                    backgroundColor: AdvantaColors.primaryGreen
                                        .withAlpha(30),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AdvantaColors.gold,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  updateState.message,
                                  style: TextStyle(
                                    color:
                                        updateState.phase == _UpdatePhase.failed
                                        ? Colors.red.shade700
                                        : AdvantaColors.primaryGreen,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  if (!forceUpdate && !updateState.isBusy) ...[
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          side: const BorderSide(
                                            color: AdvantaColors.midGreen,
                                          ),
                                        ),
                                        child: const Text(
                                          'Nanti',
                                          style: TextStyle(
                                            color: AdvantaColors.primaryGreen,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: updateState.isBusy
                                          ? null
                                          : updateState.canInstall
                                          ? _launchInstaller
                                          : () => _downloadAndInstallUpdate(
                                              apkUrl,
                                              newVersion,
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AdvantaColors.primaryGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: AdvantaColors
                                            .primaryGreen
                                            .withAlpha(100),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: updateState.isBusy
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              updateState.canInstall
                                                  ? 'Pasang Pembaruan'
                                                  : updateState.canRetry
                                                  ? 'Coba Lagi'
                                                  : 'Unduh & Pasang',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
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
    );

    unawaited(
      _restorePendingDownload(newVersion, apkUrl).catchError((Object error) {
        debugPrint('Gagal memulihkan download update: $error');
        _setUpdateState(const _UpdateUiState());
      }),
    );
    dialogFuture
        .then((_) {
          _updateDialogVisible = false;
          debugPrint('Update dialog closed.');
          if (!forceUpdate && mounted) {
            unawaited(_checkLoginStatus());
          }
        })
        .catchError((error) {
          _updateDialogVisible = false;
          debugPrint('Error showing/handling dialog: $error');
          if (!forceUpdate && mounted) {
            unawaited(_checkLoginStatus());
          }
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadPollTimer?.cancel();
    _masterController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _updateState.dispose();
    super.dispose();
  }

  // ── BUILD (TERINTEGRASI DENGAN THEME) ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mainTextColor = Colors.white;
    final subTextColor = Colors.white.withAlpha(isDark ? 180 : 210);
    final accentLineColor = isDark
        ? AdvantaColors.gold
        : AdvantaColors.goldLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              _splashWallpaperAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) =>
                  Container(color: AdvantaColors.deepForest),
            ),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AdvantaColors.deepForest.withAlpha(215),
                          AdvantaColors.deepForest.withAlpha(178),
                          const Color(0xFF071A12).withAlpha(232),
                        ]
                      : [
                          AdvantaColors.deepForest.withAlpha(110),
                          AdvantaColors.deepForest.withAlpha(82),
                          AdvantaColors.deepForest.withAlpha(205),
                        ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

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
                          child: _buildLogoBlock(
                            mainTextColor,
                            subTextColor,
                            isDark,
                          ),
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
                      child: _buildLoadingSection(
                        accentLineColor,
                        mainTextColor,
                        isDark,
                      ),
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
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: (isDark ? AdvantaColors.gold : AdvantaColors.primaryGreen)
                  .withAlpha(60),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdvantaColors.kcNavy,
                boxShadow: [
                  BoxShadow(
                    color: AdvantaColors.lightGreen.withAlpha(isDark ? 60 : 20),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Image.asset(
                  'assets/logo_kc_notitle_unbox.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.agriculture_rounded,
                    color: AdvantaColors.primaryGreen,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'KROSCEK',
          style: TextStyle(
            color: mainText,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Crop Inspection and Check Result',
          style: TextStyle(color: subText, fontSize: 13, letterSpacing: 0),
        ),
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
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'INSPECTIONS APP',
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Solusi Audit Lahan\nBerbasis Data Real-Time',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? Colors.white.withAlpha(200)
                : AdvantaColors.charcoal,
            fontSize: 15,
            height: 1.7,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSection(Color accentColor, Color textColor, bool isDark) {
    final surfaceColor = isDark
        ? Colors.white.withAlpha(18)
        : Colors.white.withAlpha(190);
    final borderColor = isDark
        ? AdvantaColors.gold.withAlpha(58)
        : AdvantaColors.primaryGreen.withAlpha(40);
    final mutedTextColor = isDark
        ? Colors.white.withAlpha(150)
        : AdvantaColors.midGreen.withAlpha(190);

    return AnimatedBuilder(
      animation: Listenable.merge([_shimmerController, _pulseController]),
      builder: (_, __) {
        final pulse = Curves.easeInOut.transform(_pulseController.value);
        final panelWidth = (MediaQuery.sizeOf(context).width - 48)
            .clamp(248.0, 340.0)
            .toDouble();

        return Container(
          width: panelWidth,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: AdvantaColors.deepForest.withAlpha(isDark ? 70 : 20),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 36 : 24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withAlpha(70)),
                    ),
                    child: Icon(
                      Icons.radar_rounded,
                      color: accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Memuat Kroscek',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Menyiapkan modul audit lapangan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.88 + (pulse * 0.12),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withAlpha(120),
                            blurRadius: 12 + (pulse * 8),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: CustomPaint(
                  painter: _PremiumLoadingRailPainter(
                    progress: _shimmerController.value,
                    pulse: pulse,
                    accentColor: accentColor,
                    isDark: isDark,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildLoadingSignal(
                      'Database',
                      accentColor,
                      textColor,
                      isDark,
                      0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLoadingSignal(
                      'Maps',
                      accentColor,
                      textColor,
                      isDark,
                      1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLoadingSignal(
                      'Audit',
                      accentColor,
                      textColor,
                      isDark,
                      2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingSignal(
    String label,
    Color accentColor,
    Color textColor,
    bool isDark,
    int index,
  ) {
    final offset = index * 0.22;
    final wave = ((_shimmerController.value + offset) % 1.0);
    final glow = Curves.easeInOut.transform(
      wave < 0.5 ? wave * 2 : (1 - wave) * 2,
    );

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(10)
            : AdvantaColors.primaryGreen.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withAlpha(24 + (glow * 42).round()),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(120 + (glow * 120).round()),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withAlpha(isDark ? 180 : 170),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color textColor, Color accentColor) {
    return Column(
      children: [
        Container(width: 48, height: 1, color: accentColor.withAlpha(60)),
        const SizedBox(height: 14),
        Text(
          '© 2024-${DateTime.now().year} Advanta Seeds Indonesia',
          style: TextStyle(color: textColor.withAlpha(100), fontSize: 11),
        ),
        const SizedBox(height: 6),
        if (_version.isNotEmpty)
          Text(
            'v$_version',
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _PremiumLoadingRailPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final Color accentColor;
  final bool isDark;

  _PremiumLoadingRailPainter({
    required this.progress,
    required this.pulse,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final railTop = size.height * 0.54;
    final railHeight = 8.0;
    final railRect = Rect.fromLTWH(0, railTop, size.width, railHeight);
    final railRadius = Radius.circular(railHeight);
    final railRRect = RRect.fromRectAndRadius(railRect, railRadius);

    final trackPaint = Paint()
      ..color = isDark
          ? Colors.white.withAlpha(18)
          : AdvantaColors.deepForest.withAlpha(18);
    canvas.drawRRect(railRRect, trackPaint);

    final fieldPath = Path();
    for (double x = 0; x <= size.width; x += 4) {
      final wave = math.sin(
        (x / size.width * math.pi * 2) + progress * math.pi * 2,
      );
      final y = 11 + wave * 3;
      if (x == 0) {
        fieldPath.moveTo(x, y);
      } else {
        fieldPath.lineTo(x, y);
      }
    }

    final fieldPaint = Paint()
      ..color = accentColor.withAlpha(isDark ? 68 : 48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(fieldPath, fieldPaint);

    final tickPaint = Paint()
      ..color = accentColor.withAlpha(isDark ? 48 : 36)
      ..strokeWidth = 1;
    for (int i = 0; i <= 12; i++) {
      final x = size.width * (i / 12);
      final tickHeight = i % 3 == 0 ? 14.0 : 9.0;
      canvas.drawLine(
        Offset(x, railTop - tickHeight),
        Offset(x, railTop - 3),
        tickPaint,
      );
    }

    final segmentWidth = size.width * 0.34;
    final leading = (size.width + segmentWidth) * progress - segmentWidth;
    final movingRect = Rect.fromLTWH(
      leading,
      railTop,
      segmentWidth,
      railHeight,
    ).intersect(railRect);

    if (!movingRect.isEmpty) {
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            accentColor.withAlpha(0),
            accentColor.withAlpha(isDark ? 155 : 130),
            AdvantaColors.goldLight.withAlpha(isDark ? 230 : 190),
            accentColor.withAlpha(0),
          ],
        ).createShader(movingRect.inflate(12));
      canvas.drawRRect(
        RRect.fromRectAndRadius(movingRect, railRadius),
        activePaint,
      );
    }

    final headX = leading + segmentWidth * 0.66;
    if (headX >= 0 && headX <= size.width) {
      final glowPaint = Paint()
        ..color = AdvantaColors.goldLight.withAlpha((70 + pulse * 70).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(
        Offset(headX, railTop + railHeight / 2),
        8 + pulse * 3,
        glowPaint,
      );

      final headPaint = Paint()..color = AdvantaColors.goldLight;
      canvas.drawCircle(
        Offset(headX, railTop + railHeight / 2),
        3.2,
        headPaint,
      );
    }

    final baselinePaint = Paint()
      ..color = isDark
          ? Colors.white.withAlpha(38)
          : Colors.white.withAlpha(130)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, railTop + railHeight + 7),
      Offset(size.width, railTop + railHeight + 7),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumLoadingRailPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
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

    const r = 28.0;
    const h = r * 1.732; // sqrt(3) * r
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
      final px = center.dx + r * _cos(angle);
      final py = center.dy + r * _sin(angle);
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
