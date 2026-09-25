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

  bool get isSyncing => const {
    'EXTRACTING',
    'WAITING_EXPORT',
    'VALIDATING',
    'APPLYING',
  }.contains(latestStatus);

  bool get needsAttention =>
      const {'FAILED', 'BLOCKED', 'READY'}.contains(latestStatus);

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
