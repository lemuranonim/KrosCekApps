import 'dart:async';
import 'dart:convert';

enum MasterFieldCacheBackend {
  hive,
  drift,
  disabled;

  static MasterFieldCacheBackend parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'drift' => MasterFieldCacheBackend.drift,
      'disabled' => MasterFieldCacheBackend.disabled,
      _ => MasterFieldCacheBackend.hive,
    };
  }
}

enum MasterFieldCacheDatasetFamily {
  map,
  coverage,
  planning,
  other;

  static MasterFieldCacheDatasetFamily fromDataset(String dataset) {
    final base = dataset.trim().toLowerCase().split(':').first;
    return switch (base) {
      'map' => MasterFieldCacheDatasetFamily.map,
      'coverage' ||
      'coverage-regions' => MasterFieldCacheDatasetFamily.coverage,
      'planning_index' => MasterFieldCacheDatasetFamily.planning,
      _ => MasterFieldCacheDatasetFamily.other,
    };
  }
}

class MasterFieldCacheFeatureFlags {
  final bool enabled;
  final MasterFieldCacheBackend mapBackend;
  final MasterFieldCacheBackend coverageBackend;
  final MasterFieldCacheBackend planningBackend;
  final bool dualWriteHiveWhenDrift;
  final Set<MasterFieldCacheDatasetFamily> driftShadowFamilies;
  final int driftShadowSamplePercent;

  const MasterFieldCacheFeatureFlags({
    this.enabled = true,
    this.mapBackend = MasterFieldCacheBackend.hive,
    this.coverageBackend = MasterFieldCacheBackend.hive,
    this.planningBackend = MasterFieldCacheBackend.hive,
    this.dualWriteHiveWhenDrift = false,
    this.driftShadowFamilies = const {},
    this.driftShadowSamplePercent = 10,
  });

  factory MasterFieldCacheFeatureFlags.fromEnvironment() {
    const enabled = bool.fromEnvironment(
      'KC_MASTER_FIELD_LOCAL_CACHE_ENABLED',
      defaultValue: true,
    );
    const mapBackend = String.fromEnvironment(
      'KC_MASTER_FIELD_MAP_CACHE_BACKEND',
      defaultValue: 'hive',
    );
    const coverageBackend = String.fromEnvironment(
      'KC_MASTER_FIELD_COVERAGE_CACHE_BACKEND',
      defaultValue: 'hive',
    );
    const planningBackend = String.fromEnvironment(
      'KC_MASTER_FIELD_PLANNING_CACHE_BACKEND',
      defaultValue: 'hive',
    );
    const dualWriteHiveWhenDrift = bool.fromEnvironment(
      'KC_MASTER_FIELD_DRIFT_DUAL_WRITE_HIVE',
      defaultValue: false,
    );
    const driftShadowDatasets = String.fromEnvironment(
      'KC_MASTER_FIELD_DRIFT_SHADOW_DATASETS',
      defaultValue: '',
    );
    const driftShadowSamplePercent = int.fromEnvironment(
      'KC_MASTER_FIELD_DRIFT_SHADOW_SAMPLE_PERCENT',
      defaultValue: 10,
    );

    return MasterFieldCacheFeatureFlags(
      enabled: enabled,
      mapBackend: MasterFieldCacheBackend.parse(mapBackend),
      coverageBackend: MasterFieldCacheBackend.parse(coverageBackend),
      planningBackend: MasterFieldCacheBackend.parse(planningBackend),
      dualWriteHiveWhenDrift: dualWriteHiveWhenDrift,
      driftShadowFamilies: _parseShadowFamilies(driftShadowDatasets),
      driftShadowSamplePercent: driftShadowSamplePercent,
    );
  }

  /// Whether the process needs to open the optional Drift database.
  ///
  /// Keeping this false for the default Hive configuration prevents SQLite
  /// initialization and file creation until a dataset is explicitly opted in.
  bool get requestsDrift =>
      enabled &&
      (mapBackend == MasterFieldCacheBackend.drift ||
          coverageBackend == MasterFieldCacheBackend.drift ||
          planningBackend == MasterFieldCacheBackend.drift ||
          (driftShadowFamilies.contains(MasterFieldCacheDatasetFamily.map) &&
              mapBackend == MasterFieldCacheBackend.hive) ||
          (driftShadowFamilies.contains(
                MasterFieldCacheDatasetFamily.coverage,
              ) &&
              coverageBackend == MasterFieldCacheBackend.hive) ||
          (driftShadowFamilies.contains(
                MasterFieldCacheDatasetFamily.planning,
              ) &&
              planningBackend == MasterFieldCacheBackend.hive));

