import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/drift_master_field_read_cache_store.dart';
import 'package:kroscek/services/master_field_cache_database.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  late MasterFieldCacheDatabase database;
  late DriftMasterFieldReadCacheStore store;

  setUp(() {
    database = MasterFieldCacheDatabase(NativeDatabase.memory());
    store = DriftMasterFieldReadCacheStore(database);
  });

  tearDown(() async {
    if (store.isAvailable) await store.close();
  });

  test('round-trips nested rows and snapshot metadata', () async {
    const scope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'map:fi:baseline',
      season: 'DS26',
      region: 'Region 5',
      district: 'Blitar',
    );
    final savedAt = DateTime(2026, 10, 4, 9, 30, 15, 250);
    final rows = <Map<String, dynamic>>[
      {
        'field_number': 'FN-001',
        'season': 'DS26',
        'region': 'Region 5',
        'district_kab': 'Blitar',
        'coordinate': {'lat': -7.1, 'lng': 112.1},
        'tags': ['seed', 42, true],
        'nullable': null,
      },
      {'field_number': 'FN-002', 'active': false},
    ];

    await store.write(
      scope,
      MasterFieldReadCacheEntry(version: 17, savedAt: savedAt, rows: rows),
    );
    final result = await store.read(scope);

    expect(result?.version, 17);
    expect(
      result?.savedAt.millisecondsSinceEpoch,
      savedAt.millisecondsSinceEpoch,
    );
    expect(result?.rows, rows);
  });

  test('rewriting a scope atomically replaces its rows', () async {
    const scope = MasterFieldCacheScope(userId: 'user-a', dataset: 'map');
    await store.write(scope, _entry(1, ['FN-001', 'FN-002']));
    await store.write(scope, _entry(2, ['FN-003']));

    final result = await store.read(scope);
    final storedRows = await database
        .select(database.masterFieldCacheRows)
        .get();

    expect(result?.version, 2);
    expect(result?.rows, [
      {'field_number': 'FN-003'},
    ]);
    expect(storedRows, hasLength(1));
  });

  test('scope and user identities remain isolated', () async {
    const first = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'coverage:all',
      region: 'Region 5',
    );
    const second = MasterFieldCacheScope(
      userId: 'user-b',
      dataset: 'coverage:all',
      region: 'Region 5',
    );
    await store.write(first, _entry(1, ['FN-A']));
    await store.write(second, _entry(2, ['FN-B']));

    expect((await store.read(first))?.rows.single['field_number'], 'FN-A');
    expect((await store.read(second))?.rows.single['field_number'], 'FN-B');
  });

  test('retains the newest 12 snapshots per user and cascades rows', () async {
    for (var index = 0; index < 13; index++) {
      await store.write(
        MasterFieldCacheScope(userId: 'user-a', dataset: 'map:$index'),
        _entry(index, ['FN-$index'], dayOffset: index),
      );
    }
    const otherUser = MasterFieldCacheScope(userId: 'user-b', dataset: 'map:0');
    await store.write(otherUser, _entry(99, ['FN-OTHER']));

    final userASnapshots = await (database.select(
      database.masterFieldCacheSnapshots,
    )..where((table) => table.userId.equals('user-a'))).get();
    final allRows = await database.select(database.masterFieldCacheRows).get();

    expect(userASnapshots, hasLength(12));
    expect(
      await store.read(
        const MasterFieldCacheScope(userId: 'user-a', dataset: 'map:0'),
      ),
      isNull,
    );
    expect(
      (await store.read(
        const MasterFieldCacheScope(userId: 'user-a', dataset: 'map:1'),
      ))?.version,
      1,
    );
    expect((await store.read(otherUser))?.version, 99);
    expect(allRows, hasLength(13));
  });

  test('clearUser deletes only that user and cascades child rows', () async {
    const first = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'planning_index',
    );
    const second = MasterFieldCacheScope(
      userId: 'user-b',
      dataset: 'planning_index',
    );
    await store.write(first, _entry(1, ['FN-A']));
    await store.write(second, _entry(2, ['FN-B']));

    await store.clearUser('user-a');

    expect(await store.read(first), isNull);
    expect((await store.read(second))?.version, 2);
    final rows = await database.select(database.masterFieldCacheRows).get();
    expect(rows.map((row) => row.fieldNumber), ['FN-B']);
  });

  test('stores normalized query metadata beside the JSON payload', () async {
    const scope = MasterFieldCacheScope(userId: 'user-a', dataset: 'map');
    await store.write(
      scope,
      MasterFieldReadCacheEntry(
        version: 1,
        savedAt: DateTime.utc(2026, 10, 4),
        rows: const [
          {
            'field_number': ' FN-123 ',
            'season': ' DS26 ',
            'region': ' Region 5 ',
            'district_kab': ' Blitar ',
            'qa_fi': ' qa@example.com ',
            'qa_spv': '',
          },
        ],
      ),
    );

    final row = await database
        .select(database.masterFieldCacheRows)
        .getSingle();

    expect(row.fieldNumber, 'FN-123');
    expect(row.season, 'DS26');
    expect(row.region, 'Region 5');
    expect(row.district, 'Blitar');
    expect(row.qaFi, 'qa@example.com');
    expect(row.qaSpv, isNull);
  });

  test(
    'discards a partially stored snapshot instead of returning partial data',
    () async {
      const scope = MasterFieldCacheScope(userId: 'user-a', dataset: 'map');
      await database
          .into(database.masterFieldCacheSnapshots)
          .insert(
            MasterFieldCacheSnapshotsCompanion.insert(
              cacheKey: scope.storageKey,
              userId: scope.userId,
              dataset: scope.dataset,
              version: 1,
              savedAtMillis: DateTime.utc(2026, 10, 4).millisecondsSinceEpoch,
              rowCount: 1,
              payloadBytes: 0,
            ),
          );

      expect(await store.read(scope), isNull);
      expect(
        await database.select(database.masterFieldCacheSnapshots).get(),
        isEmpty,
      );
    },
  );

  test('schema v1 enables SQLite foreign keys', () async {
    await database.customSelect('SELECT 1').getSingle();
    final pragma = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();

    expect(database.schemaVersion, 1);
    expect(pragma.read<int>('foreign_keys'), 1);
    await expectLater(database.verifyIntegrity(), completes);
    final journalLimit = await database
        .customSelect('PRAGMA journal_size_limit')
        .getSingle();
    expect(
      journalLimit.read<int>('journal_size_limit'),
      MasterFieldCacheDatabase.journalSizeLimitBytes,
    );
  });

  test(
    'persists cache snapshots after closing and reopening the file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kroscek_drift_cache_',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}cache.sqlite',
      );
      const scope = MasterFieldCacheScope(
        userId: 'user-a',
        dataset: 'coverage:all',
      );

      await store.close();
      database = MasterFieldCacheDatabase(NativeDatabase(file));
      store = DriftMasterFieldReadCacheStore(database);
      await store.write(scope, _entry(42, ['FN-PERSISTED']));
      await store.close();

      database = MasterFieldCacheDatabase(NativeDatabase(file));
      store = DriftMasterFieldReadCacheStore(database);
      final result = await store.read(scope);

      expect(result?.version, 42);
      expect(result?.rows.single['field_number'], 'FN-PERSISTED');
      await store.close();
      await directory.delete(recursive: true);
    },
  );

  test('round-trips the 34,600-row production reference size', () async {
    const referenceRowCount = 34600;
    const scope = MasterFieldCacheScope(
      userId: 'production-reference',
      dataset: 'map:fi:baseline',
      season: 'DS26',
    );
    final rows = List<Map<String, dynamic>>.generate(
      referenceRowCount,
      (index) => {
        'field_number': 'FN-${index.toString().padLeft(5, '0')}',
        'season': 'DS26',
        'region': 'Region ${index % 7}',
        'district_kab': 'District ${index % 25}',
        'qa_fi': 'fi-${index % 50}@example.com',
        'area': index / 10,
      },
      growable: false,
    );

    await store.write(
      scope,
      MasterFieldReadCacheEntry(
        version: referenceRowCount,
        savedAt: DateTime.utc(2026, 10, 4),
        rows: rows,
      ),
    );
    final result = await store.read(scope);

    expect(result?.rows, hasLength(referenceRowCount));
    expect(result?.rows.first['field_number'], 'FN-00000');
    expect(result?.rows.last['field_number'], 'FN-34599');
    final snapshot = await database
        .select(database.masterFieldCacheSnapshots)
        .getSingle();
    expect(snapshot.rowCount, referenceRowCount);
    expect(snapshot.payloadBytes, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

MasterFieldReadCacheEntry _entry(
  int version,
  List<String> fieldNumbers, {
  int dayOffset = 0,
}) {
  return MasterFieldReadCacheEntry(
    version: version,
    savedAt: DateTime.utc(2026, 10, 1).add(Duration(days: dayOffset)),
    rows: fieldNumbers
        .map((fieldNumber) => <String, dynamic>{'field_number': fieldNumber})
        .toList(growable: false),
  );
}
