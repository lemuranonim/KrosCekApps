import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AbsenCacheManager {
  static const String _cacheValidityKey = 'absen_cache_validity';
  static const String _lastAbsenActionKey = 'last_absen_action_timestamp';
  static const Duration _cacheValidityDuration = Duration(hours: 2);

  /// Cek apakah cache masih valid (belum expired)
  static Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString(_cacheValidityKey);

    if (lastUpdate == null) return false;

    final lastUpdateTime = DateTime.parse(lastUpdate);
    final now = DateTime.now();

    return now.difference(lastUpdateTime) < _cacheValidityDuration;
  }

  /// Set cache validity timestamp
  static Future<void> setCacheValidity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheValidityKey, DateTime.now().toIso8601String());
  }

  /// Invalidate cache (force refresh next time)
  static Future<void> invalidateCache() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await prefs.remove(_cacheValidityKey);
    await prefs.remove('cachedHasAbsen_$today');
    await prefs.remove('cachedJamAbsen_$today');
    await prefs.remove('cachedRegion_$today');

    debugPrint("[AbsenCache] 🔄 Cache invalidated");
  }

  /// Mark that user just did absen action
  static Future<void> markAbsenAction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAbsenActionKey, DateTime.now().toIso8601String());
    debugPrint("[AbsenCache] ✅ Absen action marked");
  }

  /// Check if we should force refresh after absen action
  static Future<bool> shouldForceRefreshAfterAbsen() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAction = prefs.getString(_lastAbsenActionKey);

    if (lastAction == null) return false;

    final lastActionTime = DateTime.parse(lastAction);
    final now = DateTime.now();

    // Force refresh jika absen action < 5 menit yang lalu
    return now.difference(lastActionTime) < const Duration(minutes: 5);
  }

  /// Get cache info for debugging
  static Future<Map<String, dynamic>> getCacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return {
      'isValid': await isCacheValid(),
      'lastUpdate': prefs.getString(_cacheValidityKey),
      'hasAbsen': prefs.getBool('cachedHasAbsen_$today'),
      'jamAbsen': prefs.getString('cachedJamAbsen_$today'),
      'region': prefs.getString('cachedRegion_$today'),
      'shouldForceRefresh': await shouldForceRefreshAfterAbsen(),
    };
  }
}

class EnhancedAbsenService {
  static Future<Map<String, dynamic>> _fetchAbsenFromFirestore({
    required String userName,
  }) async {
    try {
      debugPrint("[AbsenService] 🔥 Querying Firestore for user: $userName");

      // Tentukan rentang waktu untuk "hari ini"
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day); // Jam 00:00:00
      final startOfTomorrow = DateTime(now.year, now.month, now.day + 1); // Besok jam 00:00:00

      // Buat query ke Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('absen_logs')
          .where('userName', isEqualTo: userName) // Cari berdasarkan nama
          .where('timestamp', isGreaterThanOrEqualTo: startOfToday) // Setelah awal hari ini
          .where('timestamp', isLessThan: startOfTomorrow)      // Sebelum awal besok
          .limit(1) // Cukup ambil 1 data saja untuk konfirmasi
          .get();

      // Cek apakah ada data yang ditemukan
      if (querySnapshot.docs.isNotEmpty) {
        final absenDoc = querySnapshot.docs.first.data();
        final absenTimestamp = (absenDoc['timestamp'] as Timestamp).toDate();

        debugPrint("[AbsenService] ✅ Firestore FOUND absen for today!");

        return {
          'hasAbsen': true,
          'jamAbsen': DateFormat('HH:mm').format(absenTimestamp),
          'region': absenDoc['region'],
        };
      } else {
        debugPrint("[AbsenService] ℹ️ Firestore NOT FOUND absen for today.");
        return {'hasAbsen': false, 'jamAbsen': null, 'region': null};
      }
    } catch (e) {
      debugPrint("[AbsenService] ❌ Firestore query error: $e");
      return {'hasAbsen': false, 'jamAbsen': null, 'region': null};
    }
  }
  /// Check absen status with smart caching
  static Future<Map<String, dynamic>> checkAbsenStatus({
    required String userName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 🔍 Step 1 & 2 (Cache Logic): TIDAK BERUBAH
    final shouldForceRefresh = await AbsenCacheManager.shouldForceRefreshAfterAbsen();
    final isCacheValid = await AbsenCacheManager.isCacheValid();

    // 🔍 Step 3 (Use Cache): TIDAK BERUBAH
    if (isCacheValid && !shouldForceRefresh) {
      final cachedHasAbsen = prefs.getBool('cachedHasAbsen_$today') ?? false;
      final cachedJamAbsen = prefs.getString('cachedJamAbsen_$today');
      final cachedRegion = prefs.getString('cachedRegion_$today');

      debugPrint("[AbsenService] 📦 Using valid cache (expires in ${_getCacheExpiry(prefs)})");
      return {
        'hasAbsen': cachedHasAbsen,
        'jamAbsen': cachedJamAbsen,
        'region': cachedRegion,
        'fromCache': true,
      };
    }

    // 🔍 Step 4 (Fetch from API): INI YANG BERUBAH TOTAL
    debugPrint("[AbsenService] 🌐 Fetching fresh data from Firestore${shouldForceRefresh ? ' (forced)' : ''}");

    // Panggil fungsi baru kita untuk fetch dari Firestore
    final result = await _fetchAbsenFromFirestore(userName: userName);

    // 🔍 Step 5 & 6 (Save to Cache): TIDAK BERUBAH
    await _saveToCache(prefs, today, result);
    await AbsenCacheManager.setCacheValidity();

    result['fromCache'] = false;
    return result;
  }

  /// Force refresh absen status (bypass cache)
  static Future<Map<String, dynamic>> forceRefreshAbsenStatus({
    required String userName,
  }) async {
    debugPrint("[AbsenService] 🔄 Force refresh requested");

    // Invalidate cache first
    await AbsenCacheManager.invalidateCache();

    // Then fetch fresh data
    return await checkAbsenStatus(
      userName: userName,
    );
  }

  /// Save result to cache
  static Future<void> _saveToCache(
      SharedPreferences prefs,
      String today,
      Map<String, dynamic> result,
      ) async {
    await prefs.setBool('cachedHasAbsen_$today', result['hasAbsen'] ?? false);

    if (result['jamAbsen'] != null) {
      await prefs.setString('cachedJamAbsen_$today', result['jamAbsen']);
    } else {
      await prefs.remove('cachedJamAbsen_$today');
    }

    if (result['region'] != null) {
      await prefs.setString('cachedRegion_$today', result['region']);
    } else {
      await prefs.remove('cachedRegion_$today');
    }

    await prefs.setString('lastAbsenCheckDate', today);

    debugPrint("[AbsenService] 💾 Data saved to cache");
  }

  /// Get cache expiry time string
  static String _getCacheExpiry(SharedPreferences prefs) {
    final lastUpdate = prefs.getString('absen_cache_validity');
    if (lastUpdate == null) return 'unknown';

    final lastUpdateTime = DateTime.parse(lastUpdate);
    final expiryTime = lastUpdateTime.add(const Duration(hours: 2));
    final now = DateTime.now();
    final remaining = expiryTime.difference(now);

    if (remaining.inMinutes < 60) {
      return '${remaining.inMinutes}m';
    } else {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
  }
}