const String seasonIndependentMasterFieldRegion = 'Region Trial';

bool isSeasonIndependentMasterFieldRegion(Object? region) =>
    region?.toString().trim().toLowerCase() ==
    seasonIndependentMasterFieldRegion.toLowerCase();

String? masterFieldSeasonForRegion({
  required String? season,
  required Object? region,
}) => isSeasonIndependentMasterFieldRegion(region) ? null : season;

List<String> includeSeasonIndependentMasterFieldRegions({
  required Iterable<String> scopedRegions,
  required Iterable<String> allSeasonRegions,
}) {
  final byNormalizedName = <String, String>{};

  void add(String region) {
    final trimmed = region.trim();
    if (trimmed.isEmpty) return;
    byNormalizedName.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
  }

  for (final region in scopedRegions) {
    add(region);
  }
  for (final region in allSeasonRegions) {
    if (isSeasonIndependentMasterFieldRegion(region)) add(region);
  }

  return byNormalizedName.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}
