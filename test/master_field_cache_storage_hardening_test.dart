import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/drift_master_field_read_cache_store.dart';
import 'package:kroscek/services/master_field_cache_database.dart';
import 'package:kroscek/services/master_field_read_cache_contract.dart';

void main() {
  late MasterFieldCacheDatabase database;
  DriftMasterFieldReadCacheStore? store;

  setUp(() {
    database = MasterFieldCacheDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    final activeStore = store;
    if (activeStore != null && activeStore.isAvailable) {
      await activeStore.close();
    } else {
      await database.close();
    }
  });

  DriftMasterFieldReadCacheStore openStore({int? payloadBudget}) {
    final result = DriftMasterFieldReadCacheStore(
      database,
      maxPayloadBytesPerUser:
          payloadBudget ??
          DriftMasterFieldReadCacheStore.defaultMaxPayloadBytesPerUser,
    );
    store = result;
    return result;
  }

  test('SQLite integrity and journal-size guards are active', () async {
    openStore();

    await expectLater(database.verifyIntegrity(), completes);
    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    final journalLimit = await database
        .customSelect('PRAGMA journal_size_limit')
        .getSingle();

    expect(foreignKeys.read<int>('foreign_keys'), 1);
    expect(
      journalLimit.read<int>('journal_size_limit'),
      MasterFieldCacheDatabase.journalSizeLimitBytes,
    );
  });

  test('invalid JSON is discarded with its snapshot and child rows', () async {
    final activeStore = openStore();
    const scope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'map:corrupt',
    );
    await _insertRawSnapshot(
      database,
      scope,
      rowCount: 1,
      payload: '{invalid-json',
    );

    expect(await activeStore.read(scope), isNull);
    expect(
      await database.select(database.masterFieldCacheSnapshots).get(),
      isEmpty,
    );
    expect(await database.select(database.masterFieldCacheRows).get(), isEmpty);
  });

  test('corrupt cleanup remains isolated from another account', () async {
    final activeStore = openStore();
    const corruptScope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'coverage:corrupt',
    );
    const healthyScope = MasterFieldCacheScope(
      userId: 'user-b',
      dataset: 'coverage:healthy',
    );
    await _insertRawSnapshot(
      database,
      corruptScope,
      rowCount: 1,
      payload: '[]',
    );
    await activeStore.write(healthyScope, _entry(2, 'FN-HEALTHY'));

    expect(await activeStore.read(corruptScope), isNull);
    expect(
      (await activeStore.read(healthyScope))?.rows.single['field_number'],
      'FN-HEALTHY',
    );
  });

  test('payload quota evicts the oldest snapshot and cascades rows', () async {
    final oneRowBytes = utf8.encode(jsonEncode(_row('FN-OLD'))).length;
    final activeStore = openStore(payloadBudget: oneRowBytes + 1);
    const oldScope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'map:old',
    );
    const newScope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'map:new',
    );

    await activeStore.write(oldScope, _entry(1, 'FN-OLD'));
    await activeStore.write(
      newScope,
      _entry(2, 'FN-NEW', savedAt: DateTime.utc(2026, 10, 5)),
    );

    expect(await activeStore.read(oldScope), isNull);
    expect((await activeStore.read(newScope))?.version, 2);
    final snapshots = await database
        .select(database.masterFieldCacheSnapshots)
        .get();
    final rows = await database.select(database.masterFieldCacheRows).get();
    expect(snapshots.map((snapshot) => snapshot.cacheKey), [
      newScope.storageKey,
    ]);
    expect(rows.map((row) => row.fieldNumber), ['FN-NEW']);
  });

  test('payload quota is isolated per account', () async {
    final oneRowBytes = utf8.encode(jsonEncode(_row('FN-A1'))).length;
    final activeStore = openStore(payloadBudget: oneRowBytes + 1);
    const firstA = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'planning_index:first',
    );
    const secondA = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'planning_index:second',
    );
    const userB = MasterFieldCacheScope(
      userId: 'user-b',
      dataset: 'planning_index:first',
    );

    await activeStore.write(firstA, _entry(1, 'FN-A1'));
    await activeStore.write(
      secondA,
      _entry(2, 'FN-A2', savedAt: DateTime.utc(2026, 10, 5)),
    );
    await activeStore.write(userB, _entry(3, 'FN-B1'));

    expect(await activeStore.read(firstA), isNull);
    expect((await activeStore.read(secondA))?.version, 2);
    expect((await activeStore.read(userB))?.version, 3);
  });

  test(
    'an oversized current snapshot is retained as the only snapshot',
    () async {
      final activeStore = openStore(payloadBudget: 1);
      const first = MasterFieldCacheScope(
        userId: 'user-a',
        dataset: 'map:first',
      );
      const second = MasterFieldCacheScope(
        userId: 'user-a',
        dataset: 'map:second',
      );

      await activeStore.write(first, _entry(1, 'FN-FIRST'));
      expect((await activeStore.read(first))?.version, 1);

      await activeStore.write(
        second,
        _entry(2, 'FN-SECOND', savedAt: DateTime.utc(2026, 10, 5)),
      );

      expect(await activeStore.read(first), isNull);
      expect((await activeStore.read(second))?.version, 2);
      expect(
        await database.select(database.masterFieldCacheSnapshots).get(),
        hasLength(1),
      );
    },
  );

  test('rewriting a scope counts only its replacement payload', () async {
    final replacementBytes = utf8.encode(jsonEncode(_row('FN-NEW'))).length;
    final activeStore = openStore(payloadBudget: replacementBytes);
    const scope = MasterFieldCacheScope(
      userId: 'user-a',
      dataset: 'coverage:rewrite',
    );

    await activeStore.write(scope, _entry(1, 'FN-OLD'));
    await activeStore.write(scope, _entry(2, 'FN-NEW'));

    expect((await activeStore.read(scope))?.version, 2);
    final snapshots = await database
        .select(database.masterFieldCacheSnapshots)
        .get();
    expect(snapshots, hasLength(1));
    expect(snapshots.single.payloadBytes, replacementBytes);
  });
}

Future<void> _insertRawSnapshot(
  MasterFieldCacheDatabase database,
  MasterFieldCacheScope scope, {
  required int rowCount,
  required String payload,
}) async {
  await database.transaction(() async {
    await database
        .into(database.masterFieldCacheSnapshots)
        .insert(
          MasterFieldCacheSnapshotsCompanion.insert(
            cacheKey: scope.storageKey,
            userId: scope.userId,
            dataset: scope.dataset,
            version: 1,
            savedAtMillis: DateTime.utc(2026, 10, 4).millisecondsSinceEpoch,
            rowCount: rowCount,
            payloadBytes: utf8.encode(payload).length,
          ),
        );
    await database
        .into(database.masterFieldCacheRows)
        .insert(
          MasterFieldCacheRowsCompanion.insert(
            cacheKey: scope.storageKey,
            rowIndex: 0,
            payload: payload,
          ),
        );
  });
}

MasterFieldReadCacheEntry _entry(
  int version,
  String fieldNumber, {
  DateTime? savedAt,
}) {
  return MasterFieldReadCacheEntry(
    version: version,
    savedAt: savedAt ?? DateTime.utc(2026, 10, 4),
    rows: [_row(fieldNumber)],
  );
}

Map<String, dynamic> _row(String fieldNumber) => {'field_number': fieldNumber};
