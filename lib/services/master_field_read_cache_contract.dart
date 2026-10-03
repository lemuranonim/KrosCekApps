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

  const MasterFieldCacheFeatureFlags({
    this.enabled = true,
    this.mapBackend = MasterFieldCacheBackend.hive,
    this.coverageBackend = MasterFieldCacheBackend.hive,
    this.planningBackend = MasterFieldCacheBackend.hive,
    this.dualWriteHiveWhenDrift = false,
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

    return MasterFieldCacheFeatureFlags(
      enabled: enabled,
      mapBackend: MasterFieldCacheBackend.parse(mapBackend),
      coverageBackend: MasterFieldCacheBackend.parse(coverageBackend),
      planningBackend: MasterFieldCacheBackend.parse(planningBackend),
      dualWriteHiveWhenDrift: dualWriteHiveWhenDrift,
    );
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

class MasterFieldReadCacheRouter {
  final MasterFieldCacheFeatureFlags flags;
  final MasterFieldReadCacheStore hiveStore;
  final MasterFieldReadCacheStore? driftStore;
  final MasterFieldCacheLog? log;

  const MasterFieldReadCacheRouter({
    required this.flags,
    required this.hiveStore,
    this.driftStore,
    this.log,
  });

  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    if (!scope.isValid) return null;
    final backend = flags.backendForDataset(scope.dataset);
    final stores = switch (backend) {
      MasterFieldCacheBackend.disabled => const <MasterFieldReadCacheStore>[],
      MasterFieldCacheBackend.hive => <MasterFieldReadCacheStore>[hiveStore],
      MasterFieldCacheBackend.drift => <MasterFieldReadCacheStore>[
        if (driftStore != null) driftStore!,
        hiveStore,
      ],
    };

    for (final store in stores) {
      if (!store.isAvailable) continue;
      try {
        final entry = await store.read(scope);
        if (entry != null) return entry;
      } catch (error, stackTrace) {
        _report('read', scope, store, error, stackTrace);
      }
    }
    return null;
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
        await _writeTo(hiveStore, scope, entry);
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
