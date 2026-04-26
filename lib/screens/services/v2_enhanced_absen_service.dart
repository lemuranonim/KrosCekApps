import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CACHE MANAGER (Tetap dipertahankan agar aplikasi tidak bolak-balik query DB)
// ============================================================================
class AbsenCacheManager {
  static const String _cacheValidityKey = 'absen_cache_validity';
  static const Duration _cacheValidityDuration = Duration(hours: 2);

  static Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString(_cacheValidityKey);

    if (lastUpdate == null) return false;

    final lastUpdateTime = DateTime.parse(lastUpdate);
    final now = DateTime.now();

    return now.difference(lastUpdateTime) < _cacheValidityDuration;
  }

  static Future<void> setCacheValidity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheValidityKey, DateTime.now().toIso8601String());
  }

  // ✅ SOLUSI ERROR 3: Menambahkan fungsi markAbsenAction
  // Fungsi ini dipanggil ketika user baru saja selesai absen
  static Future<void> markAbsenAction() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setBool('cachedHasAbsen_$today', true);
    await setCacheValidity();
    debugPrint("[AbsenCache] ✅ Action marked as completed");
  }

  static Future<void> invalidateCache() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await prefs.remove(_cacheValidityKey);
    await prefs.remove('cachedHasAbsen_$today');
    await prefs.remove('cachedJamAbsen_$today');
    await prefs.remove('cachedRegion_$today');

    debugPrint("[AbsenCache] 🗑️ Cache invalidated");
  }
}

// ============================================================================
// V2 ENHANCED ABSEN SERVICE (SUPABASE VERSION)
// ============================================================================
class V2EnhancedAbsenService {
  static final _supabase = Supabase.instance.client;

  /// 1. CEK STATUS ABSEN HARI INI
  static Future<Map<String, dynamic>> checkAbsenStatus({
    required String userEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // --- A. Cek Cache Lokal Dulu ---
      if (await AbsenCacheManager.isCacheValid()) {
        final hasAbsen = prefs.getBool('cachedHasAbsen_$today');
        if (hasAbsen != null) {
          debugPrint("[V2 AbsenService] ⚡ Memuat dari Cache");
          return {
            'hasAbsen': hasAbsen,
            'jamAbsen': prefs.getString('cachedJamAbsen_$today'),
            'region': prefs.getString('cachedRegion_$today'),
            // ✅ SOLUSI LINTER 4: Menambahkan parameter isCache
            'isCache': true,
          };
        }
      }

      // --- B. Query ke Supabase ---
      debugPrint("[V2 AbsenService] 🌐 Query ke Supabase...");

      final response = await _supabase
          .from('absensi_logs')
          .select('waktu_absen, region')
          .eq('user_email', userEmail)
          .eq('tanggal', today)
          .maybeSingle();

      if (response != null) {
        final result = {
          'hasAbsen': true,
          'jamAbsen': response['waktu_absen'].toString().substring(0, 5),
          'region': response['region'],
          'isCache': false, // Karena ini fresh dari DB
        };
        await _saveToCache(prefs, today, result);
        await AbsenCacheManager.setCacheValidity();
        return result;
      } else {
        final result = {'hasAbsen': false, 'isCache': false};
        await _saveToCache(prefs, today, result);
        await AbsenCacheManager.setCacheValidity();
        return result;
      }
    } catch (e) {
      debugPrint("[V2 AbsenService] ❌ Error Check Status: $e");
      return {'hasAbsen': false, 'error': e.toString(), 'isCache': false};
    }
  }

  /// 2. SUBMIT ABSENSI KE SUPABASE
  static Future<Map<String, dynamic>> submitAbsen({
    required String userEmail,
    required String userName,
    required String role,
    required String region,
    required double latitude,
    required double longitude,
    required File image,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timeNow = DateFormat('HH:mm:ss').format(DateTime.now());

      debugPrint("[V2 AbsenService] 📤 Mengunggah foto...");
      final cleanEmail = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = '${cleanEmail}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imagePath = '$today/$fileName';

      await _supabase.storage.from('absensi_photos').upload(imagePath, image);
      final photoUrl = _supabase.storage.from('absensi_photos').getPublicUrl(imagePath);

      debugPrint("[V2 AbsenService] 💾 Menyimpan log absensi...");
      await _supabase.from('absensi_logs').insert({
        'user_email': userEmail,
        'user_name': userName,
        'role': role,
        'region': region,
        'tanggal': today,
        'waktu_absen': timeNow,
        'latitude': latitude,
        'longitude': longitude,
        'photo_url': photoUrl,
      });

      final prefs = await SharedPreferences.getInstance();
      final result = {
        'hasAbsen': true,
        'jamAbsen': timeNow.substring(0, 5),
        'region': region,
      };
      await _saveToCache(prefs, today, result);
      await AbsenCacheManager.setCacheValidity();

      return {
        'success': true,
        'message': 'Absensi berhasil disimpan',
      };
    } catch (e) {
      debugPrint("[V2 AbsenService] ❌ Error Submit Absen: $e");
      return {
        'success': false,
        'message': 'Gagal menyimpan absensi: $e',
      };
    }
  }

  /// 3. PAKSA REFRESH
  static Future<Map<String, dynamic>> forceRefreshStatus({
    required String userEmail,
  }) async {
    await AbsenCacheManager.invalidateCache();
    return await checkAbsenStatus(userEmail: userEmail);
  }

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
    debugPrint("[V2 AbsenService] 💾 Data tersimpan di cache lokal");
  }
}