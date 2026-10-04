import 'package:flutter/foundation.dart';

import 'drift_master_field_read_cache_store.dart';
import 'master_field_cache_database.dart';
import 'master_field_read_cache.dart';

/// Lazily owns the optional Drift database for the app process.
///
/// The default Hive-only build never creates or opens a SQLite file. Any
/// initialization failure is fail-open: the router remains configured and
/// transparently falls back to Hive.
class MasterFieldCacheRuntime {
  MasterFieldCacheRuntime._();

  static DriftMasterFieldReadCacheStore? _driftStore;

  static bool get isDriftOpen => _driftStore?.isAvailable ?? false;

  static Future<void> initialize() async {
    final flags = MasterFieldCacheFeatureFlags.fromEnvironment();
    if (!flags.requestsDrift) {
      MasterFieldReadCache.configure(flags: flags);
      return;
    }

    if (kIsWeb) {
      debugPrint(
        'Drift master-field cache is not enabled for web in Stage 3; '
        'falling back to Hive.',
      );
      MasterFieldReadCache.configure(flags: flags);
      return;
    }

    final existingStore = _driftStore;
    if (existingStore != null && existingStore.isAvailable) {
      MasterFieldReadCache.configure(flags: flags, driftStore: existingStore);
      return;
    }

    MasterFieldCacheDatabase? database;
    try {
      database = MasterFieldCacheDatabase.defaults();
      await database.customSelect('SELECT 1').getSingle();
      final store = DriftMasterFieldReadCacheStore(database);
      _driftStore = store;
      MasterFieldReadCache.configure(flags: flags, driftStore: store);
    } catch (error) {
      await database?.close();
      _driftStore = null;
      MasterFieldReadCache.configure(flags: flags);
      debugPrint(
        'Drift master-field cache initialization failed; falling back to '
        'Hive: $error',
      );
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
