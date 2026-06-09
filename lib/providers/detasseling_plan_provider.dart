import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/supabase_auth_service.dart';
import '../utils/dap_helper.dart';
import '../utils/qa_name_helper.dart';
import 'master_fields_provider.dart';

enum DetasselingCropFilter { all, fc, sc }

enum DetasselingStatusFilter { all, pending, done }

enum DetasselingGroupStatus { pending, done }

enum DetasselingScopeType { all, fi, spv, blocked }

class DetasselingRoleScope {
  final DetasselingScopeType type;
  final String role;
  final String name;
  final String action;

  const DetasselingRoleScope({
    required this.type,
    required this.role,
    required this.name,
    required this.action,
  });

  bool get canView => type != DetasselingScopeType.blocked;

  bool get isRestricted =>
      type == DetasselingScopeType.fi || type == DetasselingScopeType.spv;

  String get label {
    switch (type) {
      case DetasselingScopeType.fi:
        return 'QA FI';
      case DetasselingScopeType.spv:
        return 'QA SPV Team';
      case DetasselingScopeType.blocked:
        return 'No Access';
      case DetasselingScopeType.all:
        return role.isEmpty ? 'All Area' : '$role Area';
    }
  }

  String get displayLabel {
    if (type == DetasselingScopeType.all) return '$label • All';
    if (type == DetasselingScopeType.blocked) return label;
    return name.isEmpty ? label : '$label • $name';
  }
}

class DetasselingWeekOption {
  final String label;
  final DateTime startDate;
  final DateTime endDate;

  const DetasselingWeekOption({
    required this.label,
    required this.startDate,
    required this.endDate,
  });

  String get rangeLabel {
    final start = DateFormat('d MMM', 'id_ID').format(startDate);
    final end = DateFormat('d MMM yyyy', 'id_ID').format(endDate);
    return startDate.month == endDate.month
        ? '${startDate.day}-${DateFormat('d MMM yyyy', 'id_ID').format(endDate)}'
        : '$start-$end';
  }

  String get compactRangeLabel {
    final start = DateFormat('d MMM', 'id_ID').format(startDate);
    final end = DateFormat('d MMM', 'id_ID').format(endDate);
    return startDate.month == endDate.month
        ? '${startDate.day}-$end'
        : '$start-$end';
  }
}

class DetasselingPlanningParams {
  final DateTime weekStart;
  final String? region;
  final DetasselingCropFilter crop;
  final DetasselingStatusFilter status;
  final String searchQuery;

  const DetasselingPlanningParams({
    required this.weekStart,
    this.region,
    this.crop = DetasselingCropFilter.all,
    this.status = DetasselingStatusFilter.all,
    this.searchQuery = '',
  });

  DateTime get normalizedWeekStart => normalizeDate(weekStart);

  @override
  bool operator ==(Object other) {
    return other is DetasselingPlanningParams &&
        normalizedWeekStart == other.normalizedWeekStart &&
        region == other.region &&
        crop == other.crop &&
        status == other.status &&
        searchQuery == other.searchQuery;
  }

  @override
  int get hashCode => Object.hash(
        normalizedWeekStart,
        region,
        crop,
        status,
        searchQuery,
      );
}

class DetasselingPlanField {
  final ParsedFieldData parsed;
  final String fieldNumber;
  final String farmerName;
  final String codet;
  final String village;
  final String hybrid;
  final DetasselingCropFilter crop;
  final double areaHa;
  final int currentDap;
  final int plannedDap;
  final int dtEndDap;
  final int detasselingStartDap;
  final DateTime passOneDate;
  final int plannedPass;
  final int recommendedTkd;
  final int passRecommendedTkd;
  final DateTime plannedDate;
  final bool isAssessmentDone;

  const DetasselingPlanField({
    required this.parsed,
    required this.fieldNumber,
    required this.farmerName,
    required this.codet,
    required this.village,
    required this.hybrid,
    required this.crop,
    required this.areaHa,
    required this.currentDap,
    required this.plannedDap,
    required this.dtEndDap,
    required this.detasselingStartDap,
    required this.passOneDate,
    required this.plannedPass,
    required this.recommendedTkd,
    required this.passRecommendedTkd,
    required this.plannedDate,
    required this.isAssessmentDone,
  });

