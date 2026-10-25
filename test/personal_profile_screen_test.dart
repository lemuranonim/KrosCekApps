import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kroscek/models/personal_daily_task.dart';
import 'package:kroscek/models/pld_audit_lifecycle.dart';
import 'package:kroscek/providers/attendance_clock_provider.dart';
import 'package:kroscek/providers/attendance_provider.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/providers/personal_profile_provider.dart';
import 'package:kroscek/providers/pld_audit_lifecycle_provider.dart';
import 'package:kroscek/screens/profile/personal_profile_screen.dart';
import 'package:kroscek/services/supabase_auth_service.dart';
import 'package:kroscek/theme/app_theme.dart';
import 'package:kroscek/widgets/attendance_avatar_button.dart';
import 'package:kroscek/widgets/field_detail_bottom_sheet.dart';

class _Attendance extends AttendanceNotifier {
  final AttendanceState initial;
  int reloads = 0;
  _Attendance(this.initial);
  @override
  AttendanceState build() => initial;
  @override
  Future<void> loadTodayAttendance(String userId) async => reloads++;
}

Widget _app(
  Widget child, {
  AttendanceState state = const AttendanceState(),
  DateTime? now,
  bool dark = false,
  double scale = 1,
  GoRouter? router,
  String hybrid = 'AX05',
  String phase = 'vegetative',
  Future<Map<String, dynamic>?> Function(String)? loadField,
}) => ProviderScope(
  overrides: [
    currentUserProvider.overrideWith(
      (ref) async => const AppUser(
        id: 'test-user',
        email: 'test@example.invalid',
        name: 'Andi Pratama',
        role: 'FI',
        action: 'audit',
      ),
    ),
    attendanceProvider.overrideWith(() => _Attendance(state)),
    attendanceClockProvider.overrideWith(
      (ref) => Stream.value(now ?? DateTime.utc(2026, 10, 17, 5, 30)),
    ),
    profilePhotoProvider.overrideWith((ref) async => null),
    personalDailyTasksProvider.overrideWith(
      (ref) => AsyncData(
        PersonalDailyTasks(
          pending: [
            PersonalDailyTask(
              fieldNumber: 'FN-1',
              phase: phase,
              village: 'Sumber',
            ),
          ],
        ),
      ),
    ),
    masterFieldDetailProvider.overrideWith(
      (ref, number) async => loadField == null
          ? {
              'field_number': number,
              'hybrid': hybrid,
              'farmer_name': 'Petani Sumber',
              'village_desa': 'Sumber',
              'district_kab': 'Kediri',
              'region': 'Jawa',
              'planting_date': '2026-10-01',
              'flagging_final': 'GF',
            }
          : await loadField(number),
    ),
    pldAuditLifecycleProvider.overrideWith(
      (ref, number) async => const PldAuditLifecycleBundle(
        viewerRole: 'FI',
        canRevise: false,
        statuses: [],
        history: [],
      ),
    ),
    attendanceHistoryProvider(7).overrideWith(
      (ref) async => [
        {
          'attendance_date': '2026-10-16',
          'check_in_time': '2026-10-16T00:42:00Z',
          'check_out_time': '2026-10-16T08:30:00Z',
          'status': 'closed',
        },
      ],
    ),
  ],
  child: router == null
      ? MaterialApp(
          theme: dark ? AdvantaTheme.dark() : AdvantaTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        )
      : MaterialApp.router(
          theme: dark ? AdvantaTheme.dark() : AdvantaTheme.light(),
          routerConfig: router,
        ),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'profile exposes attendance, planning, completed work and history at narrow widths',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          const PersonalProfileScreen(),
          state: AttendanceState(
            isCheckedIn: true,
            checkInTime: DateTime.utc(2026, 10, 17, 0, 42),
            checkInLat: -6.1754,
            checkInLng: 106.8272,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Profil saya'), findsOneWidget);
      expect(find.text('Pulang mulai 15.00 WIB'), findsOneWidget);
      final action = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Pulang mulai 15.00 WIB'),
      );
      expect(action.onPressed, isNull);
      expect(find.text('Lihat lokasi masuk di Maps'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Riwayat absensi'), 250);
      expect(find.text('Target hari ini'), findsOneWidget);
      expect(find.text('Selesai hari ini · 0'), findsOneWidget);
      expect(find.text('Riwayat absensi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text dark profile remains usable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        const PersonalProfileScreen(),
        dark: true,
        scale: 1.5,
        state: AttendanceState(
          isCheckedIn: true,
          isCheckedOut: true,
          checkInTime: DateTime.utc(2026, 10, 17),
          checkOutTime: DateTime.utc(2026, 10, 17, 8),
          checkInLat: -6.1754,
          checkInLng: 106.8272,
          checkOutLat: -6.1755,
          checkOutLng: 106.8273,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Riwayat absensi'), 250);
    expect(tester.takeException(), isNull);
  });

  for (final crop in [
    (
      hybrid: 'AX05',
      phase: 'vegetative',
      path: '/inspect/vegetative/FN-1',
      label: 'Vegetatif',
    ),
    (
      hybrid: 'AX01',
      phase: 'generative_4',
      path: '/inspect_sc/generative_4/FN-1',
      label: 'Generatif CP4',
    ),
    (
      hybrid: 'AS71',
      phase: 'generative_5',
      path: '/inspect_psp/generative/FN-1',
      label: 'Generatif (PSP)',
    ),
  ]) {
    testWidgets('target opens Home Map detail before ${crop.hybrid} audit', (
      tester,
    ) async {
      var formOpens = 0;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const PersonalProfileScreen()),
          GoRoute(
            path: crop.path,
            builder: (context, _) {
              formOpens++;
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text('Simpan audit uji'),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _app(
          const PersonalProfileScreen(),
          router: router,
          hybrid: crop.hybrid,
          phase: crop.phase,
          state: AttendanceState(
            isCheckedIn: true,
            checkInTime: DateTime.utc(2026, 10, 17),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('FN-1 · Sumber'), 200);
      await tester.tap(find.text('FN-1 · Sumber'));
      await tester.pumpAndSettle();
      expect(find.byType(FieldDetailBottomSheet), findsOneWidget);
      expect(find.text('Field #FN-1'), findsOneWidget);
      expect(find.text('Petani Sumber'), findsWidgets);
      expect(find.text('Info Lahan'), findsOneWidget);
      expect(formOpens, 0);
      await tester.tap(find.text('Mulai Inspeksi'));
      await tester.pumpAndSettle();
      final phaseAction = find.text(crop.label).last;
      await tester.ensureVisible(phaseAction);
      await tester.tap(phaseAction);
      await tester.pumpAndSettle();
      expect(find.text('Simpan audit uji'), findsOneWidget);
      await tester.tap(find.text('Simpan audit uji'));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PersonalProfileScreen)),
      );
      expect(
        (scope.read(attendanceProvider.notifier) as _Attendance).reloads,
        1,
      );
      expect(find.byType(FieldDetailBottomSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(FieldDetailBottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed field detail can be retried without opening a form', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      _app(
        const PersonalProfileScreen(),
        state: const AttendanceState(isCheckedIn: true),
        loadField: (number) async {
          if (++loads == 1) throw StateError('Offline');
          return {
            'field_number': number,
            'farmer_name': 'Petani Sumber',
            'hybrid': 'AX05',
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('FN-1 · Sumber'), 200);
    await tester.tap(find.text('FN-1 · Sumber'));
    await tester.pumpAndSettle();
    expect(
      find.text('Detail lahan belum dapat dimuat. Coba ketuk target lagi.'),
      findsOneWidget,
    );
    expect(find.byType(FieldDetailBottomSheet), findsNothing);
    await tester.tap(find.text('FN-1 · Sumber'));
    await tester.pumpAndSettle();
    expect(find.byType(FieldDetailBottomSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(FieldDetailBottomSheet))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'avatar keeps personal identity and switches reminder badge at noon',
    (tester) async {
      final state = AttendanceState(
        isCheckedIn: true,
        checkInTime: DateTime.utc(2026, 10, 17),
      );
      await tester.pumpWidget(
        _app(
          const Scaffold(body: AttendanceAvatarButton()),
          state: state,
          now: DateTime.utc(2026, 10, 17, 4, 59),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AP'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(
          const Scaffold(body: AttendanceAvatarButton()),
          state: state,
          now: DateTime.utc(2026, 10, 17, 5),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    },
  );
}
