class PldVisibilityHelper {
  const PldVisibilityHelper._();

  static String normalize(Object? value) =>
      value?.toString().trim().toUpperCase() ?? '';

  static bool isPartial(Object? value) => normalize(value).contains('PARTIAL');

  static bool isExplicitPld(Object? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty || isPartial(normalized)) return false;
    return normalized == 'PLD' || normalized.contains('PLD');
  }

  static bool isDecisionPld(Object? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty || isPartial(normalized)) return false;
    return normalized == 'D' ||
        normalized == 'DISCARD' ||
        isExplicitPld(normalized);
  }

  static bool isDiscardFull(Object? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty || isPartial(normalized)) return false;
    return normalized == 'G' ||
        normalized == 'DISCARD FULL' ||
        normalized.contains('DISCARD FULL') ||
        (normalized.contains('DISCARD') && normalized.contains('FULL'));
  }

  static bool isVegetativeActionPldFull(Object? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty || isPartial(normalized)) return false;
    return normalized == 'F' ||
        isDiscardFull(normalized) ||
        isExplicitPld(normalized);
  }

  static bool isPldOrDiscardFull(Object? value) =>
      isDecisionPld(value) || isDiscardFull(value);
}
