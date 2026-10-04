import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  MasterFieldCacheScope scope(
    String userId,
    String dataset, {
    String? region = 'Region 5',
  }) => MasterFieldCacheScope(
    userId: userId,
    dataset: dataset,
    season: 'DS26',
    region: region,
  );

  MasterFieldReadCacheEntry entry(int version) => MasterFieldReadCacheEntry(
    version: version,
    savedAt: DateTime.utc(2026, 10, 4, 12, 0, version.clamp(0, 59)),
    rows: [
      {'field_number': 'FN-$version', 'area': version},
    ],
  );

  test('all family rollout flags default off and clamp safely', () {
    const defaults = MasterFieldCacheFeatureFlags();
    const flags = MasterFieldCacheFeatureFlags(
      coverageDriftRolloutPercent: 150,
      planningDriftRolloutPercent: -20,
    );

    expect(defaults.effectiveMapDriftRolloutPercent, 0);
    expect(defaults.effectiveCoverageDriftRolloutPercent, 0);
    expect(defaults.effectivePlanningDriftRolloutPercent, 0);
    expect(defaults.requestsDrift, isFalse);
    expect(flags.effectiveCoverageDriftRolloutPercent, 100);
    expect(flags.effectivePlanningDriftRolloutPercent, 0);
    expect(flags.requestsDrift, isTrue);
  });

  test('Coverage and Planning percentages route independently', () {
    const coverageOnly = MasterFieldCacheFeatureFlags(
      coverageDriftRolloutPercent: 100,
    );
    const planningOnly = MasterFieldCacheFeatureFlags(
      planningDriftRolloutPercent: 100,
    );
    final coverage = scope('user-a', 'coverage:all');
    final coverageRegions = scope('user-a', 'coverage-regions:all');
    final planning = scope('user-a', 'planning_index:all');
    final map = scope('user-a', 'map:fi:baseline');

    expect(
      coverageOnly.backendForScope(coverage),
      MasterFieldCacheBackend.drift,
    );
    expect(
      coverageOnly.backendForScope(coverageRegions),
      MasterFieldCacheBackend.drift,
    );
    expect(
      coverageOnly.backendForScope(planning),
      MasterFieldCacheBackend.hive,
    );
    expect(coverageOnly.backendForScope(map), MasterFieldCacheBackend.hive);
    expect(
      planningOnly.backendForScope(planning),
      MasterFieldCacheBackend.drift,
    );
    expect(
      planningOnly.backendForScope(coverage),
      MasterFieldCacheBackend.hive,
    );
    expect(planningOnly.backendForScope(map), MasterFieldCacheBackend.hive);
  });

  test('Coverage cohort is deterministic across its related datasets', () {
    const flags = MasterFieldCacheFeatureFlags(coverageDriftRolloutPercent: 50);
    var enrolled = 0;
    var excluded = 0;

    for (var index = 0; index < 100; index++) {
      final userId = 'coverage-user-$index';
      final coverage = flags.backendForScope(scope(userId, 'coverage:all'));
      final regions = flags.backendForScope(
        scope(userId, 'coverage-regions:all', region: 'Region ${index % 8}'),
      );
      expect(regions, coverage);
      if (coverage == MasterFieldCacheBackend.drift) {
        enrolled++;
      } else {
        excluded++;
      }
    }

    expect(enrolled, greaterThan(0));
    expect(excluded, greaterThan(0));
  });

  test('explicit Coverage and Planning backends remain authoritative', () {
    const flags = MasterFieldCacheFeatureFlags(
      coverageBackend: MasterFieldCacheBackend.disabled,
      planningBackend: MasterFieldCacheBackend.drift,
      coverageDriftRolloutPercent: 100,
      planningDriftRolloutPercent: 25,
    );
    final coverage = scope('user-a', 'coverage:all');
    final planning = scope('user-a', 'planning_index:all');

    expect(flags.backendForScope(coverage), MasterFieldCacheBackend.disabled);
    expect(flags.isDriftRolloutScope(coverage), isFalse);
    expect(flags.backendForScope(planning), MasterFieldCacheBackend.drift);
    expect(flags.isDriftRolloutScope(planning), isFalse);
    expect(flags.shouldDualWriteHive(planning), isFalse);
  });

  test(
    'enrolled Coverage and Planning writes retain Hive rollback copies',
    () async {
      final hive = _MultiFamilyStore(MasterFieldCacheBackend.hive);
      final drift = _MultiFamilyStore(MasterFieldCacheBackend.drift);
      final router = _router(hive, drift);
      final coverage = scope('user-a', 'coverage:all');
      final planning = scope('user-a', 'planning_index:all');

      await router.write(coverage, entry(1));
      await router.write(planning, entry(2));

      expect(drift.entries[coverage.storageKey]?.version, 1);
      expect(hive.entries[coverage.storageKey]?.version, 1);
      expect(drift.entries[planning.storageKey]?.version, 2);
      expect(hive.entries[planning.storageKey]?.version, 2);
    },
  );

  for (final dataset in ['coverage:all', 'planning_index:all']) {
    test('$dataset miss falls back to Hive and repairs Drift', () async {
      final hive = _MultiFamilyStore(MasterFieldCacheBackend.hive);
      final drift = _MultiFamilyStore(MasterFieldCacheBackend.drift);
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _router(hive, drift, events.add);
      final cacheScope = scope('user-a', dataset);
      hive.entries[cacheScope.storageKey] = entry(3);

      final result = await router.read(cacheScope);
      await _waitFor(() => drift.entries[cacheScope.storageKey]?.version == 3);

      expect(result?.version, 3);
      expect(
        events.map((event) => event.outcome),
        containsAll([
          MasterFieldCacheRolloutOutcome.driftReadMiss,
          MasterFieldCacheRolloutOutcome.hiveFallbackHit,
          MasterFieldCacheRolloutOutcome.readRepairSucceeded,
        ]),
      );
    });
  }

  test(
    'Coverage circuit opening does not bypass healthy Planning Drift',
    () async {
      final hive = _MultiFamilyStore(MasterFieldCacheBackend.hive);
      final drift = _MultiFamilyStore(MasterFieldCacheBackend.drift)
        ..failNextReads = 3;
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _router(hive, drift, events.add);

      for (var index = 0; index < 3; index++) {
        await router.read(scope('coverage-user-$index', 'coverage:all'));
      }
      final planning = scope('planning-user', 'planning_index:all');
      drift.entries[planning.storageKey] = entry(4);

      expect((await router.read(planning))?.version, 4);
      expect(drift.readCount, 4);
      expect(
        events.where(
          (event) =>
              event.family == MasterFieldCacheDatasetFamily.coverage &&
              event.outcome == MasterFieldCacheRolloutOutcome.circuitOpened,
        ),
        hasLength(1),
      );
      expect(
        events.where(
          (event) =>
              event.family == MasterFieldCacheDatasetFamily.planning &&
              event.outcome == MasterFieldCacheRolloutOutcome.driftReadHit,
        ),
        hasLength(1),
      );
    },
  );

  test('enrolled families do not also run Stage 4 shadow reads', () async {
    final hive = _MultiFamilyStore(MasterFieldCacheBackend.hive);
    final drift = _MultiFamilyStore(MasterFieldCacheBackend.drift);
    final canaryEvents = <MasterFieldCacheCanaryEvent>[];
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(
        coverageDriftRolloutPercent: 100,
        planningDriftRolloutPercent: 100,
        driftShadowFamilies: {
          MasterFieldCacheDatasetFamily.coverage,
          MasterFieldCacheDatasetFamily.planning,
        },
        driftShadowSamplePercent: 100,
      ),
      hiveStore: hive,
      driftStore: drift,
      canaryReporter: canaryEvents.add,
    );
    final coverage = scope('user-a', 'coverage:all');
    final planning = scope('user-a', 'planning_index:all');
    drift.entries[coverage.storageKey] = entry(5);
    drift.entries[planning.storageKey] = entry(6);

    await router.read(coverage);
    await router.read(planning);
    await Future<void>.delayed(Duration.zero);

    expect(canaryEvents, isEmpty);
    expect(hive.readCount, 0);
    expect(drift.readCount, 2);
  });

  test('multi-family telemetry excludes account and scope identity', () async {
    final hive = _MultiFamilyStore(MasterFieldCacheBackend.hive);
    final drift = _MultiFamilyStore(MasterFieldCacheBackend.drift);
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _router(hive, drift, events.add);
    final planning = scope(
      'private-account-id',
      'planning_index:private employee',
      region: 'private-region',
    );
    drift.entries[planning.storageKey] = entry(7);

    await router.read(planning);

    final encoded = jsonEncode(events.single.toJson());
    expect(events.single.family, MasterFieldCacheDatasetFamily.planning);
    expect(events.single.dataset, 'planning_index');
    expect(encoded, isNot(contains('private-account-id')));
    expect(encoded, isNot(contains('private employee')));
    expect(encoded, isNot(contains('private-region')));
    expect(encoded, isNot(contains('FN-7')));
  });
}

MasterFieldReadCacheRouter _router(
  _MultiFamilyStore hive,
  _MultiFamilyStore drift, [
  MasterFieldCacheRolloutReporter? reporter,
]) => MasterFieldReadCacheRouter(
  flags: const MasterFieldCacheFeatureFlags(
    coverageDriftRolloutPercent: 100,
    planningDriftRolloutPercent: 100,
  ),
  hiveStore: hive,
  driftStore: drift,
  rolloutReporter: reporter,
);

class _MultiFamilyStore implements MasterFieldReadCacheStore {
  @override
  final MasterFieldCacheBackend backend;

  @override
  bool isAvailable;

  int failNextReads = 0;
  int readCount = 0;
  final Map<String, MasterFieldReadCacheEntry> entries = {};

  _MultiFamilyStore(this.backend) : isAvailable = true;

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    readCount++;
    if (failNextReads > 0) {
      failNextReads--;
      throw StateError('synthetic multi-family rollout read failure');
    }
    return entries[scope.storageKey];
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    entries[scope.storageKey] = entry;
  }

  @override
  Future<void> clearUser(String userId) async {
    entries.removeWhere(
      (key, _) => key.startsWith('${MasterFieldCacheScope.keyPrefix}:$userId:'),
    );
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}
