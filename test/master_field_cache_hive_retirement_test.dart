import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kroscek/services/hive_master_field_read_cache_store.dart';
import 'package:kroscek/services/master_field_cache_runtime.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  const mapScope = MasterFieldCacheScope(
    userId: 'user-a',
    dataset: 'map:fi:baseline',
    season: 'DS26',
    region: 'Region 5',
  );
  const coverageScope = MasterFieldCacheScope(
    userId: 'user-a',
    dataset: 'coverage:all',
    season: 'DS26',
    region: 'Region 5',
  );

  MasterFieldReadCacheEntry entry(int version) => MasterFieldReadCacheEntry(
    version: version,
    savedAt: DateTime.utc(2026, 10, 4, 12, 0, version.clamp(0, 59)),
    rows: [
      {'field_number': 'FN-$version'},
    ],
  );

  test('Hive retirement defaults off', () {
    const flags = MasterFieldCacheFeatureFlags();

    expect(flags.hiveRetiredFamilies, isEmpty);
    expect(flags.ignoredHiveRetirementFamilies, isEmpty);
    expect(flags.isHiveRetiredForScope(mapScope), isFalse);
    expect(flags.finalizesHiveRetirement, isFalse);
  });

  test('percentage rollout cannot retire its Hive safety path', () {
    const flags = MasterFieldCacheFeatureFlags(
      mapDriftRolloutPercent: 100,
      hiveRetiredFamilies: {MasterFieldCacheDatasetFamily.map},
    );

    expect(flags.backendForScope(mapScope), MasterFieldCacheBackend.drift);
    expect(flags.isDriftRolloutScope(mapScope), isTrue);
    expect(flags.isHiveRetiredForScope(mapScope), isFalse);
    expect(flags.ignoredHiveRetirementFamilies, {
      MasterFieldCacheDatasetFamily.map,
    });
    expect(flags.shouldDualWriteHive(mapScope), isTrue);
  });

  test('retirement requires the explicit full-Drift family backend', () {
    const flags = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.drift,
      dualWriteHiveWhenDrift: true,
      hiveRetiredFamilies: {MasterFieldCacheDatasetFamily.map},
    );

    expect(flags.isHiveRetiredForScope(mapScope), isTrue);
    expect(flags.ignoredHiveRetirementFamilies, isEmpty);
    expect(flags.shouldDualWriteHive(mapScope), isFalse);
    expect(flags.finalizesHiveRetirement, isFalse);
  });

  test('legacy box cleanup requires retirement of all managed families', () {
    const partial = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.drift,
      coverageBackend: MasterFieldCacheBackend.drift,
      planningBackend: MasterFieldCacheBackend.drift,
      hiveRetiredFamilies: {
        MasterFieldCacheDatasetFamily.map,
        MasterFieldCacheDatasetFamily.coverage,
      },
    );
    const complete = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.drift,
      coverageBackend: MasterFieldCacheBackend.drift,
      planningBackend: MasterFieldCacheBackend.drift,
      hiveRetiredFamilies: MasterFieldCacheFeatureFlags.managedFamilies,
    );

    expect(partial.finalizesHiveRetirement, isFalse);
    expect(complete.finalizesHiveRetirement, isTrue);
  });

  test('emergency rollback preserves configuration except retirement', () {
    const flags = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.drift,
      coverageBackend: MasterFieldCacheBackend.hive,
      planningBackend: MasterFieldCacheBackend.disabled,
      dualWriteHiveWhenDrift: true,
      driftShadowFamilies: {MasterFieldCacheDatasetFamily.coverage},
      driftShadowSamplePercent: 25,
      coverageDriftRolloutPercent: 10,
      hiveRetiredFamilies: {MasterFieldCacheDatasetFamily.map},
    );

    final rollback = flags.withoutHiveRetirement();

    expect(rollback.hiveRetiredFamilies, isEmpty);
    expect(rollback.mapBackend, flags.mapBackend);
    expect(rollback.coverageBackend, flags.coverageBackend);
    expect(rollback.planningBackend, flags.planningBackend);
    expect(rollback.dualWriteHiveWhenDrift, isTrue);
    expect(rollback.driftShadowFamilies, flags.driftShadowFamilies);
    expect(rollback.effectiveDriftShadowSamplePercent, 25);
    expect(rollback.effectiveCoverageDriftRolloutPercent, 10);
    expect(rollback.shouldDualWriteHive(mapScope), isTrue);
  });

  test('retired Drift miss bypasses an existing Hive snapshot', () async {
    final hive = _RetirementStore(MasterFieldCacheBackend.hive);
    final drift = _RetirementStore(MasterFieldCacheBackend.drift);
    hive.entries[mapScope.storageKey] = entry(1);
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _retiredMapRouter(hive, drift, events.add);

    expect(await router.read(mapScope), isNull);

    expect(drift.readCount, 1);
    expect(hive.readCount, 0);
    expect(
      events.map((event) => event.outcome),
      containsAll([
        MasterFieldCacheRolloutOutcome.driftReadMiss,
        MasterFieldCacheRolloutOutcome.hiveRetirementBypass,
        MasterFieldCacheRolloutOutcome.fullCacheMiss,
      ]),
    );
  });

  test('retired Drift failure falls through without reading Hive', () async {
    final hive = _RetirementStore(MasterFieldCacheBackend.hive);
    final drift = _RetirementStore(MasterFieldCacheBackend.drift)
      ..failNextReads = 1;
    hive.entries[mapScope.storageKey] = entry(2);
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _retiredMapRouter(hive, drift, events.add);

    expect(await router.read(mapScope), isNull);

    expect(hive.readCount, 0);
    expect(
      events.map((event) => event.outcome),
      containsAll([
        MasterFieldCacheRolloutOutcome.driftReadFailed,
        MasterFieldCacheRolloutOutcome.hiveRetirementBypass,
      ]),
    );
  });

  test(
    'retired family never dual-writes or fails over writes to Hive',
    () async {
      final hive = _RetirementStore(MasterFieldCacheBackend.hive);
      final drift = _RetirementStore(MasterFieldCacheBackend.drift);
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _retiredMapRouter(hive, drift, events.add);

      await router.write(mapScope, entry(3));
      drift.failNextWrites = 1;
      await router.write(mapScope, entry(4));

      expect(drift.writeCount, 2);
      expect(hive.writeCount, 0);
      expect(drift.entries[mapScope.storageKey]?.version, 3);
      expect(
        events.map((event) => event.outcome),
        containsAll([
          MasterFieldCacheRolloutOutcome.driftWriteSucceeded,
          MasterFieldCacheRolloutOutcome.driftWriteFailed,
          MasterFieldCacheRolloutOutcome.hiveRetirementBypass,
        ]),
      );
    },
  );

  test('retirement remains isolated from a non-retired family', () async {
    final hive = _RetirementStore(MasterFieldCacheBackend.hive);
    final drift = _RetirementStore(MasterFieldCacheBackend.drift);
    hive.entries[mapScope.storageKey] = entry(5);
    hive.entries[coverageScope.storageKey] = entry(6);
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(
        mapBackend: MasterFieldCacheBackend.drift,
        coverageBackend: MasterFieldCacheBackend.drift,
        hiveRetiredFamilies: {MasterFieldCacheDatasetFamily.map},
      ),
      hiveStore: hive,
      driftStore: drift,
    );

    expect(await router.read(mapScope), isNull);
    expect((await router.read(coverageScope))?.version, 6);

    expect(hive.readCount, 1);
  });

  test('open retired-family circuit never restores Hive traffic', () async {
    final hive = _RetirementStore(MasterFieldCacheBackend.hive);
    final drift = _RetirementStore(MasterFieldCacheBackend.drift)
      ..failNextReads = 3;
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _retiredMapRouter(hive, drift, events.add);

    for (var index = 0; index < 4; index++) {
      final scope = MasterFieldCacheScope(
        userId: 'user-$index',
        dataset: 'map:fi:baseline',
      );
      hive.entries[scope.storageKey] = entry(index);
      expect(await router.read(scope), isNull);
    }

    expect(drift.readCount, 3);
    expect(hive.readCount, 0);
    expect(
      events.map((event) => event.outcome),
      containsAll([
        MasterFieldCacheRolloutOutcome.circuitOpened,
        MasterFieldCacheRolloutOutcome.circuitBypass,
        MasterFieldCacheRolloutOutcome.hiveRetirementBypass,
      ]),
    );
  });

  test('legacy Hive box is deleted only after Drift is available', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kroscek-hive-retirement-',
    );
    Hive.init(directory.path);
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    final box = await Hive.openBox<dynamic>(
      HiveMasterFieldReadCacheStore.boxName,
    );
    await box.put('legacy-key', 'legacy-value');
    await box.close();
    const flags = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.drift,
      coverageBackend: MasterFieldCacheBackend.drift,
      planningBackend: MasterFieldCacheBackend.drift,
      hiveRetiredFamilies: MasterFieldCacheFeatureFlags.managedFamilies,
    );

    await MasterFieldCacheRuntime.prepareLegacyHiveStore(flags);
    expect(Hive.isBoxOpen(HiveMasterFieldReadCacheStore.boxName), isFalse);
    expect(await Hive.boxExists(HiveMasterFieldReadCacheStore.boxName), isTrue);
    expect(
      await MasterFieldCacheRuntime.finalizeLegacyHiveStore(
        flags,
        driftAvailable: false,
      ),
      isFalse,
    );
    expect(await Hive.boxExists(HiveMasterFieldReadCacheStore.boxName), isTrue);

    expect(
      await MasterFieldCacheRuntime.finalizeLegacyHiveStore(
        flags,
        driftAvailable: true,
      ),
      isTrue,
    );
    expect(
      await Hive.boxExists(HiveMasterFieldReadCacheStore.boxName),
      isFalse,
    );

    await MasterFieldCacheRuntime.prepareLegacyHiveStore(
      const MasterFieldCacheFeatureFlags(),
    );
    expect(Hive.isBoxOpen(HiveMasterFieldReadCacheStore.boxName), isTrue);
    expect(
      Hive.box<dynamic>(HiveMasterFieldReadCacheStore.boxName).isEmpty,
      isTrue,
    );
  });
}