  int get effectiveDriftShadowSamplePercent =>
      driftShadowSamplePercent.clamp(0, 100);

  bool isDriftShadowEnabledForDataset(String dataset) {
    if (!enabled ||
        backendForDataset(dataset) != MasterFieldCacheBackend.hive) {
      return false;
    }
    final family = MasterFieldCacheDatasetFamily.fromDataset(dataset);
    return family != MasterFieldCacheDatasetFamily.other &&
        driftShadowFamilies.contains(family);
  }

  bool shouldSampleDriftShadow(MasterFieldCacheScope scope) {
    if (!isDriftShadowEnabledForDataset(scope.dataset)) return false;
    final percent = effectiveDriftShadowSamplePercent;
    if (percent <= 0) return false;
    if (percent >= 100) return true;
    var hash = 0;
    for (final codeUnit in scope.storageKey.codeUnits) {
      hash = ((hash * 31) + codeUnit) % 10000;
    }
    return hash % 100 < percent;
  }

  MasterFieldCacheBackend backendForDataset(String dataset) {
    if (!enabled) return MasterFieldCacheBackend.disabled;
    return switch (MasterFieldCacheDatasetFamily.fromDataset(dataset)) {
      MasterFieldCacheDatasetFamily.map => mapBackend,
      MasterFieldCacheDatasetFamily.coverage => coverageBackend,
      MasterFieldCacheDatasetFamily.planning => planningBackend,
      MasterFieldCacheDatasetFamily.other => MasterFieldCacheBackend.hive,
    };
  }

  static Set<MasterFieldCacheDatasetFamily> _parseShadowFamilies(String value) {
    final families = <MasterFieldCacheDatasetFamily>{};
    for (final token in value.split(',')) {
      switch (token.trim().toLowerCase()) {
        case 'map':
          families.add(MasterFieldCacheDatasetFamily.map);
        case 'coverage':
          families.add(MasterFieldCacheDatasetFamily.coverage);
        case 'planning':
          families.add(MasterFieldCacheDatasetFamily.planning);
      }
    }
    return Set.unmodifiable(families);
  }
}

class MasterFieldCacheScope {
  static const keyPrefix = 'mf-read-v2';

  final String userId;
  final String dataset;
  final String? season;
  final String? region;
  final String? district;

  const MasterFieldCacheScope({
    required this.userId,
    required this.dataset,
    this.season,
    this.region,
    this.district,
  });

  bool get isValid => userId.trim().isNotEmpty && dataset.trim().isNotEmpty;

  String get storageKey {
    final identity = jsonEncode({
      'dataset': dataset,
      'season': _normalize(season),
      'region': _normalize(region),
      'district': _normalize(district),
    });
    final encodedScope = base64Url.encode(utf8.encode(identity));
    return '$keyPrefix:$userId:$encodedScope';
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class MasterFieldReadCacheEntry {
  final int version;
  final DateTime savedAt;
  final List<Map<String, dynamic>> rows;

  const MasterFieldReadCacheEntry({
    required this.version,
    required this.savedAt,
    required this.rows,
  });
}

abstract interface class MasterFieldReadCacheStore {
  MasterFieldCacheBackend get backend;

  bool get isAvailable;

  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope);

  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  );

  Future<void> clearUser(String userId);
}

typedef MasterFieldCacheLog = void Function(
  String message,
  Object error,
  StackTrace stackTrace,
);

enum MasterFieldCacheCanaryOutcome {
  mirroredWrite,
  primaryWriteFailed,
  shadowWriteFailed,
  driftUnavailable,
  bothMissing,
  hiveOnly,
  driftOnly,
  versionMismatch,
  rowCountMismatch,
  contentMismatch,
  match,
  shadowReadFailed,
  shadowReadSkippedBusy;

  bool get isHealthy =>
      this == MasterFieldCacheCanaryOutcome.mirroredWrite ||
      this == MasterFieldCacheCanaryOutcome.match ||
      this == MasterFieldCacheCanaryOutcome.bothMissing ||
      this == MasterFieldCacheCanaryOutcome.shadowReadSkippedBusy;

