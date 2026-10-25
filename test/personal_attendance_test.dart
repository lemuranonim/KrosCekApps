import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/models/personal_daily_task.dart';
import 'package:kroscek/providers/attendance_provider.dart';
import 'package:kroscek/utils/attendance_policy.dart';

final _now = DateTime.utc(2026, 10, 17, 5, 30);
Map<String, dynamic> _field({String number = 'FN-1', String? auditDate}) => {
  'field_number': number,
  'hybrid': 'FC',
  'planting_date_pdn': '2026-10-07',
  'effective_area_ha': 4,
  'region': 'East',
  'district_kab': 'Blitar',
  'village_desa': 'Sumber',
  if (auditDate != null) 'audit_vegetative': {'date_of_audit': auditDate},
};

AttendanceActivity _activity(
  String id,
  DateTime time, {
  String number = 'FN-1',
}) => AttendanceActivity(
  activityId: id,
  fieldNumber: number,
  phase: 'vegetative',
  actionTime: time,
);

void main() {
  test(
    'a partial or stale planning completion is not marked as a finished target',
    () {
      final tasks = buildPersonalDailyTasks(
        fields: [_field()],
        activities: [_activity('1', _now)],
        now: _now,
      );
      expect(tasks.pending, hasLength(1));
      expect(tasks.completed, hasLength(1));
      expect(tasks.completedTargetCount, 0);
      expect(tasks.progress, 0);
    },
  );
  test('checkout reminders start exactly at noon and checkout at 15 WIB', () {
    bool remind(DateTime time) => AttendancePolicy.remindCheckout(
      checkedIn: true,
      checkedOut: false,
      now: time,
    );
    bool checkout(DateTime time) => AttendancePolicy.canCheckOut(
      checkedIn: true,
      checkedOut: false,
      now: time,
    );
    expect(remind(DateTime.utc(2026, 10, 17, 4, 59, 59)), false);
    expect(remind(DateTime.utc(2026, 10, 17, 5)), true);
    expect(checkout(DateTime.utc(2026, 10, 17, 7, 59, 59)), false);
    expect(checkout(DateTime.utc(2026, 10, 17, 8)), true);
    expect(
      AttendancePolicy.remindCheckout(
        checkedIn: false,
        checkedOut: false,
        now: DateTime.utc(2026, 10, 17, 10),
      ),
      false,
    );
    expect(
      AttendancePolicy.canCheckOut(
        checkedIn: false,
        checkedOut: false,
        now: DateTime.utc(2026, 10, 17, 10),
      ),
      false,
    );
    expect(
      AttendancePolicy.remindCheckout(
        checkedIn: true,
        checkedOut: true,
        now: DateTime.utc(2026, 10, 17, 10),
      ),
      false,
    );
    expect(
      AttendancePolicy.canCheckOut(
        checkedIn: true,
        checkedOut: true,
        now: DateTime.utc(2026, 10, 17, 10),
      ),
      false,
    );
  });

  test('business date rolls over at 17 UTC regardless of device timezone', () {
    expect(
      AttendancePolicy.dateKey(DateTime.utc(2026, 10, 17, 16, 59, 59)),
      '2026-10-17',
    );
    expect(
      AttendancePolicy.dateKey(DateTime.utc(2026, 10, 17, 17)),
      '2026-10-18',
    );
    expect(
      AttendancePolicy.dateKey(DateTime.parse('2026-10-18T01:00:00+08:00')),
      '2026-10-18',
    );
  });

  test('invalid or non-finite GPS cannot be saved', () {
    expect(
      () => AttendancePolicy.validateCoordinates(-7.2, 112.3),
      returnsNormally,
    );
    for (final coords in [
      (91.0, 112.0),
      (0.0, 181.0),
      (double.nan, 0.0),
      (0.0, double.infinity),
    ]) {
      expect(
        () => AttendancePolicy.validateCoordinates(coords.$1, coords.$2),
        throwsArgumentError,
      );
    }
  });

  test('today targets follow DAP and exclude work completed earlier', () {
    final tasks = buildPersonalDailyTasks(
      fields: [
        _field(),
        _field(number: 'OLD', auditDate: '2026-10-16'),
      ],
      activities: [],
      now: _now,
    );
    expect(tasks.pending.map((task) => task.fieldNumber), ['FN-1']);
    expect(tasks.completed, isEmpty);
  });

  test(
    'recorded inspections move out of pending and repeated saves count once',
    () {
      final tasks = buildPersonalDailyTasks(
        fields: [_field(auditDate: '2026-10-17')],
        activities: [
          _activity('1', _now.subtract(const Duration(hours: 2))),
          _activity('2', _now),
          _activity(
            '3',
            _now.subtract(const Duration(days: 1)),
            number: 'YESTERDAY',
          ),
        ],
        now: _now,
      );
      expect(tasks.pending, isEmpty);
      expect(tasks.completed, hasLength(1));
      expect(tasks.completed.single.completedAt, _now);
      expect(tasks.progress, 1);
    },
  );

  test(
    'actual work stays visible even when no longer in active DAP window',
    () {
      final tasks = buildPersonalDailyTasks(
        fields: [],
        activities: [_activity('1', _now)],
        now: _now,
      );
      expect(tasks.completed.single.fieldNumber, 'FN-1');
      expect(tasks.pending, isEmpty);
    },
  );

  test('PLD and future DAP windows do not create pending personal tasks', () {
    final tasks = buildPersonalDailyTasks(
      fields: [
        {..._field(), 'effective_area_ha': 0},
        {..._field(number: 'FUTURE'), 'planting_date_pdn': '2026-10-17'},
      ],
      activities: [],
      now: _now,
    );
    expect(tasks.total, 0);
  });
}
