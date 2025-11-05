import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'config_manager.dart';

class AbsenSpreadsheetService {

  /// Konversi serial number Google Sheets ke DateTime
  static DateTime? _parseGoogleSheetsDate(String value) {
    try {
      final serialNumber = double.tryParse(value);

      if (serialNumber != null) {
        final baseDate = DateTime(1899, 12, 30);
        final date = baseDate.add(Duration(days: serialNumber.floor()));
        return date;
      }

      try {
        return DateFormat('dd/MM/yyyy').parse(value);
      } catch (e) {
        try {
          return DateFormat('yyyy-MM-dd').parse(value);
        } catch (e2) {
          return null;
        }
      }
    } catch (e) {
      return null;
    }
  }

  /// Konversi decimal Google Sheets ke waktu
  static String? _parseGoogleSheetsTime(String value) {
    try {
      final decimalTime = double.tryParse(value);

      if (decimalTime != null) {
        final totalSeconds = (decimalTime * 24 * 60 * 60).round();
        final hours = (totalSeconds ~/ 3600) % 24;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      if (value.contains(':')) {
        return value;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Cek dengan timeout
  static Future<Map<String, dynamic>> checkAbsenToday({
    required String spreadsheetId,
    required String userName,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // ✅ ADD TIMEOUT untuk skip region yang lambat
      return await Future.any([
        _checkAbsenTodayInternal(spreadsheetId: spreadsheetId, userName: userName),
        Future.delayed(timeout, () => {
          'hasAbsen': false,
          'jamAbsen': null,
          'tanggalAbsen': null,
          'timeout': true,
        }),
      ]);
    } catch (e) {
      debugPrint("[AbsenService] ⚠️ Error: $e");
      return {
        'hasAbsen': false,
        'jamAbsen': null,
        'tanggalAbsen': null,
      };
    }
  }

  static Future<Map<String, dynamic>> _checkAbsenTodayInternal({
    required String spreadsheetId,
    required String userName,
  }) async {
    try {
      const String worksheetName = 'Absen Log';
      final GoogleSheetsApi api = GoogleSheetsApi(spreadsheetId);

      final bool initialized = await api.init();
      if (!initialized) {
        return {
          'hasAbsen': false,
          'jamAbsen': null,
          'tanggalAbsen': null,
        };
      }

      List<List<String>> rows;
      try {
        rows = await api.getSpreadsheetData(worksheetName);
      } catch (e) {
        return {
          'hasAbsen': false,
          'jamAbsen': null,
          'tanggalAbsen': null,
        };
      }

      final DateTime today = DateTime.now();

      // Loop dari bawah ke atas (data terbaru)
      for (int i = rows.length - 1; i >= 0; i--) {
        final List<String> row = rows[i];
        if (row.length < 3) continue;

        final String namaUser = row[0].trim();
        final String tanggalAbsen = row[1].trim();
        final String jamAbsen = row[2].trim();

        if (namaUser.toLowerCase() != userName.toLowerCase()) continue;

        DateTime? absenDate = _parseGoogleSheetsDate(tanggalAbsen);
        if (absenDate == null) continue;

        String? formattedTime = _parseGoogleSheetsTime(jamAbsen);
        formattedTime ??= jamAbsen;

        if (absenDate.day == today.day &&
            absenDate.month == today.month &&
            absenDate.year == today.year) {

          return {
            'hasAbsen': true,
            'jamAbsen': formattedTime,
            'tanggalAbsen': DateFormat('dd/MM/yyyy').format(absenDate),
          };
        }
      }

      return {
        'hasAbsen': false,
        'jamAbsen': null,
        'tanggalAbsen': null,
      };

    } catch (e) {
      return {
        'hasAbsen': false,
        'jamAbsen': null,
        'tanggalAbsen': null,
      };
    }
  }

  /// ✅ OPTIMIZED untuk 32 regions
  static Future<Map<String, dynamic>> checkAbsenAnyRegion({
    required String userName,
    String? lastKnownRegion, // ✅ Prioritas region terakhir
    Function(String region, int current, int total)? onProgress,
  }) async {
    try {
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("[AbsenService] 🔍 CEK ABSEN (AGGRESSIVE MODE - 32 REGIONS)");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

      if (ConfigManager.regions.isEmpty) {
        await ConfigManager.loadConfig();
      }

      Map<String, String> regionSpreadsheetIds = ConfigManager.regions;
      final int totalRegions = regionSpreadsheetIds.length;
      debugPrint("[AbsenService] 📍 Total regions: $totalRegions");

      // ✅ PRIORITIZE last known region
      List<MapEntry<String, String>> entries = regionSpreadsheetIds.entries.toList();

      if (lastKnownRegion != null) {
        final lastIndex = entries.indexWhere((e) => e.key == lastKnownRegion);
        if (lastIndex != -1) {
          final lastEntry = entries.removeAt(lastIndex);
          entries.insert(0, lastEntry);
          debugPrint("[AbsenService] 🎯 Prioritizing last region: $lastKnownRegion");
        }
      }

      // ✅ BATCH SIZE: 5 concurrent requests (safe for 60/min quota)
      const int batchSize = 5;
      int processedCount = 0;

      for (int i = 0; i < entries.length; i += batchSize) {
        final batch = entries.skip(i).take(batchSize).toList();

        debugPrint("[AbsenService] ⚡ Processing batch ${(i ~/ batchSize) + 1}/${(entries.length / batchSize).ceil()}");

        // Run batch in parallel dengan timeout
        final futures = batch.map((entry) {
          return checkAbsenToday(
            spreadsheetId: entry.value,
            userName: userName,
            timeout: const Duration(seconds: 8), // ✅ Timeout 8 detik per region
          ).then((result) => MapEntry(entry.key, result));
        }).toList();

        final results = await Future.wait(futures);

        // Check results
        for (int j = 0; j < results.length; j++) {
          final entry = results[j];
          processedCount++;

          // Skip if timeout
          if (entry.value['timeout'] == true) {
            debugPrint("[AbsenService] ⏱️ Timeout: ${entry.key}");
            onProgress?.call(entry.key, processedCount, totalRegions);
            continue;
          }

          onProgress?.call(entry.key, processedCount, totalRegions);

          if (entry.value['hasAbsen'] == true) {
            debugPrint("[AbsenService] ✅ FOUND at: ${entry.key}");
            debugPrint("[AbsenService] ⚡ Total checked: $processedCount/$totalRegions");
            debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

            return {
              ...entry.value,
              'region': entry.key,
            };
          }
        }

        // ✅ MINIMAL DELAY: 300ms between batches (balance speed vs quota)
        if (i + batchSize < entries.length) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      debugPrint("[AbsenService] ℹ️ Not found in any region");
      debugPrint("[AbsenService] ⚡ Total checked: $processedCount/$totalRegions");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

      return {
        'hasAbsen': false,
        'jamAbsen': null,
        'tanggalAbsen': null,
        'region': null,
      };

    } catch (e) {
      debugPrint("[AbsenService] ❌ ERROR: $e");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

      return {
        'hasAbsen': false,
        'jamAbsen': null,
        'tanggalAbsen': null,
        'region': null,
      };
    }
  }
}