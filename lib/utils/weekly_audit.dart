import 'dap_helper.dart';

DateTime auditDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime auditWeekStart(DateTime date) {
  final day = auditDateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime? parseAuditDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$').firstMatch(text);
  if (slash != null) {
    final day = int.parse(slash[1]!);
    final month = int.parse(slash[2]!);
    var year = int.parse(slash[3]!);
    if (year < 100) year += 2000;
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month ? date : null;
  }
  final date = DateTime.tryParse(text);
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (date != null && iso != null) {
    final year = int.parse(iso[1]!);
    final month = int.parse(iso[2]!);
    final day = int.parse(iso[3]!);
    final calendarDate = DateTime(year, month, day);
    return calendarDate.year == year &&
            calendarDate.month == month &&
            calendarDate.day == day
        ? calendarDate
        : null;
  }
  return date == null ? null : auditDateOnly(date);
}

Map<String, dynamic> auditRow(dynamic value) {
  if (value is List) return value.isEmpty ? {} : auditRow(value.first);
  return value is Map ? Map<String, dynamic>.from(value) : {};
}

double auditArea(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  return number.isFinite && number > 0 ? number : 0;
}

String auditStage(String phase) =>
    phase.startsWith('generative') ? 'generative' : phase;

const auditStageLabels = {
  'vegetative': 'Vegetative',
  'generative': 'Generative',
  'pre_harvest': 'PreHarvest',
  'harvest': 'Harvest',
};

const auditFlagLabels = [
  'GF',
  'RFI',
  'RFD',
  'BF',
  'OF',
  'RF',
  'PLD',
  'Belum ada'
];
const defaultAuditFlags = {'GF', 'RFI', 'RFD', 'BF', 'OF', 'RF', 'Belum ada'};

class AuditObservation {
  final int sequence;
  final String phase;
  final DateTime date;
  final String? flag;
  final String? roguing;
  final String? lsv;
  final String? isolation;
  final String? cu;
  final String? ch;
  final String? maleChopping;

  const AuditObservation({
    this.sequence = 0,
    required this.phase,
    required this.date,
    this.flag,
    this.roguing,
    this.lsv,
    this.isolation,
    this.cu,
    this.ch,
    this.maleChopping,
  });
}

class WeeklyAuditTarget {
  final String phase;
  final DateTime plannedDate;
  final DateTime deadline;
  final double completion;
  final bool overdue;

  const WeeklyAuditTarget(
      {required this.phase,
      required this.plannedDate,
      required this.deadline,
      required this.completion,
      required this.overdue});

  bool get done => completion >= 1;
}

/// One field is counted once in area/flag/stage totals, even when a week
/// overlaps several generative checkpoints. Each checkpoint remains a target.
class WeeklyAuditField {
  final Map<String, dynamic> raw;
  final DateTime weekStart;
  final DateTime asOf;
  final int dap;
  final String stage;
  final List<WeeklyAuditTarget> targets;
  final List<AuditObservation> observations;
  final Map<String, double> phaseCompletions;
  final String flag;

  const WeeklyAuditField._(
      {required this.raw,
      required this.weekStart,
      required this.asOf,
      required this.dap,
      required this.stage,
      required this.targets,
      required this.observations,
      required this.phaseCompletions,
      required this.flag});

  double get areaHa => auditArea(raw['effective_area_ha']);
  bool get isTarget => targets.isNotEmpty;
  bool get done => isTarget && targets.every((target) => target.done);
  bool get overdue => targets.any((target) => target.overdue);
  double get completion => !isTarget
      ? 0
      : targets.fold(0.0, (sum, target) => sum + target.completion) /
          targets.length;
  String get village => _text(raw['village_desa']) ?? 'Desa belum diisi';
  // Same village name in different districts must never be merged.
  String get villageKey => [
        'region',
        'district_kab',
        'sub_district_kec',
        'village_desa'
      ].map((key) => raw[key]?.toString().trim().toLowerCase() ?? '').join('|');

  String? latest(String? Function(AuditObservation) value) {
    for (final observation in observations.reversed) {
      final result = value(observation);
      if (result != null) return result;
    }
    return null;
  }

  bool get roguingNegative => const {'not yet', 'on going', 'a', 'b'}
      .contains(latest((o) => o.roguing)?.toLowerCase());
  bool get lsvNegative => const {'low', 'moderate', 'high', '>0', 'b', 'c', 'd'}
      .contains(latest((o) => o.lsv)?.toLowerCase());
  bool get isolationNegative =>
      const {'yes', 'a'}.contains(latest((o) => o.isolation)?.toLowerCase());
  bool get needsAttention =>
      overdue ||
      roguingNegative ||
      lsvNegative ||
      isolationNegative ||
      const {'RFI', 'RFD', 'BF', 'PLD', 'OF', 'RF'}.contains(flag);

