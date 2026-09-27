enum FieldStopReason { active, pld, discard, zeroEffectiveArea }

class FieldLifecycleState {
  final FieldStopReason reason;
  final DateTime? stoppedAt;
  final String? stoppedPhase;
  final double? effectiveAreaHa;

  const FieldLifecycleState({
    required this.reason,
    this.stoppedAt,
    this.stoppedPhase,
    this.effectiveAreaHa,
  });

  bool get isStopped => reason != FieldStopReason.active;

  bool get isOperational =>
      !isStopped && (effectiveAreaHa == null || effectiveAreaHa! > 0);

  String get statusLabel {
    switch (reason) {
      case FieldStopReason.pld:
        return 'PLD';
      case FieldStopReason.discard:
        return 'Discard';
      case FieldStopReason.zeroEffectiveArea:
        return 'Berhenti';
      case FieldStopReason.active:
        return 'Aktif';
    }
  }
}

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
        normalized == 'DISCARD' ||
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

  /// Resolves the current lifecycle from effective area and the latest dated
  /// audit. An older PLD can be superseded by a newer non-terminal audit.
  static FieldLifecycleState resolveField(
    Map<String, dynamic> raw, {
    DateTime? asOf,
  }) {
    final effectiveArea = _readArea(raw['effective_area_ha']);
    final limit = asOf == null ? null : _dateOnly(asOf);
    final observations = <_LifecycleObservation>[];
    _LifecycleObservation? undatedStop;
    var sequence = 0;

    void addObservation({
      required String phase,
      required Object? dateValue,
      required FieldStopReason? stopReason,
    }) {
      final date = _parseDate(dateValue);
      if (date == null) {
        if (stopReason != null) {
          undatedStop = _LifecycleObservation(
            sequence: sequence++,
            phase: phase,
            date: null,
            stopReason: stopReason,
          );
        }
        return;
      }
      if (limit != null && date.isAfter(limit)) return;
      observations.add(
        _LifecycleObservation(
          sequence: sequence++,
          phase: phase,
          date: date,
          stopReason: stopReason,
        ),
      );
    }

    final vegetative = _firstRow(raw['audit_vegetative']);
    if (vegetative != null) {
      addObservation(
        phase: 'Vegetatif',
        dateValue:
            vegetative['audit_date_user'] ??
            vegetative['date_of_audit'] ??
            vegetative['submitted_at'],
        stopReason: _stopReason(
          decisions: [vegetative['decision'], vegetative['final_decision']],
          actions: [vegetative['action_needed']],
          flags: [vegetative['flagging'], vegetative['final_flagging']],
        ),
      );
    }

    final generative = _firstRow(raw['audit_generative']);
    if (generative != null) {
      for (var checkpoint = 1; checkpoint <= 5; checkpoint++) {
        addObservation(
          phase: 'Generatif CP$checkpoint',
          dateValue:
              generative['date_of_audit_$checkpoint'] ??
              generative['submitted_at_$checkpoint'],
          stopReason: _stopReason(
            decisions: [generative['final_decision_$checkpoint']],
            actions: [generative['action_needed_$checkpoint']],
            flags: [
              generative['final_flagging_$checkpoint'],
              generative['flagging_$checkpoint'],
              if (checkpoint == 3) generative['flagging'],
            ],
          ),
        );
      }
    }

    final preHarvest = _firstRow(raw['audit_pre_harvest']);
    if (preHarvest != null) {
      addObservation(
        phase: 'Pre-Harvest',
        dateValue:
            preHarvest['audit_date'] ??
            preHarvest['date_of_audit'] ??
            preHarvest['submitted_at'],
        stopReason: _stopReason(
          decisions: [preHarvest['final_decision']],
          actions: [preHarvest['action_needed']],
          flags: [preHarvest['final_flagging'], preHarvest['flagging']],
        ),
      );
    }

    final harvest = _firstRow(raw['audit_harvest']);
    if (harvest != null) {
      addObservation(
        phase: 'Harvest',
        dateValue:
            harvest['date_of_audit'] ??
            harvest['audit_date'] ??
            harvest['submitted_at'],
        stopReason: _stopReason(
          decisions: [harvest['final_decision'], harvest['status_downgrade']],
          actions: [harvest['action_needed']],
          flags: [
            harvest['final_flagging'],
            harvest['downgrade_flagging'],
            harvest['flagging'],
          ],
        ),
      );
    }

    observations.sort((a, b) {
      final dateOrder = a.date!.compareTo(b.date!);
      return dateOrder != 0 ? dateOrder : a.sequence.compareTo(b.sequence);
    });
    final latest = observations.isEmpty ? null : observations.last;
    _LifecycleObservation? latestTerminal;
    for (final observation in observations.reversed) {
      if (observation.stopReason != null) {
        latestTerminal = observation;
        break;
      }
    }
    final masterStop = _stopReason(
      decisions: [raw['final_decision']],
      flags: [raw['flagging_final']],
    );

    if (effectiveArea != null && effectiveArea <= 0) {
      final terminal = latestTerminal ?? undatedStop;
      return FieldLifecycleState(
        reason:
            terminal?.stopReason ??
            masterStop ??
            FieldStopReason.zeroEffectiveArea,
        stoppedAt: terminal?.date ?? latest?.date,
        stoppedPhase: terminal?.phase ?? latest?.phase,
        effectiveAreaHa: effectiveArea,
      );
    }

    if (latest?.stopReason != null) {
      return FieldLifecycleState(
        reason: latest!.stopReason!,
        stoppedAt: latest.date,
        stoppedPhase: latest.phase,
        effectiveAreaHa: effectiveArea,
      );
    }

    if (latest == null && (undatedStop != null || masterStop != null)) {
      return FieldLifecycleState(
        reason: undatedStop?.stopReason ?? masterStop!,
        stoppedPhase: undatedStop?.phase ?? 'Master',
        effectiveAreaHa: effectiveArea,
      );
    }

    return FieldLifecycleState(
      reason: FieldStopReason.active,
      effectiveAreaHa: effectiveArea,
    );
  }

  static FieldStopReason? _stopReason({
    Iterable<Object?> decisions = const [],
    Iterable<Object?> actions = const [],
    Iterable<Object?> flags = const [],
  }) {
    for (final value in decisions) {
      final text = normalize(value);
      if (text.isEmpty || isPartial(text)) continue;
      if (text == 'D' || text.contains('DISCARD')) {
        return FieldStopReason.discard;
      }
      if (isExplicitPld(text)) return FieldStopReason.pld;
    }
    for (final value in actions) {
      final text = normalize(value);
      if (text.isEmpty || isPartial(text)) continue;
      if (const {'F', 'G'}.contains(text) || text.contains('DISCARD')) {
        return FieldStopReason.discard;
      }
      if (isExplicitPld(text)) return FieldStopReason.pld;
    }
    for (final value in flags) {
      final text = normalize(value);
      if (text.isEmpty || isPartial(text)) continue;
      if (text.contains('DISCARD')) return FieldStopReason.discard;
      if (isExplicitPld(text)) return FieldStopReason.pld;
    }
    return null;
  }

  static Map<String, dynamic>? _firstRow(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  static double? _readArea(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static DateTime? _parseDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return _dateOnly(parsed);
    final parts = text.split(RegExp(r'[/\-]'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _LifecycleObservation {
  final int sequence;
  final String phase;
  final DateTime? date;
  final FieldStopReason? stopReason;

  const _LifecycleObservation({
    required this.sequence,
    required this.phase,
    required this.date,
    required this.stopReason,
  });
}
