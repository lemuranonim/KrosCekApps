import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/weekly_audit.dart';

enum CoverageDisplayMode { allCoverage, targetAudit }

class AuditDashboardFilters {
  final CoverageDisplayMode coverageMode;
  final Set<DateTime> weeks;
  final bool allWeeks;
  final Set<String> flags;
  final String? region;
  final String? district;
  final String? village;
  final String status;
  final DateTime lastUpdated;

  const AuditDashboardFilters({
    required this.coverageMode,
    required this.weeks,
    required this.allWeeks,
    required this.flags,
    required this.region,
    required this.district,
    required this.village,
    required this.status,
    required this.lastUpdated,
  });

  factory AuditDashboardFilters.initial() => AuditDashboardFilters(
        coverageMode: CoverageDisplayMode.allCoverage,
        weeks: {auditWeekStart(DateTime.now())},
        allWeeks: false,
        flags: {...defaultAuditFlags},
        region: null,
        district: null,
        village: null,
        status: 'Pending',
        lastUpdated: DateTime.now(),
      );

  DateTime get primaryWeek {
    if (weeks.isEmpty) return auditWeekStart(DateTime.now());
    final sorted = weeks.toList()..sort();
    return sorted.last;
  }

  AuditDashboardFilters copyWith({
    CoverageDisplayMode? coverageMode,
    Set<DateTime>? weeks,
    bool? allWeeks,
    Set<String>? flags,
    String? region,
    bool clearRegion = false,
    String? district,
    bool clearDistrict = false,
    String? village,
    bool clearVillage = false,
    String? status,
    DateTime? lastUpdated,
  }) =>
      AuditDashboardFilters(
        coverageMode: coverageMode ?? this.coverageMode,
        weeks: weeks ?? this.weeks,
        allWeeks: allWeeks ?? this.allWeeks,
        flags: flags ?? this.flags,
        region: clearRegion ? null : region ?? this.region,
        district: clearDistrict ? null : district ?? this.district,
        village: clearVillage ? null : village ?? this.village,
        status: status ?? this.status,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

class AuditDashboardFilterNotifier extends Notifier<AuditDashboardFilters> {
  @override
  AuditDashboardFilters build() => AuditDashboardFilters.initial();

  void setCoverageMode(CoverageDisplayMode mode) =>
      state = state.copyWith(coverageMode: mode);

  void setWeeks(Set<DateTime> weeks, {bool all = false}) {
    final normalized = weeks.map(auditWeekStart).toSet();
    state = state.copyWith(
      weeks: normalized.isEmpty && !all
          ? {auditWeekStart(DateTime.now())}
          : normalized,
      allWeeks: all,
    );
  }

  void setFlags(Set<String> flags) =>
      state = state.copyWith(flags: Set.unmodifiable(flags));

  void setRegion(String? value) => state = state.copyWith(
        region: value,
        clearRegion: value == null,
        clearDistrict: true,
        clearVillage: true,
      );

  void setDistrict(String? value) => state = state.copyWith(
        district: value,
        clearDistrict: value == null,
        clearVillage: true,
      );

  void setVillage(String? value) => state = state.copyWith(
        village: value,
        clearVillage: value == null,
      );

  void setStatus(String value) => state = state.copyWith(status: value);

  void markUpdated() => state = state.copyWith(lastUpdated: DateTime.now());
}

final auditDashboardFilterProvider =
    NotifierProvider<AuditDashboardFilterNotifier, AuditDashboardFilters>(
  AuditDashboardFilterNotifier.new,
);
