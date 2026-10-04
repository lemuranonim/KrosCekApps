import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  MasterFieldCacheScope mapScope(
    String userId, {
    String dataset = 'map:fi:qa user',
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

  test('Map rollout defaults off and clamps percentages safely', () {
    const defaults = MasterFieldCacheFeatureFlags();
    const belowZero = MasterFieldCacheFeatureFlags(mapDriftRolloutPercent: -10);
    const aboveHundred = MasterFieldCacheFeatureFlags(
      mapDriftRolloutPercent: 150,
    );
    final scope = mapScope('user-a');

    expect(defaults.requestsDrift, isFalse);
    expect(defaults.backendForScope(scope), MasterFieldCacheBackend.hive);
    expect(belowZero.effectiveMapDriftRolloutPercent, 0);
    expect(belowZero.backendForScope(scope), MasterFieldCacheBackend.hive);
    expect(aboveHundred.effectiveMapDriftRolloutPercent, 100);
    expect(aboveHundred.requestsDrift, isTrue);
    expect(aboveHundred.backendForScope(scope), MasterFieldCacheBackend.drift);
  });

  test('rollout cohort is deterministic and account-sticky', () {
    const flags = MasterFieldCacheFeatureFlags(mapDriftRolloutPercent: 50);
    var enrolled = 0;
    var excluded = 0;

    for (var index = 0; index < 100; index++) {
      final userId = 'user-$index';
      final baseline = mapScope(userId, dataset: 'map:fi:baseline');
      final filtered = mapScope(
        userId,
        dataset: 'map:fi:qa user',
        region: 'Region ${index % 8}',
      );
      final first = flags.backendForScope(baseline);
      final second = flags.backendForScope(filtered);
      expect(second, first);
      if (first == MasterFieldCacheBackend.drift) {
        enrolled++;
      } else {
        excluded++;
      }
    }

    expect(enrolled, greaterThan(0));
    expect(excluded, greaterThan(0));
  });

  test('Map rollout never changes Coverage, Planning, or other datasets', () {
    const flags = MasterFieldCacheFeatureFlags(mapDriftRolloutPercent: 100);

    expect(
      flags.backendForScope(
        const MasterFieldCacheScope(userId: 'user-a', dataset: 'coverage:all'),
      ),
      MasterFieldCacheBackend.hive,
    );
    expect(
      flags.backendForScope(
        const MasterFieldCacheScope(
          userId: 'user-a',
          dataset: 'planning_index:all',
        ),
      ),
      MasterFieldCacheBackend.hive,
    );
    expect(
      flags.backendForScope(
        const MasterFieldCacheScope(
          userId: 'user-a',
          dataset: 'future-dataset',
        ),
      ),
      MasterFieldCacheBackend.hive,
    );
  });

  test('explicit dataset backend remains authoritative over rollout', () {
    final scope = mapScope('user-a');
    const disabled = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.disabled,
      mapDriftRolloutPercent: 100,
    );
    const explicitDrift = MasterFieldCacheFeatureFlags(
      mapBackend: MasterFieldCacheBackend.drift,
      mapDriftRolloutPercent: 25,
    );

    expect(disabled.backendForScope(scope), MasterFieldCacheBackend.disabled);
    expect(explicitDrift.backendForScope(scope), MasterFieldCacheBackend.drift);
    expect(explicitDrift.isMapDriftRolloutScope(scope), isFalse);
    expect(explicitDrift.shouldDualWriteHive(scope), isFalse);
  });

  test('enrolled Map read uses Drift without touching Hive on a hit', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift);
    final scope = mapScope('user-a');
    drift.entries[scope.storageKey] = entry(1);
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _rolloutRouter(hive, drift, events.add);

    final result = await router.read(scope);

    expect(result?.version, 1);
    expect(drift.readCount, 1);
    expect(hive.readCount, 0);
    expect(
      events.map((event) => event.outcome),
      contains(MasterFieldCacheRolloutOutcome.driftReadHit),
    );
  });

  test('enrolled Map writes always retain a Hive rollback snapshot', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift);
    final scope = mapScope('user-a');
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _rolloutRouter(hive, drift, events.add);

    await router.write(scope, entry(2));

    expect(drift.entries[scope.storageKey]?.version, 2);
    expect(hive.entries[scope.storageKey]?.version, 2);
    expect(
      events.map((event) => event.outcome),
      contains(MasterFieldCacheRolloutOutcome.driftWriteSucceeded),
    );
  });

  test('zero-percent Map scope remains Hive-only', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift);
    final scope = mapScope('user-a');
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(mapDriftRolloutPercent: 0),
      hiveStore: hive,
      driftStore: drift,
    );

    await router.write(scope, entry(3));
    final result = await router.read(scope);

    expect(result?.version, 3);
    expect(hive.writeCount, 1);
    expect(hive.readCount, 1);
    expect(drift.writeCount, 0);
    expect(drift.readCount, 0);
  });

  test(
    'Drift miss falls back to Hive and repairs Drift asynchronously',
    () async {
      final hive = _RolloutStore(MasterFieldCacheBackend.hive);
      final drift = _RolloutStore(MasterFieldCacheBackend.drift);
      final scope = mapScope('user-a');
      hive.entries[scope.storageKey] = entry(4);
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _rolloutRouter(hive, drift, events.add);

      final result = await router.read(scope);
      await _waitFor(() => drift.entries[scope.storageKey]?.version == 4);

      expect(result?.version, 4);
      expect(
        events.map((event) => event.outcome),
        containsAll([
          MasterFieldCacheRolloutOutcome.driftReadMiss,
          MasterFieldCacheRolloutOutcome.hiveFallbackHit,
          MasterFieldCacheRolloutOutcome.readRepairSucceeded,
        ]),
      );
    },
  );

  test(
    'three consecutive Drift read failures open the family circuit',
    () async {
      final hive = _RolloutStore(MasterFieldCacheBackend.hive);
      final drift = _RolloutStore(MasterFieldCacheBackend.drift)
        ..failNextReads = 3;
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _rolloutRouter(hive, drift, events.add);

      for (var index = 0; index < 4; index++) {
        expect(await router.read(mapScope('user-$index')), isNull);
      }

      expect(drift.readCount, 3);
      expect(hive.readCount, 4);
      expect(
        events.where(
          (event) =>
              event.outcome == MasterFieldCacheRolloutOutcome.circuitOpened,
        ),
        hasLength(1),
      );
      expect(
        events.map((event) => event.outcome),
        contains(MasterFieldCacheRolloutOutcome.circuitBypass),
      );
    },
  );

  test(
    'a successful Drift read resets the consecutive failure counter',
    () async {
      final hive = _RolloutStore(MasterFieldCacheBackend.hive);
      final drift = _RolloutStore(MasterFieldCacheBackend.drift)
        ..failNextReads = 1;
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _rolloutRouter(hive, drift, events.add);
      final healthyScope = mapScope('healthy-user');
      drift.entries[healthyScope.storageKey] = entry(5);

      await router.read(mapScope('failed-before-success'));
      expect((await router.read(healthyScope))?.version, 5);
      drift.failNextReads = 2;
      await router.read(mapScope('failed-after-success-1'));
      await router.read(mapScope('failed-after-success-2'));

      expect(
        events.where(
          (event) =>
              event.outcome == MasterFieldCacheRolloutOutcome.circuitOpened,
        ),
        isEmpty,
      );
      expect(drift.readCount, 4);
    },
  );

  test('Drift write failures preserve Hive and open the circuit', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift)
      ..failNextWrites = 3;
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _rolloutRouter(hive, drift, events.add);

    for (var index = 1; index <= 4; index++) {
      await router.write(mapScope('user-$index'), entry(index));
    }

    expect(drift.writeCount, 3);
    expect(hive.writeCount, 4);
    expect(hive.entries[mapScope('user-4').storageKey]?.version, 4);
    expect(
      events.map((event) => event.outcome),
      containsAll([
        MasterFieldCacheRolloutOutcome.driftWriteFailed,
        MasterFieldCacheRolloutOutcome.circuitOpened,
        MasterFieldCacheRolloutOutcome.circuitBypass,
      ]),
    );
  });

  test('open-circuit Hive write failures remain observable', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift)
      ..failNextWrites = 3;
    final events = <MasterFieldCacheRolloutEvent>[];
    final router = _rolloutRouter(hive, drift, events.add);

    for (var index = 1; index <= 3; index++) {
      await router.write(mapScope('user-$index'), entry(index));
    }
    hive.failNextWrites = 1;
    await router.write(mapScope('user-after-circuit'), entry(4));

    expect(
      events.map((event) => event.outcome),
      contains(MasterFieldCacheRolloutOutcome.hiveRollbackWriteFailed),
    );
  });

  test(
    'unavailable Drift fails open to Hive and eventually bypasses it',
    () async {
      final hive = _RolloutStore(MasterFieldCacheBackend.hive);
      final drift = _RolloutStore(
        MasterFieldCacheBackend.drift,
        isAvailable: false,
      );
      final events = <MasterFieldCacheRolloutEvent>[];
      final router = _rolloutRouter(hive, drift, events.add);
      for (var index = 0; index < 4; index++) {
        final scope = mapScope('user-$index');
        hive.entries[scope.storageKey] = entry(index);
        expect((await router.read(scope))?.version, index);
      }

      expect(drift.readCount, 0);
      expect(
        events.where(
          (event) =>
              event.outcome == MasterFieldCacheRolloutOutcome.driftUnavailable,
        ),
        hasLength(3),
      );
      expect(
        events.last.outcome,
        MasterFieldCacheRolloutOutcome.hiveFallbackHit,
      );
    },
  );

  test('rollout primary scopes do not also run Stage 4 shadow reads', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift);
    final scope = mapScope('user-a');
    drift.entries[scope.storageKey] = entry(6);
    final canaryEvents = <MasterFieldCacheCanaryEvent>[];
    final router = MasterFieldReadCacheRouter(
      flags: const MasterFieldCacheFeatureFlags(
        mapDriftRolloutPercent: 100,
        driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
        driftShadowSamplePercent: 100,
      ),
      hiveStore: hive,
      driftStore: drift,
      canaryReporter: canaryEvents.add,
    );

    expect((await router.read(scope))?.version, 6);
    await Future<void>.delayed(Duration.zero);

    expect(canaryEvents, isEmpty);
    expect(hive.readCount, 0);
    expect(drift.readCount, 1);
  });

  test('overlapping rollout writes are serialized per cache key', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift);
    final gate = Completer<void>();
    drift.pendingWrite = gate;
    final scope = mapScope('user-a');
    final router = _rolloutRouter(hive, drift, (_) {});

    final first = router.write(scope, entry(7));
    await _waitFor(() => drift.writeCount == 1);
    final second = router.write(scope, entry(8));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(drift.writeCount, 1);
    gate.complete();
    await Future.wait([first, second]);

    expect(drift.startedVersions, [7, 8]);
    expect(drift.entries[scope.storageKey]?.version, 8);
    expect(hive.entries[scope.storageKey]?.version, 8);
  });

  test('rollout telemetry is aggregated without scope identity', () async {
    final hive = _RolloutStore(MasterFieldCacheBackend.hive);
    final drift = _RolloutStore(MasterFieldCacheBackend.drift);
    final scope = mapScope(
      'private-user-id',
      dataset: 'map:fi:private employee',
    );
    drift.entries[scope.storageKey] = entry(9);
    final monitor = MasterFieldCacheRolloutMonitor();
    final captured = <MasterFieldCacheRolloutEvent>[];
    final router = _rolloutRouter(hive, drift, (event) {
      monitor.record(event);
      captured.add(event);
    });

    await router.read(scope);

    final snapshot = monitor.snapshot;
    expect(snapshot.totalEvents, 1);
    expect(
      snapshot.driftReadHitRateForFamily(MasterFieldCacheDatasetFamily.map),
      1,
    );
    final encoded = jsonEncode(captured.single.toJson());
    expect(captured.single.dataset, 'map');
    expect(encoded, isNot(contains('private-user-id')));
    expect(encoded, isNot(contains('private employee')));
    expect(encoded, isNot(contains('FN-9')));
  });

  test('rollout monitor exposes circuit and failure totals by family', () {
    final monitor = MasterFieldCacheRolloutMonitor();
    for (final outcome in [
      MasterFieldCacheRolloutOutcome.driftReadFailed,
      MasterFieldCacheRolloutOutcome.readRepairFailed,
      MasterFieldCacheRolloutOutcome.circuitOpened,
    ]) {
      monitor.record(
        MasterFieldCacheRolloutEvent(
          recordedAt: DateTime.utc(2026, 10, 4),
          family: MasterFieldCacheDatasetFamily.map,
          dataset: 'map',
          outcome: outcome,
          elapsed: Duration.zero,
        ),
      );
    }

    final snapshot = monitor.snapshot;
    expect(
      snapshot.driftFailureCountForFamily(MasterFieldCacheDatasetFamily.map),
      2,
    );
    expect(snapshot.isCircuitOpen(MasterFieldCacheDatasetFamily.map), isTrue);
    expect(
      snapshot.isCircuitOpen(MasterFieldCacheDatasetFamily.coverage),
      isFalse,
    );
  });
}

MasterFieldReadCacheRouter _rolloutRouter(
  _RolloutStore hive,
  _RolloutStore drift,
  MasterFieldCacheRolloutReporter reporter,
) => MasterFieldReadCacheRouter(
  flags: const MasterFieldCacheFeatureFlags(mapDriftRolloutPercent: 100),
  hiveStore: hive,
  driftStore: drift,
  rolloutReporter: reporter,
);

class _RolloutStore implements MasterFieldReadCacheStore {
  @override
  final MasterFieldCacheBackend backend;

  @override
  bool isAvailable;

  int failNextReads = 0;
  int failNextWrites = 0;
  int readCount = 0;
  int writeCount = 0;
  Completer<void>? pendingWrite;
  final List<int> startedVersions = [];
  final Map<String, MasterFieldReadCacheEntry> entries = {};

  _RolloutStore(this.backend, {this.isAvailable = true});

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    readCount++;
    if (failNextReads > 0) {
      failNextReads--;
      throw StateError('synthetic rollout read failure');
    }
    return entries[scope.storageKey];
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    writeCount++;
    startedVersions.add(entry.version);
    if (failNextWrites > 0) {
      failNextWrites--;
      throw StateError('synthetic rollout write failure');
    }
    await pendingWrite?.future;
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
