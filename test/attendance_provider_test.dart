import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/providers/attendance_clock_provider.dart';
import 'package:kroscek/providers/attendance_provider.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/services/supabase_auth_service.dart';
import 'package:kroscek/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Service extends SupabaseService {
  final Map<String, Completer<Map<String, dynamic>?>> requests = {};
  _Service(SupabaseClient client) : super(client: client);
  @override
  Future<Map<String, dynamic>?> getTodayAttendance(String userId) =>
      requests.putIfAbsent(userId, Completer.new).future;
  @override
  Future<List<Map<String, dynamic>>> getTodayActivities(String id) async => [];
}

void main() {
  test(
    'late attendance responses cannot restore the previous account',
    () async {
      final client = SupabaseClient('https://attendance.invalid', 'test-key');
      addTearDown(client.dispose);
      final service = _Service(client);
      var userId = 'account-a';
      final container = ProviderContainer(
        overrides: [
          supabaseServiceProvider.overrideWithValue(service),
          currentUserProvider.overrideWith(
            (ref) async => AppUser(
              id: userId,
              email: '$userId@example.invalid',
              name: userId,
              role: 'FI',
              action: 'audit',
            ),
          ),
          attendanceClockProvider.overrideWith(
            (ref) => Stream.value(DateTime.now()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(attendanceProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(service.requests, contains('account-a'));
      userId = 'account-b';
      container.invalidate(currentUserProvider);
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(Duration.zero);
      service.requests['account-a']!.complete({
        'attendance_id': 'old-attendance',
        'check_in_time': DateTime.now().toIso8601String(),
        'check_in_lat': 10,
        'status': 'open',
      });
      service.requests['account-b']!.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(attendanceProvider).attendanceId, isNull);
      expect(container.read(attendanceProvider).isCheckedIn, false);
      expect(container.read(attendanceProvider).checkInLat, isNull);
    },
  );
}
