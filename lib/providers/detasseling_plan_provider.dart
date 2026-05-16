import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../utils/dap_helper.dart';
import 'master_fields_provider.dart';

enum DetasselingCropFilter { all, fc, sc }

enum DetasselingStatusFilter { all, pending, done }

enum DetasselingGroupStatus { pending, done }

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
    required this.plannedDate,
    required this.isAssessmentDone,
  });

  String get cropLabel => crop == DetasselingCropFilter.sc ? 'SC' : 'FC';
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

  const DetasselingDailySummary({
    required this.date,
    required this.codetCount,
    required this.areaHa,
  });
}

class DetasselingPlanningData {
  final DetasselingWeekOption week;
  final List<DetasselingPlanGroup> groups;
  final List<DetasselingDailySummary> dailySummaries;
  final int sourceFieldCount;
  final int plannedFieldCount;

  const DetasselingPlanningData({
    required this.week,
    required this.groups,
    required this.dailySummaries,
    required this.sourceFieldCount,
    required this.plannedFieldCount,
  });

  double get totalAreaHa =>
      groups.fold(0, (sum, group) => sum + group.totalAreaHa);

  int get codetCount => groups.length;

  int get pendingGroupCount => groups
      .where((group) => group.status == DetasselingGroupStatus.pending)
      .length;

  int get doneGroupCount => groups.length - pendingGroupCount;
}

final detasselingPlanningProvider =
    FutureProvider.family<DetasselingPlanningData, DetasselingPlanningParams>(
        (ref, params) async {
  final parsedFields = await ref.watch(parsedMapFieldsProvider.future);
  return buildDetasselingPlanningData(parsedFields, params);
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
  DetasselingPlanningParams params,
) {
  final weekStart = params.normalizedWeekStart;
  final week = DetasselingWeekOption(
    label: 'W${isoWeekNumber(weekStart)}',
    startDate: weekStart,
    endDate: weekStart.add(const Duration(days: 6)),
  );
  final today = normalizeDate(DateTime.now());
  final startDelta = weekStart.difference(today).inDays;
  final selectedRegion = params.region?.trim().toLowerCase();
  final search = params.searchQuery.trim().toLowerCase();
  final fields = <DetasselingPlanField>[];

  for (final parsed in parsedFields) {
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

    final firstPlannedOffset = _firstOffsetAtOrAbove50Dap(
      currentDap: parsed.dap,
      startDelta: startDelta,
    );
    if (firstPlannedOffset == null) continue;

    final plannedDate = weekStart.add(Duration(days: firstPlannedOffset));
    final codet = _readCodet(raw);
    final village = _readText(raw['village_desa'], fallback: 'Unknown Desa');
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
        currentDap: parsed.dap,
        plannedDap: parsed.dap + startDelta + firstPlannedOffset,
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
    for (final group in groups) {
      for (final field in group.fields) {
        if (normalizeDate(field.plannedDate) == date) {
          codets.add(group.key);
          area += field.areaHa;
        }
      }
    }
    return DetasselingDailySummary(
      date: date,
      codetCount: codets.length,
      areaHa: area,
    );
  });

  return DetasselingPlanningData(
    week: week,
    groups: List.unmodifiable(groups),
    dailySummaries: List.unmodifiable(summaries),
    sourceFieldCount: parsedFields.length,
    plannedFieldCount: groups.fold(0, (sum, group) => sum + group.fieldCount),
  );
}

int? _firstOffsetAtOrAbove50Dap({
  required int currentDap,
  required int startDelta,
}) {
  for (var offset = 0; offset < 7; offset++) {
    if (currentDap + startDelta + offset >= 50) return offset;
  }
  return null;
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
