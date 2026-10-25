import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/attendance_clock_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/master_fields_provider.dart';
import '../providers/personal_profile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/attendance_policy.dart';

class ProfilePortrait extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  const ProfilePortrait({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    final initials = parts
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    final fallback = ColoredBox(
      color: AdvantaColors.paleGreen,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: AdvantaColors.deepForest,
            fontWeight: FontWeight.w800,
            fontSize: size * .32,
          ),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: photoUrl == null
            ? fallback
            : Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

class AttendanceAvatarButton extends ConsumerStatefulWidget {
  const AttendanceAvatarButton({super.key});
  @override
  ConsumerState<AttendanceAvatarButton> createState() =>
      _AttendanceAvatarButtonState();
}

class _AttendanceAvatarButtonState extends ConsumerState<AttendanceAvatarButton>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      ref.read(attendanceProvider.notifier).loadTodayAttendance(user.id);
    }
    ref.invalidate(profilePhotoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final attendance = ref.watch(attendanceProvider);
    final now = ref.watch(attendanceClockProvider).value ?? DateTime.now();
    final photo = ref.watch(profilePhotoProvider).asData?.value;
    final guest = user?.role.toLowerCase() == 'guest';
    IconData? badge;
    var label = 'Profil saya';
    var ring = AdvantaColors.mutedGrey;
    var badgeColor = AdvantaColors.gold;
    if (!guest && user != null) {
      if (attendance.isLoading) {
        label += ', memuat absensi';
        badge = Icons.sync_rounded;
      } else if (attendance.errorMessage != null) {
        label += ', absensi perlu dimuat ulang';
        badge = Icons.sync_problem_rounded;
      } else if (!attendance.isCheckedIn) {
        label += ', belum absen masuk';
        ring = badgeColor = AdvantaColors.error;
        badge = Icons.priority_high_rounded;
      } else if (attendance.isCheckedOut) {
        label += ', absensi lengkap';
        ring = badgeColor = AdvantaColors.success;
        badge = Icons.check_rounded;
      } else {
        ring = AdvantaColors.success;
        label += ', sudah absen masuk';
        if (AttendancePolicy.remindCheckout(
          checkedIn: true,
          checkedOut: false,
          now: now,
        )) {
          badge =
              AttendancePolicy.canCheckOut(
                checkedIn: true,
                checkedOut: false,
                now: now,
              )
              ? Icons.logout_rounded
              : Icons.schedule_rounded;
          label += ', belum absen pulang';
        }
      }
    }
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkResponse(
          onTap: () => context.push('/profile'),
          radius: 28,
          child: SizedBox.square(
            dimension: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ring, width: 2),
                  ),
                  child: ProfilePortrait(
                    name: user?.name ?? '',
                    photoUrl: photo,
                    size: 36,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -1,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badgeColor,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(badge, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
