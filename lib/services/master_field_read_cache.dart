import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'hive_master_field_read_cache_store.dart';
import 'master_field_cache_canary.dart';
import 'master_field_read_cache_contract.dart';

export 'master_field_read_cache_contract.dart';

/// Stable facade for the expensive Map/Coverage/Planning local read cache.
///
/// Hive remains the default store while the Stage 5 Map rollout can promote a
/// deterministic account cohort to Drift. Redis remains the shared server
/// cache, and a local miss or failure still falls through to the existing
/// network path.
class MasterFieldReadCache {
  MasterFieldReadCache._();

  static const boxName = HiveMasterFieldReadCacheStore.boxName;

  static final HiveMasterFieldReadCacheStore _hiveStore =
      HiveMasterFieldReadCacheStore();
  static final MasterFieldCacheCanaryMonitor _canaryMonitor =
      MasterFieldCacheCanaryMonitor();
  static final MasterFieldCacheRolloutMonitor _rolloutMonitor =
      MasterFieldCacheRolloutMonitor();

  static MasterFieldReadCacheRouter _router = _buildRouter();

  static bool get isAvailable => _hiveStore.isAvailable;

  static MasterFieldCacheFeatureFlags get featureFlags => _router.flags;

  static MasterFieldCacheCanarySnapshot get canarySnapshot =>
      _canaryMonitor.snapshot;

  static MasterFieldCacheRolloutSnapshot get rolloutSnapshot =>
      _rolloutMonitor.snapshot;

  /// Registers the future Drift store and/or an explicit rollout policy.
  ///
  /// Calling this is optional. Without it, compile-time flags are read and
  /// Hive remains the default backend. Until a Drift store is registered, a
  /// requested Drift route safely falls back to Hive.
  static void configure({
    MasterFieldCacheFeatureFlags? flags,
    MasterFieldReadCacheStore? driftStore,
  }) {
    _router = _buildRouter(flags: flags, driftStore: driftStore);
  }

  static String key({
    required String userId,
    required String dataset,
    String? season,
    String? region,
    String? district,
  }) => MasterFieldCacheScope(
    userId: userId,
    dataset: dataset,
    season: season,
    region: region,
    district: district,
  ).storageKey;

  static Future<MasterFieldReadCacheEntry?> read({
    required String userId,
    required String dataset,
    String? season,
    String? region,
    String? district,
  }) => _router.read(
    MasterFieldCacheScope(
      userId: userId,
      dataset: dataset,
      season: season,
      region: region,
      district: district,
    ),
  );

  static Future<void> write({
    required String userId,
    required String dataset,
    required int version,
    required List<Map<String, dynamic>> rows,
    String? season,
    String? region,
    String? district,
  }) => _router.write(
    MasterFieldCacheScope(
      userId: userId,
      dataset: dataset,
      season: season,
      region: region,
      district: district,
    ),
    MasterFieldReadCacheEntry(
      version: version,
      savedAt: DateTime.now(),
      rows: rows,
    ),
  );

  static Future<void> clearUser(String userId) => _router.clearUser(userId);

  @visibleForTesting
  static void resetConfiguration() {
    _canaryMonitor.reset();
    _rolloutMonitor.reset();
    _router = _buildRouter();
  }

  static MasterFieldReadCacheRouter _buildRouter({
    MasterFieldCacheFeatureFlags? flags,
    MasterFieldReadCacheStore? driftStore,
  }) => MasterFieldReadCacheRouter(
    flags: flags ?? MasterFieldCacheFeatureFlags.fromEnvironment(),
    hiveStore: _hiveStore,
    driftStore: driftStore,
    log: (message, error, _) => debugPrint('$message: $error'),
    canaryRowsEqual: compareMasterFieldCacheRows,
    canaryReporter: (event) {
      _canaryMonitor.record(event);
      if (!event.outcome.isHealthy) {
        debugPrint('Master-field cache canary: ${jsonEncode(event.toJson())}');
      }
    },
    rolloutReporter: (event) {
      _rolloutMonitor.record(event);
      if (event.outcome.isDriftFailure ||
          event.outcome == MasterFieldCacheRolloutOutcome.circuitOpened) {
        debugPrint('Master-field cache rollout: ${jsonEncode(event.toJson())}');
      }
    },
  );
}
