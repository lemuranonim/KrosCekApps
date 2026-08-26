import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kroscek/providers/audit_plan_provider.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/screens/qa/audit_planning_screen.dart';
import 'package:kroscek/screens/coverage/coverage_screen.dart';
import 'package:kroscek/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kroscek/utils/weekly_audit.dart';
import 'package:kroscek/widgets/weekly_audit_widgets.dart';

import 'weekly_audit_test.dart' as fixtures;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  for (final role in ['MANAGER', 'SPV', 'FI']) {
    testWidgets(
        'Coverage $role renders mobile area cards within the role scope',
        (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        SessionKeys.activeUserId: 'test-user',
        SessionKeys.activeUserRole: role,
        SessionKeys.activeUserName: role == 'SPV' ? 'SPV 1' : 'FI 1',
      });
      final monday = auditWeekStart(DateTime.now());
      Map<String, dynamic> raw(String id, double area, String flag) => {
            ...fixtures.fieldAt(20, id: id, area: area),
            'planting_date_pdn':
                monday.subtract(const Duration(days: 20)).toIso8601String(),
            'flagging_final': flag,
          };
      final fields = [
        raw('GF1', 95, 'GF'),
        raw('RFI1', 3, 'RFI'),
        raw('PLD1', 2, 'PLD'),
        {...raw('Other-team', 50, 'GF'), 'qa_fi': 'FI 2', 'qa_spv': 'SPV 2'}
      ].map((raw) => FieldCoverageStatus.fromRaw(raw)).toList();
      await tester.pumpWidget(ProviderScope(overrides: [
        coverageStatusListProvider.overrideWith((ref) async => fields),
        coverageStatusListScopedProvider(
                const MasterFieldMapScope(region: 'East'))
            .overrideWith((ref) async => fields),
        coverageStatusListScopedProvider(const MasterFieldMapScope.all())
            .overrideWith((ref) async => fields),
        activeMasterFieldRegionsProvider(const MasterFieldMapScope.all())
            .overrideWith((ref) async => ['East']),
      ], child: const MaterialApp(home: CoverageScreen())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Area coverage'), 220,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(role == 'MANAGER' ? '148 ha' : '98 ha'), findsWidgets);
      await tester.ensureVisible(find.text('Lihat detail'));
      await tester.tap(find.text('Lihat detail'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PLD1'), findsNothing);
      expect(find.textContaining('Other-team'),
          role == 'MANAGER' ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'flag filter keeps PLD hidden by default, supports selecting nothing',
      (tester) async {
    Set<String>? chosen;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuditFlagFilter(
                selected: defaultAuditFlags,
                onChanged: (value) => chosen = value))));
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(
                find.widgetWithText(CheckboxListTile, 'PLD'))
            .value,
        false);
    await tester.tap(find.text('PLD').last);
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(chosen, contains('PLD'));

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuditFlagFilter(
                selected: const {}, onChanged: (value) => chosen = value))));
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan'));
    expect(chosen, isEmpty);
  });

  testWidgets('week arrows change exactly one Monday week', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AuditWeekSelector(
                weekStart: fixtures.week,
                onChanged: (week) => selected = week))));
    await tester.tap(find.byTooltip('Minggu berikutnya'));
    expect(selected, DateTime(2026, 8, 31));
    await tester.tap(find.byTooltip('Minggu sebelumnya'));
    expect(selected, DateTime(2026, 8, 17));
  });

  testWidgets(
      'all dashboard metric cards render on narrow phones and drill down',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final summary = WeeklyAuditSummary([
      fixtures.project(fixtures.fieldAt(20, veg: {
        'date_of_audit': '2026-08-24',
        'flagging': 'GF',
        'roguing_status': 'Not Yet',
        'lsv_status': 'Low',
        'crop_uniformity': 'Good',
        'crop_health': 'Fair',
      })),
      fixtures.project(fixtures.fieldAt(71, id: 'PH', ph: {
        'audit_date': '2026-08-24',
        'final_flagging': 'RFI',
        'male_chopping_rows': 'Complete',
      })),
    ]);
    String? detail;
    List<WeeklyAuditField>? detailFields;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: WeeklyAuditCards(
                        summary: summary,
                        onDetail: (title, fields) {
                          detail = title;
                          detailFields = fields;
                        }))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Roguing belum Done'));
    expect(detail, 'NC · Roguing');
    expect(detailFields!.single.raw['field_number'], 'F1');
    await tester.ensureVisible(find.text('Stage'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Vegetative'), findsOneWidget);
    expect(find.text('Generative'), findsOneWidget);
    expect(find.text('PreHarvest'), findsOneWidget);
    expect(find.text('Harvest'), findsOneWidget);
  });

  testWidgets('planning tabs filter phases and group by village without Codet',
      (tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final raw = [
      fixtures.fieldAt(20, id: 'V1'),
      fixtures.fieldAt(20, id: 'V2'),
      fixtures.fieldAt(71, id: 'PH'),
      fixtures.fieldAt(95, id: 'H')
    ];
    final fields = raw
        .map((f) => AuditPlanField(
            ParsedFieldData(
                raw: f,
                lat: -7.6,
                lng: 112.1,
                isDefault: false,
                isCorrected: false,
                isFromPolygon: false,
                dap: 20),
            fixtures.project(f)))
        .toList();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          auditPlanningProvider((weekStart: fixtures.week, region: 'East'))
              .overrideWith((ref) async => fields),
          auditPlanningRegionsProvider.overrideWith((ref) async => ['East']),
        ],
        child: MaterialApp(
            home: AuditPlanningScreen(initialWeek: fixtures.week))));
    await tester.pumpAndSettle();
    expect(find.text('Vegetative · 1 desa · 2 lahan'), findsOneWidget);
    expect(find.textContaining('Codet'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('V1 ·'), findsNothing);
    await tester.scrollUntilVisible(find.text('Sumber'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sumber'));
    await tester.pumpAndSettle();
    expect(find.textContaining('V1 ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'PreHarvest'), -180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'PreHarvest'));
    await tester.pumpAndSettle();
    expect(find.text('PreHarvest · 1 desa · 1 lahan'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Harvest'));
    await tester.pumpAndSettle();
    expect(find.text('Harvest · 1 desa · 1 lahan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planning waits for region scope and All Region is opt-in',
      (tester) async {
    final ready = Completer<List<String>>();
    final requestedRegions = <String?>[];
    await tester.pumpWidget(ProviderScope(
        overrides: [
          auditPlanningRegionsProvider.overrideWith((ref) => ready.future),
          auditPlanningProvider.overrideWith((ref, params) async {
            requestedRegions.add(params.region);
            return [];
          }),
        ],
        child: MaterialApp(
            home: AuditPlanningScreen(initialWeek: fixtures.week))));
    await tester.pump();
    expect(requestedRegions, isEmpty);
    expect(find.text('Memuat daftar region…'), findsOneWidget);
    ready.complete(['East', 'West']);
    await tester.pumpAndSettle();
    expect(requestedRegions, ['East']);
    await tester.tap(find.widgetWithText(Chip, 'East'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Region').last);
    await tester.pumpAndSettle();
    expect(requestedRegions, ['East', null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planning shows fetch failures and retry can recover',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          auditPlanningRegionsProvider.overrideWith((ref) async => ['East']),
          auditPlanningProvider.overrideWith((ref, params) async {
            attempts++;
            if (attempts == 1) throw StateError('Network unavailable');
            return [];
          }),
        ],
        child: MaterialApp(
            home: AuditPlanningScreen(initialWeek: fixtures.week))));
    await tester.pumpAndSettle();
    expect(find.text('Data planning belum dapat dimuat.'), findsOneWidget);
    expect(attempts, 1);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Data planning belum dapat dimuat.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('render metric cards for visual inspection', (tester) async {
    final fontPath = Platform.environment['AUDIT_QA_FONT'];
    if (fontPath != null) {
      await tester.runAsync(() async {
        final font = FontLoader('AuditPreview')
          ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final summary = WeeklyAuditSummary([
      fixtures.project(fixtures.fieldAt(20, area: 95, veg: {
        'date_of_audit': '2026-08-24',
        'flagging': 'GF',
        'crop_uniformity': 'Good',
        'crop_health': 'Fair',
        'roguing_status': 'Done',
        'lsv_status': 'None',
        'isolation_problem_by_audit': 'No'
      })),
      fixtures.project(fixtures.fieldAt(71, id: 'PH', area: 3, ph: {
        'audit_date': '2026-08-24',
        'final_flagging': 'RFI',
        'crop_uniformity': 'Fair',
        'crop_health': 'Good',
        'male_chopping_rows': 'Complete'
      })),
    ]);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: fontPath == null ? null : 'AuditPreview'),
        home: Scaffold(
            backgroundColor: const Color(0xfff2f5f3),
            body: RepaintBoundary(
                key: key,
                child: ColoredBox(
                    color: const Color(0xfff2f5f3),
                    child: SingleChildScrollView(
                        child: WeeklyAuditCards(
                            summary: summary, onDetail: (_, __) {})))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/weekly_coverage_mobile.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }, skip: Platform.environment['AUDIT_QA_CAPTURE'] != 'true');
}
