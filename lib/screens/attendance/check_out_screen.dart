// lib/screens/attendance/check_out_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class CheckOutScreen extends ConsumerStatefulWidget {
  const CheckOutScreen({super.key});

  @override
  ConsumerState<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends ConsumerState<CheckOutScreen>
    with TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────────────────
  Position? _position;
  bool _isLocating = true;
  bool _isSubmitting = false;
  String _locationStatus = 'Mencari sinyal GPS…';
  final TextEditingController _notesController = TextEditingController();
  int _notesLength = 0;
  static const int _maxNotesLength = 300;

  // ── Clock ─────────────────────────────────────────────────────────────────
  late Timer _timer;
  DateTime _now = DateTime.now();

  // ── Animations ─────────────────────────────────────────────────────────
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startTimer();
    _determinePosition();
    _notesController.addListener(
          () => setState(() => _notesLength = _notesController.text.length),
    );
  }

  void _setupAnimations() {
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _slideCtrl.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Location ─────────────────────────────────────────────────────────────
  Future<void> _determinePosition() async {
    setState(() {
      _isLocating = true;
      _locationStatus = 'Mencari sinyal GPS…';
    });
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        setState(() {
          _position = position;
          _isLocating = false;
          _locationStatus =
          'Lokasi terdeteksi (±${position.accuracy.toInt()}m)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _locationStatus = 'Gagal mendapatkan lokasi.';
        });
      }
    }
  }

  // ── Check-out ─────────────────────────────────────────────────────────
  Future<void> _handleCheckOut() async {
    if (_position == null || _isSubmitting) return;

    final confirm = await _showConfirmDialog();
    if (!confirm) return;

    setState(() => _isSubmitting = true);

    try {
      final session = await SessionManager.instance.getActiveSession();
      final userId = session?.userId;
      if (userId == null || userId.isEmpty) {
        throw Exception('Sesi tidak valid. Silakan login ulang.');
      }

      // Refresh activities terlebih dahulu untuk data akurat
      await ref.read(attendanceProvider.notifier).refreshActivities();

      await ref.read(attendanceProvider.notifier).performCheckOut(
        userId: userId,
        lat: _position!.latitude,
        lng: _position!.longitude,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        _showSummarySheet();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal check-out: $e',
                style: AdvantaText.body2.copyWith(color: Colors.white)),
            backgroundColor: AdvantaColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AdvantaRadius.dialogRadius),
        title: Text('Konfirmasi Check-out',
            style: AdvantaText.heading2),
        content: Text(
          'Anda akan mengakhiri hari kerja ini. Yakin?',
          style: AdvantaText.body2
              .copyWith(color: AdvantaColors.mutedGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: AdvantaText.bodyBold
                    .copyWith(color: AdvantaColors.mutedGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdvantaColors.gold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Ya, Check-out'),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ── Summary Bottom Sheet ──────────────────────────────────────────────────
  void _showSummarySheet() {
    final attendance = ref.read(attendanceProvider);
    final checkInStr = attendance.checkInTime != null
        ? DateFormat('HH:mm').format(attendance.checkInTime!)
        : '--:--';
    final checkOutStr = DateFormat('HH:mm').format(DateTime.now());
    final duration = attendance.workDurationFormatted;
    final totalActivities = attendance.totalActivities;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: AdvantaRadius.sheetRadius),
      backgroundColor:
      Theme.of(context).brightness == Brightness.dark
          ? AdvantaColors.midGreen
          : Colors.white,
      builder: (sheetCtx) => _SummarySheet(
        checkInStr: checkInStr,
        checkOutStr: checkOutStr,
        duration: duration,
        totalActivities: totalActivities,
        onClose: () {
          Navigator.pop(sheetCtx);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendance = ref.watch(attendanceProvider);
    final canCheckOut = _position != null && !_isSubmitting;

    return Scaffold(
      backgroundColor:
      isDark ? AdvantaColors.deepForest : AdvantaColors.cream,
      appBar: AppBar(title: const Text('Selesai Hari Ini')),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusCard(isDark, attendance),
                const SizedBox(height: 16),
                _buildLocationRow(isDark),
                const SizedBox(height: 16),
                _buildActivitySummary(isDark, attendance),
                const SizedBox(height: 20),
                _buildNotesField(isDark),
                const SizedBox(height: 32),
                _buildCheckOutButton(canCheckOut),
                const SizedBox(height: 12),
                _buildRefreshButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI Widgets ────────────────────────────────────────────────────────────

  Widget _buildStatusCard(bool isDark, AttendanceState attendance) {
    final checkInStr = attendance.checkInTime != null
        ? DateFormat('HH:mm').format(attendance.checkInTime!)
        : '--:--';
    final nowStr = DateFormat('HH:mm').format(_now);
    final duration = attendance.workDurationFormatted;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AdvantaColors.gold.withAlpha(200), const Color(0xFFB8860B)]
              : [AdvantaColors.gold, AdvantaColors.goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AdvantaRadius.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AdvantaColors.gold.withAlpha(70),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RINGKASAN HARI INI',
            style: AdvantaText.label.copyWith(
              color: Colors.white.withAlpha(180),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _timeColumn('Check-in', checkInStr),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white60, size: 18),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        duration,
                        style: AdvantaText.label.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _timeColumn('Sekarang', nowStr),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeColumn(String label, String time) {
    return Column(
      children: [
        Text(
          label,
          style: AdvantaText.caption
              .copyWith(color: Colors.white.withAlpha(180)),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: AdvantaText.heading2.copyWith(
            color: Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(30)
              : AdvantaColors.dividerGrey,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _position != null
                ? Icons.location_on_rounded
                : Icons.location_searching_rounded,
            color: _position != null
                ? AdvantaColors.success
                : AdvantaColors.gold,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _locationStatus,
              style: AdvantaText.body2.copyWith(
                color: isDark
                    ? AdvantaColors.goldLight
                    : AdvantaColors.deepForest,
              ),
            ),
          ),
          if (_isLocating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AdvantaColors.gold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivitySummary(bool isDark, AttendanceState attendance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AdvantaColors.midGreen : Colors.white,
        borderRadius: AdvantaRadius.cardRadius,
        border: Border.all(
          color: isDark
              ? AdvantaColors.goldLight.withAlpha(30)
              : AdvantaColors.dividerGrey,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdvantaColors.primaryGreen.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.grass_rounded,
                color: AdvantaColors.primaryGreen, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Aktivitas Lapangan',
                  style: AdvantaText.caption.copyWith(
                    color: AdvantaColors.mutedGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${attendance.totalActivities} aktivitas tercatat',
                  style: AdvantaText.bodyBold.copyWith(
                    color: isDark
                        ? AdvantaColors.goldLight
                        : AdvantaColors.deepForest,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${attendance.totalActivities}',
            style: AdvantaText.display.copyWith(
              color: AdvantaColors.primaryGreen,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _notesController,
          maxLines: 4,
          maxLength: _maxNotesLength,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
          null,
          style: AdvantaText.body2.copyWith(
            color: isDark ? AdvantaColors.goldLight : AdvantaColors.deepForest,
          ),
          decoration: InputDecoration(
            labelText: 'Catatan Kendala Lapangan (opsional)',
            hintText: 'Tuliskan kendala yang ditemui hari ini…',
            alignLabelWithHint: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8, top: 14),
              child: Icon(Icons.note_alt_outlined,
                  color: AdvantaColors.mutedGrey, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_notesLength / $_maxNotesLength',
          style: AdvantaText.caption.copyWith(color: AdvantaColors.mutedGrey),
        ),
      ],
    );
  }

  Widget _buildCheckOutButton(bool canCheckOut) {
    if (_isSubmitting) {
      return Container(
        height: 58,
        decoration: BoxDecoration(
          color: AdvantaColors.gold.withAlpha(150),
          borderRadius: AdvantaRadius.buttonRadius,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: canCheckOut
            ? const LinearGradient(
          colors: [AdvantaColors.goldLight, AdvantaColors.gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: canCheckOut ? null : AdvantaColors.mutedGrey.withAlpha(60),
        borderRadius: AdvantaRadius.buttonRadius,
        boxShadow: canCheckOut
            ? [
          BoxShadow(
            color: AdvantaColors.gold.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canCheckOut ? _handleCheckOut : null,
          borderRadius: AdvantaRadius.buttonRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'SELESAI HARI INI',
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
        onPressed: _isLocating ? null : _determinePosition,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Perbarui Lokasi'),
        style: TextButton.styleFrom(foregroundColor: AdvantaColors.mutedGrey),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY SHEET WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _SummarySheet extends StatefulWidget {
  final String checkInStr;
  final String checkOutStr;
  final String duration;
  final int totalActivities;
  final VoidCallback onClose;

  const _SummarySheet({
    required this.checkInStr,
    required this.checkOutStr,
    required this.duration,
    required this.totalActivities,
    required this.onClose,
  });

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AdvantaColors.dividerGrey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Checkmark Icon
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AdvantaColors.lightGreen, AdvantaColors.primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AdvantaColors.primaryGreen.withAlpha(80),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Check-out Berhasil!', style: AdvantaText.heading1),
          const SizedBox(height: 8),
          Text(
            'Terima kasih atas kerja keras Anda hari ini.',
            style: AdvantaText.body2
                .copyWith(color: AdvantaColors.mutedGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Stat row
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AdvantaColors.deepForest : AdvantaColors.softGrey,
              borderRadius: AdvantaRadius.cardRadius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statTile(
                  Icons.login_rounded,
                  'CHECK-IN',
                  widget.checkInStr,
                  AdvantaColors.primaryGreen,
                ),
                _divider(),
                _statTile(
                  Icons.timer_outlined,
                  'DURASI',
                  widget.duration,
                  AdvantaColors.gold,
                ),
                _divider(),
                _statTile(
                  Icons.grass_rounded,
                  'AKTIVITAS',
                  '${widget.totalActivities}',
                  AdvantaColors.lightGreen,
                ),
                _divider(),
                _statTile(
                  Icons.logout_rounded,
                  'CHECK-OUT',
                  widget.checkOutStr,
                  AdvantaColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AdvantaColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: AdvantaRadius.buttonRadius),
                elevation: 0,
              ),
              child: Text('KEMBALI KE BERANDA',
                  style: AdvantaText.button.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: AdvantaText.heading3.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AdvantaText.caption
              .copyWith(color: AdvantaColors.mutedGrey, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
        width: 1, height: 40, color: AdvantaColors.dividerGrey);
  }
}