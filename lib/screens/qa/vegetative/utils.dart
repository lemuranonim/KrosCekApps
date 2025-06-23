import 'package:flutter/material.dart';

// Utility functions shared across tabs
String formatPercentage(int part, int total) {
  if (total == 0) return '0.0';
  return ((part / total) * 100).toStringAsFixed(1);
}

String getValue(List<String> row, int index, String defaultValue) {
  if (row.isEmpty || index >= row.length) return defaultValue;
  return row[index];
}

int calculateDAP(List<String> row) {
  try {
    final plantingDate = getValue(row, 9, ''); // Get planting date from column 9
    if (plantingDate.isEmpty) return 0;

    // Try to parse as Excel date number
    final parsedNumber = double.tryParse(plantingDate);
    if (parsedNumber != null) {
      final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
      final today = DateTime.now();
      return today.difference(date).inDays;
    } else {
      // Try to parse as formatted date
      try {
        final parts = plantingDate.split('/');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]) ?? 1;
          final month = int.tryParse(parts[1]) ?? 1;
          final year = int.tryParse(parts[2]) ?? DateTime.now().year;

          final date = DateTime(year, month, day);
          final today = DateTime.now();
          return today.difference(date).inDays;
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }
    return 0;
  } catch (e) {
    return 0;
  }
}

String getLastVisitText(String fieldNumber, Map<String, List<DateTime>> activityTimestamps) {
  // Get the list of timestamps for this field
  final timestamps = activityTimestamps[fieldNumber];

  // If no timestamps, return "No data"
  if (timestamps == null || timestamps.isEmpty) {
    return "Mboten wonten data";
  }

  // Get the most recent timestamp (already sorted in _loadActivityData)
  final lastVisit = timestamps.first;

  return getTimeAgo(lastVisit);
}

String getTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  // Format based on how long ago the visit was
  if (difference.inDays == 0) {
    // Today
    if (difference.inHours == 0) {
      if (difference.inMinutes < 5) {
        return "Baru saja";
      } else {
        // Minutes ago
        return "${difference.inMinutes} menit yang lalu";
      }
    } else {
      // Hours ago
      return "${difference.inHours} jam yang lalu";
    }
  } else if (difference.inDays == 1) {
    // Yesterday
    return "Kemarin";
  } else if (difference.inDays < 7) {
    // Within a week
    return "${difference.inDays} hari yang lalu";
  } else if (difference.inDays < 30) {
    // Within a month
    final weeks = (difference.inDays / 7).floor();
    return "$weeks minggu yang lalu";
  } else if (difference.inDays < 365) {
    // Within a year
    final months = (difference.inDays / 30).floor();
    return "$months bulan yang lalu";
  } else {
    // More than a year
    final years = (difference.inDays / 365).floor();
    return "$years tahun yang lalu";
  }
}

Color getActivityCountColor(int count) {
  if (count == 0) return Colors.grey.shade300;
  if (count == 1) return Colors.blue.shade300;
  if (count == 2) return Colors.green.shade400;
  if (count == 3) return Colors.amber.shade400;
  if (count <= 5) return Colors.orange.shade500;
  return Colors.red.shade500;
}

Color getHeatmapColor(int count) {
  if (count == 0) return Colors.grey.shade200;
  if (count == 1) return Colors.blue.shade200;
  if (count == 2) return Colors.green.shade300;
  if (count == 3) return Colors.amber.shade300;
  if (count <= 5) return Colors.orange.shade400;
  return Colors.red.shade500;
}

class ParsedDistrictInfo {
  final String baseName; // Contoh: "Kediri"
  final String originalType; // Contoh: "Kabupaten" atau "Kota"
  final String? gadmTypeName; // Untuk mencocokkan dengan ENGTYPE_2 di GADM, contoh: "Regency" atau "City"

  ParsedDistrictInfo({
    required this.baseName,
    required this.originalType,
    this.gadmTypeName,
  });
}

ParsedDistrictInfo parseSpreadsheetDistrictName(String spreadsheetDistrictName) {
  String name = spreadsheetDistrictName.trim();
  String type = "";
  String? gadmType;

  if (name.toLowerCase().startsWith("kabupaten ")) {
    type = "Kabupaten";
    name = name.substring("kabupaten ".length).trim();
    gadmType = "Regency"; // Sesuai ENGTYPE_2 GADM
  } else if (name.toLowerCase().startsWith("kota ")) {
    type = "Kota";
    name = name.substring("kota ".length).trim();
    gadmType = "City"; // Sesuai ENGTYPE_2 GADM
  }
  // Tambahkan kondisi lain jika ada format awalan yang berbeda

  // Normalisasi tambahan jika diperlukan (misalnya, menghapus spasi ganda, dll.)
  // name = name.replaceAll(RegExp(r'\s+'), ' '); // Contoh: normalisasi spasi

  return ParsedDistrictInfo(
    baseName: name, // Nama dasar, contoh: "Kediri"
    originalType: type, // Tipe dari spreadsheet, contoh: "Kabupaten"
    gadmTypeName: gadmType, // Tipe yang akan dicocokkan dengan GADM
  );
}

