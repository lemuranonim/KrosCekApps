import 'dart:convert';
import 'package:flutter/services.dart';

class ConfigManager {
  static Map<String, String> regions = {};

  /// Muat konfigurasi dari file JSON
  static Future<void> loadConfig() async {
    try {
      final String configData = await rootBundle.loadString('assets/config.json');
      regions = Map<String, String>.from(jsonDecode(configData)['regions']);
    } catch (e) {
      // print("Error loading configurations: $e");
    }
  }

  /// Ambil Spreadsheet ID berdasarkan nama region
  static String? getSpreadsheetId(String region) {
    return regions[region];
  }
}
