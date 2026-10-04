import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/master_field_cache_canary.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  const mapScope = MasterFieldCacheScope(
    userId: 'user-a',
    dataset: 'map:fi:baseline',
    season: 'DS26',
  );

  group('canary flags', () {
    test('shadow families request Drift while Hive stays primary', () {
      const flags = MasterFieldCacheFeatureFlags(
        driftShadowFamilies: {
          MasterFieldCacheDatasetFamily.map,
          MasterFieldCacheDatasetFamily.coverage,
        },
      );

      expect(flags.requestsDrift, isTrue);
      expect(
        flags.backendForDataset(mapScope.dataset),
        MasterFieldCacheBackend.hive,
      );
      expect(flags.isDriftShadowEnabledForDataset(mapScope.dataset), isTrue);
      expect(
        flags.isDriftShadowEnabledForDataset('coverage:spv:baseline'),
        isTrue,
      );
      expect(
        flags.isDriftShadowEnabledForDataset('planning_index:all'),
        isFalse,
      );
      expect(flags.isDriftShadowEnabledForDataset('future-data'), isFalse);
    });

    test('shadowing is disabled after a family becomes Drift-primary', () {
      const flags = MasterFieldCacheFeatureFlags(
        mapBackend: MasterFieldCacheBackend.drift,
        driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
      );

      expect(flags.requestsDrift, isTrue);
      expect(flags.isDriftShadowEnabledForDataset(mapScope.dataset), isFalse);
    });

    test('disabled shadow families do not open Drift', () {
      const flags = MasterFieldCacheFeatureFlags(
        mapBackend: MasterFieldCacheBackend.disabled,
        driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
      );

      expect(flags.requestsDrift, isFalse);
      expect(flags.isDriftShadowEnabledForDataset(mapScope.dataset), isFalse);
    });

    test('sampling clamps safely and remains deterministic per scope', () {
      const disabled = MasterFieldCacheFeatureFlags(
        driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
        driftShadowSamplePercent: -20,
      );
      const all = MasterFieldCacheFeatureFlags(
        driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
        driftShadowSamplePercent: 120,
      );
      const partial = MasterFieldCacheFeatureFlags(
        driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
        driftShadowSamplePercent: 17,
      );

      expect(disabled.shouldSampleDriftShadow(mapScope), isFalse);
      expect(all.shouldSampleDriftShadow(mapScope), isTrue);
      final first = partial.shouldSampleDriftShadow(mapScope);
      expect(partial.shouldSampleDriftShadow(mapScope), first);
    });
  });

  group('shadow writes', () {
    test('mirrors Hive-primary writes to Drift', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift);
      final events = <MasterFieldCacheCanaryEvent>[];
      final router = _shadowRouter(hive, drift, events.add);

      await router.write(mapScope, _entry(7, ['FN-001']));

      expect(hive.entries[mapScope.storageKey]?.version, 7);
      expect(drift.entries[mapScope.storageKey]?.version, 7);
      expect(
        events.single.outcome,
        MasterFieldCacheCanaryOutcome.mirroredWrite,
      );
      expect(events.single.hiveWriteSucceeded, isTrue);
      expect(events.single.driftWriteSucceeded, isTrue);
    });

    test('a shadow write failure never removes the Hive snapshot', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift)
        ..throwOnWrite = true;
      final events = <MasterFieldCacheCanaryEvent>[];
      final router = _shadowRouter(hive, drift, events.add);

      await router.write(mapScope, _entry(8, ['FN-002']));

      expect(hive.entries[mapScope.storageKey]?.version, 8);
      expect(
        events.single.outcome,
        MasterFieldCacheCanaryOutcome.shadowWriteFailed,
      );
    });

    test('unavailable Drift is reported without affecting Hive', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(
        MasterFieldCacheBackend.drift,
        isAvailable: false,
      );
      final events = <MasterFieldCacheCanaryEvent>[];
      final router = _shadowRouter(hive, drift, events.add);

      await router.write(mapScope, _entry(9, ['FN-003']));

      expect(hive.entries[mapScope.storageKey]?.version, 9);
      expect(drift.writeCount, 0);
      expect(
        events.single.outcome,
        MasterFieldCacheCanaryOutcome.driftUnavailable,
      );
    });

    test('default Hive mode never touches Drift', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift);
      final router = MasterFieldReadCacheRouter(
        flags: const MasterFieldCacheFeatureFlags(),
        hiveStore: hive,
        driftStore: drift,
      );

      await router.write(mapScope, _entry(10, ['FN-004']));

      expect(hive.writeCount, 1);
      expect(drift.writeCount, 0);
    });

    test('serializes overlapping mirrored writes for the same scope', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift);
      final firstHiveWrite = Completer<void>();
      hive.pendingWrite = firstHiveWrite;
      final router = _shadowRouter(hive, drift, (_) {});

      final first = router.write(mapScope, _entry(1, ['FN-001']));
      await _waitFor(() => hive.writeCount == 1);
      final second = router.write(mapScope, _entry(2, ['FN-002']));
      await Future<void>.delayed(Duration.zero);

      expect(hive.writeCount, 1);
      expect(drift.writeCount, 0);
      firstHiveWrite.complete();
      await Future.wait([first, second]);

      expect(hive.entries[mapScope.storageKey]?.version, 2);
      expect(drift.entries[mapScope.storageKey]?.version, 2);
    });
  });

  group('shadow reads', () {
    test('returns Hive without waiting for the Drift comparison', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift);
      final hiveEntry = _entry(10, ['FN-001']);
      hive.entries[mapScope.storageKey] = hiveEntry;
      final pendingDriftRead = Completer<MasterFieldReadCacheEntry?>();
      drift.pendingRead = pendingDriftRead;
      final eventReceived = Completer<MasterFieldCacheCanaryEvent>();
      final router = _shadowRouter(hive, drift, eventReceived.complete);

      final result = await router.read(mapScope);

      expect(result, same(hiveEntry));
      expect(eventReceived.isCompleted, isFalse);
      pendingDriftRead.complete(_entry(10, ['FN-001']));
      final event = await eventReceived.future;
      expect(event.outcome, MasterFieldCacheCanaryOutcome.match);
    });

    for (final testCase
        in <
          ({
            String name,
            MasterFieldReadCacheEntry? hive,
            MasterFieldReadCacheEntry? drift,
            MasterFieldCacheCanaryOutcome expected,
          })
        >[
          (
            name: 'both stores miss',
            hive: null,
            drift: null,
            expected: MasterFieldCacheCanaryOutcome.bothMissing,
          ),
          (
            name: 'Hive has data but Drift misses',
            hive: _entry(1, ['FN-001']),
            drift: null,
            expected: MasterFieldCacheCanaryOutcome.hiveOnly,
          ),
          (
            name: 'Drift has data but Hive misses',
            hive: null,
            drift: _entry(1, ['FN-001']),
            expected: MasterFieldCacheCanaryOutcome.driftOnly,
          ),
          (
            name: 'versions differ',
            hive: _entry(1, ['FN-001']),
            drift: _entry(2, ['FN-001']),
            expected: MasterFieldCacheCanaryOutcome.versionMismatch,
          ),
          (
            name: 'row counts differ',
            hive: _entry(1, ['FN-001']),
            drift: _entry(1, ['FN-001', 'FN-002']),
            expected: MasterFieldCacheCanaryOutcome.rowCountMismatch,
          ),
          (
            name: 'row content differs',
            hive: _entry(1, ['FN-001']),
            drift: _entry(1, ['FN-999']),
            expected: MasterFieldCacheCanaryOutcome.contentMismatch,
          ),
        ]) {
      test('reports ${testCase.name}', () async {
        final hive = _CanaryStore(MasterFieldCacheBackend.hive);
        final drift = _CanaryStore(MasterFieldCacheBackend.drift);
        if (testCase.hive != null) {
          hive.entries[mapScope.storageKey] = testCase.hive!;
        }
        if (testCase.drift != null) {
          drift.entries[mapScope.storageKey] = testCase.drift!;
        }
        final eventReceived = Completer<MasterFieldCacheCanaryEvent>();
        final router = _shadowRouter(hive, drift, eventReceived.complete);

        final primary = await router.read(mapScope);
        final event = await eventReceived.future;

        expect(primary, same(testCase.hive));
        expect(event.outcome, testCase.expected);
        expect(event.dataset, 'map');
        expect(event.family, MasterFieldCacheDatasetFamily.map);
      });
    }

    test('Drift read failures do not affect the Hive result', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift)
        ..throwOnRead = true;
      final hiveEntry = _entry(11, ['FN-011']);
      hive.entries[mapScope.storageKey] = hiveEntry;
      final eventReceived = Completer<MasterFieldCacheCanaryEvent>();
      final router = _shadowRouter(hive, drift, eventReceived.complete);

      final result = await router.read(mapScope);
      final event = await eventReceived.future;

      expect(result, same(hiveEntry));
      expect(event.outcome, MasterFieldCacheCanaryOutcome.shadowReadFailed);
    });

    test('zero percent sampling performs no Drift read', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift);
      hive.entries[mapScope.storageKey] = _entry(1, ['FN-001']);
      final router = MasterFieldReadCacheRouter(
        flags: const MasterFieldCacheFeatureFlags(
          driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
          driftShadowSamplePercent: 0,
        ),
        hiveStore: hive,
        driftStore: drift,
        canaryReporter: (_) {},
      );

      await router.read(mapScope);
      await Future<void>.delayed(Duration.zero);

      expect(drift.readCount, 0);
    });

    test('deduplicates overlapping shadow reads for one scope', () async {
      final hive = _CanaryStore(MasterFieldCacheBackend.hive);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift);
      final entry = _entry(1, ['FN-001']);
      hive.entries[mapScope.storageKey] = entry;
      final pendingDriftRead = Completer<MasterFieldReadCacheEntry?>();
      drift.pendingRead = pendingDriftRead;
      final events = <MasterFieldCacheCanaryEvent>[];
      final router = _shadowRouter(hive, drift, events.add);

      await router.read(mapScope);
      await router.read(mapScope);

      expect(drift.readCount, 1);
      pendingDriftRead.complete(entry);
      await _waitFor(() => events.isNotEmpty);
      expect(events.single.outcome, MasterFieldCacheCanaryOutcome.match);
    });

    test('rechecks transient mismatches before recording telemetry', () async {
      final oldEntry = _entry(1, ['FN-OLD']);
      final newEntry = _entry(2, ['FN-NEW']);
      final hive = _CanaryStore(MasterFieldCacheBackend.hive)
        ..queuedReads.addAll([oldEntry, newEntry]);
      final drift = _CanaryStore(MasterFieldCacheBackend.drift)
        ..queuedReads.addAll([newEntry, newEntry]);
      final eventReceived = Completer<MasterFieldCacheCanaryEvent>();
      final router = _shadowRouter(hive, drift, eventReceived.complete);

      final primary = await router.read(mapScope);
      final event = await eventReceived.future;

      expect(primary?.version, 1);
      expect(hive.readCount, 2);
      expect(drift.readCount, 2);
      expect(event.outcome, MasterFieldCacheCanaryOutcome.match);
      expect(event.hiveVersion, 2);
      expect(event.driftVersion, 2);
    });
  });

  test('monitor exposes aggregate counts and exact-content match rate', () {
    final monitor = MasterFieldCacheCanaryMonitor();
    monitor.record(_event(MasterFieldCacheCanaryOutcome.match));
    monitor.record(_event(MasterFieldCacheCanaryOutcome.contentMismatch));
    monitor.record(_event(MasterFieldCacheCanaryOutcome.mirroredWrite));

    final snapshot = monitor.snapshot;
    expect(snapshot.totalEvents, 3);
    expect(snapshot.contentComparisonCount, 2);
    expect(snapshot.contentMatchRate, 0.5);
    expect(snapshot.count(MasterFieldCacheCanaryOutcome.mirroredWrite), 1);
    expect(
      snapshot.contentMatchRateForFamily(MasterFieldCacheDatasetFamily.map),
      0.5,
    );
    expect(
      snapshot.driftFailureRateForFamily(MasterFieldCacheDatasetFamily.map),
      0,
    );

    monitor.reset();
    expect(monitor.snapshot.totalEvents, 0);
  });

  test('telemetry never exposes role-scoped dataset identities', () async {
    final hive = _CanaryStore(MasterFieldCacheBackend.hive);
    final drift = _CanaryStore(MasterFieldCacheBackend.drift);
    hive.entries[mapScope.storageKey] = _entry(1, ['FN-001']);
    drift.entries[mapScope.storageKey] = _entry(1, ['FN-001']);
    final eventReceived = Completer<MasterFieldCacheCanaryEvent>();
    final router = _shadowRouter(hive, drift, eventReceived.complete);

    await router.read(mapScope);
    final event = await eventReceived.future;
    final encoded = event.toJson().toString();

    expect(event.dataset, 'map');
    expect(encoded, isNot(contains('fi')));
    expect(encoded, isNot(contains('baseline')));
    expect(encoded, isNot(contains('user-a')));
  });

  test(
    'off-isolate comparator validates the 34,600-row reference size',
    () async {
      const rowCount = 34600;
      final hiveRows = List<Map<String, dynamic>>.generate(
        rowCount,
        (index) => {
          'field_number': 'FN-${index.toString().padLeft(5, '0')}',
          'season': 'DS26',
          'region': 'Region ${index % 7}',
          'area': index / 10,
        },
        growable: false,
      );
      final driftRows = hiveRows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

      expect(await compareMasterFieldCacheRows(hiveRows, driftRows), isTrue);
      driftRows.last['area'] = -1;
      expect(await compareMasterFieldCacheRows(hiveRows, driftRows), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

MasterFieldReadCacheRouter _shadowRouter(
  _CanaryStore hive,
  _CanaryStore drift,
  MasterFieldCacheCanaryReporter reporter,
) => MasterFieldReadCacheRouter(
  flags: const MasterFieldCacheFeatureFlags(
    driftShadowFamilies: {MasterFieldCacheDatasetFamily.map},
    driftShadowSamplePercent: 100,
  ),
  hiveStore: hive,
  driftStore: drift,
  canaryReporter: reporter,
);

MasterFieldReadCacheEntry _entry(int version, List<String> fieldNumbers) {
  return MasterFieldReadCacheEntry(
    version: version,
    savedAt: DateTime.utc(2026, 10, 4),
    rows: fieldNumbers
        .map((fieldNumber) => <String, dynamic>{'field_number': fieldNumber})
        .toList(growable: false),
  );
}

MasterFieldCacheCanaryEvent _event(MasterFieldCacheCanaryOutcome outcome) {
  return MasterFieldCacheCanaryEvent(
    recordedAt: DateTime.utc(2026, 10, 4),
    family: MasterFieldCacheDatasetFamily.map,
    dataset: 'map',
    outcome: outcome,
    elapsed: Duration.zero,
  );
}

class _CanaryStore implements MasterFieldReadCacheStore {
  @override
  final MasterFieldCacheBackend backend;

  @override
  bool isAvailable;

  bool throwOnRead = false;
  bool throwOnWrite = false;
  int readCount = 0;
  int writeCount = 0;
  Completer<MasterFieldReadCacheEntry?>? pendingRead;
  Completer<void>? pendingWrite;
  final List<MasterFieldReadCacheEntry?> queuedReads = [];
  final Map<String, MasterFieldReadCacheEntry> entries = {};

  _CanaryStore(this.backend, {this.isAvailable = true});

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    readCount++;
    if (throwOnRead) throw StateError('synthetic shadow read failure');
    final pending = pendingRead;
    if (pending != null) return pending.future;
    if (queuedReads.isNotEmpty) return queuedReads.removeAt(0);
    return entries[scope.storageKey];
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    writeCount++;
    if (throwOnWrite) throw StateError('synthetic shadow write failure');
    await pendingWrite?.future;
    entries[scope.storageKey] = entry;
  }

  @override
  Future<void> clearUser(String userId) async {
    entries.removeWhere((key, _) {
      return key.startsWith('${MasterFieldCacheScope.keyPrefix}:$userId:');
    });
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
