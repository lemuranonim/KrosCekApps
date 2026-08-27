class AuditPlanningTextFilter {
  final String fieldKey;
  final String label;
  final String value;

  const AuditPlanningTextFilter({
    required this.fieldKey,
    required this.label,
    required this.value,
  });
}

class AuditPlanningInitialFilters {
  final String? region;
  final String? district;
  final String? season;
  final String? phase;
  final String? status;
  final bool allRegions;
  final bool allSeasons;
  final bool showPld;
  final List<AuditPlanningTextFilter> textFilters;

  const AuditPlanningInitialFilters({
    this.region,
    this.district,
    this.season,
    this.phase,
    this.status,
    this.allRegions = false,
    this.allSeasons = false,
    this.showPld = false,
    this.textFilters = const [],
  });
}
