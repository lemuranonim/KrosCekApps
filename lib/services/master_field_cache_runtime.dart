import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'drift_master_field_read_cache_store.dart';
import 'hive_master_field_read_cache_store.dart';
import 'master_field_cache_database.dart';
import 'master_field_read_cache.dart';

/// Lazily owns the optional Drift database for the app process.
///
/// The default Hive-only build never creates or opens a SQLite file. Any
/// initialization failure is fail-open: the router restores the Hive safety
/// path for the process, including when a retirement build cannot open Drift.
class MasterFieldCacheRuntime {
  MasterFieldCacheRuntime._();

  static DriftMasterFieldReadCacheStore? _driftStore;

  static bool get isDriftOpen => _driftStore?.isAvailable ?? false;

  /// Opens the legacy box unless every managed family has explicitly
  /// graduated to Drift and opted into Hive retirement.
  static Future<void> prepareLegacyHiveStore(
    MasterFieldCacheFeatureFlags flags,
  ) async {
    if (flags.finalizesHiveRetirement) return;
    if (!Hive.isBoxOpen(HiveMasterFieldReadCacheStore.boxName)) {
      await Hive.openBox<dynamic>(HiveMasterFieldReadCacheStore.boxName);
    }
  }

  static Future<void> initialize({MasterFieldCacheFeatureFlags? flags}) async {
    final effectiveFlags =
        flags ?? MasterFieldCacheFeatureFlags.fromEnvironment();
    final ignoredRetirements = effectiveFlags.ignoredHiveRetirementFamilies;
    if (ignoredRetirements.isNotEmpty) {
      debugPrint(
        'Ignoring Hive retirement without an explicit full-Drift backend for: '
        '${ignoredRetirements.map((family) => family.name).join(', ')}.',
      );
    }
    if (!effectiveFlags.requestsDrift) {
      MasterFieldReadCache.configure(flags: effectiveFlags);
      return;
    }

    if (kIsWeb) {
      debugPrint(
        'Drift master-field cache is not enabled for web; '
        'falling back to Hive.',
      );
      final fallbackFlags = await _restoreHiveFallback(effectiveFlags);
      MasterFieldReadCache.configure(flags: fallbackFlags);
      return;
    }

    final existingStore = _driftStore;
    if (existingStore != null && existingStore.isAvailable) {
      MasterFieldReadCache.configure(
        flags: effectiveFlags,
        driftStore: existingStore,
      );
      return;
    }

    MasterFieldCacheDatabase? database;
    try {
      database = MasterFieldCacheDatabase.defaults();
      await database.customSelect('SELECT 1').getSingle();
      final store = DriftMasterFieldReadCacheStore(database);
      _driftStore = store;
      MasterFieldReadCache.configure(flags: effectiveFlags, driftStore: store);
    } catch (error) {
      await database?.close();
      _driftStore = null;
      final fallbackFlags = await _restoreHiveFallback(effectiveFlags);
      MasterFieldReadCache.configure(flags: fallbackFlags);
      debugPrint(
        'Drift master-field cache initialization failed; falling back to '
        'Hive: $error',
      );
    }
  }

  static Future<MasterFieldCacheFeatureFlags> _restoreHiveFallback(
    MasterFieldCacheFeatureFlags flags,
  ) async {
    if (flags.hiveRetiredFamilies.isEmpty) return flags;
    final fallbackFlags = flags.withoutHiveRetirement();
    try {
      await prepareLegacyHiveStore(fallbackFlags);
    } catch (error) {
      debugPrint('Emergency Hive fallback could not be opened: $error');
    }
    return fallbackFlags;
  }

  /// Deletes the disposable legacy box only after the full retirement gate is
  /// satisfied and the replacement Drift database opened successfully.
  static Future<bool> finalizeLegacyHiveStore(
    MasterFieldCacheFeatureFlags flags, {
    bool? driftAvailable,
  }) async {
    if (!flags.finalizesHiveRetirement || !(driftAvailable ?? isDriftOpen)) {
      return false;
    }
    try {
      await Hive.deleteBoxFromDisk(HiveMasterFieldReadCacheStore.boxName);
      return true;
    } catch (error) {
      debugPrint('Legacy master-field Hive cleanup skipped: $error');
      return false;
    }
  }

  @visibleForTesting
  static Future<void> close() async {
    final store = _driftStore;
    _driftStore = null;
    await store?.close();
    MasterFieldReadCache.configure();
  }
}