  String get cropLabel => crop == DetasselingCropFilter.sc ? 'SC' : 'FC';

  String get dtDapRangeLabel => plannedDap == dtEndDap
      ? 'DT DAP $plannedDap'
      : 'DT DAP $plannedDap-$dtEndDap';
}

class DetasselingPlanGroup {
  final String key;
  final String codet;
  final String village;
  final String hybrid;
  final DetasselingCropFilter crop;
  final List<DetasselingPlanField> fields;
  final LatLng center;

  const DetasselingPlanGroup({
    required this.key,
    required this.codet,
    required this.village,
    required this.hybrid,
    required this.crop,
    required this.fields,
    required this.center,
  });

  double get totalAreaHa => fields.fold(0, (sum, field) => sum + field.areaHa);

  int get fieldCount => fields.length;

  int get recommendedTkd =>
      fields.fold(0, (sum, field) => sum + field.recommendedTkd);

  int get passRecommendedTkd =>
      fields.fold(0, (sum, field) => sum + field.passRecommendedTkd);

  int get pendingCount =>
      fields.where((field) => !field.isAssessmentDone).length;

  int get doneCount => fields.length - pendingCount;

  DetasselingGroupStatus get status => pendingCount == 0
      ? DetasselingGroupStatus.done
      : DetasselingGroupStatus.pending;

  String get statusLabel =>
      status == DetasselingGroupStatus.done ? 'Done' : 'Pending';

  String get cropLabel => crop == DetasselingCropFilter.sc ? 'SC' : 'FC';
}

class DetasselingDailySummary {
  final DateTime date;
  final int codetCount;
  final double areaHa;
  final int recommendedTkd;

  const DetasselingDailySummary({
    required this.date,
    required this.codetCount,
    required this.areaHa,
    required this.recommendedTkd,
  });
}

class DetasselingPlanningData {
  final DetasselingWeekOption week;
  final List<DetasselingPlanGroup> groups;
  final List<DetasselingDailySummary> dailySummaries;
  final int sourceFieldCount;
  final int plannedFieldCount;
  final DetasselingRoleScope roleScope;

  const DetasselingPlanningData({
    required this.week,
    required this.groups,
    required this.dailySummaries,
    required this.sourceFieldCount,
    required this.plannedFieldCount,
    required this.roleScope,
  });

  double get totalAreaHa =>
      groups.fold(0, (sum, group) => sum + group.totalAreaHa);

  int get codetCount => groups.length;

  int get recommendedTkd =>
      groups.fold(0, (sum, group) => sum + group.recommendedTkd);

  int get passRecommendedTkd =>
      groups.fold(0, (sum, group) => sum + group.passRecommendedTkd);

  int get pendingGroupCount => groups
      .where((group) => group.status == DetasselingGroupStatus.pending)
      .length;

  int get doneGroupCount => groups.length - pendingGroupCount;
}

final detasselingPlanningProvider =
    FutureProvider.family<DetasselingPlanningData, DetasselingPlanningParams>(
        (ref, params) async {
  final parsedFields = await ref.watch(
    parsedMasterFieldMapScopedProvider(
      MasterFieldMapScope(region: params.region),
    ).future,
  );
  final user = await ref.watch(currentUserProvider.future);
  return buildDetasselingPlanningData(parsedFields, params, user: user);
});

DateTime normalizeDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime startOfWorkWeek(DateTime date) {
  final normalized = normalizeDate(date);
  return normalized
      .subtract(Duration(days: normalized.weekday - DateTime.monday));
}

DateTime defaultDetasselingWeekStart({DateTime? now}) {
  return startOfWorkWeek(now ?? DateTime.now()).add(const Duration(days: 7));
}

List<DetasselingWeekOption> generateDetasselingWeeks({DateTime? now}) {
  final currentWeekStart = startOfWorkWeek(now ?? DateTime.now());
  return List.generate(13, (index) {
    final offset = index - 4;
    final start = currentWeekStart.add(Duration(days: offset * 7));
    final end = start.add(const Duration(days: 6));
    return DetasselingWeekOption(
      label: 'W${isoWeekNumber(start)}',
      startDate: start,
      endDate: end,
    );
  });
}

