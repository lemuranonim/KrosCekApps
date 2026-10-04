import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'master_field_cache_database.dart';
import 'master_field_read_cache_contract.dart';

class DriftMasterFieldReadCacheStore implements MasterFieldReadCacheStore {
  static const maxEntriesPerUser = 12;
  static const _insertChunkSize = 500;

  final MasterFieldCacheDatabase database;
  bool _closed = false;

  DriftMasterFieldReadCacheStore(this.database);

  @override
  MasterFieldCacheBackend get backend => MasterFieldCacheBackend.drift;

  @override
  bool get isAvailable => !_closed;

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    _ensureOpen();
    final cacheKey = scope.storageKey;
    final snapshot = await (database.select(
      database.masterFieldCacheSnapshots,
    )..where((table) => table.cacheKey.equals(cacheKey))).getSingleOrNull();
    if (snapshot == null) return null;

    final storedRows =
        await (database.select(database.masterFieldCacheRows)
              ..where((table) => table.cacheKey.equals(cacheKey))
              ..orderBy([(table) => OrderingTerm.asc(table.rowIndex)]))
            .get();
    if (storedRows.length != snapshot.rowCount) {
      throw FormatException(
        'Incomplete Drift cache snapshot: expected ${snapshot.rowCount} rows, '
        'found ${storedRows.length}',
      );
    }

    final rows = await compute(
      _decodeCacheRows,
      storedRows.map((row) => row.payload).toList(growable: false),
    );
    return MasterFieldReadCacheEntry(
      version: snapshot.version,
      savedAt: DateTime.fromMillisecondsSinceEpoch(snapshot.savedAtMillis),
      rows: rows,
    );
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    _ensureOpen();
    final encodedRows = await compute(_encodeCacheRows, entry.rows);
    final cacheKey = scope.storageKey;
    final payloadBytes = encodedRows.fold<int>(
      0,
      (total, row) => total + (row['payloadBytes']! as int),
    );

    await database.transaction(() async {
      await database
          .into(database.masterFieldCacheSnapshots)
          .insertOnConflictUpdate(
            MasterFieldCacheSnapshotsCompanion.insert(
              cacheKey: cacheKey,
              userId: scope.userId,
              dataset: scope.dataset,
              season: Value(_normalized(scope.season)),
              region: Value(_normalized(scope.region)),
              district: Value(_normalized(scope.district)),
              version: entry.version,
              savedAtMillis: entry.savedAt.millisecondsSinceEpoch,
              rowCount: encodedRows.length,
              payloadBytes: payloadBytes,
            ),
          );
      await (database.delete(
        database.masterFieldCacheRows,
      )..where((table) => table.cacheKey.equals(cacheKey))).go();

      for (
        var offset = 0;
        offset < encodedRows.length;
        offset += _insertChunkSize
      ) {
        final end = (offset + _insertChunkSize).clamp(0, encodedRows.length);
        final companions = <MasterFieldCacheRowsCompanion>[];
        for (var index = offset; index < end; index++) {
          final row = encodedRows[index];
          companions.add(
            MasterFieldCacheRowsCompanion.insert(
              cacheKey: cacheKey,
              rowIndex: index,
              fieldNumber: Value(row['fieldNumber'] as String?),
              season: Value(row['season'] as String?),
              region: Value(row['region'] as String?),
              district: Value(row['district'] as String?),
              qaFi: Value(row['qaFi'] as String?),
              qaSpv: Value(row['qaSpv'] as String?),
              payload: row['payload']! as String,
            ),
          );
        }
        await database.batch((batch) {
          batch.insertAll(database.masterFieldCacheRows, companions);
        });
      }

      await _pruneUserEntries(scope.userId);
    });
  }

  @override
  Future<void> clearUser(String userId) async {
    _ensureOpen();
    if (userId.trim().isEmpty) return;
    await (database.delete(
      database.masterFieldCacheSnapshots,
    )..where((table) => table.userId.equals(userId))).go();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await database.close();
  }

  Future<void> _pruneUserEntries(String userId) async {
    final snapshots =
        await (database.select(database.masterFieldCacheSnapshots)
              ..where((table) => table.userId.equals(userId))
              ..orderBy([
                (table) => OrderingTerm.asc(table.savedAtMillis),
                (table) => OrderingTerm.asc(table.cacheKey),
              ]))
            .get();
    final deleteCount = snapshots.length - maxEntriesPerUser;
    if (deleteCount <= 0) return;
    final expiredKeys = snapshots
        .take(deleteCount)
        .map((snapshot) => snapshot.cacheKey)
        .toList(growable: false);
    await (database.delete(
      database.masterFieldCacheSnapshots,
    )..where((table) => table.cacheKey.isIn(expiredKeys))).go();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Drift master-field cache is closed');
  }
}

List<Map<String, Object?>> _encodeCacheRows(List<Map<String, dynamic>> rows) {
  return rows
      .map((row) {
        final payload = jsonEncode(row);
        return <String, Object?>{
          'payload': payload,
          'payloadBytes': utf8.encode(payload).length,
          'fieldNumber': _indexValue(row['field_number']),
          'season': _indexValue(row['season']),
          'region': _indexValue(row['region']),
          'district': _indexValue(row['district_kab']),
          'qaFi': _indexValue(row['qa_fi']),
          'qaSpv': _indexValue(row['qa_spv']),
        };
      })
      .toList(growable: false);
}

List<Map<String, dynamic>> _decodeCacheRows(List<String> payloads) {
  return payloads
      .map((payload) {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) throw const FormatException('Invalid cached row');
        return Map<String, dynamic>.from(decoded);
      })
      .toList(growable: false);
}

String? _indexValue(Object? value) => _normalized(value?.toString());

String? _normalized(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
