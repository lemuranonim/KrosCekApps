// lib/screens/attendance/check_in_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen>
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  Position? _position;
  _LocationStatus _locationStatus = _LocationStatus.loading;
  String _statusMessage = 'Mengakses GPS…';
  bool _isSubmitting = false;

  // ── Clocks ───────────────────────────────────────────────────────────────
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startClock();
    _determinePosition();
  }

  void _setupAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );

    _slideCtrl.forward();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  // ── Location ─────────────────────────────────────────────────────────────
  Future<void> _determinePosition() async {
    setState(() {
      _locationStatus = _LocationStatus.loading;
      _statusMessage = 'Mengakses GPS…';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Layanan lokasi dinonaktifkan.\nAktifkan GPS di pengaturan.');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _setError('Izin GPS ditolak.\nBuka Pengaturan > Izin Aplikasi.');
        return;
      }

      setState(() => _statusMessage = 'Memperhalus akurasi…');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _position = position;
        _locationStatus = _LocationStatus.found;
        _statusMessage = _accuracyLabel(position.accuracy);
      });
    } catch (e) {
      _setError('Gagal mengambil lokasi.\nCoba lagi atau pindah ke area terbuka.');
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _locationStatus = _LocationStatus.error;
      _statusMessage = msg;
    });
  }

  String _accuracyLabel(double accuracy) {
    if (accuracy <= 10) return 'Akurasi sangat tinggi (±${accuracy.toInt()}m)';
    if (accuracy <= 30) return 'Akurasi tinggi (±${accuracy.toInt()}m)';
    if (accuracy <= 60) return 'Akurasi cukup (±${accuracy.toInt()}m)';
    return 'Akurasi rendah (±${accuracy.toInt()}m) — coba di luar ruangan';
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy <= 30) return AdvantaColors.success;
    if (accuracy <= 60) return AdvantaColors.gold;
    return AdvantaColors.error;
  }

  // ── Check-in ─────────────────────────────────────────────────────────────
  Future<void> _handleCheckIn() async {
    if (_position == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final session = await SessionManager.instance.getActiveSession();
      final userId = session?.userId;
      if (userId == null || userId.isEmpty) {
        throw Exception('Sesi tidak valid. Silakan login ulang.');
      }

      await ref.read(attendanceProvider.notifier).performCheckIn(
        userId: userId,
        lat: _position!.latitude,
        lng: _position!.longitude,
      );

      if (mounted) {
        _showSuccessAndPop();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnack('Gagal check-in: $e');
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessAndPop() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Check-in berhasil! Selamat bekerja 💪',
              style: AdvantaText.bodyBold.copyWith(color: Colors.white)),
        ]),
        backgroundColor: AdvantaColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    Navigator.pop(context);
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: AdvantaText.body2.copyWith(color: Colors.white)),
        backgroundColor: AdvantaColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canCheckIn =
        _locationStatus == _LocationStatus.found && !_isSubmitting;

    return Scaffold(
      backgroundColor: isDark ? AdvantaColors.deepForest : AdvantaColors.cream,
      appBar: AppBar(
        title: const Text('Mulai Hari Ini'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildClockCard(isDark),
                const SizedBox(height: 20),
                _buildLocationCard(isDark),
                const SizedBox(height: 20),
                _buildCoordinateCard(isDark),
                const SizedBox(height: 32),
                _buildCheckInButton(canCheckIn, isDark),
                const SizedBox(height: 16),
                _buildRefreshButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI Widgets ────────────────────────────────────────────────────────────

  Widget _buildClockCard(bool isDark) {
    final timeStr = DateFormat('HH:mm').format(_now);
    final secStr = DateFormat('ss').format(_now);
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AdvantaColors.primaryGreen, AdvantaColors.deepForest]
              : [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AdvantaRadius.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AdvantaColors.primaryGreen.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: AdvantaText.label.copyWith(
              color: Colors.white.withAlpha(180),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: AdvantaText.display.copyWith(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  ':$secStr',
                  style: AdvantaText.heading1.copyWith(
                    color: Colors.white.withAlpha(160),
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AdvantaColors.lightGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Belum absen hari ini',
                style: AdvantaText.caption.copyWith(
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool isDark) {
    final bgColor = isDark ? AdvantaColors.midGreen : Colors.white;

    Widget statusIcon;
    Color statusColor;

    switch (_locationStatus) {
      case _LocationStatus.loading:
        statusColor = AdvantaColors.gold;
        statusIcon = ScaleTransition(
          scale: _pulseAnim,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AdvantaColors.gold.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_searching_rounded,
                color: AdvantaColors.gold, size: 32),
          ),
        );
        break;
      case _LocationStatus.found:
        statusColor =
            _accuracyColor(_position?.accuracy ?? 100);
        statusIcon = Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.my_location_rounded,
              color: statusColor, size: 32),
        );
        break;
      case _LocationStatus.error:
        statusColor = AdvantaColors.error;
        statusIcon = Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AdvantaColors.error.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_off_rounded,
              color: AdvantaColors.error, size: 32),
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(30)
              : AdvantaColors.dividerGrey,
        ),
        boxShadow: AdvantaShadows.card(isDark),
      ),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _locationStatus == _LocationStatus.loading
                      ? 'Mencari lokasi'
                      : _locationStatus == _LocationStatus.found
                      ? 'Lokasi terdeteksi'
                      : 'Gagal mendapatkan lokasi',
                  style: AdvantaText.bodyBold.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight
                        : AdvantaColors.deepForest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: AdvantaText.caption.copyWith(
                    color: statusColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (_locationStatus == _LocationStatus.loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AdvantaColors.gold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinateCard(bool isDark) {
    if (_position == null) return const SizedBox.shrink();

    final bgColor = isDark ? AdvantaColors.midGreen : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(30)
              : AdvantaColors.dividerGrey,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _coordTile(
              isDark: isDark,
              label: 'LATITUDE',
              value: _position!.latitude.toStringAsFixed(6),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark
                ? AdvantaColors.goldLight.withAlpha(30)
                : AdvantaColors.dividerGrey,
          ),
          Expanded(
            child: _coordTile(
              isDark: isDark,
              label: 'LONGITUDE',
              value: _position!.longitude.toStringAsFixed(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordTile({
    required bool isDark,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AdvantaText.caption.copyWith(
            color: AdvantaColors.mutedGrey,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AdvantaText.bodyBold.copyWith(
            color: isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton(bool canCheckIn, bool isDark) {
    if (_isSubmitting) {
      return Container(
        height: 58,
        decoration: BoxDecoration(
          color: AdvantaColors.primaryGreen.withAlpha(150),
          borderRadius: AdvantaRadius.buttonRadius,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: canCheckIn
            ? const LinearGradient(
          colors: [AdvantaColors.midGreen, AdvantaColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: canCheckIn ? null : AdvantaColors.mutedGrey.withAlpha(60),
        borderRadius: AdvantaRadius.buttonRadius,
        boxShadow: canCheckIn
            ? [
          BoxShadow(
            color: AdvantaColors.primaryGreen.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canCheckIn ? _handleCheckIn : null,
          borderRadius: AdvantaRadius.buttonRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'MULAI HARI INI',
                  style: AdvantaText.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Center(
      child: TextButton.icon(
        onPressed:
        _locationStatus != _LocationStatus.loading ? _determinePosition : null,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Perbarui Lokasi'),
        style: TextButton.styleFrom(
          foregroundColor: AdvantaColors.mutedGrey,
        ),
      ),
    );
  }
}

enum _LocationStatus { loading, found, error }