int isoWeekNumber(DateTime date) {
  final normalized = normalizeDate(date);
  final thursday =
      normalized.add(Duration(days: DateTime.thursday - normalized.weekday));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstWeekStart = firstThursday
      .subtract(Duration(days: firstThursday.weekday - DateTime.monday));
  return thursday.difference(firstWeekStart).inDays ~/ 7 + 1;
}

DetasselingPlanningData buildDetasselingPlanningData(
  List<ParsedFieldData> parsedFields,
  DetasselingPlanningParams params, {
  AppUser? user,
}) {
  final weekStart = params.normalizedWeekStart;
  final week = DetasselingWeekOption(
    label: 'W${isoWeekNumber(weekStart)}',
    startDate: weekStart,
    endDate: weekStart.add(const Duration(days: 6)),
  );
  final roleScope = detasselingRoleScopeFor(user);
  final scopedFields = roleScope.canView
      ? parsedFields
          .where((parsed) => _isFieldAllowedForScope(parsed.raw, roleScope))
          .toList(growable: false)
      : const <ParsedFieldData>[];
  final today = normalizeDate(DateTime.now());
  final selectedRegion = params.region?.trim().toLowerCase();
  final search = params.searchQuery.trim().toLowerCase();
  final fields = <DetasselingPlanField>[];

  for (final parsed in scopedFields) {
    final raw = parsed.raw;
    final hybrid = _readText(raw['hybrid']).toUpperCase();
    if (hybrid.isEmpty || DapHelper.isPsp(hybrid)) continue;

    final crop = DapHelper.isSweetCorn(hybrid)
        ? DetasselingCropFilter.sc
        : DetasselingCropFilter.fc;
    if (params.crop != DetasselingCropFilter.all && params.crop != crop) {
      continue;
    }

    if (selectedRegion != null && selectedRegion.isNotEmpty) {
      final region = _readText(raw['region']).toLowerCase();
      if (region != selectedRegion) continue;
    }

    final fieldNumber = _readText(raw['field_number']);
    final farmerName = _readText(raw['farmer_name']);
    if (search.isNotEmpty &&
        !fieldNumber.toLowerCase().contains(search) &&
        !farmerName.toLowerCase().contains(search)) {
      continue;
    }

    final plantingDate = _readPlanningPlantingDate(raw);
    if (plantingDate == null) continue;

    final detasselingStartDap = DapHelper.detasselingStartDapForField(raw);
    final passOneDate = _detasselingPassOneDate(
      plantingDate: plantingDate,
      startDap: detasselingStartDap,
    );
    final passSchedules = _detasselingPassSchedulesInRange(
      passOneDate: passOneDate,
      crop: crop,
      startDate: week.startDate,
      endDate: week.endDate,
    );
    if (passSchedules.isEmpty) continue;

    final firstSchedule = passSchedules.first;
    final lastSchedule = passSchedules.last;
    final plannedDate = firstSchedule.date;
    final currentDap = _detasselingDapOnDate(plantingDate, today);
    final plannedDap = _detasselingDapOnDate(plantingDate, plannedDate);
    final dtEndDap = _detasselingDapOnDate(plantingDate, lastSchedule.date);
    final codet = _readCodet(raw);
    final village = _readText(raw['village_desa'], fallback: 'Unknown Desa');
    final plannedPass = firstSchedule.pass;
    fields.add(
      DetasselingPlanField(
        parsed: parsed,
        fieldNumber: fieldNumber,
        farmerName: farmerName,
        codet: codet,
        village: village,
        hybrid: hybrid,
        crop: crop,
        areaHa: _readArea(raw),
        currentDap: currentDap,
        plannedDap: plannedDap,
        dtEndDap: dtEndDap,
        detasselingStartDap: detasselingStartDap,
        passOneDate: passOneDate,
        plannedPass: plannedPass,
        recommendedTkd: detasselingRecommendedTkdForArea(
          _readArea(raw),
          crop,
        ),
        passRecommendedTkd: detasselingRecommendedTkdForPass(
          areaHa: _readArea(raw),
          crop: crop,
          pass: plannedPass,
        ),
        plannedDate: plannedDate,
        isAssessmentDone: _hasDetasselingAssessment(raw),
      ),
    );
  }

  final grouped = <String, List<DetasselingPlanField>>{};
  for (final field in fields) {
    final key = [
      field.codet.toLowerCase(),
      field.village.toLowerCase(),
      field.hybrid.toLowerCase(),
      field.cropLabel.toLowerCase(),
    ].join('|');
    grouped.putIfAbsent(key, () => <DetasselingPlanField>[]).add(field);
  }

  var groups = grouped.entries.map((entry) {
    final groupFields = entry.value
      ..sort((a, b) => a.plannedDate.compareTo(b.plannedDate));
    return DetasselingPlanGroup(
      key: entry.key,
      codet: groupFields.first.codet,
      village: groupFields.first.village,
      hybrid: groupFields.first.hybrid,
      crop: groupFields.first.crop,
      fields: List.unmodifiable(groupFields),
      center: _calculateCenter(groupFields),
    );
  }).toList()
    ..sort((a, b) {
      final areaCompare = b.totalAreaHa.compareTo(a.totalAreaHa);
      if (areaCompare != 0) return areaCompare;
      return a.codet.compareTo(b.codet);
    });

  if (params.status != DetasselingStatusFilter.all) {
    groups = groups.where((group) {
      final isDone = group.status == DetasselingGroupStatus.done;
      return params.status == DetasselingStatusFilter.done ? isDone : !isDone;
    }).toList();
  }

  final summaries = List.generate(7, (index) {
    final date = weekStart.add(Duration(days: index));
    final codets = <String>{};
    double area = 0;
    var recommendedTkd = 0;
    for (final group in groups) {
      for (final field in group.fields) {
        final pass = detasselingPassForFieldOnDate(field, date);
        if (pass != null) {
          codets.add(group.key);
          area += field.areaHa;
          recommendedTkd += detasselingRecommendedTkdForPass(
            areaHa: field.areaHa,
            crop: field.crop,
            pass: pass,
          );
        }
      }
    }
    return DetasselingDailySummary(
      date: date,
      codetCount: codets.length,
      areaHa: area,
      recommendedTkd: recommendedTkd,
    );
  });

  return DetasselingPlanningData(
    week: week,
    groups: List.unmodifiable(groups),
    dailySummaries: List.unmodifiable(summaries),
    sourceFieldCount: scopedFields.length,
    plannedFieldCount: groups.fold(0, (sum, group) => sum + group.fieldCount),
    roleScope: roleScope,
  );
}

