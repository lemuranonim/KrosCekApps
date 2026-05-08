import 'package:flutter/material.dart';

import 'active_phase_filter.dart';

class DapPhaseRule {
  final String key;
  final int phaseStart;

  /// Batas akhir fase inspeksi, termasuk masa overdue yang masih
  /// dihitung sebagai fase tersebut untuk warna marker/filter.
  final int phaseEnd;
  final int onGoingStart;
  final int onGoingEnd;
  final Color markerColor;

  const DapPhaseRule({
    required this.key,
    required this.phaseStart,
    required this.phaseEnd,
    required this.onGoingStart,
    required this.onGoingEnd,
    required this.markerColor,
  });

  bool containsPhaseDap(int dap) => dap >= phaseStart && dap <= phaseEnd;
  bool containsOnGoingDap(int dap) => dap >= onGoingStart && dap <= onGoingEnd;
}

class DapHelper {
  static const Color _vegetativeColor = Color(0xFF78909C);
  static const Color _generative1Color = Color(0xFFFFCA28);
  static const Color _generative2Color = Color(0xFFFF7043);
  static const Color _generative3Color = Color(0xFFE53935);
  static const Color _generative4Color = Color(0xFF8E24AA);
  static const Color _generative5Color = Color(0xFFD81B60);
  static const Color _preHarvestColor = Color(0xFF795548);
  static const Color _harvestColor = Color(0xFF43A047);

  static const List<DapPhaseRule> _fcRules = [
    DapPhaseRule(
      key: 'vegetative',
      phaseStart: 0,
      phaseEnd: 49,
      onGoingStart: 7,
      onGoingEnd: 35,
      markerColor: _vegetativeColor,
    ),
    DapPhaseRule(
      key: 'generative_1',
      phaseStart: 50,
      phaseEnd: 54,
      onGoingStart: 50,
      onGoingEnd: 54,
      markerColor: _generative1Color,
    ),
    DapPhaseRule(
      key: 'generative_2',
      phaseStart: 55,
      phaseEnd: 59,
      onGoingStart: 55,
      onGoingEnd: 59,
      markerColor: _generative2Color,
    ),
    DapPhaseRule(
      key: 'generative_3',
      phaseStart: 60,
      phaseEnd: 70,
      onGoingStart: 60,
      onGoingEnd: 65,
      markerColor: _generative3Color,
    ),
    DapPhaseRule(
      key: 'pre_harvest',
      phaseStart: 71,
      phaseEnd: 94,
      onGoingStart: 71,
      onGoingEnd: 90,
      markerColor: _preHarvestColor,
    ),
    DapPhaseRule(
      key: 'harvest',
      phaseStart: 95,
      phaseEnd: 105,
      onGoingStart: 95,
      onGoingEnd: 105,
      markerColor: _harvestColor,
    ),
  ];

  static const List<DapPhaseRule> _scRules = [
    DapPhaseRule(
      key: 'vegetative',
      phaseStart: 0,
      phaseEnd: 39,
      onGoingStart: 7,
      onGoingEnd: 25,
      markerColor: _vegetativeColor,
    ),
    DapPhaseRule(
      key: 'generative_1',
      phaseStart: 40,
      phaseEnd: 47,
      onGoingStart: 40,
      onGoingEnd: 47,
      markerColor: _generative1Color,
    ),
    DapPhaseRule(
      key: 'generative_2',
      phaseStart: 48,
      phaseEnd: 50,
      onGoingStart: 48,
      onGoingEnd: 50,
      markerColor: _generative2Color,
    ),
    DapPhaseRule(
      key: 'generative_3',
      phaseStart: 51,
      phaseEnd: 53,
      onGoingStart: 51,
      onGoingEnd: 53,
      markerColor: _generative3Color,
    ),
    DapPhaseRule(
      key: 'generative_4',
      phaseStart: 54,
      phaseEnd: 56,
      onGoingStart: 54,
      onGoingEnd: 56,
      markerColor: _generative4Color,
    ),
    DapPhaseRule(
      key: 'generative_5',
      phaseStart: 57,
      phaseEnd: 59,
      onGoingStart: 57,
      onGoingEnd: 60,
      markerColor: _generative5Color,
    ),
    DapPhaseRule(
      key: 'pre_harvest',
      phaseStart: 60,
      phaseEnd: 89,
      onGoingStart: 60,
      onGoingEnd: 89,
      markerColor: _preHarvestColor,
    ),
    DapPhaseRule(
      key: 'harvest',
      phaseStart: 90,
      phaseEnd: 100,
      onGoingStart: 90,
      onGoingEnd: 100,
      markerColor: _harvestColor,
    ),
  ];

