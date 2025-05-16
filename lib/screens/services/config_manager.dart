import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigManager {
  static Map<String, String> regions = {};

  /// Muat konfigurasi dari Firestore
  static Future<void> loadConfig() async {
    try {
      // Ambil data dari Firestore
      DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('config').doc('regions').get();

      if (snapshot.exists) {
        // Mengonversi data menjadi Map<String, String>
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        // Directly convert the document data to Map<String, String>
        // since each field is a region name with spreadsheet ID as value
        regions = data.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      // print("Error loading configurations: $e");
    }
  }

  /// Ambil Spreadsheet ID berdasarkan nama region
  static String? getSpreadsheetId(String region) {
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
}