DetasselingRoleScope detasselingRoleScopeFor(AppUser? user) {
  return detasselingRoleScopeForValues(
    role: user?.role,
    action: user?.action,
    name: user?.name,
  );
}

DetasselingRoleScope detasselingRoleScopeForValues({
  String? role,
  String? action,
  String? name,
}) {
  final normalizedRole = role?.trim().toUpperCase() ?? '';
  final normalizedAction = action?.trim().toLowerCase() ?? '';
  final normalizedName = name?.trim() ?? '';

  if (normalizedRole.isEmpty || normalizedRole == 'GUEST') {
    return DetasselingRoleScope(
      type: DetasselingScopeType.blocked,
      role: normalizedRole,
      name: normalizedName,
      action: normalizedAction,
    );
  }

  if (normalizedAction == 'audit' && normalizedRole == 'FI') {
    return DetasselingRoleScope(
      type: DetasselingScopeType.fi,
      role: normalizedRole,
      name: normalizedName,
      action: normalizedAction,
    );
  }

  if (normalizedAction == 'audit' && normalizedRole == 'SPV') {
    return DetasselingRoleScope(
      type: DetasselingScopeType.spv,
      role: normalizedRole,
      name: normalizedName,
      action: normalizedAction,
    );
  }

  const allAccessRoles = {'QA', 'MANAGER', 'DEV'};
  if (normalizedAction == 'all' || allAccessRoles.contains(normalizedRole)) {
    return DetasselingRoleScope(
      type: DetasselingScopeType.all,
      role: normalizedRole,
      name: normalizedName,
      action: normalizedAction,
    );
  }

  return DetasselingRoleScope(
    type: DetasselingScopeType.blocked,
    role: normalizedRole,
    name: normalizedName,
    action: normalizedAction,
  );
}

