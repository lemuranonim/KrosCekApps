// lib/widgets/attendance_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/attendance_provider.dart';
import '../theme/app_theme.dart';

class AttendanceBanner extends ConsumerStatefulWidget {
  const AttendanceBanner({super.key});

  @override
  ConsumerState<AttendanceBanner> createState() => _AttendanceBannerState();
}

class _AttendanceBannerState extends ConsumerState<AttendanceBanner>
    with SingleTickerProviderStateMixin {
  // Real-time clock untuk durasi kerja
  late Timer _timer;
  DateTime _now = DateTime.now();

  // Pulse animation untuk state belum check-in
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(DateTime checkIn) {
    final diff = _now.difference(checkIn);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (h > 0) {
      return '${h}j ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}d';
    }
    return '${m}m ${s.toString().padLeft(2, '0')}d';
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceProvider);

    // ── SUDAH CHECK-OUT ──────────────────────────────────────────────────
    if (attendance.isCheckedOut) {
      return _ClosedBanner(
        checkInStr: attendance.checkInTime != null
            ? DateFormat('HH:mm').format(attendance.checkInTime!)
            : '--:--',
        checkOutStr: attendance.checkOutTime != null
            ? DateFormat('HH:mm').format(attendance.checkOutTime!)
            : '--:--',
        duration: attendance.workDurationFormatted,
        totalActivities: attendance.totalActivities,
      );
    }

    // ── SUDAH CHECK-IN, BELUM CHECK-OUT ──────────────────────────────────
    if (attendance.isCheckedIn) {
      final checkInStr = attendance.checkInTime != null
          ? DateFormat('HH:mm').format(attendance.checkInTime!)
          : '--:--';
      final liveDuration = attendance.checkInTime != null
          ? _formatDuration(attendance.checkInTime!)
          : '--:--';

      return _ActiveBanner(
        checkInStr: checkInStr,
        liveDuration: liveDuration,
        totalActivities: attendance.totalActivities,
        onCheckOut: () => context.push('/checkout'),
      );
    }

    // ── BELUM CHECK-IN ───────────────────────────────────────────────────
    return FadeTransition(
      opacity: _pulseOpacity,
      child: _NotCheckedInBanner(
        onCheckIn: () => context.push('/checkin'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER: BELUM CHECK-IN
// ─────────────────────────────────────────────────────────────────────────────

class _NotCheckedInBanner extends StatelessWidget {
  final VoidCallback onCheckIn;
  const _NotCheckedInBanner({required this.onCheckIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Belum Absen!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  Text(
                    'Lakukan check-in sebelum inspeksi lahan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCheckIn,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CHECK-IN',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.8,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER: AKTIF BEKERJA
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  final String checkInStr;
  final String liveDuration;
  final int totalActivities;
  final VoidCallback onCheckOut;

  const _ActiveBanner({
    required this.checkInStr,
    required this.liveDuration,
    required this.totalActivities,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AdvantaColors.primaryGreen, AdvantaColors.midGreen],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AdvantaColors.lightGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            // Main content
            Expanded(
              child: Row(
                children: [
                  _statChip(
                    icon: Icons.login_rounded,
                    value: checkInStr,
                    label: 'Masuk',
                  ),
                  const SizedBox(width: 12),
                  _statChip(
                    icon: Icons.timer_rounded,
                    value: liveDuration,
                    label: 'Durasi',
                    isLive: true,
                  ),
                  const SizedBox(width: 12),
                  _statChip(
                    icon: Icons.grass_rounded,
                    value: '$totalActivities',
                    label: 'Aktivitas',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Check-out button
            GestureDetector(
              onTap: onCheckOut,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AdvantaColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'KELUAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontFamily: 'Nunito',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
    bool isLive = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 10),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontFamily: 'Nunito',
                letterSpacing: 0.3,
              ),
            ),
            if (isLive) ...[
              const SizedBox(width: 3),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AdvantaColors.lightGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'Nunito',
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER: SUDAH SELESAI
// ─────────────────────────────────────────────────────────────────────────────

class _ClosedBanner extends StatelessWidget {
  final String checkInStr;
  final String checkOutStr;
  final String duration;
  final int totalActivities;

  const _ClosedBanner({
    required this.checkInStr,
    required this.checkOutStr,
    required this.duration,
    required this.totalActivities,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AdvantaColors.gold, AdvantaColors.goldLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.task_alt_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Hari kerja selesai · Kerja bagus!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFamily: 'Nunito',
                    ),
                  ),
                  Text(
                    '$checkInStr → $checkOutStr  ·  $duration  ·  $totalActivities aktivitas',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}