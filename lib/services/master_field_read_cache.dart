import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class MasterFieldReadCacheEntry {
  final int version;
  final DateTime savedAt;
  final List<Map<String, dynamic>> rows;

  const MasterFieldReadCacheEntry({
    required this.version,
    required this.savedAt,
    required this.rows,
  });
}

/// Persistent, per-account read-through snapshot for the two largest payloads.
///
/// Redis remains the shared server cache. This snapshot only prevents an
/// unchanged Map/Coverage payload from being downloaded again on every app
/// start. The Edge Function validates [version] before this data is returned.
class MasterFieldReadCache {
  MasterFieldReadCache._();

  static const boxName = 'masterFieldReadCacheV2';
  static const _keyPrefix = 'mf-read-v2';
  static const _maxEntriesPerUser = 12;

  static bool get isAvailable => Hive.isBoxOpen(boxName);

  static String key({
    required String userId,
    required String dataset,
    String? season,
    String? region,
    String? district,
  }) {
    final identity = jsonEncode({
      'dataset': dataset,
      'season': _normalize(season),
      'region': _normalize(region),
      'district': _normalize(district),
    });
    final encodedScope = base64Url.encode(utf8.encode(identity));
    return '$_keyPrefix:$userId:$encodedScope';
  }

  static Future<MasterFieldReadCacheEntry?> read({
    required String userId,
    required String dataset,
    String? season,
    String? region,
    String? district,
  }) async {
    if (!isAvailable || userId.trim().isEmpty) return null;
    try {
      final cacheKey = key(
        userId: userId,
        dataset: dataset,
        season: season,
        region: region,
        district: district,
      );
      final raw = Hive.box<dynamic>(boxName).get(cacheKey);
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
    } catch (error) {
      debugPrint('Local $dataset cache read skipped: $error');
      return null;
    }
  }

  static Future<void> write({
    required String userId,
    required String dataset,
    required int version,
    required List<Map<String, dynamic>> rows,
    String? season,
    String? region,
    String? district,
  }) async {
    if (!isAvailable || userId.trim().isEmpty || version < 0) return;
    try {
      final box = Hive.box<dynamic>(boxName);
      final cacheKey = key(
        userId: userId,
        dataset: dataset,
        season: season,
        region: region,
        district: district,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = await compute(_encodeRows, rows);
      await box.put(cacheKey, {
        'version': version,
        'savedAt': now,
        'payload': payload,
      });
      await _pruneUserEntries(box, userId);
    } catch (error) {
      debugPrint('Local $dataset cache write skipped: $error');
    }
  }

  static Future<void> clearUser(String userId) async {
    if (!isAvailable || userId.trim().isEmpty) return;
    final box = Hive.box<dynamic>(boxName);
    final prefix = '$_keyPrefix:$userId:';
    final keys = box.keys
        .where((key) => key is String && key.startsWith(prefix))
        .toList(growable: false);
    if (keys.isNotEmpty) await box.deleteAll(keys);
  }

  static Future<void> _pruneUserEntries(Box<dynamic> box, String userId) async {
    final prefix = '$_keyPrefix:$userId:';
    final entries = <({dynamic key, int savedAt})>[];
    for (final cacheKey in box.keys) {
      if (cacheKey is! String || !cacheKey.startsWith(prefix)) continue;
      final value = box.get(cacheKey);
      final savedAt = value is Map && value['savedAt'] is int
          ? value['savedAt'] as int
          : 0;
      entries.add((key: cacheKey, savedAt: savedAt));
    }
    if (entries.length <= _maxEntriesPerUser) return;
    entries.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final deleteCount = entries.length - _maxEntriesPerUser;
    await box.deleteAll(
      entries.take(deleteCount).map((entry) => entry.key).toList(),
    );
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
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