  bool get isContentComparison =>
      this == MasterFieldCacheCanaryOutcome.match ||
      this == MasterFieldCacheCanaryOutcome.versionMismatch ||
      this == MasterFieldCacheCanaryOutcome.rowCountMismatch ||
      this == MasterFieldCacheCanaryOutcome.contentMismatch;

  bool get requiresConsistencyRetry =>
      this == MasterFieldCacheCanaryOutcome.hiveOnly ||
      this == MasterFieldCacheCanaryOutcome.driftOnly ||
      this == MasterFieldCacheCanaryOutcome.versionMismatch ||
      this == MasterFieldCacheCanaryOutcome.rowCountMismatch ||
      this == MasterFieldCacheCanaryOutcome.contentMismatch;
}

class MasterFieldCacheCanaryEvent {
  final DateTime recordedAt;
  final MasterFieldCacheDatasetFamily family;
  final String dataset;
  final MasterFieldCacheCanaryOutcome outcome;
  final Duration elapsed;
  final int? hiveVersion;
  final int? driftVersion;
  final int? hiveRowCount;
  final int? driftRowCount;
  final bool? hiveWriteSucceeded;
  final bool? driftWriteSucceeded;

  const MasterFieldCacheCanaryEvent({
    required this.recordedAt,
    required this.family,
    required this.dataset,
    required this.outcome,
    required this.elapsed,
    this.hiveVersion,
    this.driftVersion,
    this.hiveRowCount,
    this.driftRowCount,
    this.hiveWriteSucceeded,
    this.driftWriteSucceeded,
  });

  Map<String, Object?> toJson() => {
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'family': family.name,
    'dataset': dataset,
    'outcome': outcome.name,
    'elapsedMicros': elapsed.inMicroseconds,
    if (hiveVersion != null) 'hiveVersion': hiveVersion,
    if (driftVersion != null) 'driftVersion': driftVersion,
    if (hiveRowCount != null) 'hiveRowCount': hiveRowCount,
    if (driftRowCount != null) 'driftRowCount': driftRowCount,
    if (hiveWriteSucceeded != null) 'hiveWriteSucceeded': hiveWriteSucceeded,
    if (driftWriteSucceeded != null) 'driftWriteSucceeded': driftWriteSucceeded,
  };
}

class MasterFieldCacheCanarySnapshot {
  final int totalEvents;
  final Map<MasterFieldCacheCanaryOutcome, int> outcomes;
  final Map<MasterFieldCacheDatasetFamily, int> families;
  final Map<
    MasterFieldCacheDatasetFamily,
    Map<MasterFieldCacheCanaryOutcome, int>
  >
  outcomesByFamily;

  const MasterFieldCacheCanarySnapshot({
    required this.totalEvents,
    required this.outcomes,
    required this.families,
    required this.outcomesByFamily,
  });

  int count(MasterFieldCacheCanaryOutcome outcome) => outcomes[outcome] ?? 0;

  int get contentComparisonCount => MasterFieldCacheCanaryOutcome.values
      .where((outcome) => outcome.isContentComparison)
      .fold(0, (total, outcome) => total + count(outcome));

  double? get contentMatchRate {
    final comparisons = contentComparisonCount;
    if (comparisons == 0) return null;
    return count(MasterFieldCacheCanaryOutcome.match) / comparisons;
  }

  int countForFamily(
    MasterFieldCacheDatasetFamily family,
    MasterFieldCacheCanaryOutcome outcome,
  ) => outcomesByFamily[family]?[outcome] ?? 0;

  int contentComparisonCountForFamily(MasterFieldCacheDatasetFamily family) =>
      MasterFieldCacheCanaryOutcome.values
          .where((outcome) => outcome.isContentComparison)
          .fold(0, (total, outcome) => total + countForFamily(family, outcome));

  double? contentMatchRateForFamily(MasterFieldCacheDatasetFamily family) {
    final comparisons = contentComparisonCountForFamily(family);
    if (comparisons == 0) return null;
    return countForFamily(family, MasterFieldCacheCanaryOutcome.match) /
        comparisons;
  }

  int driftFailureCountForFamily(MasterFieldCacheDatasetFamily family) {
    return countForFamily(
          family,
          MasterFieldCacheCanaryOutcome.driftUnavailable,
        ) +
        countForFamily(
          family,
          MasterFieldCacheCanaryOutcome.shadowWriteFailed,
        ) +
        countForFamily(family, MasterFieldCacheCanaryOutcome.shadowReadFailed);
  }

