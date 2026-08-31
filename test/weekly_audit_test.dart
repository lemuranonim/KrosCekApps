import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/utils/weekly_audit.dart';
import 'package:kroscek/screens/coverage/coverage_screen.dart';

final week = DateTime(2026, 8, 24);
final end = DateTime(2026, 8, 30);

Map<String, dynamic> fieldAt(int dap,
        {String id = 'F1',
        String hybrid = 'FC',
        double area = 10,
        Map<String, dynamic>? veg,
        Map<String, dynamic>? gen,
        Map<String, dynamic>? ph,
        Map<String, dynamic>? hv}) =>
    {
      'field_number': id,
      'hybrid': hybrid,
      'effective_area_ha': area,
      'planting_date_pdn': week.subtract(Duration(days: dap)).toIso8601String(),
      'region': 'East',
      'district_kab': 'Blitar',
      'sub_district_kec': 'Wates',
      'village_desa': 'Sumber',
      'qa_fi': 'FI 1',
      'qa_spv': 'SPV 1',
      if (veg != null) 'audit_vegetative': veg,
      if (gen != null) 'audit_generative': gen,
      if (ph != null) 'audit_pre_harvest': ph,
      if (hv != null) 'audit_harvest': hv,
    };

WeeklyAuditField project(Map<String, dynamic> raw,
        {DateTime? now, DateTime? start}) =>
    WeeklyAuditField.fromRaw(raw, weekStart: start ?? week, now: now ?? end);

