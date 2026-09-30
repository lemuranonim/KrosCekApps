import 'dart:convert';

class ActSyncStatus {
  const ActSyncStatus({
    required this.latestStatus,
    required this.isCurrent,
    required this.fcCount,
    required this.psCount,
    required this.scCount,
    required this.totalRows,
    required this.insertedRows,
    required this.updatedRows,
    required this.unchangedRows,
    required this.missingSourceRows,
    required this.invalidRows,
    required this.blockers,
    required this.harvestNeedsReview,
    this.latestTargetSourceDate,
    this.latestStartedAt,
    this.latestCompletedAt,
    this.lastSuccessSourceDate,
    this.lastSuccessAt,
  });

  factory ActSyncStatus.fromJson(Map<String, dynamic> json) {
    final sourceCounts = _map(json['source_counts']);
    final summary = _map(json['summary']);

    return ActSyncStatus(
      latestStatus: _text(json['latest_status'], fallback: 'NEVER'),
      latestTargetSourceDate: _date(json['latest_target_source_date']),
      latestStartedAt: _dateTime(json['latest_started_at']),
      latestCompletedAt: _dateTime(json['latest_completed_at']),
      lastSuccessSourceDate: _date(json['last_success_source_date']),
      lastSuccessAt: _dateTime(json['last_success_at']),
      isCurrent: json['is_current'] == true,
      fcCount: _integer(sourceCounts['FC']),
      psCount: _integer(sourceCounts['PS']),
      scCount: _integer(sourceCounts['SC']),
      totalRows: _integer(summary['source_rows']),
      insertedRows: _integer(summary['insert']),
      updatedRows: _integer(summary['update']),
      unchangedRows: _integer(summary['unchanged']),
      missingSourceRows: _integer(summary['missing_source']),
      invalidRows: _integer(summary['invalid']),
      blockers: _integer(summary['blockers']),
      harvestNeedsReview: _integer(summary['harvest_needs_review']),
    );
  }

  final String latestStatus;
  final DateTime? latestTargetSourceDate;
  final DateTime? latestStartedAt;
  final DateTime? latestCompletedAt;
  final DateTime? lastSuccessSourceDate;
  final DateTime? lastSuccessAt;
  final bool isCurrent;
  final int fcCount;
  final int psCount;
  final int scCount;
  final int totalRows;
  final int insertedRows;
  final int updatedRows;
  final int unchangedRows;
  final int missingSourceRows;
  final int invalidRows;
  final int blockers;
  final int harvestNeedsReview;

  bool get isSyncing => const {
    'EXTRACTING',
    'WAITING_EXPORT',
    'VALIDATING',
    'APPLYING',
  }.contains(latestStatus);

  bool get hasSyncError =>
      const {'FAILED', 'BLOCKED', 'READY'}.contains(latestStatus);

  bool get hasHarvestReview => harvestNeedsReview > 0;

  bool get needsAttention => hasSyncError;

  bool get hasSuccessfulSync => lastSuccessSourceDate != null;

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static int _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _text(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text.toUpperCase();
  }

  static DateTime? _date(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static DateTime? _dateTime(Object? value) {
    final parsed = _date(value);
    return parsed?.toLocal();
  }
}

class ActHarvestReview {
  const ActHarvestReview({
    required this.fieldNumber,
    required this.status,
    required this.reason,
    required this.effectiveAreaHa,
    required this.reportedHarvestAreaHa,
    required this.safeHarvestAreaHa,
    required this.harvestEventCount,
    this.lastHarvestDate,
    this.hybrid,
    this.farmerName,
    this.grower,
    this.region,
    this.district,
    this.subDistrict,
    this.village,
    this.qaFi,
    this.qaSpv,
    this.fieldAssistant,
    this.season,
    this.seedType,
  });