  double? driftFailureRateForFamily(MasterFieldCacheDatasetFamily family) {
    final events = families[family] ?? 0;
    if (events == 0) return null;
    return driftFailureCountForFamily(family) / events;
  }
}

class MasterFieldCacheCanaryMonitor {
  final Map<MasterFieldCacheCanaryOutcome, int> _outcomes = {};
  final Map<MasterFieldCacheDatasetFamily, int> _families = {};
  final Map<
    MasterFieldCacheDatasetFamily,
    Map<MasterFieldCacheCanaryOutcome, int>
  >
  _outcomesByFamily = {};
  int _totalEvents = 0;

  void record(MasterFieldCacheCanaryEvent event) {
    _totalEvents++;
    _outcomes.update(event.outcome, (count) => count + 1, ifAbsent: () => 1);
    _families.update(event.family, (count) => count + 1, ifAbsent: () => 1);
    final familyOutcomes = _outcomesByFamily.putIfAbsent(
      event.family,
      () => {},
    );
    familyOutcomes.update(
      event.outcome,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  MasterFieldCacheCanarySnapshot get snapshot => MasterFieldCacheCanarySnapshot(
    totalEvents: _totalEvents,
    outcomes: Map.unmodifiable(_outcomes),
    families: Map.unmodifiable(_families),
    outcomesByFamily:
        Map<
          MasterFieldCacheDatasetFamily,
          Map<MasterFieldCacheCanaryOutcome, int>
        >.unmodifiable({
          for (final entry in _outcomesByFamily.entries)
            entry.key: Map<MasterFieldCacheCanaryOutcome, int>.unmodifiable(
              entry.value,
            ),
        }),
  );

  void reset() {
    _totalEvents = 0;
    _outcomes.clear();
    _families.clear();
    _outcomesByFamily.clear();
  }
}

typedef MasterFieldCacheCanaryReporter = void Function(
  MasterFieldCacheCanaryEvent event,
);
typedef MasterFieldCacheRowsEqual = Future<bool> Function(
  List<Map<String, dynamic>> hiveRows,
  List<Map<String, dynamic>> driftRows,
);

class MasterFieldReadCacheRouter {
  static const maxConcurrentShadowReads = 2;

  final MasterFieldCacheFeatureFlags flags;
  final MasterFieldReadCacheStore hiveStore;
  final MasterFieldReadCacheStore? driftStore;
  final MasterFieldCacheLog? log;
  final MasterFieldCacheCanaryReporter? canaryReporter;
  final MasterFieldCacheRowsEqual? canaryRowsEqual;
  final Set<String> _shadowReadsInFlight = {};
  final Map<String, Future<void>> _shadowWriteTails = {};

  MasterFieldReadCacheRouter({
    required this.flags,
    required this.hiveStore,
    this.driftStore,
    this.log,
    this.canaryReporter,
    this.canaryRowsEqual,
  });

  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    if (!scope.isValid) return null;
    final backend = flags.backendForDataset(scope.dataset);
    switch (backend) {
      case MasterFieldCacheBackend.disabled:
        return null;
      case MasterFieldCacheBackend.hive:
        final hiveEntry = await _readFrom(hiveStore, scope);
        _scheduleDriftShadowRead(scope, hiveEntry);
        return hiveEntry;
      case MasterFieldCacheBackend.drift:
        final drift = driftStore;
        if (drift != null) {
          final driftEntry = await _readFrom(drift, scope);
          if (driftEntry != null) return driftEntry;
        }
        return _readFrom(hiveStore, scope);
    }
  }

  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    if (!scope.isValid || entry.version < 0) return;
    final backend = flags.backendForDataset(scope.dataset);
    switch (backend) {
      case MasterFieldCacheBackend.disabled:
        return;
      case MasterFieldCacheBackend.hive:
        if (flags.isDriftShadowEnabledForDataset(scope.dataset)) {
          await _writeHiveAndDriftShadow(scope, entry);
        } else {
          await _writeTo(hiveStore, scope, entry);
        }
        return;
      case MasterFieldCacheBackend.drift:
        final driftWritten =
            driftStore != null && await _writeTo(driftStore!, scope, entry);
        if (!driftWritten || flags.dualWriteHiveWhenDrift) {
          await _writeTo(hiveStore, scope, entry);
        }
    }
  }

