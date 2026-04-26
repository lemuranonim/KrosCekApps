import 'package:flutter/material.dart';

class DapHelper {
  /// Menghitung DAP (Days After Planting) dari string tanggal tanam.
  static int calculateDAP(String? plantingDateString) {
    if (plantingDateString == null || plantingDateString.trim().isEmpty) return 0;
    try {
      DateTime plantingDate;
      if (plantingDateString.contains('/')) {
        final parts = plantingDateString.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year += 2000;
          plantingDate = DateTime(year, month, day);
        } else {
          return 0;
        }
      } else if (plantingDateString.contains('-')) {
        plantingDate = DateTime.parse(plantingDateString);
      } else {
        return 0;
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final plantingDateOnly = DateTime(plantingDate.year, plantingDate.month, plantingDate.day);
      return today.difference(plantingDateOnly).inDays;
    } catch (e) {
      debugPrint('Error calculating DAP: $e');
      return 0;
    }
  }

  /// Menentukan fase yang direkomendasikan berdasarkan batas "On Going" terbaru
  static String getRecommendedPhase(int dap) {
    if (dap <= 35) return 'vegetative';
    if (dap <= 54) return 'generative_1';
    if (dap <= 59) return 'generative_2';
    if (dap <= 65) return 'generative_3';
    if (dap <= 90) return 'pre_harvest';
    return 'harvest';
  }

  /// Badge label berdasarkan rentang fixed dari Manajemen
  static String getDapBadgeLabel(int dap, String phaseKey) {
    switch (phaseKey) {
      case 'vegetative':
        if (dap < 7) return 'Upcoming';
        if (dap <= 35) return 'On Going';
        return 'Overdue';
      case 'generative_1':
        if (dap < 50) return 'Upcoming';
        if (dap <= 54) return 'On Going';
        return 'Overdue';
      case 'generative_2':
        if (dap < 55) return 'Upcoming';
        if (dap <= 59) return 'On Going';
        return 'Overdue';
      case 'generative_3':
        if (dap < 60) return 'Upcoming';
        if (dap <= 65) return 'On Going';
        return 'Overdue';
      case 'pre_harvest':
        if (dap < 71) return 'Upcoming';
        if (dap <= 90) return 'On Going';
        return 'Overdue';
      case 'harvest':
        if (dap < 95) return 'Upcoming';
        if (dap <= 105) return 'On Going';
        return 'Overdue';
      default:
        return 'Unknown';
    }
  }

  /// Warna badge berdasarkan status
  static Color getDapBadgeColor(String badgeLabel) {
    switch (badgeLabel) {
      case 'On Going': return Colors.green.shade600;
      case 'Upcoming': return Colors.blue.shade500;
      case 'Overdue': return Colors.red.shade600;
      default: return Colors.grey;
    }
  }

  /// Menentukan warna marker Peta berdasarkan batas fase (Rekomendasi)
  static Color getDapMarkerColor(int dap) {
    if (dap <= 35) return Colors.grey;            // Vegetative
    if (dap <= 54) return Colors.yellow.shade700; // Gen-1
    if (dap <= 59) return Colors.orange;          // Gen-2
    if (dap <= 65) return Colors.red;             // Gen-3
    if (dap <= 90) return Colors.brown;           // Pre-Harvest
    return Colors.green;                          // Harvest
  }
}