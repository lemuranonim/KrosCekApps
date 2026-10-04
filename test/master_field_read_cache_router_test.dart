import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  const mapScope = MasterFieldCacheScope(
    userId: 'user-a',
    dataset: 'map:fi:baseline',
    season: 'DS26',
    region: 'Region 5',
  );

  MasterFieldReadCacheEntry entry(int version) => MasterFieldReadCacheEntry(
    version: version,
    savedAt: DateTime.utc(2026, 10, 4),
    rows: [
      {'field_number': 'FN-$version'},
    ],
  );

  test('cache scope keeps the existing Hive v2 key byte-compatible', () {
    const compatibilityScope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'map',
      season: 'DS26',
      region: 'Region 5',
      district: 'Blitar',
    );
    expect(
      compatibilityScope.storageKey,
      'mf-read-v2:user-a:'
      'eyJkYXRh'
      'c2V0IjoibWFwIiwic2Vhc29uIjoiRFMyNiIsInJlZ2lvbiI6IlJlZ2lvbiA1IiwiZGlzdHJpY3QiOiJCbGl0YXIifQ==',
    );
  });

  test('feature flags route role-scoped datasets independently', () {
    const flags = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.disabled,
      coverageBackend: MasterFieldCacheBackend.drift,
      planningBackend: MasterFieldCacheBackend.hive,
    );

    expect(
      flags.backendForDataset('map:fi:qa baseline'),
      MasterFieldCacheBackend.disabled,
    );
    expect(
      flags.backendForDataset('coverage:spv:qa baseline'),
      MasterFieldCacheBackend.drift,
    );
    expect(
      flags.backendForDataset('coverage-regions:all'),
      MasterFieldCacheBackend.drift,
    );
    expect(
      flags.backendForDataset('planning_index:all'),
      MasterFieldCacheBackend.hive,
    );
    expect(
      flags.backendForDataset('future-dataset'),
      MasterFieldCacheBackend.hive,
    );
    expect(flags.requestsDrift, isTrue);
    expect(const MasterFieldCacheFeatureFlags().requestsDrift, isFalse);
    expect(
      const MasterFieldCacheFeatureFlags(
        enabled: false,
        mapBackend: MasterFieldCacheBackend.drift,
      ).requestsDrift,
      isFalse,
    );
  });

  test('global kill switch disables reads and writes', () async {
    final hive = _MemoryStore(MasterFieldCacheBackend.hive);
    final drift = _MemoryStore(MasterFieldCacheBackend.drift);
    hive.entries[mapScope.storageKey] = entry(1);
    drift.entries[mapScope.storageKey] = entry(2);
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(enabled: false),
      hiveStore: hive,
      driftStore: drift,
    );

    expect(await router.read(mapScope), isNull);
    await router.write(mapScope, entry(3));

    expect(hive.writeCount, 0);
    expect(drift.writeCount, 0);
  });

  test(
    'logout clearing reaches every registered backend even when disabled',
    () async {
      final hive = _MemoryStore(MasterFieldCacheBackend.hive);
      final drift = _MemoryStore(MasterFieldCacheBackend.drift);
      final router = MasterFieldReadCacheRouter(
        flags: const MasterFieldCacheFeatureFlags(enabled: false),
        hiveStore: hive,
        driftStore: drift,
      );

      await router.clearUser('user-a');

      expect(hive.clearedUsers, ['user-a']);
      expect(drift.clearedUsers, ['user-a']);
    },
  );

  test(
    'requested Drift falls back to Hive when Drift is unavailable',
    () async {
      final hive = _MemoryStore(MasterFieldCacheBackend.hive);
      final drift = _MemoryStore(
        MasterFieldCacheBackend.drift,
        isAvailable: false,
      );
      hive.entries[mapScope.storageKey] = entry(7);
      final router = MasterFieldReadCacheRouter(
        flags: const MasterFieldCacheFeatureFlags(
          mapBackend: MasterFieldCacheBackend.drift,
        ),
        hiveStore: hive,
        driftStore: drift,
      );

      expect((await router.read(mapScope))?.version, 7);
      await router.write(mapScope, entry(8));
      expect(hive.entries[mapScope.storageKey]?.version, 8);
    },
  );

  test('Drift miss and failure fail over to Hive', () async {
    final hive = _MemoryStore(MasterFieldCacheBackend.hive);
    final drift = _MemoryStore(MasterFieldCacheBackend.drift)
      ..throwOnRead = true
      ..throwOnWrite = true;
    hive.entries[mapScope.storageKey] = entry(10);
    final messages = <String>[];
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(
        mapBackend: MasterFieldCacheBackend.drift,
      ),
      hiveStore: hive,
      driftStore: drift,
      log: (message, _, _) => messages.add(message),
    );

    expect((await router.read(mapScope))?.version, 10);
    await router.write(mapScope, entry(11));

    expect(hive.entries[mapScope.storageKey]?.version, 11);
    expect(messages, hasLength(2));
  });

  test('Drift is primary without changing unrelated datasets', () async {
    final hive = _MemoryStore(MasterFieldCacheBackend.hive);
    final drift = _MemoryStore(MasterFieldCacheBackend.drift);
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(
        mapBackend: MasterFieldCacheBackend.drift,
      ),
      hiveStore: hive,
      driftStore: drift,
    );
    const coverageScope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'coverage:all',
      region: 'Region 5',
    );

    await router.write(mapScope, entry(20));
    await router.write(coverageScope, entry(21));

    expect(drift.entries[mapScope.storageKey]?.version, 20);
    expect(hive.entries[mapScope.storageKey], isNull);
    expect(hive.entries[coverageScope.storageKey]?.version, 21);
    expect(drift.entries[coverageScope.storageKey], isNull);
  });

  test(
    'dual-write keeps Hive rollback snapshot while Drift is primary',
    () async {
      final hive = _MemoryStore(MasterFieldCacheBackend.hive);
      final drift = _MemoryStore(MasterFieldCacheBackend.drift);
      final router = MasterFieldReadCacheRouter(
        flags: const MasterFieldCacheFeatureFlags(
          mapBackend: MasterFieldCacheBackend.drift,
          dualWriteHiveWhenDrift: true,
        ),
        hiveStore: hive,
        driftStore: drift,
      );

      await router.write(mapScope, entry(30));

      expect(drift.entries[mapScope.storageKey]?.version, 30);
      expect(hive.entries[mapScope.storageKey]?.version, 30);
    },
  );

  test('invalid identity and version are ignored', () async {
    final hive = _MemoryStore(MasterFieldCacheBackend.hive);
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(),
      hiveStore: hive,
    );
    const invalidScope = MasterFieldCacheScope(userId: ' ', dataset: 'map');

    expect(await router.read(invalidScope), isNull);
    await router.write(mapScope, entry(-1));

    expect(hive.readCount, 0);
    expect(hive.writeCount, 0);
  });
}

class _MemoryStore implements MasterFieldReadCacheStore {
  @override
  final MasterFieldCacheBackend backend;

  @override
  bool isAvailable;

  bool throwOnRead = false;
  bool throwOnWrite = false;
  int readCount = 0;
  int writeCount = 0;
  final Map<String, MasterFieldReadCacheEntry> entries = {};
  final List<String> clearedUsers = [];

  _MemoryStore(this.backend, {this.isAvailable = true});

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    readCount++;
    if (throwOnRead) throw StateError('synthetic read failure');
    return entries[scope.storageKey];
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    writeCount++;
    if (throwOnWrite) throw StateError('synthetic write failure');
    entries[scope.storageKey] = entry;
  }

  @override
  Future<void> clearUser(String userId) async {
    clearedUsers.add(userId);
    entries.removeWhere((key, _) {
      return key.startsWith('${MasterFieldCacheScope.keyPrefix}:$userId:');
    });
  }
}
