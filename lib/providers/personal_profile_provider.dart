import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/personal_daily_task.dart';
import '../utils/qa_name_helper.dart';
import '../utils/weekly_audit.dart';
import 'attendance_clock_provider.dart';
import 'attendance_provider.dart';
import 'master_fields_provider.dart';

final profilePhotoProvider = FutureProvider.autoDispose<String?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  final refresh = Timer(const Duration(minutes: 50), ref.invalidateSelf);
  ref.onDispose(refresh.cancel);
  return ref.watch(supabaseServiceProvider).getProfilePhotoUrl(user.id);
}, retry: (_, __) => null);

final personalPlanningFieldsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, day) async {
      final user = await ref.watch(currentUserProvider.future);
      if (user == null ||
          user.name.trim().isEmpty ||
          user.role.toLowerCase() == 'guest') {
        return [];
      }
      final isSpv = user.role.trim().toLowerCase() == 'spv';
      final rows = await ref
          .watch(supabaseServiceProvider)
          .getAuditPlanningIndex(
            qaFi: isSpv ? null : user.name,
            qaSpv: isSpv ? user.name : null,
          );
      // Recheck exact names after the API's broad ILIKE matching/cache response.
      final scoped = rows
          .where(
            (row) =>
                row['region']?.toString().trim().toLowerCase() !=
                    'region tester' &&
                (isSpv
                    ? QaNameHelper.fieldHasSpv(row, user.name)
                    : QaNameHelper.fieldHasFi(row, user.name)),
          )
          .toList();
      if (!ref.mounted) return [];
      final today = DateTime.parse(day);
      final numbers = scoped
          .where(
            (row) => WeeklyAuditField.fromRaw(
              row,
              weekStart: auditWeekStart(today),
              now: today,
            ).targets.any((target) => target.includesDate(today)),
          )
          .map((row) => row['field_number']?.toString().trim() ?? '')
          .where((number) => number.isNotEmpty)
          .toSet()
          .toList();
      if (numbers.isEmpty) return [];
      final details = await ref
          .read(supabaseServiceProvider)
          .getAuditPlanningFields(
            numbers,
            qaFi: isSpv ? null : user.name,
            qaSpv: isSpv ? user.name : null,
          );
      return details
          .where(
            (row) => isSpv
                ? QaNameHelper.fieldHasSpv(row, user.name)
                : QaNameHelper.fieldHasFi(row, user.name),
          )
          .toList();
    }, retry: (_, __) => null);

final personalDailyTasksProvider =
    Provider.autoDispose<AsyncValue<PersonalDailyTasks>>((ref) {
      final day = ref.watch(attendanceDayProvider);
      final fields = ref.watch(personalPlanningFieldsProvider(day));
      final activities = ref.watch(
        attendanceProvider.select((state) => state.activities),
      );
      return fields.whenData(
        (rows) => buildPersonalDailyTasks(
          fields: rows,
          activities: activities,
          now: DateTime.now(),
        ),
      );
    });

final attendanceHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, limit) async {
      ref.watch(attendanceDayProvider);
      final user = await ref.watch(currentUserProvider.future);
      if (user == null || user.role.toLowerCase() == 'guest') return [];
      // Watching timestamps also refreshes history immediately after either action.
      ref.watch(
        attendanceProvider.select((s) => (s.checkInTime, s.checkOutTime)),
      );
      return ref
          .watch(supabaseServiceProvider)
          .getAttendanceHistory(user.id, limit: limit);
    }, retry: (_, __) => null);