  factory ActHarvestReview.fromJson(Map<String, dynamic> json) {
    return ActHarvestReview(
      fieldNumber: json['field_number']?.toString().trim() ?? '-',
      status: json['status']?.toString().trim() ?? 'NEEDS_CONFIRMATION',
      reason: json['reason']?.toString().trim() ?? '',
      effectiveAreaHa: _number(json['effective_area_ha']),
      reportedHarvestAreaHa: _number(json['reported_harvest_area_ha']),
      safeHarvestAreaHa: _number(json['safe_harvest_area_ha']),
      harvestEventCount: ActSyncStatus._integer(json['harvest_event_count']),
      lastHarvestDate: ActSyncStatus._date(json['last_harvest_date']),
      hybrid: _optionalText(json['hybrid']),
      farmerName: _optionalText(json['farmer_name']),
      grower: _optionalText(json['grower']),
      region: _optionalText(json['region']),
      district: _optionalText(json['district_kab']),
      subDistrict: _optionalText(json['sub_district_kec']),
      village: _optionalText(json['village_desa']),
      qaFi: _optionalText(json['qa_fi']),
      qaSpv: _optionalText(json['qa_spv']),
      fieldAssistant: _optionalText(json['fa']),
      season: _optionalText(json['season']),
      seedType: _optionalText(json['type']),
    );
  }

  final String fieldNumber;
  final String status;
  final String reason;
  final double effectiveAreaHa;
  final double reportedHarvestAreaHa;
  final double safeHarvestAreaHa;
  final int harvestEventCount;
  final DateTime? lastHarvestDate;
  final String? hybrid;
  final String? farmerName;
  final String? grower;
  final String? region;
  final String? district;
  final String? subDistrict;
  final String? village;
  final String? qaFi;
  final String? qaSpv;
  final String? fieldAssistant;
  final String? season;
  final String? seedType;

  String get qaOwner => qaFi ?? fieldAssistant ?? '-';

  String get locationLabel {
    return [
      village,
      subDistrict,
      district,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
  }

  String get searchableText => [
    fieldNumber,
    hybrid,
    farmerName,
    grower,
    region,
    district,
    subDistrict,
    village,
    qaFi,
    qaSpv,
    fieldAssistant,
    season,
    seedType,
  ].whereType<String>().join(' ').toLowerCase();

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class ActSyncHistoryItem {
  const ActSyncHistoryItem({
    required this.runId,
    required this.status,
    required this.sourceFrom,
    required this.sourceTo,
    required this.sourceRows,
    required this.insertedRows,
    required this.updatedRows,
    required this.invalidRows,
    required this.blockers,
    required this.harvestNeedsReview,
    required this.startedAt,
    this.completedAt,
  });

  factory ActSyncHistoryItem.fromJson(Map<String, dynamic> json) {
    return ActSyncHistoryItem(
      runId: json['run_id']?.toString() ?? '',
      status: ActSyncStatus._text(json['status'], fallback: 'UNKNOWN'),
      sourceFrom: ActSyncStatus._date(json['source_from']),
      sourceTo: ActSyncStatus._date(json['source_to']),
      sourceRows: ActSyncStatus._integer(json['source_rows']),
      insertedRows: ActSyncStatus._integer(json['inserted_rows']),
      updatedRows: ActSyncStatus._integer(json['updated_rows']),
      invalidRows: ActSyncStatus._integer(json['invalid_rows']),
      blockers: ActSyncStatus._integer(json['blockers']),
      harvestNeedsReview: ActSyncStatus._integer(json['harvest_needs_review']),
      startedAt: ActSyncStatus._dateTime(json['started_at']) ?? DateTime(1970),
      completedAt: ActSyncStatus._dateTime(json['completed_at']),
    );
  }

  final String runId;
  final String status;
  final DateTime? sourceFrom;
  final DateTime? sourceTo;
  final int sourceRows;
  final int insertedRows;
  final int updatedRows;
  final int invalidRows;
  final int blockers;
  final int harvestNeedsReview;
  final DateTime startedAt;
  final DateTime? completedAt;

  bool get isSuccessful => status == 'COMPLETED';
}

class ActSyncDailySummary {
  const ActSyncDailySummary({
    required this.status,
    required this.scopeRole,
    required this.totalRows,
    required this.insertedRows,
    required this.updatedRows,
    required this.unchangedRows,
    required this.missingSourceRows,
    required this.invalidRows,
    required this.conflictRows,
    required this.changedRows,
    required this.appliedRows,
    this.runId,
    this.sourceFrom,
    this.sourceTo,
    this.startedAt,
    this.completedAt,
  });

  factory ActSyncDailySummary.fromJson(Map<String, dynamic> json) {
    return ActSyncDailySummary(
      runId: ActHarvestReview._optionalText(json['run_id']),
      status: ActSyncStatus._text(json['status'], fallback: 'UNKNOWN'),
      scopeRole: ActSyncStatus._text(json['scope_role'], fallback: 'NONE'),
      sourceFrom: ActSyncStatus._date(json['source_from']),
      sourceTo: ActSyncStatus._date(json['source_to']),
      startedAt: ActSyncStatus._dateTime(json['started_at']),
      completedAt: ActSyncStatus._dateTime(json['completed_at']),
      totalRows: ActSyncStatus._integer(json['total_rows']),
      insertedRows: ActSyncStatus._integer(json['inserted_rows']),
      updatedRows: ActSyncStatus._integer(json['updated_rows']),
      unchangedRows: ActSyncStatus._integer(json['unchanged_rows']),
      missingSourceRows: ActSyncStatus._integer(json['missing_source_rows']),
      invalidRows: ActSyncStatus._integer(json['invalid_rows']),
      conflictRows: ActSyncStatus._integer(json['conflict_rows']),
      changedRows: ActSyncStatus._integer(json['changed_rows']),
      appliedRows: ActSyncStatus._integer(json['applied_rows']),
    );
  }

  final String? runId;
  final String status;
  final String scopeRole;
  final DateTime? sourceFrom;
  final DateTime? sourceTo;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int totalRows;
  final int insertedRows;
  final int updatedRows;
  final int unchangedRows;
  final int missingSourceRows;
  final int invalidRows;
  final int conflictRows;
  final int changedRows;
  final int appliedRows;

  int get issueRows => missingSourceRows + invalidRows + conflictRows;
}

class ActSyncFieldChange {
  const ActSyncFieldChange({
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
  });

  factory ActSyncFieldChange.fromJson(String fieldName, Object? value) {
    final values = value is Map
        ? value.map((key, item) => MapEntry(key.toString(), item))
        : const <String, dynamic>{};
    return ActSyncFieldChange(
      fieldName: fieldName,
      oldValue: values['old'],
      newValue: values['new'],
    );
  }

  final String fieldName;
  final Object? oldValue;
  final Object? newValue;

  String get oldText => _valueText(oldValue);
  String get newText => _valueText(newValue);

  static String _valueText(Object? value) {
    if (value == null) return 'Kosong';
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? 'Kosong' : text;
    }
    if (value is num || value is bool) return value.toString();
    return jsonEncode(value);
  }
}

class ActSyncDailyChange {
  const ActSyncDailyChange({
    required this.fieldNumber,
    required this.changeKind,
    required this.applied,
    required this.changedFieldCount,
    required this.changedFields,
    required this.validationErrors,
    this.sourceType,
    this.appliedAt,
    this.farmerName,
    this.hybrid,
    this.region,
    this.district,
    this.village,
    this.qaFi,
    this.qaSpv,
    this.applyError,
  });