  Future<void> clearUser(String userId) async {
    if (userId.trim().isEmpty) return;
    for (final store in _registeredStores) {
      if (!store.isAvailable) continue;
      try {
        await store.clearUser(userId);
      } catch (error, stackTrace) {
        _reportUserClear(store, error, stackTrace);
      }
    }
  }

  Iterable<MasterFieldReadCacheStore> get _registeredStores sync* {
    yield hiveStore;
    final drift = driftStore;
    if (drift != null && !identical(drift, hiveStore)) yield drift;
  }

  Future<bool> _writeTo(
    MasterFieldReadCacheStore store,
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    if (!store.isAvailable) return false;
    try {
      await store.write(scope, entry);
      return true;
    } catch (error, stackTrace) {
      _report('write', scope, store, error, stackTrace);
      return false;
    }
  }

  Future<MasterFieldReadCacheEntry?> _readFrom(
    MasterFieldReadCacheStore store,
    MasterFieldCacheScope scope,
  ) async {
    if (!store.isAvailable) return null;
    try {
      return await store.read(scope);
    } catch (error, stackTrace) {
      _report('read', scope, store, error, stackTrace);
      return null;
    }
  }

  Future<void> _writeDriftShadow(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
    bool hiveWritten,
  ) async {
    final stopwatch = Stopwatch()..start();
    final drift = driftStore;
    if (drift == null || !drift.isAvailable) {
      _emitCanary(
        _canaryEvent(
          scope: scope,
          outcome: MasterFieldCacheCanaryOutcome.driftUnavailable,
          elapsed: stopwatch.elapsed,
          hiveWriteSucceeded: hiveWritten,
          driftWriteSucceeded: false,
        ),
      );
      return;
    }

    final driftWritten = await _writeTo(drift, scope, entry);
    final outcome = !hiveWritten
        ? MasterFieldCacheCanaryOutcome.primaryWriteFailed
        : driftWritten
        ? MasterFieldCacheCanaryOutcome.mirroredWrite
        : MasterFieldCacheCanaryOutcome.shadowWriteFailed;
    _emitCanary(
      _canaryEvent(
        scope: scope,
        outcome: outcome,
        elapsed: stopwatch.elapsed,
        hiveWriteSucceeded: hiveWritten,
        driftWriteSucceeded: driftWritten,
      ),
    );
  }

  Future<void> _writeHiveAndDriftShadow(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    final cacheKey = scope.storageKey;
    final previous = _shadowWriteTails[cacheKey];
    final operation = _performHiveAndDriftShadowWrite(previous, scope, entry);
    _shadowWriteTails[cacheKey] = operation;
    try {
      await operation;
    } finally {
      if (identical(_shadowWriteTails[cacheKey], operation)) {
        _shadowWriteTails.remove(cacheKey);
      }
    }
  }

