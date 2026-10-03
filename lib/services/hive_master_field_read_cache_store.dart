import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'master_field_read_cache_contract.dart';

class HiveMasterFieldReadCacheStore implements MasterFieldReadCacheStore {
  static const boxName = 'masterFieldReadCacheV2';
  static const maxEntriesPerUser = 12;

  @override
  MasterFieldCacheBackend get backend => MasterFieldCacheBackend.hive;

  @override
  bool get isAvailable => Hive.isBoxOpen(boxName);

  @override
  Future<MasterFieldReadCacheEntry?> read(MasterFieldCacheScope scope) async {
    if (!isAvailable) return null;
    final raw = Hive.box<dynamic>(boxName).get(scope.storageKey);
    if (raw is! Map) return null;

    final version = raw['version'];
    final savedAtMillis = raw['savedAt'];
    final payload = raw['payload'];
    if (version is! int ||
        savedAtMillis is! int ||
        payload is! String ||
        payload.isEmpty) {
      return null;
    }

    final rows = await compute(_decodeRows, payload);
    return MasterFieldReadCacheEntry(
      version: version,
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
      rows: rows,
    );
  }

  @override
  Future<void> write(
    MasterFieldCacheScope scope,
    MasterFieldReadCacheEntry entry,
  ) async {
    if (!isAvailable) return;
    final box = Hive.box<dynamic>(boxName);
    final payload = await compute(_encodeRows, entry.rows);
    await box.put(scope.storageKey, {
      'version': entry.version,
      'savedAt': entry.savedAt.millisecondsSinceEpoch,
      'payload': payload,
    });
    await _pruneUserEntries(box, scope.userId);
  }

  @override
  Future<void> clearUser(String userId) async {
    if (!isAvailable || userId.trim().isEmpty) return;
    final box = Hive.box<dynamic>(boxName);
    final prefix = '${MasterFieldCacheScope.keyPrefix}:$userId:';
    final keys = box.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList(growable: false);
    if (keys.isNotEmpty) await box.deleteAll(keys);
  }

  Future<void> _pruneUserEntries(Box<dynamic> box, String userId) async {
    final prefix = '${MasterFieldCacheScope.keyPrefix}:$userId:';
    final entries = <({dynamic key, int savedAt})>[];
    for (final cacheKey in box.keys) {
      if (cacheKey is! String || !cacheKey.startsWith(prefix)) continue;
      final value = box.get(cacheKey);
      final savedAt = value is Map && value['savedAt'] is int
          ? value['savedAt'] as int
          : 0;
      entries.add((key: cacheKey, savedAt: savedAt));
    }
    if (entries.length <= maxEntriesPerUser) return;
    entries.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final deleteCount = entries.length - maxEntriesPerUser;
    await box.deleteAll(
      entries.take(deleteCount).map((entry) => entry.key).toList(),
    );
  }
}

String _encodeRows(List<Map<String, dynamic>> rows) => jsonEncode(rows);

List<Map<String, dynamic>> _decodeRows(String payload) {
  final decoded = jsonDecode(payload);
  if (decoded is! List) throw const FormatException('Invalid cached rows');
  return decoded
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