MasterFieldReadCacheRouter _retiredMapRouter(
  _RetirementStore hive,
  _RetirementStore drift,
  MasterFieldCacheRolloutReporter reporter,
) => MasterFieldReadCacheRouter(
  flags: const MasterFieldCacheFeatureFlags(
    mapBackend: MasterFieldCacheBackend.drift,
    dualWriteHiveWhenDrift: true,
    hiveRetiredFamilies: {MasterFieldCacheDatasetFamily.map},
  ),
  hiveStore: hive,
  driftStore: drift,
  rolloutReporter: reporter,
);

class _RetirementStore implements MasterFieldReadCacheStore {
  @override
  final MasterFieldCacheBackend backend;

  @override
  bool isAvailable;

  int failNextReads = 0;
  int failNextWrites = 0;
  int readCount = 0;
  int writeCount = 0;
  final Map<String, MasterFieldReadCacheEntry> entries = {};

  _RetirementStore(this.backend) : isAvailable = true;

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    readCount++;
    if (failNextReads > 0) {
      failNextReads--;
      throw StateError('synthetic retirement read failure');
    }
    return entries[scope.storageKey];
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    writeCount++;
    if (failNextWrites > 0) {
      failNextWrites--;
      throw StateError('synthetic retirement write failure');
    }
    entries[scope.storageKey] = entry;
  }

  @override
  Future<void> clearUser(String userId) async {
    entries.removeWhere(
      (key, _) => key.startsWith('${MasterFieldCacheScope.keyPrefix}:$userId:'),
    );
  }
}
