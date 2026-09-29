class PldAuditLifecycleBundle {
  const PldAuditLifecycleBundle({
    required this.viewerRole,
    required this.canRevise,
    required this.statuses,
    required this.history,
    this.fieldNumber,
  });

  factory PldAuditLifecycleBundle.fromJson(Map<String, dynamic> json) {
    final rawStatuses = json['statuses'];
    final rawHistory = json['history'];
    return PldAuditLifecycleBundle(
      fieldNumber: _text(json['field_number']),
      viewerRole: (_text(json['viewer_role']) ?? 'NONE').toUpperCase(),
      canRevise: json['can_revise'] == true,
      statuses: rawStatuses is List
          ? rawStatuses
                .whereType<Map>()
                .map(
                  (row) => PldAuditPhaseStatus.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
      history: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (row) => PldAuditRevision.fromJson(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final String? fieldNumber;
  final String viewerRole;
  final bool canRevise;
  final List<PldAuditPhaseStatus> statuses;
  final List<PldAuditRevision> history;

  Map<String, PldAuditPhaseStatus> get byPhase => {
    for (final status in statuses) status.phaseKey: status,
  };

  Set<String> get pendingPhaseKeys => statuses
      .where((status) => status.isPending)
      .map((status) => status.phaseKey)
      .toSet();

  bool get hasPending => statuses.any((status) => status.isPending);
  bool get hasConfirmed => statuses.any((status) => status.isConfirmed);
}

class PldAuditPhaseStatus {
  const PldAuditPhaseStatus({
    required this.phaseKey,
    required this.status,
    required this.locked,
    required this.effectiveAreaHa,
    this.recommendedFlagging,
    this.activeFlagging,
    this.recommendedAt,
    this.confirmedAt,
    this.confirmedRunId,
    this.revisedAt,
    this.updatedAt,
  });

  factory PldAuditPhaseStatus.fromJson(Map<String, dynamic> json) {
    return PldAuditPhaseStatus(
      phaseKey: _text(json['phase_key']) ?? '',
      status: (_text(json['status']) ?? 'PENDING').toUpperCase(),
      locked: json['locked'] == true,
      effectiveAreaHa: _number(json['effective_area_ha']),
      recommendedFlagging: _text(json['recommended_flagging']),
      activeFlagging: _text(json['active_flagging']),
      recommendedAt: _dateTime(json['recommended_at']),
      confirmedAt: _dateTime(json['confirmed_at']),
      confirmedRunId: _text(json['confirmed_run_id']),
      revisedAt: _dateTime(json['revised_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  final String phaseKey;
  final String status;
  final bool locked;
  final double? effectiveAreaHa;
  final String? recommendedFlagging;
  final String? activeFlagging;
  final DateTime? recommendedAt;
  final DateTime? confirmedAt;
  final String? confirmedRunId;
  final DateTime? revisedAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isUpdated => status == 'UPDATED';
}

class PldAuditRevision {
  const PldAuditRevision({
    required this.id,
    required this.phaseKey,
    required this.eventType,
    required this.oldPayload,
    required this.newPayload,
    required this.createdAt,
    this.oldFlagging,
    this.newFlagging,
    this.lifecycleStatus,
    this.actorName,
    this.actorRole,
    this.actSyncRunId,
  });

  factory PldAuditRevision.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payload(Object? value) {
      if (value is! Map) return const {};
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return PldAuditRevision(
      id: _integer(json['id']),
      phaseKey: _text(json['phase_key']) ?? '',
      eventType: (_text(json['event_type']) ?? 'UPDATED').toUpperCase(),
      oldPayload: payload(json['old_payload']),
      newPayload: payload(json['new_payload']),
      oldFlagging: _text(json['old_flagging']),
      newFlagging: _text(json['new_flagging']),
      lifecycleStatus: _text(json['lifecycle_status'])?.toUpperCase(),
      actorName: _text(json['actor_name']),
      actorRole: _text(json['actor_role']),
      actSyncRunId: _text(json['act_sync_run_id']),
      createdAt: _dateTime(json['created_at']) ?? DateTime(1970),
    );
  }

  final int id;
  final String phaseKey;
  final String eventType;
  final Map<String, dynamic> oldPayload;
  final Map<String, dynamic> newPayload;
  final String? oldFlagging;
  final String? newFlagging;
  final String? lifecycleStatus;
  final String? actorName;
  final String? actorRole;
  final String? actSyncRunId;
  final DateTime createdAt;

  bool get isActEvent =>
      eventType == 'ACT_CONFIRMED' || eventType == 'ACT_REOPENED';
}

String pldAuditPhaseLabel(String phaseKey) {
  return switch (phaseKey) {
    'vegetative' => 'Vegetative',
    'generative_1' => 'Generative CP1',
    'generative_2' => 'Generative CP2',
    'generative_3' => 'Generative CP3',
    'generative_4' => 'Generative CP4',
    'generative_5' => 'Generative CP5',
    'pre_harvest' => 'Pre-Harvest',
    'harvest' => 'Harvest',
    _ => phaseKey.replaceAll('_', ' '),
  };
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _number(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _dateTime(Object? value) {
  final text = _text(value);
  return text == null ? null : DateTime.tryParse(text)?.toLocal();
}