  factory WeeklyAuditField.fromRaw(Map<String, dynamic> raw,
      {required DateTime weekStart, DateTime? now}) {
    final start = auditWeekStart(weekStart);
    final end = start.add(const Duration(days: 6));
    final today = auditDateOnly(now ?? DateTime.now());
    final asOf = end.isBefore(today) ? end : today;
    final hybrid = raw['hybrid']?.toString();
    final psp = DapHelper.isPsp(hybrid);
    final veg = auditRow(raw['audit_vegetative']);
    final gen = auditRow(raw['audit_generative']);
    final ph = auditRow(raw['audit_pre_harvest']);
    final hv = auditRow(raw['audit_harvest']);
    final planting = parseAuditDate(veg['rev_planting_date']) ??
        parseAuditDate(raw['planting_date_pdn']);
    final observations = <AuditObservation>[];
    final phaseDates = <String, List<DateTime>>{};

    void add(String phase, Map<String, dynamic> row, dynamic dateValue,
        {String suffix = '',
        bool roguing = false,
        bool countForCompletion = true}) {
      final date = parseAuditDate(dateValue);
      if (date == null) return;
      if (countForCompletion) phaseDates.putIfAbsent(phase, () => []).add(date);
      if (date.isAfter(asOf)) return;
      final isGen = phase.startsWith('generative');
      final flagValue = roguing
          ? row['flagging$suffix']
          : phase == 'vegetative'
              ? row['flagging']
              : isGen
                  ? (row['final_flagging$suffix'] ??
                      (suffix == '_3' ? row['flagging'] : null))
                  : row['final_flagging'];
      final decision = roguing
          ? row['recommendation$suffix']
          : phase == 'vegetative'
              ? row['decision']
              : row['final_decision$suffix'];
      final action = row['action_needed$suffix'];
      final discarded = _isDiscard(decision, decision: true) ||
          _isDiscard(action, action: true);
      observations.add(AuditObservation(
        sequence: observations.length,
        phase: phase,
        date: date,
        flag: discarded ? 'PLD' : _flag(flagValue),
        roguing: _text(row['roguing_status$suffix']),
        lsv: _text(row['${roguing ? 'audit_lsv' : 'lsv_status'}$suffix']),
        isolation: _text(row['isolation_problem_by_audit$suffix'] ??
            row['isolation_problem$suffix'] ??
            row['isolation_audit$suffix']),
        cu: _text(row['crop_uniformity$suffix']),
        ch: _text(row['crop_health$suffix']),
        maleChopping: _text(row['male_chopping_rows']),
      ));
    }

    if (psp) {
      for (var i = 1; i <= 4; i++) {
        add('vegetative', veg, veg['date_of_inspeksi_roguing_$i'],
            suffix: '_roguing_$i', roguing: true);
      }
      for (var i = 5; i <= 6; i++) {
        add('generative_5', gen, gen['date_of_inspeksi_roguing_$i'],
            suffix: '_roguing_$i', roguing: true);
      }
    }
    // Legacy PSP rows may only have the phase-level audit date.
    if (!psp) {
      add('vegetative', veg, veg['audit_date_user'] ?? veg['date_of_audit']);
    } else {
      if (phaseDates['vegetative']?.isEmpty ?? true) {
        add('vegetative', veg, veg['date_of_audit']);
      }
      add('vegetative', veg, veg['audit_date_user'] ?? veg['date_of_audit'],
          countForCompletion: false);
    }
    for (var i = 1; i <= 5; i++) {
      if (psp &&
          (i != 5 || (phaseDates['generative_5']?.isNotEmpty ?? false))) {
        continue;
      }
      add('generative_$i', gen, gen['date_of_audit_$i'], suffix: '_$i');
    }
    if (psp && (phaseDates['generative_5']?.isNotEmpty ?? false)) {
      add('generative_5', gen, gen['date_of_audit_5'] ?? gen['submitted_at_5'],
          suffix: '_5', countForCompletion: false);
    }
    add('pre_harvest', ph, ph['audit_date']);
    add('harvest', hv, hv['date_of_audit']);
    observations.sort((a, b) {
      final dateOrder = a.date.compareTo(b.date);
      if (dateOrder != 0) return dateOrder;
      final phaseOrder = _phaseOrder(a.phase).compareTo(_phaseOrder(b.phase));
      return phaseOrder != 0 ? phaseOrder : a.sequence.compareTo(b.sequence);
    });
    var flag = 'Belum ada';
    for (final observation in observations) {
      if (observation.flag != null) flag = observation.flag!;
    }
    // Undated master status cannot reconstruct a historical week.
    if (flag == 'Belum ada' && !end.isBefore(today)) {
      flag = _flag(raw['flagging_final']) ?? flag;
    }
    final rules = DapHelper.getPhaseRules(
        hybrid: hybrid,
        district: raw['district_kab']?.toString(),
        region: raw['region']?.toString(),
        subDistrict: raw['sub_district_kec']?.toString());
    final targets = <WeeklyAuditTarget>[];
    final phaseCompletions = <String, double>{};
    int requiredPasses(String phase) {
      if (!psp) return 1;
      if (phase == 'vegetative' &&
          List.generate(4, (i) => i + 1).any((i) =>
              parseAuditDate(veg['date_of_inspeksi_roguing_$i']) != null)) {
        return 4;
      }
      if (phase == 'generative_5' &&
          [5, 6].any((i) =>
              parseAuditDate(gen['date_of_inspeksi_roguing_$i']) != null)) {
        return 2;
      }
      return 1;
    }

    for (final rule in rules) {
      phaseCompletions[rule.key] = ((phaseDates[rule.key] ?? const <DateTime>[])
                  .where((d) => !d.isAfter(asOf))
                  .length /
              requiredPasses(rule.key))
          .clamp(0.0, 1.0);
    }
    if (planting != null) {
      for (final rule in rules) {
        final windowStart = planting.add(Duration(days: rule.onGoingStart));
        final windowEnd = planting.add(Duration(days: rule.onGoingEnd));
        if (windowStart.isAfter(end) || windowEnd.isBefore(start)) continue;
        final dates = phaseDates[rule.key] ?? const <DateTime>[];
        if (dates.where((d) => d.isBefore(start) && !d.isAfter(today)).length >=
            requiredPasses(rule.key)) {
          continue;
        }
        final completion = phaseCompletions[rule.key] ?? 0;
        final deadline = windowEnd.isBefore(end) ? windowEnd : end;
        targets.add(WeeklyAuditTarget(
            phase: rule.key,
            plannedDate: windowStart.isAfter(start) ? windowStart : start,
            deadline: deadline,
            completion: completion,
            overdue: completion < 1 && deadline.isBefore(today)));
      }
    }
    final dap = planting == null ? 0 : end.difference(planting).inDays;
    final stage = auditStage(DapHelper.getRecommendedPhase(dap,
        hybrid: hybrid,
        district: raw['district_kab']?.toString(),
        region: raw['region']?.toString(),
        subDistrict: raw['sub_district_kec']?.toString()));
    return WeeklyAuditField._(
        raw: raw,
        weekStart: start,
        asOf: asOf,
        dap: dap,
        stage: stage,
        targets: targets,
        observations: observations,
        phaseCompletions: phaseCompletions,
        flag: flag);
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

String? _flag(dynamic value) {
  final text = _text(value)?.toUpperCase();
  if (text == 'DISCARD') return 'PLD';
  return auditFlagLabels.contains(text) ? text : null;
}

bool _isDiscard(dynamic value, {bool decision = false, bool action = false}) {
  final text = _text(value)?.toUpperCase() ?? '';
  return text.contains('DISCARD') ||
      text.contains('PLD') ||
      (decision && text == 'D') ||
      (action && const {'F', 'G'}.contains(text));
}

int _phaseOrder(String phase) => phase == 'vegetative'
    ? 0
    : phase == 'pre_harvest'
        ? 6
        : phase == 'harvest'
            ? 7
            : int.tryParse(phase.split('_').last) ?? 0;

class AuditAreaMetric {
  final double areaHa;
  final double baseHa;
  final double assessedHa;
  const AuditAreaMetric(this.areaHa, this.baseHa, this.assessedHa);
  double get percent => baseHa > 0 ? areaHa / baseHa * 100 : 0;
}

class WeeklyAuditSummary {
  final List<WeeklyAuditField> fields;
  WeeklyAuditSummary(Iterable<WeeklyAuditField> fields)
      : fields = fields.where((f) => f.isTarget).toList();

  double get targetHa => fields.fold(0.0, (sum, f) => sum + f.areaHa);
  double get achievedHa =>
      fields.where((f) => f.done).fold(0.0, (sum, f) => sum + f.areaHa);
  double get overdueHa =>
      fields.where((f) => f.overdue).fold(0.0, (sum, f) => sum + f.areaHa);
  double get achievementPercent =>
      targetHa > 0 ? achievedHa / targetHa * 100 : 0;

  Map<String, AuditAreaMetric> composition(
      String Function(WeeklyAuditField) key) {
    final areas = <String, double>{};
    for (final field in fields) {
      areas.update(key(field), (area) => area + field.areaHa,
          ifAbsent: () => field.areaHa);
    }
    return areas.map((key, area) =>
        MapEntry(key, AuditAreaMetric(area, targetHa, targetHa)));
  }

  AuditAreaMetric metric(
      String? Function(WeeklyAuditField) read, bool Function(String) matches) {
    var area = 0.0;
    var assessed = 0.0;
    for (final field in fields) {
      final value = read(field);
      if (value == null) continue;
      assessed += field.areaHa;
      if (matches(value.toLowerCase())) area += field.areaHa;
    }
    return AuditAreaMetric(area, targetHa, assessed);
  }
}

Map<String, List<WeeklyAuditField>> groupAuditFieldsByVillage(
    Iterable<WeeklyAuditField> fields) {
  final groups = <String, List<WeeklyAuditField>>{};
  for (final field in fields) {
    groups.putIfAbsent(field.villageKey, () => []).add(field);
  }
  return groups;
}
