import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_restart_service.dart';
import '../services/shorebird_update_service.dart';
import '../theme/app_theme.dart';

typedef RestartApplication = Future<void> Function();

/// A global, non-dismissible gate for Shorebird patches.
///
/// It checks on startup and whenever the app resumes. Normal navigation stays
/// available when the device is offline and no update has been confirmed. Once
/// a patch is confirmed, users must download it and restart before continuing.
class MandatoryPatchUpdateGate extends StatefulWidget {
  const MandatoryPatchUpdateGate({
    super.key,
    required this.child,
    this.service,
    this.restartApplication,
    this.resumeCheckCooldown = const Duration(minutes: 2),
  });

  final Widget child;
  final ShorebirdUpdateService? service;
  final RestartApplication? restartApplication;
  final Duration resumeCheckCooldown;

  @override
  State<MandatoryPatchUpdateGate> createState() =>
      _MandatoryPatchUpdateGateState();
}

class _MandatoryPatchUpdateGateState extends State<MandatoryPatchUpdateGate>
    with WidgetsBindingObserver {
  late final ShorebirdUpdateService _service;
  late final RestartApplication _restartApplication;

  ShorebirdUpdateResult _result = ShorebirdUpdateResult.idle(isAvailable: true);
  DateTime? _lastCheckedAt;
  bool _gateVisible = false;
  bool _checking = false;
  bool _downloading = false;
  bool _restarting = false;
  bool _downloadFailed = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ShorebirdUpdateService();
    _restartApplication =
        widget.restartApplication ?? const AppRestartService().restart;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkForPatch(force: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkForPatch());
    }
  }

  Future<void> _checkForPatch({bool force = false}) async {
    if (_checking || _downloading || _restarting) return;

    final lastCheckedAt = _lastCheckedAt;
    if (!force &&
        lastCheckedAt != null &&
        DateTime.now().difference(lastCheckedAt) < widget.resumeCheckCooldown) {
      return;
    }

    _checking = true;
    _lastCheckedAt = DateTime.now();
    try {
      final result = await _service.checkForUpdate();
      if (!mounted) return;

      final requiresAction =
          result.state == ShorebirdUpdateState.updateAvailable ||
          result.state == ShorebirdUpdateState.downloaded;

      setState(() {
        _result = result;
        _downloadFailed = false;
        if (requiresAction) {
          _gateVisible = true;
        } else if (result.state != ShorebirdUpdateState.error) {
          _gateVisible = false;
        }
      });
    } finally {
      _checking = false;
    }
  }

  Future<void> _downloadPatch() async {
    if (_downloading || _restarting) return;

    setState(() {
      _downloading = true;
      _downloadFailed = false;
      _result = _result.copyWith(state: ShorebirdUpdateState.downloading);
    });

    final result = await _service.downloadUpdate();
    if (!mounted) return;

    setState(() {
      _downloading = false;
      _result = result;
      _downloadFailed = result.state == ShorebirdUpdateState.error;
      _gateVisible = true;
    });
  }

  Future<void> _restartNow() async {
    if (_restarting) return;

    setState(() => _restarting = true);
    try {
      await _restartApplication();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restarting = false;
        _result = _result.copyWith(
          state: ShorebirdUpdateState.error,
          errorMessage:
              'Aplikasi belum dapat dimulai ulang. Silakan coba lagi.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_gateVisible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_gateVisible) _buildBlockingOverlay(context),
        ],
      ),
    );
  }

  Widget _buildBlockingOverlay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final downloaded = _result.state == ShorebirdUpdateState.downloaded;
    final failed = _result.state == ShorebirdUpdateState.error;
    final patchNumber = _result.nextPatchNumber;

    return Positioned.fill(
      child: Material(
        color: AdvantaColors.deepForest.withAlpha(238),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Semantics(
                namesRoute: true,
                label: 'Pembaruan aplikasi wajib',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF17231E)
                          : AdvantaColors.cream,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AdvantaColors.gold.withAlpha(105),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 36,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeaderIcon(downloaded, failed),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AdvantaColors.goldPale,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'UPDATE WAJIB',
                            style: TextStyle(
                              color: Color(0xFF8A6400),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          downloaded
                              ? 'Pembaruan siap dipakai'
                              : failed
                              ? 'Pembaruan belum selesai'
                              : 'Pembaruan KC tersedia',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : AdvantaColors.deepForest,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          downloaded
                              ? 'Patch${patchNumber == null ? '' : ' #$patchNumber'} sudah diunduh. KC akan mencoba terbuka kembali otomatis. Jika ditahan Android, buka KC dari notifikasi.'
                              : failed
                              ? (_result.errorMessage ??
                                    'Periksa koneksi internet, lalu coba kembali.')
                              : 'Versi ini perlu diperbarui sebelum Anda melanjutkan audit dan sinkronisasi data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white.withAlpha(178)
                                : AdvantaColors.charcoal.withAlpha(178),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildProgressSteps(isDark),
                        const SizedBox(height: 22),
                        if (_downloading || _restarting) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: const LinearProgressIndicator(
                              minHeight: 7,
                              color: AdvantaColors.primaryGreen,
                              backgroundColor: AdvantaColors.paleGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _restarting
                                ? 'Memulai ulang KC...'
                                : 'Mengunduh patch dengan aman...',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AdvantaColors.midGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _downloading || _restarting
                                ? null
                                : downloaded
                                ? _restartNow
                                : failed && !_downloadFailed
                                ? () => _checkForPatch(force: true)
                                : _downloadPatch,
                            icon: Icon(
                              downloaded
                                  ? Icons.restart_alt_rounded
                                  : failed && !_downloadFailed
                                  ? Icons.refresh_rounded
                                  : Icons.system_update_alt_rounded,
                            ),
                            label: Text(
                              downloaded
                                  ? 'Terapkan & restart'
                                  : failed && !_downloadFailed
                                  ? 'Cek kembali'
                                  : _downloadFailed
                                  ? 'Coba unduh lagi'
                                  : 'Perbarui sekarang',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AdvantaColors.primaryGreen,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AdvantaColors
                                  .primaryGreen
                                  .withAlpha(110),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: isDark
                                  ? Colors.white54
                                  : AdvantaColors.mutedGrey,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Data audit tersimpan tidak akan terhapus',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : AdvantaColors.mutedGrey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(bool downloaded, bool failed) {
    final color = failed
        ? AdvantaColors.error
        : downloaded
        ? AdvantaColors.success
        : AdvantaColors.gold;
    final icon = failed
        ? Icons.wifi_off_rounded
        : downloaded
        ? Icons.rocket_launch_rounded
        : Icons.system_update_rounded;

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(75), width: 2),
      ),
      child: Icon(icon, color: color, size: 38),
    );
  }

  Widget _buildProgressSteps(bool isDark) {
    final downloaded = _result.state == ShorebirdUpdateState.downloaded;
    final downloading =
        _downloading ||
        _result.state == ShorebirdUpdateState.downloading ||
        _downloadFailed;

    return Row(
      children: [
        Expanded(
          child: _UpdateStep(
            number: '1',
            label: 'Tersedia',
            complete: true,
            active: !downloading && !downloaded,
            isDark: isDark,
          ),
        ),
        _StepConnector(active: downloading || downloaded),
        Expanded(
          child: _UpdateStep(
            number: '2',
            label: 'Unduh',
            complete: downloaded,
            active: downloading && !downloaded,
            isDark: isDark,
          ),
        ),
        _StepConnector(active: downloaded),
        Expanded(
          child: _UpdateStep(
            number: '3',
            label: 'Restart',
            complete: false,
            active: downloaded,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _UpdateStep extends StatelessWidget {
  const _UpdateStep({
    required this.number,
    required this.label,
    required this.complete,
    required this.active,
    required this.isDark,
  });

  final String number;
  final String label;
  final bool complete;
  final bool active;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final highlighted = complete || active;
    final color = complete
        ? AdvantaColors.success
        : active
        ? AdvantaColors.gold
        : AdvantaColors.mutedGrey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: highlighted ? color : color.withAlpha(22),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: complete
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : Text(
                  number,
                  style: TextStyle(
                    color: highlighted
                        ? Colors.white
                        : isDark
                        ? Colors.white60
                        : AdvantaColors.mutedGrey,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: highlighted
                ? isDark
                      ? Colors.white
                      : AdvantaColors.deepForest
                : isDark
                ? Colors.white54
                : AdvantaColors.mutedGrey,
            fontSize: 10,
            fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 22),
        color: active ? AdvantaColors.success : AdvantaColors.dividerGrey,
      ),
    );
  }
}
