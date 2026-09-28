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

  bool get needsAttention => hasSyncError || hasHarvestReview;

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
