import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/personal_daily_task.dart';
import '../../providers/attendance_clock_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/personal_profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/attendance_policy.dart';
import '../../widgets/attendance_avatar_button.dart';
import '../../widgets/field_detail_bottom_sheet.dart';

class PersonalProfileScreen extends ConsumerStatefulWidget {
  const PersonalProfileScreen({super.key});
  @override
  ConsumerState<PersonalProfileScreen> createState() =>
      _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends ConsumerState<PersonalProfileScreen>
    with WidgetsBindingObserver {
  bool _uploading = false;
  bool _allPending = false;
  String? _openingTask;
  int _historyLimit = 7;

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
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final user = ref.read(currentUserProvider).value;
    final day = ref.read(attendanceDayProvider);
    ref.invalidate(personalPlanningFieldsProvider(day));
    ref.invalidate(attendanceHistoryProvider(_historyLimit));
    if (user != null) {
      await ref.read(attendanceProvider.notifier).loadTodayAttendance(user.id);
    }
  }

  Future<void> _photo() async {
    if (_uploading) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.role.toLowerCase() == 'guest') {
      return;
    }
    setState(() => _uploading = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final extension = file.name.split('.').last.toLowerCase();
      await ref
          .read(supabaseServiceProvider)
          .uploadProfilePhoto(user.id, await file.readAsBytes(), extension);
      if (!mounted) return;
      ref.invalidate(profilePhotoProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Foto profil diperbarui.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto belum dapat disimpan. Gunakan JPG/PNG/WebP maksimal 3 MB dan coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _attendanceAction() async {
    final attendance = ref.read(attendanceProvider);
    if (attendance.isLoading ||
        attendance.errorMessage != null ||
        attendance.isCheckedOut) {
      return;
    }
    if (attendance.isCheckedIn &&
        !AttendancePolicy.canCheckOut(
          checkedIn: true,
          checkedOut: false,
          now: DateTime.now(),
        )) {
      return;
    }
    await context.push(attendance.isCheckedIn ? '/checkout' : '/checkin');
    if (mounted) await _refresh();
  }

  Future<void> _openTask(PersonalDailyTask task) async {
    if (_openingTask != null) return;
    if (task.isDone) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(task.title, style: AdvantaText.heading3),
              Text(task.fieldNumber),
              const SizedBox(height: 12),
              Text('Inspeksi tercatat pukul ${_time(task.completedAt)} WIB.'),
              if (task.lat != null && task.lng != null)
                _locationLink('Lokasi aktivitas', task.lat!, task.lng!),
            ],
          ),
        ),
      );
      return;
    }
    final attendance = ref.read(attendanceProvider);
    if (attendance.isLoading || attendance.errorMessage != null) return;
    if (!attendance.isCheckedIn && !task.isDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Absen masuk terlebih dahulu sebelum inspeksi.'),
        ),
      );
      return;
    }
    if (attendance.isCheckedOut && !task.isDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Absensi hari ini sudah selesai.')),
      );
      return;
    }
    setState(() => _openingTask = task.key);
    try {
      final field = await ref.refresh(
        masterFieldDetailProvider(task.fieldNumber).future,
      );
      if (!mounted) return;
      if (field == null) throw StateError('Field detail unavailable');
      FieldDetailBottomSheet.show(
        context,
        field,
        dapReferenceDate: AttendancePolicy.day(DateTime.now()),
        onInspectDone: (_) async => _refresh(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Detail lahan belum dapat dimuat. Coba ketuk target lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingTask = null);
    }
  }

  String _time(DateTime? value) => value == null
      ? '—'
      : DateFormat('HH:mm').format(AttendancePolicy.workTime(value));

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final photo = ref.watch(profilePhotoProvider);
    final attendance = ref.watch(attendanceProvider);
    final now = ref.watch(attendanceClockProvider).value ?? DateTime.now();
    final tasks = ref.watch(personalDailyTasksProvider);
    final history = ref.watch(attendanceHistoryProvider(_historyLimit));
    final isGuest = user?.role.toLowerCase() == 'guest';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil saya'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan akun',
            onPressed: () => context.push('/qa/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(currentUserProvider),
            child: const Text('Muat ulang profil'),
          ),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      ProfilePortrait(
                        name: user?.name ?? '',
                        photoUrl: photo.asData?.value,
                        size: 64,
                      ),
                      if (!isGuest)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _uploading ? null : _photo,
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: _uploading
                                    ? const SizedBox.square(
                                        dimension: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.edit_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Profil saya',
                          style: AdvantaText.heading2,
                        ),
                        Text(
                          user?.role ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (photo.hasError)
                TextButton.icon(
                  onPressed: () => ref.invalidate(profilePhotoProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Muat ulang foto'),
                ),
              const SizedBox(height: 22),
              if (isGuest)
                const _ProfileSurface(
                  child: Text('Akun tamu memiliki akses baca.'),
                )
              else ...[
                _attendanceCard(attendance, now),
                const SizedBox(height: 24),
                tasks.when(
                  loading: () => const _ProfileSurface(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, __) => _ProfileSurface(
                    child: Column(
                      children: [
                        const Text('Planning hari ini belum dapat dimuat.'),
                        TextButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                  data: _tasks,
                ),
                const SizedBox(height: 24),
                Text('Riwayat absensi', style: AdvantaText.heading3),
                const SizedBox(height: 10),
                history.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => TextButton(
                    onPressed: () => ref.invalidate(
                      attendanceHistoryProvider(_historyLimit),
                    ),
                    child: const Text('Muat ulang riwayat absensi'),
                  ),
                  data: (rows) => rows.isEmpty
                      ? const _ProfileSurface(
                          child: Text('Belum ada riwayat absensi.'),
                        )
                      : _ProfileSurface(
                          child: Column(
                            children: [
                              for (var i = 0; i < rows.length; i++) ...[
                                if (i > 0) const Divider(height: 20),
                                _historyRow(rows[i]),
                              ],
                              if (rows.length == _historyLimit &&
                                  _historyLimit < 90)
                                TextButton(
                                  onPressed: () => setState(
                                    () => _historyLimit = (_historyLimit + 14)
                                        .clamp(1, 90),
                                  ),
                                  child: const Text('Lihat lebih banyak'),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _attendanceCard(AttendanceState attendance, DateTime now) {
    final canOut = AttendancePolicy.canCheckOut(
      checkedIn: attendance.isCheckedIn,
      checkedOut: attendance.isCheckedOut,
      now: now,
    );
    final reminder = AttendancePolicy.remindCheckout(
      checkedIn: attendance.isCheckedIn,
      checkedOut: attendance.isCheckedOut,
      now: now,
    );
    final ready = !attendance.isLoading && attendance.errorMessage == null;
    final title = attendance.isLoading
        ? 'Memuat absensi…'
        : attendance.errorMessage != null
        ? 'Absensi belum dapat dimuat'
        : attendance.isCheckedOut
        ? 'Selesai untuk hari ini'
        : !attendance.isCheckedIn
        ? 'Siap memulai hari?'
        : canOut
        ? 'Sudah selesai bekerja?'
        : 'Selamat bekerja!';
    final status = attendance.isCheckedOut
        ? 'Absensi lengkap'
        : !attendance.isCheckedIn
        ? 'Belum masuk'
        : reminder
        ? 'Belum absen pulang'
        : 'Sedang bekerja';
    final color = !ready
        ? AdvantaColors.mutedGrey
        : attendance.isCheckedOut
        ? AdvantaColors.success
        : !attendance.isCheckedIn
        ? AdvantaColors.error
        : reminder
        ? AdvantaColors.gold
        : AdvantaColors.success;
    return _ProfileSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('ABSENSI HARI INI', style: AdvantaText.label),
              if (ready)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AdvantaText.heading2),
          const SizedBox(height: 5),
          Text(
            '${DateFormat('d MMMM yyyy', 'id_ID').format(AttendancePolicy.workTime(now))} · WIB',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _clock('Masuk', _time(attendance.checkInTime))),
              Expanded(child: _clock('Pulang', _time(attendance.checkOutTime))),
              Expanded(
                child: _clock('Durasi', attendance.workDurationFormatted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (attendance.isLoading)
            const LinearProgressIndicator()
          else if (attendance.errorMessage != null)
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Muat ulang absensi'),
            )
          else
            FilledButton.icon(
              onPressed:
                  attendance.isCheckedOut || (attendance.isCheckedIn && !canOut)
                  ? null
                  : _attendanceAction,
              icon: Icon(
                attendance.isCheckedOut
                    ? Icons.check_circle_outline
                    : !attendance.isCheckedIn
                    ? Icons.login_rounded
                    : canOut
                    ? Icons.logout_rounded
                    : Icons.lock_clock_outlined,
              ),
              label: Text(
                attendance.isCheckedOut
                    ? 'Absensi lengkap'
                    : !attendance.isCheckedIn
                    ? 'Absen masuk'
                    : canOut
                    ? 'Absen pulang'
                    : 'Pulang mulai 15.00 WIB',
              ),
            ),
          if (attendance.isCheckedIn && !attendance.isCheckedOut && ready)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                reminder
                    ? 'Jangan lupa absen pulang. Tersedia mulai pukul 15.00 WIB.'
                    : 'Absen masuk sudah tercatat. Selamat beraktivitas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (attendance.checkInLat != null && attendance.checkInLng != null)
            _locationLink(
              'Lokasi masuk',
              attendance.checkInLat!,
              attendance.checkInLng!,
            ),
          if (attendance.checkOutLat != null && attendance.checkOutLng != null)
            _locationLink(
              'Lokasi pulang',
              attendance.checkOutLat!,
              attendance.checkOutLng!,
            ),
        ],
      ),
    );
  }

  Widget _clock(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(value, style: AdvantaText.heading3),
    ],
  );

  Widget _tasks(PersonalDailyTasks tasks) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text('Target hari ini', style: AdvantaText.heading3),
          ),
          Text(
            '${tasks.completedTargetCount} / ${tasks.total} selesai',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(value: tasks.progress, minHeight: 5),
      ),
      const SizedBox(height: 8),
      Text(
        'Mengikuti planning dan jendela DAP hari ini.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      _ProfileSurface(
        child: tasks.pending.isEmpty
            ? Text(
                tasks.total == 0
                    ? 'Tidak ada target planning untuk hari ini.'
                    : 'Tidak ada target tertunda hari ini.',
              )
            : Column(
                children: [
                  for (final task in tasks.pending.take(
                    _allPending ? tasks.pending.length : 3,
                  ))
                    _taskTile(task),
                  if (tasks.pending.length > 3)
                    TextButton(
                      onPressed: () =>
                          setState(() => _allPending = !_allPending),
                      child: Text(
                        _allPending
                            ? 'Ringkas daftar'
                            : 'Lihat ${tasks.pending.length} tugas',
                      ),
                    ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      _ProfileSurface(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            'Selesai hari ini · ${tasks.completed.length}',
            style: AdvantaText.heading3,
          ),
          subtitle: const Text('Aktivitas inspeksi yang kamu catat hari ini'),
          children: tasks.completed.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Belum ada aktivitas selesai hari ini.'),
                  ),
                ]
              : tasks.completed.map(_taskTile).toList(),
        ),
      ),
    ],
  );

  Widget _taskTile(PersonalDailyTask task) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: AdvantaColors.paleGreen,
      child: Icon(
        task.isDone ? Icons.check : Icons.grass,
        color: AdvantaColors.primaryGreen,
      ),
    ),
    title: Text(task.title, style: AdvantaText.bodyBold),
    subtitle: Text(
      [
        task.fieldNumber,
        if (task.village.isNotEmpty) task.village,
        if (task.isDone) 'Tercatat ${_time(task.completedAt)} WIB',
      ].join(' · '),
    ),
    trailing: _openingTask == task.key
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chevron_right),
    onTap: () => _openTask(task),
  );

  Widget _historyRow(Map<String, dynamic> row) {
    final date = DateTime.tryParse(row['attendance_date']?.toString() ?? '');
    final checkIn = DateTime.tryParse(row['check_in_time']?.toString() ?? '');
    final checkOut = DateTime.tryParse(row['check_out_time']?.toString() ?? '');
    return InkWell(
      onTap: () => _historyDetail(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date == null
                        ? '—'
                        : DateFormat('d MMM yyyy', 'id_ID').format(date),
                    style: AdvantaText.bodyBold,
                  ),
                  Text(
                    checkOut != null ? 'Absensi lengkap' : 'Belum absen pulang',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text('${_time(checkIn)} → ${_time(checkOut)}'),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  void _historyDetail(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Detail absensi · ${row['attendance_date']}',
              style: AdvantaText.heading3,
            ),
            const SizedBox(height: 16),
            Text(
              'Masuk: ${_time(DateTime.tryParse(row['check_in_time']?.toString() ?? ''))} WIB',
            ),
            Text(
              'Pulang: ${_time(DateTime.tryParse(row['check_out_time']?.toString() ?? ''))} WIB',
            ),
            if (row['check_in_lat'] is num && row['check_in_lng'] is num)
              _locationLink(
                'Lokasi masuk',
                (row['check_in_lat'] as num).toDouble(),
                (row['check_in_lng'] as num).toDouble(),
              ),
            if (row['check_out_lat'] is num && row['check_out_lng'] is num)
              _locationLink(
                'Lokasi pulang',
                (row['check_out_lat'] as num).toDouble(),
                (row['check_out_lng'] as num).toDouble(),
              ),
            if ((row['notes']?.toString() ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(row['notes'].toString()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _locationLink(String label, double lat, double lng) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 64),
        padding: const EdgeInsets.all(14),
        backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withAlpha(110),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        final uri = Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': '$lat,$lng',
        });
        try {
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            throw StateError('Maps unavailable');
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Peta belum dapat dibuka.')),
            );
          }
        }
      },
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lihat ${label.toLowerCase()} di Maps',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    ),
  );
}

class _ProfileSurface extends StatelessWidget {
  final Widget child;
  const _ProfileSurface({required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