bool canAccessDetasselingMapForRole({
  String? role,
  String? action,
  String? name,
}) {
  return detasselingRoleScopeForValues(
    role: role,
    action: action,
    name: name,
  ).canView;
}

int detasselingTotalTkdPerHaFor(DetasselingCropFilter crop) {
  return crop == DetasselingCropFilter.sc ? 20 : 15;
}

List<int> detasselingPassTkdPerHaFor(DetasselingCropFilter crop) {
  return crop == DetasselingCropFilter.sc
      ? const [4, 4, 4, 4, 4]
      : const [5, 5, 5];
}

int detasselingPassCountFor(DetasselingCropFilter crop) {
  return detasselingPassTkdPerHaFor(crop).length;
}

DateTime detasselingPassDateForField(
  DetasselingPlanField field,
  int pass,
) {
  return normalizeDate(field.passOneDate).add(Duration(days: (pass - 1) * 2));
}

int? detasselingPassForFieldOnDate(
  DetasselingPlanField field,
  DateTime date,
) {
  final normalized = normalizeDate(date);
  for (var pass = 1; pass <= detasselingPassCountFor(field.crop); pass++) {
    if (detasselingPassDateForField(field, pass) == normalized) return pass;
  }
  return null;
}

String detasselingPassLabelForFieldOnDate(
  DetasselingPlanField field,
  DateTime date,
) {
  final pass = detasselingPassForFieldOnDate(field, date);
  return pass == null ? '-' : 'P$pass';
}

String detasselingPassLabelsForFieldsOnDate(
  Iterable<DetasselingPlanField> fields,
  DateTime date,
) {
  final passes = <int>{};
  for (final field in fields) {
    final pass = detasselingPassForFieldOnDate(field, date);
    if (pass != null) passes.add(pass);
  }
  if (passes.isEmpty) return '-';
  final sorted = passes.toList()..sort();
  return sorted.map((pass) => 'P$pass').join('/');
}

int detasselingRecommendedTkdForFieldOnDate(
  DetasselingPlanField field,
  DateTime date,
) {
  final pass = detasselingPassForFieldOnDate(field, date);
  if (pass == null) return 0;
  return detasselingRecommendedTkdForPass(
    areaHa: field.areaHa,
    crop: field.crop,
    pass: pass,
  );
}

int detasselingRecommendedTkdForArea(
  double areaHa,
  DetasselingCropFilter crop,
) {
  return _roundPositiveTkd(areaHa * detasselingTotalTkdPerHaFor(crop));
}

int detasselingRecommendedTkdForPass({
  required double areaHa,
  required DetasselingCropFilter crop,
  required int pass,
}) {
  final allocated = detasselingAllocatedTkdByPass(areaHa, crop);
  if (pass < 1 || pass > allocated.length) return 0;
  return allocated[pass - 1];
}

List<int> detasselingAllocatedTkdByPass(
  double areaHa,
  DetasselingCropFilter crop,
) {
  final passTkdPerHa = detasselingPassTkdPerHaFor(crop);
  if (areaHa <= 0) return List.filled(passTkdPerHa.length, 0);

  final exact = passTkdPerHa.map((value) => areaHa * value).toList();
  final floors = exact.map((value) => value.floor()).toList();
  final targetTotal =
      exact.fold<double>(0, (total, value) => total + value).round();
  var remainder = targetTotal - floors.fold<int>(0, (a, b) => a + b);
  if (remainder <= 0) return floors;

  final order = List<int>.generate(exact.length, (index) => index);
  order.sort((a, b) {
    final aFraction = exact[a] - floors[a];
    final bFraction = exact[b] - floors[b];
    final byFraction = bFraction.compareTo(aFraction);
    if (byFraction != 0) return byFraction;
    return a.compareTo(b);
  });

  var cursor = 0;
  while (remainder > 0 && order.isNotEmpty) {
    floors[order[cursor % order.length]] += 1;
    cursor++;
    remainder--;
  }
  return floors;
}

