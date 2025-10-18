import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ConfigManager {
  static Map<String, String> regions = {};
  static bool _isInitialized = false; // ✅ Track status inisialisasi

  /// Muat konfigurasi dari Firestore
  static Future<void> loadConfig() async {
    if (_isInitialized) {
      debugPrint("ConfigManager already initialized");
      return;
    }

    try {
      debugPrint("Loading ConfigManager from Firestore...");

      // ✅ Tambahkan timeout untuk menghindari hang
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('regions')
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: Gagal terhubung ke Firestore dalam 10 detik');
        },
      );

      if (snapshot.exists) {
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        regions = data.map((key, value) => MapEntry(key, value.toString()));
        _isInitialized = true;
        debugPrint("ConfigManager loaded successfully: ${regions.length} regions");
      } else {
        debugPrint("WARNING: Document 'config/regions' tidak ditemukan di Firestore");
        throw Exception("Document 'config/regions' tidak ditemukan");
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error loading configurations: $e");
      debugPrint("Stack trace: $stackTrace");
      // ✅ Jangan throw error, biarkan app tetap jalan dengan data kosong
      regions = {};
      _isInitialized = false;
      rethrow; // Re-throw untuk ditangani di level atas
    }
  }

  /// Ambil Spreadsheet ID berdasarkan nama region
  static String? getSpreadsheetId(String region) {
    if (!_isInitialized) {
      debugPrint("WARNING: ConfigManager belum diinisialisasi!");
      return null;
    }
    return regions[region];
  }

  /// Ambil semua Spreadsheet ID
  static List<String> getAllSpreadsheetIds() {
    return regions.values.toList();
  }

  /// Ambil semua nama region
  static List<String> getAllRegionNames() {
    return regions.keys.toList();
  }

  /// Reset konfigurasi (berguna untuk testing atau reload)
  static void reset() {
    regions = {};
    _isInitialized = false;
  }
}