  factory ActSyncDailyChange.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changed_columns'];
    final changes = rawChanges is Map
        ? rawChanges.entries
              .map(
                (entry) => ActSyncFieldChange.fromJson(
                  entry.key.toString(),
                  entry.value,
                ),
              )
              .toList(growable: false)
        : const <ActSyncFieldChange>[];
    final rawErrors = json['validation_errors'];
    return ActSyncDailyChange(
      fieldNumber: json['field_number']?.toString().trim() ?? '-',
      changeKind: ActSyncStatus._text(json['change_kind'], fallback: 'UNKNOWN'),
      sourceType: ActHarvestReview._optionalText(json['source_type']),
      applied: json['applied'] == true,
      appliedAt: ActSyncStatus._dateTime(json['applied_at']),
      farmerName: ActHarvestReview._optionalText(json['farmer_name']),
      hybrid: ActHarvestReview._optionalText(json['hybrid']),
      region: ActHarvestReview._optionalText(json['region']),
      district: ActHarvestReview._optionalText(json['district_kab']),
      village: ActHarvestReview._optionalText(json['village_desa']),
      qaFi: ActHarvestReview._optionalText(json['qa_fi']),
      qaSpv: ActHarvestReview._optionalText(json['qa_spv']),
      changedFieldCount: ActSyncStatus._integer(json['changed_field_count']),
      changedFields: changes,
      validationErrors: rawErrors is List
          ? rawErrors.map((item) => item.toString()).toList(growable: false)
          : const [],
      applyError: ActHarvestReview._optionalText(json['apply_error']),
    );
  }

