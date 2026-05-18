class QaNameHelper {
  QaNameHelper._();

  static String normalize(Object? value) {
    return (value?.toString() ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  static List<String> splitNames(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return const [];

    return raw
        .split(RegExp(r'\s*(?:,|;|\||/|&|\b(?:dan|and)\b)\s*',
            caseSensitive: false))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  static bool containsExactName(Object? value, String name) {
    final normalizedName = normalize(name);
    if (normalizedName.isEmpty) return false;

    return splitNames(value).any((item) => normalize(item) == normalizedName);
  }

  static bool fieldHasFi(Map<String, dynamic> field, String name) {
    return containsExactName(field['qa_fi'], name) ||
        containsExactName(field['qa_fi_list'], name);
  }

  static bool fieldHasSpv(Map<String, dynamic> field, String name) {
    return containsExactName(field['qa_spv'], name);
  }

  static bool fieldMatchesFiSearch(Map<String, dynamic> field, String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return true;

    final values = <String>[
      ...splitNames(field['qa_fi']),
      ...splitNames(field['qa_fi_list']),
    ];

    return values.any((name) => normalize(name).contains(normalizedQuery));
  }
}