int _roundPositiveTkd(double value) {
  if (value <= 0) return 0;
  final rounded = value.round();
  return rounded < 1 ? 1 : rounded;
}

bool _isFieldAllowedForScope(
  Map<String, dynamic> raw,
  DetasselingRoleScope scope,
) {
  switch (scope.type) {
    case DetasselingScopeType.fi:
      return QaNameHelper.fieldHasFi(raw, scope.name);
    case DetasselingScopeType.spv:
      return QaNameHelper.fieldHasSpv(raw, scope.name);
    case DetasselingScopeType.all:
      return true;
    case DetasselingScopeType.blocked:
      return false;
  }
}

class _DetasselingPassSchedule {
  final int pass;
  final DateTime date;

  const _DetasselingPassSchedule({
    required this.pass,
    required this.date,
  });
}

DateTime _detasselingPassOneDate({
  required DateTime plantingDate,
  required int startDap,
}) {
  return normalizeDate(plantingDate).add(Duration(days: startDap - 1));
}

List<_DetasselingPassSchedule> _detasselingPassSchedulesInRange({
  required DateTime passOneDate,
  required DetasselingCropFilter crop,
  required DateTime startDate,
  required DateTime endDate,
}) {
  final start = normalizeDate(startDate);
  final end = normalizeDate(endDate);
  final schedules = <_DetasselingPassSchedule>[];
  for (var pass = 1; pass <= detasselingPassCountFor(crop); pass++) {
    final date = normalizeDate(passOneDate).add(Duration(days: (pass - 1) * 2));
    if (!date.isBefore(start) && !date.isAfter(end)) {
      schedules.add(_DetasselingPassSchedule(pass: pass, date: date));
    }
  }
  return schedules;
}

DateTime? _readPlanningPlantingDate(Map<String, dynamic> raw) {
  final veg = _firstRow(raw['audit_vegetative']);
  final revPlantingDate = _parsePlanningDate(
    _readText(veg?['rev_planting_date']),
  );
  if (revPlantingDate != null) return revPlantingDate;

  return _parsePlanningDate(_readText(raw['planting_date_pdn']));
}

DateTime? _parsePlanningDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;

  try {
    if (text.contains('/')) {
      final parts = text.split('/');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      var year = int.parse(parts[2]);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length != 3 || parts.first.length > 2) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      var year = int.parse(parts[2]);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }

    return null;
  } catch (_) {
    return null;
  }
}

int _detasselingDapOnDate(DateTime plantingDate, DateTime targetDate) {
  final planting = normalizeDate(plantingDate);
  final target = normalizeDate(targetDate);
  return target.difference(planting).inDays + 1;
}

LatLng _calculateCenter(List<DetasselingPlanField> fields) {
  var lat = 0.0;
  var lng = 0.0;
  for (final field in fields) {
    lat += field.parsed.lat;
    lng += field.parsed.lng;
  }
  return LatLng(lat / fields.length, lng / fields.length);
}

String _readCodet(Map<String, dynamic> raw) {
  final veg = _firstRow(raw['audit_vegetative']);
  final codet = _readText(veg?['co_detasseling']);
  if (codet.isNotEmpty) return codet;
  return 'Belum ada Codet';
}

bool _hasDetasselingAssessment(Map<String, dynamic> raw) {
  final gen = _firstRow(raw['audit_generative']);
  return _readText(gen?['detasseling_assesment_3']).isNotEmpty ||
      _readText(gen?['detasseling_assesment_5']).isNotEmpty;
}

Map<String, dynamic>? _firstRow(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

String _readText(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _readArea(Map<String, dynamic> raw) {
  for (final value in [
    raw['effective_area_ha'],
    raw['effective_area'],
    raw['area_ha'],
    raw['ha'],
  ]) {
    if (value == null) continue;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString().replaceAll(',', '.'));
    if (parsed != null) return parsed;
  }
  return 0;
}
