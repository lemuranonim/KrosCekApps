import '../providers/attendance_provider.dart';
import '../utils/attendance_policy.dart';
import '../utils/weekly_audit.dart';

class PersonalDailyTask {
  final String fieldNumber;
  final String phase;
  final String village;
  final String hybrid;
  final DateTime? deadline;
  final DateTime? completedAt;
  final double? lat;
  final double? lng;

  const PersonalDailyTask({
    required this.fieldNumber,
    required this.phase,
    this.village = '',
    this.hybrid = '',
    this.deadline,
    this.completedAt,
    this.lat,
    this.lng,
  });

  String get key => '$fieldNumber|$phase';
  bool get isDone => completedAt != null;
  String get title => phase.replaceAll('_', ' ').toUpperCase();
}

class PersonalDailyTasks {
  final List<PersonalDailyTask> pending;
  final List<PersonalDailyTask> completed;
  final int completedTargetCount;
  const PersonalDailyTasks({
    this.pending = const [],
    this.completed = const [],
    this.completedTargetCount = 0,
  });

  int get total => pending.length + completedTargetCount;
  double get progress => total == 0 ? 0 : completedTargetCount / total;
}

/// Pending targets use the same DAP windows as Planning Audit. Completion is
/// attributed only to this user's recorded inspection activities for this day.
PersonalDailyTasks buildPersonalDailyTasks({
  required List<Map<String, dynamic>> fields,
  required List<AttendanceActivity> activities,
  required DateTime now,
}) {
  final today = AttendancePolicy.day(now);
  final recorded = <String, AttendanceActivity>{};
  for (final activity in activities) {
    final number = activity.fieldNumber?.trim() ?? '';
    final phase = activity.phase?.trim().toLowerCase() ?? '';
    if (number.isEmpty ||
        phase.isEmpty ||
        AttendancePolicy.dateKey(activity.actionTime) !=
            AttendancePolicy.dateKey(now)) {
      continue;
    }
    final key = '$number|$phase';
    final previous = recorded[key];
    if (previous == null || previous.actionTime.isBefore(activity.actionTime)) {
      recorded[key] = activity;
    }
  }
  final pending = <String, PersonalDailyTask>{};
  final completedTargets = <String>{};
  final metadata = <String, Map<String, dynamic>>{};
  for (final row in fields) {
    final number = row['field_number']?.toString().trim() ?? '';
    if (number.isEmpty) continue;
    metadata[number] = row;
    final weekly = WeeklyAuditField.fromRaw(
      row,
      weekStart: auditWeekStart(today),
      now: today,
    );
    if (!weekly.isAuditEligible) continue;
    for (final target in weekly.targets) {
      final key = '$number|${target.phase}';
      if (target.done &&
          target.includesDate(today) &&
          recorded.containsKey(key)) {
        completedTargets.add(key);
      }
      if (target.done || !target.includesDate(today)) {
        continue;
      }
      pending[key] = PersonalDailyTask(
        fieldNumber: number,
        phase: target.phase,
        village: row['village_desa']?.toString() ?? '',
        hybrid: row['hybrid']?.toString() ?? '',
        deadline: target.deadline,
      );
    }
  }
  final completed = recorded.values.map((activity) {
    final row = metadata[activity.fieldNumber] ?? const <String, dynamic>{};
    return PersonalDailyTask(
      fieldNumber: activity.fieldNumber!,
      phase: activity.phase!.toLowerCase(),
      village: row['village_desa']?.toString() ?? '',
      hybrid: row['hybrid']?.toString() ?? '',
      completedAt: activity.actionTime,
      lat: activity.lat,
      lng: activity.lng,
    );
  }).toList()..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  final remaining = pending.values.toList()
    ..sort((a, b) {
      final date = a.deadline!.compareTo(b.deadline!);
      return date == 0 ? a.key.compareTo(b.key) : date;
    });
  return PersonalDailyTasks(
    pending: remaining,
    completed: completed,
    completedTargetCount: completedTargets.length,
  );
}