  final String fieldNumber;
  final String changeKind;
  final String? sourceType;
  final bool applied;
  final DateTime? appliedAt;
  final String? farmerName;
  final String? hybrid;
  final String? region;
  final String? district;
  final String? village;
  final String? qaFi;
  final String? qaSpv;
  final int changedFieldCount;
  final List<ActSyncFieldChange> changedFields;
  final List<String> validationErrors;
  final String? applyError;

  bool get isIssue => const {
    'INVALID',
    'CONFLICT_SOURCE_DUPLICATE',
    'CONFLICT_KC_DUPLICATE',
    'MISSING_SOURCE',
  }.contains(changeKind);

  String get locationLabel => [
    village,
    district,
    region,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
}

class ActSyncDailyPage {
  const ActSyncDailyPage({
    required this.totalCount,
    required this.offset,
    required this.limit,
    required this.items,
    this.runId,
  });

  factory ActSyncDailyPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ActSyncDailyPage(
      runId: ActHarvestReview._optionalText(json['run_id']),
      totalCount: ActSyncStatus._integer(json['total_count']),
      offset: ActSyncStatus._integer(json['offset']),
      limit: ActSyncStatus._integer(json['limit']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (row) => ActSyncDailyChange.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final String? runId;
  final int totalCount;
  final int offset;
  final int limit;
  final List<ActSyncDailyChange> items;

  bool get hasPrevious => offset > 0;
  bool get hasNext => offset + items.length < totalCount;
}

class ActSyncDailyQuery {
  const ActSyncDailyQuery({
    this.runId,
    this.category = 'CHANGED',
    this.query,
    this.offset = 0,
    this.limit = 20,
  });

  final String? runId;
  final String category;
  final String? query;
  final int offset;
  final int limit;

  Map<String, dynamic> get rpcParams => {
    'p_run_id': runId,
    'p_category': category,
    'p_query': query,
    'p_offset': offset,
    'p_limit': limit,
  };

  @override
  bool operator ==(Object other) {
    return other is ActSyncDailyQuery &&
        other.runId == runId &&
        other.category == category &&
        other.query == query &&
        other.offset == offset &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(runId, category, query, offset, limit);
}

class PlantingDataMonitorFilter {
  const PlantingDataMonitorFilter({
    this.region,
    this.district,
    this.owner,
    this.season,
    this.seedType,
  });

  final String? region;
  final String? district;
  final String? owner;
  final String? season;
  final String? seedType;

  Map<String, dynamic> get rpcParams => {
    'p_region': region,
    'p_district': district,
    'p_owner': owner,
    'p_season': season,
    'p_seed_type': seedType,
  };

  bool get isEmpty =>
      region == null &&
      district == null &&
      owner == null &&
      season == null &&
      seedType == null;

  @override
  bool operator ==(Object other) {
    return other is PlantingDataMonitorFilter &&
        other.region == region &&
        other.district == district &&
        other.owner == owner &&
        other.season == season &&
        other.seedType == seedType;
  }

  @override
  int get hashCode => Object.hash(region, district, owner, season, seedType);
}

class PlantingDataMonitorSummary {
  const PlantingDataMonitorSummary({
    required this.fieldCount,
    required this.plantedAreaHa,
    required this.discardAreaHa,
    required this.effectiveAreaHa,
    required this.harvestedAreaHa,
    required this.standingCropAreaHa,
    required this.harvestNeedsReview,
  });

  factory PlantingDataMonitorSummary.fromJson(Map<String, dynamic> json) {
    return PlantingDataMonitorSummary(
      fieldCount: ActSyncStatus._integer(json['field_count']),
      plantedAreaHa: ActHarvestReview._number(json['planted_area_ha']),
      discardAreaHa: ActHarvestReview._number(json['discard_area_ha']),
      effectiveAreaHa: ActHarvestReview._number(json['effective_area_ha']),
      harvestedAreaHa: ActHarvestReview._number(json['harvested_area_ha']),
      standingCropAreaHa: ActHarvestReview._number(
        json['standing_crop_area_ha'],
      ),
      harvestNeedsReview: ActSyncStatus._integer(json['harvest_needs_review']),
    );
  }

  final int fieldCount;
  final double plantedAreaHa;
  final double discardAreaHa;
  final double effectiveAreaHa;
  final double harvestedAreaHa;
  final double standingCropAreaHa;
  final int harvestNeedsReview;
}

class PlantingPldLifecycleSummary {
  const PlantingPldLifecycleSummary({
    required this.totalRecommendedFn,
    required this.activeRecommendedFn,
    required this.pendingFn,
    required this.confirmedFn,
    required this.updatedFn,
    required this.phaseRows,
    required this.historicalFn,
    required this.confirmationRate,
  });

  factory PlantingPldLifecycleSummary.fromJson(Map<String, dynamic> json) {
    return PlantingPldLifecycleSummary(
      totalRecommendedFn: ActSyncStatus._integer(json['total_recommended_fn']),
      activeRecommendedFn: ActSyncStatus._integer(
        json['active_recommended_fn'],
      ),
      pendingFn: ActSyncStatus._integer(json['pending_fn']),
      confirmedFn: ActSyncStatus._integer(json['confirmed_fn']),
      updatedFn: ActSyncStatus._integer(json['updated_fn']),
      phaseRows: ActSyncStatus._integer(json['phase_rows']),
      historicalFn: ActSyncStatus._integer(json['historical_fn']),
      confirmationRate: ActHarvestReview._number(json['confirmation_rate']),
    );
  }

  final int totalRecommendedFn;
  final int activeRecommendedFn;
  final int pendingFn;
  final int confirmedFn;
  final int updatedFn;
  final int phaseRows;
  final int historicalFn;
  final double confirmationRate;
}

class PlantingPldLifecyclePhase {
  const PlantingPldLifecyclePhase({
    required this.phaseKey,
    required this.status,
    this.recommendedFlagging,
    this.activeFlagging,
    this.recommendedAt,
    this.confirmedAt,
    this.revisedAt,
  });

  factory PlantingPldLifecyclePhase.fromJson(Map<String, dynamic> json) {
    return PlantingPldLifecyclePhase(
      phaseKey: ActHarvestReview._optionalText(json['phase_key']) ?? '',
      status: ActSyncStatus._text(json['status'], fallback: 'PENDING'),
      recommendedFlagging: ActHarvestReview._optionalText(
        json['recommended_flagging'],
      ),
      activeFlagging: ActHarvestReview._optionalText(json['active_flagging']),
      recommendedAt: ActSyncStatus._dateTime(json['recommended_at']),
      confirmedAt: ActSyncStatus._dateTime(json['confirmed_at']),
      revisedAt: ActSyncStatus._dateTime(json['revised_at']),
    );
  }

  final String phaseKey;
  final String status;
  final String? recommendedFlagging;
  final String? activeFlagging;
  final DateTime? recommendedAt;
  final DateTime? confirmedAt;
  final DateTime? revisedAt;
}

class PlantingPldLifecycleItem {
  const PlantingPldLifecycleItem({
    required this.fieldNumber,
    required this.status,
    required this.phaseCount,
    required this.totalAreaPlantedHa,
    required this.discardAreaHa,
    required this.effectiveAreaHa,
    required this.historicalOnly,
    required this.phases,
    this.farmerName,
    this.grower,
    this.hybrid,
    this.region,
    this.district,
    this.subDistrict,
    this.village,
    this.qaFi,
    this.qaSpv,
    this.fieldAssistant,
    this.season,
    this.seedType,
    this.recommendedAt,
    this.confirmedAt,
    this.revisedAt,
    this.confirmedRunId,
    this.recommenderNames,
  });

  factory PlantingPldLifecycleItem.fromJson(Map<String, dynamic> json) {
    final rawPhases = json['phases'];
    return PlantingPldLifecycleItem(
      fieldNumber: json['field_number']?.toString().trim() ?? '-',
      status: ActSyncStatus._text(json['status'], fallback: 'PENDING'),
      phaseCount: ActSyncStatus._integer(json['phase_count']),
      totalAreaPlantedHa: ActHarvestReview._number(
        json['total_area_planted_ha'],
      ),
      discardAreaHa: ActHarvestReview._number(json['discard_area_ha']),
      effectiveAreaHa: ActHarvestReview._number(json['effective_area_ha']),
      historicalOnly: json['historical_only'] == true,
      phases: rawPhases is List
          ? rawPhases
                .whereType<Map>()
                .map(
                  (row) => PlantingPldLifecyclePhase.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
      farmerName: ActHarvestReview._optionalText(json['farmer_name']),
      grower: ActHarvestReview._optionalText(json['grower']),
      hybrid: ActHarvestReview._optionalText(json['hybrid']),
      region: ActHarvestReview._optionalText(json['region']),
      district: ActHarvestReview._optionalText(json['district_kab']),
      subDistrict: ActHarvestReview._optionalText(json['sub_district_kec']),
      village: ActHarvestReview._optionalText(json['village_desa']),
      qaFi: ActHarvestReview._optionalText(json['qa_fi']),
      qaSpv: ActHarvestReview._optionalText(json['qa_spv']),
      fieldAssistant: ActHarvestReview._optionalText(json['fa']),
      season: ActHarvestReview._optionalText(json['season']),
      seedType: ActHarvestReview._optionalText(json['type']),
      recommendedAt: ActSyncStatus._dateTime(json['recommended_at']),
      confirmedAt: ActSyncStatus._dateTime(json['confirmed_at']),
      revisedAt: ActSyncStatus._dateTime(json['revised_at']),
      confirmedRunId: ActHarvestReview._optionalText(json['confirmed_run_id']),
      recommenderNames: ActHarvestReview._optionalText(
        json['recommender_names'],
      ),
    );
  }

  final String fieldNumber;
  final String status;
  final int phaseCount;
  final double totalAreaPlantedHa;
  final double discardAreaHa;
  final double effectiveAreaHa;
  final bool historicalOnly;
  final List<PlantingPldLifecyclePhase> phases;
  final String? farmerName;
  final String? grower;
  final String? hybrid;
  final String? region;
  final String? district;
  final String? subDistrict;
  final String? village;
  final String? qaFi;
  final String? qaSpv;
  final String? fieldAssistant;
  final String? season;
  final String? seedType;
  final DateTime? recommendedAt;
  final DateTime? confirmedAt;
  final DateTime? revisedAt;
  final String? confirmedRunId;
  final String? recommenderNames;

  String get locationLabel => [
    village,
    subDistrict,
    district,
    region,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
}

class PlantingPldLifecyclePage {
  const PlantingPldLifecyclePage({
    required this.totalCount,
    required this.offset,
    required this.limit,
    required this.status,
    required this.items,
  });

  factory PlantingPldLifecyclePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return PlantingPldLifecyclePage(
      totalCount: ActSyncStatus._integer(json['total_count']),
      offset: ActSyncStatus._integer(json['offset']),
      limit: ActSyncStatus._integer(json['limit']),
      status: ActSyncStatus._text(json['status'], fallback: 'ALL'),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (row) => PlantingPldLifecycleItem.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final int totalCount;
  final int offset;
  final int limit;
  final String status;
  final List<PlantingPldLifecycleItem> items;

  bool get hasPrevious => offset > 0;
  bool get hasNext => offset + items.length < totalCount;
}

class PlantingPldLifecycleQuery {
  const PlantingPldLifecycleQuery({
    required this.filter,
    this.status = 'ALL',
    this.query,
    this.offset = 0,
    this.limit = 20,
  });

  final PlantingDataMonitorFilter filter;
  final String status;
  final String? query;
  final int offset;
  final int limit;

  Map<String, dynamic> get rpcParams => {
    ...filter.rpcParams,
    'p_status': status,
    'p_query': query,
    'p_offset': offset,
    'p_limit': limit,
  };

  @override
  bool operator ==(Object other) {
    return other is PlantingPldLifecycleQuery &&
        other.filter == filter &&
        other.status == status &&
        other.query == query &&
        other.offset == offset &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(filter, status, query, offset, limit);
}

class PlantingDataMonitorOptions {
  const PlantingDataMonitorOptions({
    this.regions = const [],
    this.districts = const [],
    this.owners = const [],
    this.seasons = const [],
    this.seedTypes = const [],
  });

  factory PlantingDataMonitorOptions.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) {
      if (value is! List) return const [];
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return PlantingDataMonitorOptions(
      regions: strings(json['regions']),
      districts: strings(json['districts']),
      owners: strings(json['owners']),
      seasons: strings(json['seasons']),
      seedTypes: strings(json['seed_types']),
    );
  }

  final List<String> regions;
  final List<String> districts;
  final List<String> owners;
  final List<String> seasons;
  final List<String> seedTypes;
}
