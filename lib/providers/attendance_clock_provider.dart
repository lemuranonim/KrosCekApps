import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/attendance_policy.dart';

final attendanceClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final attendanceDayProvider = Provider<String>(
  (ref) => AttendancePolicy.dateKey(
    ref.watch(attendanceClockProvider).value ?? DateTime.now(),
  ),
);