void main() {
  test('week is Monday to Sunday including ISO year boundary', () {
    expect(auditWeekStart(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
    expect(auditWeekStart(end), week);
    expect(auditIsoWeekNumber(week), 35);
    expect(auditIsoWeekNumber(DateTime(2027, 1, 1)), 53);
    expect(parseAuditDate('2026-08-24T00:00:00+07:00'), week);
  });

  test('invalid or missing planting date never creates audit target', () {
    for (final date in [null, '', 'bad-date', '31/02/2026', '2026-02-31']) {
      expect(
          project({...fieldAt(20), 'planting_date_pdn': date}).isTarget, false);
    }
  });

  test('DAP eligibility includes entry into a phase later in the selected week',
      () {
    final f = project(fieldAt(2));
    expect(f.targets.single.phase, 'vegetative');
    expect(f.targets.single.plannedDate, DateTime(2026, 8, 29));
    expect(project(fieldAt(0)).isTarget, false);
    expect(project(fieldAt(200)).isTarget, false);
  });

  test('revised planting date and list joins are respected', () {
    final f = project({
      ...fieldAt(200),
      'audit_vegetative': [
        {'rev_planting_date': '04/08/2026'}
      ]
    });
    expect(f.targets.single.phase, 'vegetative');
    expect(f.dap, 26);
  });

  test('completed audits before selected week are not planned again', () {
    final f = project(fieldAt(20, veg: {'date_of_audit': '2026-08-23'}));
    expect(f.isTarget, false);
    expect(WeeklyAuditSummary([f]).targetHa, 0);
  });

  test('same week completion remains both target and achievement', () {
    final f = project(fieldAt(20, veg: {'date_of_audit': '2026-08-24'}));
    expect(f.done, true);
    expect(WeeklyAuditSummary([f]).achievedHa, 10);
  });

  test('future audit cannot complete the current or historical week', () {
    final raw = fieldAt(20, veg: {
      'date_of_audit': '2026-08-29',
      'flagging': 'PLD',
      'crop_health': 'Best'
    });
    final f = project(raw, now: DateTime(2026, 8, 26));
    expect(f.done, false);
    expect(f.flag, auditNotYetFlagging);
    expect(f.latest((o) => o.ch), null);
    final historical = project(
        fieldAt(20, veg: {'date_of_audit': '2026-08-31'}),
        now: DateTime(2026, 9, 5));
    expect(historical.done, false);
  });

  test(
      'closed-week pending targets are overdue without leaking later completion',
      () {
    final f = project(fieldAt(20, veg: {'date_of_audit': '2026-08-31'}),
        now: DateTime(2026, 9, 5));
    expect(f.overdue, true);
    expect(WeeklyAuditSummary([f]).overdueHa, 10);
  });

  test('phase deadline inside current week determines overdue', () {
    final f = project(fieldAt(35), now: DateTime(2026, 8, 26));
    expect(f.targets.single.deadline, week);
    expect(f.overdue, true);
  });

  test('PLD exclusion normalizes 95/3/2 to 100 percent, keeps hectares', () {
    final all = [
      project(fieldAt(20,
          id: 'GF',
          area: 95,
          veg: {'date_of_audit': '2026-08-24', 'flagging': 'GF'})),
      project(fieldAt(20,
          id: 'RFI',
          area: 3,
          veg: {'date_of_audit': '2026-08-24', 'flagging': 'RFI'})),
      project(fieldAt(20,
          id: 'PLD',
          area: 2,
          veg: {'date_of_audit': '2026-08-24', 'flagging': 'PLD'})),
    ];
    final full = WeeklyAuditSummary(all).composition((f) => f.flag);
    expect(full['PLD']!.percent, 2);
    expect(defaultAuditFlags, contains('PLD'));
    final filtered = WeeklyAuditSummary(all.where((f) => f.flag != 'PLD'));
    final flags = filtered.composition((f) => f.flag);
    expect(filtered.targetHa, 98);
    expect(flags['GF']!.areaHa, 95);
    expect(flags['GF']!.percent, closeTo(96.9387755, .00001));
    expect(flags['RFI']!.percent, closeTo(3.0612245, .00001));
    expect(flags.values.fold(0.0, (sum, value) => sum + value.percent),
        closeTo(100, .00001));
  });

  test('missing flagging is explicit and is never silently good', () {
    final f = project(fieldAt(20));
    expect(f.flag, auditNotYetFlagging);
    expect(WeeklyAuditSummary([f]).composition((f) => f.flag).keys,
        [auditNotYetFlagging]);
  });

  test('latest dated flagging wins; old PLD does not permanently hide a field',
      () {
    final f = project(fieldAt(71,
        veg: {'date_of_audit': '2026-08-01', 'flagging': 'PLD'},
        ph: {'audit_date': '2026-08-24', 'final_flagging': 'GF'}));
    expect(f.flag, 'GF');
    expect(defaultAuditFlags.contains(f.flag), true);
  });

  test('Monitor action D is not Discard decision D', () {
    expect(
        project(fieldAt(50,
                gen: {'date_of_audit_1': '2026-08-24', 'action_needed_1': 'D'}))
            .flag,
        auditNotYetFlagging);
    expect(
        project(fieldAt(71,
            ph: {'audit_date': '2026-08-24', 'final_decision': 'D'})).flag,
        'PLD');
  });

  test('undated master flag does not leak into historical weeks', () {
    final raw = {...fieldAt(20), 'flagging_final': 'RFD'};
    expect(project(raw).flag, 'RFD');
    expect(project(raw, now: DateTime(2026, 9, 1)).flag, auditNotYetFlagging);
  });

  test('multiple generative checkpoints count field area only once', () {
    final raw = fieldAt(50, area: 12, gen: {
      'date_of_audit_1': '2026-08-24',
      'date_of_audit_2': '2026-08-29',
    });
    final f = project(raw);
    expect(f.targets.map((t) => t.phase), ['generative_1', 'generative_2']);
    final summary = WeeklyAuditSummary([f]);
    expect(summary.targetHa, 12);
    expect(summary.achievedHa, 12);
    final coverage = calculateFilteredPhases(
        [FieldCoverageStatus.fromRaw(raw, weekStart: week, now: end)]);
    expect(coverage.phases.singleWhere((p) => p.label == 'Generative').totalHa,
        12);
    expect(coverage.targetCompletionPct, 100);
  });

  test('partial checkpoints do not count a whole field as achieved', () {
    final raw = fieldAt(50, gen: {'date_of_audit_1': '2026-08-24'});
    final f = project(raw);
    expect(f.completion, .5);
    expect(WeeklyAuditSummary([f]).achievedHa, 0);
  });

  test('FN achievement is not distorted by field area', () {
    final fields = [
      FieldCoverageStatus.fromRaw(
          fieldAt(20, area: 95, veg: {'date_of_audit': '2026-08-24'}),
          weekStart: week,
          now: end),
      FieldCoverageStatus.fromRaw(fieldAt(20, id: 'F2', area: 5),
          weekStart: week, now: end),
    ];
    expect(aggregateCoverageScore(fields), 50);
    expect(FICoverage.fromFields('FI 1', fields).coverageScore, 50);
    expect(calculateFilteredPhases(fields).targetCompletionPct, 50);
  });

  test('SC highland rules use location, PSP has no PreHarvest', () {
    final lowland = project(fieldAt(40, hybrid: 'AX01'));
    final highland =
        project({...fieldAt(40, hybrid: 'AX01'), 'district_kab': 'Malang'});
    expect(lowland.targets.any((t) => t.phase == 'generative_1'), true);
    expect(highland.isTarget, false);
    expect(
        project(fieldAt(75, hybrid: 'ASF123'))
            .targets
            .any((t) => t.phase == 'pre_harvest'),
        false);
    expect(project(fieldAt(110, hybrid: 'ASF123')).targets.single.phase,
        'harvest');
  });

  test('PSP pass dates, even with only pass two present, remain partial', () {
    final f = project(fieldAt(35, hybrid: 'ASF123', veg: {
      'date_of_inspeksi_roguing_2': '2026-08-24',
      'audit_lsv_roguing_2': '>0',
      'crop_health_roguing_2': 'Fair',
    }));
    expect(f.targets.single.completion, .25);
    expect(f.done, false);
    expect(f.latest((o) => o.ch), 'Fair');
    expect(f.lsvNegative, true);
  });

  test(
      'PSP draft summary dates do not mark a phase completed, PLD still filters',
      () {
    final f = project(fieldAt(35, hybrid: 'ASF123', veg: {
      'audit_date_user': '2026-08-24',
      'decision': 'Discard',
      'flagging': 'PLD',
    }));
    expect(f.done, false);
    expect(f.flag, 'PLD');
  });

  test('SC checkpoint three uses the shared flagging column', () {
    final f = project(fieldAt(51, hybrid: 'AX01', gen: {
      'date_of_audit_3': '2026-08-24',
      'flagging': 'RFI',
    }));
    expect(f.flag, 'RFI');
  });

  test('village grouping ignores Codet and crop, respects geography', () {
    final a = project({...fieldAt(20), 'co_detasseling': 'A'});
    final b = project(
        {...fieldAt(20, hybrid: 'AX01', id: 'F2'), 'co_detasseling': 'B'});
    final c = project({...fieldAt(20, id: 'F3'), 'district_kab': 'Kediri'});
    final groups = groupAuditFieldsByVillage([a, b, c]);
    expect(groups.length, 2);
    expect(groups[a.villageKey]!.length, 2);
  });

  test('NC and crop data do not treat missing values as compliant', () {
    final fields = [
      project(fieldAt(20, area: 6, veg: {
        'date_of_audit': '2026-08-24',
        'roguing_status': 'On Going',
        'lsv_status': 'Low',
        'isolation_problem_by_audit': 'Yes',
        'crop_uniformity': 'Good',
      })),
      project(fieldAt(20, id: 'F2', area: 4))
    ];
    expect(fields.first.needsAttention, true);
    expect(fields.first.roguingNegative, true);
    expect(fields.first.isolationNegative, true);
    final cu = WeeklyAuditSummary(fields)
        .metric((f) => f.latest((o) => o.cu), (v) => v == 'good');
    expect(cu.areaHa, 6);
    expect(cu.assessedHa, 6);
    expect(cu.percent, 60);
  });

  test('stage composition is disjoint across four planting phases', () {
    final summary = WeeklyAuditSummary([
      project(fieldAt(20)),
      project(fieldAt(50)),
      project(fieldAt(71)),
      project(fieldAt(95))
    ]);
    expect(summary.composition((f) => f.stage).keys.toSet(),
        auditStageLabels.keys.toSet());
    expect(summary.targetHa, 40);
  });

  test('empty and zero area selections never produce NaN or divide by zero',
      () {
    final empty = WeeklyAuditSummary([]);
    expect(empty.achievementPercent, 0);
    expect(empty.composition((f) => f.flag), isEmpty);
    for (final area in [0.0, -3.0, double.nan, double.infinity]) {
      final summary = WeeklyAuditSummary([project(fieldAt(20, area: area))]);
      expect(summary.targetHa, 0);
      expect(summary.achievementPercent.isFinite, true);
    }
  });
}