  Future<void> _performHiveAndDriftShadowWrite(
    Future<void>? previous,
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // Cache writes are already fail-open. Continue the per-key queue.
      }
    }
    final hiveWritten = await _writeTo(hiveStore, scope, entry);
    await _writeDriftShadow(scope, entry, hiveWritten);
  }

  void _scheduleDriftShadowRead(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry? hiveEntry,
  ) {
    if (canaryReporter == null || !flags.shouldSampleDriftShadow(scope)) return;
    final drift = driftStore;
    if (drift == null || !drift.isAvailable) {
      _emitCanary(
        _canaryEvent(
          scope: scope,
          outcome: MasterFieldCacheCanaryOutcome.driftUnavailable,
          elapsed: Duration.zero,
          hiveEntry: hiveEntry,
        ),
      );
      return;
    }
    final cacheKey = scope.storageKey;
    if (_shadowReadsInFlight.contains(cacheKey)) return;
    if (_shadowReadsInFlight.length >= maxConcurrentShadowReads) {
      _emitCanary(
        _canaryEvent(
          scope: scope,
          outcome: MasterFieldCacheCanaryOutcome.shadowReadSkippedBusy,
          elapsed: Duration.zero,
          hiveEntry: hiveEntry,
        ),
      );
      return;
    }
    _shadowReadsInFlight.add(cacheKey);
    unawaited(
      _runDriftShadowRead(
        scope,
        hiveEntry,
        drift,
      ).whenComplete(() => _shadowReadsInFlight.remove(cacheKey)),
    );
  }

  Future<void> _runDriftShadowRead(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry? hiveEntry,
    MasterFieldReadCacheStore drift,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      var comparedHiveEntry = hiveEntry;
      final pendingWrite = _shadowWriteTails[scope.storageKey];
      if (pendingWrite != null) {
        await pendingWrite;
        comparedHiveEntry = await hiveStore.read(scope);
      }
      var driftEntry = await drift.read(scope);
      var outcome = await _compareCanaryEntries(comparedHiveEntry, driftEntry);
      if (outcome.requiresConsistencyRetry) {
        comparedHiveEntry = await hiveStore.read(scope);
        driftEntry = await drift.read(scope);
        outcome = await _compareCanaryEntries(comparedHiveEntry, driftEntry);
      }
      _emitCanary(
        _canaryEvent(
          scope: scope,
          outcome: outcome,
          elapsed: stopwatch.elapsed,
          hiveEntry: comparedHiveEntry,
          driftEntry: driftEntry,
        ),
      );
    } catch (error, stackTrace) {
      _report('shadow read', scope, drift, error, stackTrace);
      _emitCanary(
        _canaryEvent(
          scope: scope,
          outcome: MasterFieldCacheCanaryOutcome.shadowReadFailed,
          elapsed: stopwatch.elapsed,
          hiveEntry: hiveEntry,
        ),
      );
    }
  }

  Future<MasterFieldCacheCanaryOutcome> _compareCanaryEntries(
    MasterFieldReadCacheEntry? hiveEntry,
    MasterFieldReadCacheEntry? driftEntry,
  ) async {
    if (hiveEntry == null && driftEntry == null) {
      return MasterFieldCacheCanaryOutcome.bothMissing;
    }
    if (hiveEntry != null && driftEntry == null) {
      return MasterFieldCacheCanaryOutcome.hiveOnly;
    }
    if (hiveEntry == null) return MasterFieldCacheCanaryOutcome.driftOnly;
    if (hiveEntry.version != driftEntry!.version) {
      return MasterFieldCacheCanaryOutcome.versionMismatch;
    }
    if (hiveEntry.rows.length != driftEntry.rows.length) {
      return MasterFieldCacheCanaryOutcome.rowCountMismatch;
    }
    final equal = await (canaryRowsEqual ?? _rowsEqualInline)(
      hiveEntry.rows,
      driftEntry.rows,
    );
    return equal
        ? MasterFieldCacheCanaryOutcome.match
        : MasterFieldCacheCanaryOutcome.contentMismatch;
  }

  Future<bool> _rowsEqualInline(
    List<Map<String, dynamic>> hiveRows,
    List<Map<String, dynamic>> driftRows,
  ) async => jsonEncode(hiveRows) == jsonEncode(driftRows);

  MasterFieldCacheCanaryEvent _canaryEvent({
    required MasterFieldCacheScope scope,
    required MasterFieldCacheCanaryOutcome outcome,
    required Duration elapsed,
    MasterFieldReadCacheEntry? hiveEntry,
    MasterFieldReadCacheEntry? driftEntry,
    bool? hiveWriteSucceeded,
    bool? driftWriteSucceeded,
  }) => MasterFieldCacheCanaryEvent(
    recordedAt: DateTime.now(),
    family: MasterFieldCacheDatasetFamily.fromDataset(scope.dataset),
    dataset: scope.dataset.trim().toLowerCase().split(':').first,
    outcome: outcome,
    elapsed: elapsed,
    hiveVersion: hiveEntry?.version,
    driftVersion: driftEntry?.version,
    hiveRowCount: hiveEntry?.rows.length,
    driftRowCount: driftEntry?.rows.length,
    hiveWriteSucceeded: hiveWriteSucceeded,
    driftWriteSucceeded: driftWriteSucceeded,
  );

  void _emitCanary(MasterFieldCacheCanaryEvent event) {
    try {
      canaryReporter?.call(event);
    } catch (error, stackTrace) {
      log?.call('Local cache canary telemetry skipped', error, stackTrace);
    }
  }

  void _report(
    String operation,
    MasterFieldCacheScope scope,
    MasterFieldReadCacheStore store,
    Object error,
    StackTrace stackTrace,
  ) {
    log?.call(
      'Local ${scope.dataset} ${store.backend.name} cache $operation skipped',
      error,
      stackTrace,
    );
  }

  void _reportUserClear(
    MasterFieldReadCacheStore store,
    Object error,
    StackTrace stackTrace,
  ) {
    log?.call(
      'Local ${store.backend.name} cache clear skipped',
      error,
      stackTrace,
    );
  }
}