  /// Menghitung DAP (Days After Planting) dari string tanggal tanam.
  static int calculateDAP(String? plantingDateString) {
    if (plantingDateString == null || plantingDateString.trim().isEmpty) {
      return 0;
    }
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
      final plantingDateOnly =
          DateTime(plantingDate.year, plantingDate.month, plantingDate.day);
      return today.difference(plantingDateOnly).inDays;
    } catch (e) {
      debugPrint('Error calculating DAP: $e');
      return 0;
    }
  }

  /// Helper untuk cek apakah hybrid adalah Sweet Corn
  static bool isSweetCorn(String? hybrid) {
    final h = hybrid?.toUpperCase().trim() ?? '';
    return ['AX01', 'AX02', 'AX03', 'AX04'].contains(h);
  }

  static List<DapPhaseRule> getPhaseRules({String? hybrid}) {
    return isSweetCorn(hybrid) ? _scRules : _fcRules;
  }

  static DapPhaseRule? getPhaseRule(String phaseKey, {String? hybrid}) {
    for (final rule in getPhaseRules(hybrid: hybrid)) {
      if (rule.key == phaseKey) return rule;
    }
    return null;
  }

  /// Menentukan fase rekomendasi dari DAP.
  ///
  /// Untuk FC, phaseEnd sudah mencakup masa overdue yang masih dihitung
  /// sebagai fase tersebut:
  /// Veg 0-49, Gen1 50-54, Gen2 55-59, Gen3 60-70,
  /// Pre-Harvest 71-94, Harvest 95-105+ DAP.
  ///
  /// Untuk SC, rule mengikuti jadwal:
  /// Veg 7-39, Gen1 40-47, Gen2 48-50, Gen3 51-53, Gen4 54-56,
  /// Gen5 57-59, Pre-Harvest 60-89, Harvest 90-100 DAP.
  static String getRecommendedPhase(int dap, {String? hybrid}) {
    final rules = getPhaseRules(hybrid: hybrid);
    for (final rule in rules) {
      if (dap <= rule.phaseEnd) return rule.key;
    }
    return 'harvest';
  }

  static ActivePhaseView getActivePhaseView(int dap, {String? hybrid}) {
    final phaseKey = getRecommendedPhase(dap, hybrid: hybrid);
    return phaseKeyToView(phaseKey);
  }

  static ActivePhaseView phaseKeyToView(String phaseKey) {
    switch (phaseKey) {
      case 'vegetative':
      case 'generative_1':
      case 'generative_2':
      case 'generative_3':
      case 'generative_4':
      case 'generative_5':
      case 'pre_harvest':
      case 'harvest':
        break;
      default:
        return ActivePhaseView.auto;
    }

    if (phaseKey == 'vegetative') return ActivePhaseView.vegetative;
    if (phaseKey.startsWith('generative_')) return ActivePhaseView.generative;
    if (phaseKey == 'pre_harvest') return ActivePhaseView.preHarvest;
    return ActivePhaseView.harvest;
  }

  static bool isDapInPhaseView(
    int dap,
    ActivePhaseView phase, {
    String? hybrid,
  }) {
    if (phase == ActivePhaseView.auto) return true;
    final rules = getPhaseRules(hybrid: hybrid);

    bool matchesRule(DapPhaseRule rule) {
      switch (phase) {
        case ActivePhaseView.vegetative:
          return rule.key == 'vegetative';
        case ActivePhaseView.generative:
          return rule.key.startsWith('generative_');
        case ActivePhaseView.preHarvest:
          return rule.key == 'pre_harvest';
        case ActivePhaseView.harvest:
          return rule.key == 'harvest';
        case ActivePhaseView.auto:
          return true;
      }
    }

    for (final rule in rules.where(matchesRule)) {
      if (rule.containsPhaseDap(dap)) return true;
    }
    return phase == ActivePhaseView.harvest && dap > rules.last.phaseEnd;
  }

  static List<List<int>> getOperationalRanges(
    ActivePhaseView phase, {
    String? hybrid,
  }) {
    final rules = getPhaseRules(hybrid: hybrid);

    bool matchesRule(DapPhaseRule rule) {
      switch (phase) {
        case ActivePhaseView.auto:
          return true;
        case ActivePhaseView.vegetative:
          return rule.key == 'vegetative';
        case ActivePhaseView.generative:
          return rule.key.startsWith('generative_');
        case ActivePhaseView.preHarvest:
          return rule.key == 'pre_harvest';
        case ActivePhaseView.harvest:
          return rule.key == 'harvest';
      }
    }

    return rules
        .where(matchesRule)
        .map((rule) => [rule.phaseStart, rule.phaseEnd])
        .toList(growable: false);
  }

  static List<int> getPhaseLimits({String? hybrid}) {
    return getPhaseRules(hybrid: hybrid)
        .map((rule) => rule.phaseEnd)
        .toList(growable: false);
  }

  static List<String> getPhaseShortLabels({String? hybrid}) {
    final labels = <String, String>{
      'vegetative': 'Veg',
      'generative_1': 'G1',
      'generative_2': 'G2',
      'generative_3': 'G3',
      'generative_4': 'G4',
      'generative_5': 'G5',
      'pre_harvest': 'Pre-H',
      'harvest': 'Harvest',
    };

    return getPhaseRules(hybrid: hybrid)
        .map((rule) => labels[rule.key] ?? rule.key)
        .toList(growable: false);
  }

  /// Badge label berdasarkan prioritas status:
  /// Done > On Going > Upcoming > Overdue.
  static String getDapBadgeLabel(
    int dap,
    String phaseKey, {
    String? hybrid,
    bool isDone = false,
  }) {
    if (isDone) return 'Done';

    final rule = getPhaseRule(phaseKey, hybrid: hybrid);
    if (rule == null) return 'Unknown';

    if (rule.containsOnGoingDap(dap)) return 'On Going';
    if (dap < rule.onGoingStart) return 'Upcoming';
    return 'Overdue';
  }

  /// Warna badge berdasarkan status
  static Color getDapBadgeColor(String badgeLabel) {
    switch (badgeLabel) {
      case 'Done':
        return Colors.green.shade700;
      case 'On Going':
        return Colors.green.shade600;
      case 'Upcoming':
        return Colors.blue.shade500;
      case 'Overdue':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  /// Menentukan warna marker Peta berdasarkan batas fase (Rekomendasi)
  static Color getDapMarkerColor(int dap, {String? hybrid}) {
    final phaseKey = getRecommendedPhase(dap, hybrid: hybrid);
    return getPhaseRule(phaseKey, hybrid: hybrid)?.markerColor ?? _harvestColor;
  }
}
