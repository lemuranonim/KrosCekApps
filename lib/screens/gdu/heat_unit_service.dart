import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HeatUnitService {
  static const int _cacheDurationHours = 24;
  static const double _baseTemp = 10.0;
  static const double _maxTempCap = 30.0;
  static const double _avgDailyGDU = 17.5;
  static const double _avgDailyCHU = 22.0;

  static DateTime? _lastApiCall;
  static const int _minApiCallIntervalMs = 100;

  // 🆕 GDU Thresholds dengan definisi fase yang lebih jelas
  static const Map<String, double> _gduThresholds = {
    'PL': 0.0,
    'V2': 111.1,
    'V4': 191.7,
    'V6': 263.9,
    'V8': 338.9,
    'V10': 411.1,
    'V12': 483.3,
    'V14': 555.6,    // ← Batas akhir Vegetative
    'V16': 630.6,
    'VT': 777.8,     // ← Batas akhir Generative
    'R2': 922.2,     // ← Batas akhir penyerbukan
    'R4': 1069.4,
    'R5': 1216.7,
    'R5.5': 1361.1,  // ← Batas akhir Pre-Harvest
    'R6': 1500.0,    // ← Harvest (Masak Fisiologis)
  };

  // 🆕 Definisi fase utama dengan range GDU yang jelas
  static const Map<String, Map<String, dynamic>> _mainPhases = {
    'Vegetative': {
      'minGDU': 0.0,
      'maxGDU': 555.6,
      'color': Colors.green,
      'icon': Icons.eco,
      'description': 'Fase pertumbuhan daun dan batang',
    },
    'Generative': {
      'minGDU': 555.6,
      'maxGDU': 922.2,
      'color': Colors.amber,
      'icon': Icons.local_florist,
      'description': 'Fase pembungaan dan penyerbukan',
    },
    'Pre-Harvest': {
      'minGDU': 922.2,
      'maxGDU': 1500.0,
      'color': Colors.orange,
      'icon': Icons.grain,
      'description': 'Fase pengisian dan pematangan biji',
    },
    'Harvest': {
      'minGDU': 1500.0,
      'maxGDU': double.infinity,
      'color': Colors.brown,
      'icon': Icons.agriculture,
      'description': 'Siap panen - Masak fisiologis',
    },
  };

  /// 🆕 Dapatkan nama fase utama berdasarkan GDU kumulatif
  String getMainPhase(double cumulativeGDU) {
    if (cumulativeGDU < 555.6) {
      return 'Vegetative';
    } else if (cumulativeGDU < 922.2) {
      return 'Generative';
    } else if (cumulativeGDU < 1500.0) {
      return 'Pre-Harvest';
    } else {
      return 'Harvest';
    }
  }

  /// 🆕 Dapatkan informasi lengkap fase utama
  Map<String, dynamic> getMainPhaseInfo(double cumulativeGDU) {
    final phaseName = getMainPhase(cumulativeGDU);
    final phaseInfo = Map<String, dynamic>.from(_mainPhases[phaseName]!);
    phaseInfo['name'] = phaseName;

    // Hitung progress dalam fase saat ini
    final minGDU = phaseInfo['minGDU'] as double;
    final maxGDU = phaseInfo['maxGDU'] as double;

    if (maxGDU == double.infinity) {
      phaseInfo['progress'] = 100.0;
    } else {
      final progress = ((cumulativeGDU - minGDU) / (maxGDU - minGDU) * 100).clamp(0.0, 100.0);
      phaseInfo['progress'] = progress;
    }

    phaseInfo['gduInPhase'] = cumulativeGDU - minGDU;
    phaseInfo['gduToNextPhase'] = maxGDU == double.infinity ? 0.0 : maxGDU - cumulativeGDU;

    return phaseInfo;
  }

  /// 🆕 Cek apakah tanaman sudah keluar dari fase tertentu
  bool isOutOfPhase(double cumulativeGDU, String targetPhase) {
    final currentPhase = getMainPhase(cumulativeGDU);

    // Urutan fase: Vegetative -> Generative -> Pre-Harvest -> Harvest
    final phaseOrder = ['Vegetative', 'Generative', 'Pre-Harvest', 'Harvest'];
    final currentIndex = phaseOrder.indexOf(currentPhase);
    final targetIndex = phaseOrder.indexOf(targetPhase);

    return currentIndex > targetIndex;
  }

  /// 🆕 Dapatkan pesan rekomendasi jika tanaman sudah keluar dari fase
  String? getPhaseTransitionMessage(double cumulativeGDU, String currentScreenPhase) {
    if (!isOutOfPhase(cumulativeGDU, currentScreenPhase)) {
      return null; // Masih dalam fase yang sesuai
    }

    final actualPhase = getMainPhase(cumulativeGDU);

    switch (actualPhase) {
      case 'Generative':
        return '⚠️ Tanaman telah memasuki fase Generative (GDU: ${cumulativeGDU.toStringAsFixed(0)}°C). '
            'Disarankan untuk memindahkan monitoring ke screen Generative untuk tracking yang lebih akurat.';

      case 'Pre-Harvest':
        return '⚠️ Tanaman telah memasuki fase Pre-Harvest (GDU: ${cumulativeGDU.toStringAsFixed(0)}°C). '
            'Segera pindahkan ke monitoring Pre-Harvest untuk memantau pematangan biji.';

      case 'Harvest':
        return '🎉 Tanaman telah mencapai masak fisiologis (GDU: ${cumulativeGDU.toStringAsFixed(0)}°C). '
            'Siap untuk dipanen! Pindahkan ke screen Harvest.';

      default:
        return null;
    }
  }

  Future<void> _throttleApiCall() async {
    if (_lastApiCall != null) {
      final timeSinceLastCall = DateTime.now().difference(_lastApiCall!).inMilliseconds;
      if (timeSinceLastCall < _minApiCallIntervalMs) {
        final waitTime = _minApiCallIntervalMs - timeSinceLastCall;
        await Future.delayed(Duration(milliseconds: waitTime));
      }
    }
    _lastApiCall = DateTime.now();
  }

  double _calculateGDU(double maxTemp, double minTemp) {
    double cappedMax = min(maxTemp, _maxTempCap);
    double cappedMin = max(minTemp, _baseTemp);
    double avgTemp = (cappedMax + cappedMin) / 2;
    double gdu = avgTemp - _baseTemp;
    return max(gdu, 0.0);
  }

  double _calculateCHU(double maxTemp, double minTemp) {
    double yMax = 1.8 * (maxTemp - 10.0);
    double yMin = 3.33 * (minTemp - 4.4);
    yMax = max(yMax, 0.0);
    yMin = max(yMin, 0.0);
    return max((yMax + yMin) / 2, 0.0);
  }

  Future<Map<String, double>> fetchHistoricalHeatUnits({
    required double latitude,
    required double longitude,
    required DateTime plantingDate,
  }) async {
    try {
      final today = DateTime.now();

      if (plantingDate.isAfter(today) || _isSameDay(plantingDate, today)) {
        return {'gdu': 0.0, 'chu': 0.0};
      }

      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        throw Exception('Invalid coordinates');
      }

      final cacheKey = _getCacheKey(latitude, longitude, plantingDate);
      final cachedData = await _loadFromCache(cacheKey);
      if (cachedData != null) {
        return cachedData;
      }

      final maxHistoricalDate = today.subtract(const Duration(days: 180));
      final effectivePlantingDate = plantingDate.isBefore(maxHistoricalDate)
          ? maxHistoricalDate
          : plantingDate;

      final startDate = DateFormat('yyyy-MM-dd').format(effectivePlantingDate);
      final endDate = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));

      await _throttleApiCall();

      final now = DateTime.now();
      final daysAgo = now.difference(plantingDate).inDays;

      String url;
      if (daysAgo <= 7) {
        url = 'https://api.open-meteo.com/v1/forecast?'
            'latitude=${latitude.toStringAsFixed(6)}&'
            'longitude=${longitude.toStringAsFixed(6)}&'
            'daily=temperature_2m_max,temperature_2m_min&'
            'past_days=$daysAgo&'
            'timezone=auto';
      } else {
        url = 'https://archive-api.open-meteo.com/v1/archive?'
            'latitude=${latitude.toStringAsFixed(6)}&'
            'longitude=${longitude.toStringAsFixed(6)}&'
            'start_date=$startDate&'
            'end_date=$endDate&'
            'daily=temperature_2m_max,temperature_2m_min&'
            'timezone=auto';
      }

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['daily'] == null ||
            data['daily']['temperature_2m_max'] == null ||
            data['daily']['temperature_2m_min'] == null) {
          throw Exception('No temperature data available');
        }

        final result = _processHistoricalData(data);
        await _saveToCache(cacheKey, result);
        return result;
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } on TimeoutException {
      return _estimateHeatUnits(plantingDate);
    } on SocketException {
      return _estimateHeatUnits(plantingDate);
    } catch (e) {
      debugPrint('Error fetching historical heat units: $e');
      return _estimateHeatUnits(plantingDate);
    }
  }

  Map<String, double> _processHistoricalData(Map<String, dynamic> data) {
    try {
      final maxTemps = List<double>.from(
          data['daily']['temperature_2m_max'].map((e) => e?.toDouble() ?? 0.0)
      );
      final minTemps = List<double>.from(
          data['daily']['temperature_2m_min'].map((e) => e?.toDouble() ?? 0.0)
      );

      double totalGDU = 0.0;
      double totalCHU = 0.0;

      for (int i = 0; i < maxTemps.length; i++) {
        if (maxTemps[i] == 0.0 && minTemps[i] == 0.0) continue;
        totalGDU += _calculateGDU(maxTemps[i], minTemps[i]);
        totalCHU += _calculateCHU(maxTemps[i], minTemps[i]);
      }

      return {'gdu': totalGDU, 'chu': totalCHU};
    } catch (e) {
      return {'gdu': 0.0, 'chu': 0.0};
    }
  }

  Map<String, double> _estimateHeatUnits(DateTime plantingDate) {
    final today = DateTime.now();
    final dap = today.difference(plantingDate).inDays;

    if (dap <= 0) {
      return {'gdu': 0.0, 'chu': 0.0};
    }

    return {
      'gdu': dap * _avgDailyGDU,
      'chu': dap * _avgDailyCHU,
    };
  }

  Map<String, dynamic> getGDUStatus(double cumulativeGDU, int dap) {
    if (cumulativeGDU < _gduThresholds['V2']!) {
      return {
        'status': 'PL - Ditanam',
        'phase': 'PL',
        'color': Colors.brown[300],
        'icon': Icons.eco,
        'description': 'Benih ditanam di dalam tanah',
        'mainPhase': 'Vegetative',
        'expectedDays': '0-3 hari',
        'nextMilestone': 'V2 - 2 Helai Daun',
        'gduToNext': _gduThresholds['V2']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V4']!) {
      return {
        'status': 'V2 - 2 Helai Daun',
        'phase': 'V2',
        'color': Colors.lightGreen[300],
        'icon': Icons.spa,
        'description': 'Dua helai daun pertama telah sepenuhnya terbuka',
        'mainPhase': 'Vegetative',
        'expectedDays': '3-7 hari',
        'nextMilestone': 'V4 - 4 Helai Daun',
        'gduToNext': _gduThresholds['V4']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V6']!) {
      return {
        'status': 'V4 - 4 Helai Daun',
        'phase': 'V4',
        'color': Colors.lightGreen[400],
        'icon': Icons.park,
        'description': 'Empat helai daun telah terbuka',
        'mainPhase': 'Vegetative',
        'expectedDays': '7-12 hari',
        'nextMilestone': 'V6 - 6 Helai Daun',
        'gduToNext': _gduThresholds['V6']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V8']!) {
      return {
        'status': 'V6 - 6 Helai Daun',
        'phase': 'V6',
        'color': Colors.green[400],
        'icon': Icons.grass,
        'description': 'Titik tumbuh muncul ke atas permukaan tanah',
        'mainPhase': 'Vegetative',
        'expectedDays': '12-17 hari',
        'nextMilestone': 'V8 - 8 Helai Daun',
        'gduToNext': _gduThresholds['V8']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V10']!) {
      return {
        'status': 'V8 - 8 Helai Daun',
        'phase': 'V8',
        'color': Colors.green[500],
        'icon': Icons.energy_savings_leaf,
        'description': 'Malai mulai berkembang di dalam batang',
        'mainPhase': 'Vegetative',
        'expectedDays': '17-22 hari',
        'nextMilestone': 'V10 - 10 Helai Daun',
        'gduToNext': _gduThresholds['V10']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V12']!) {
      return {
        'status': 'V10 - 10 Helai Daun',
        'phase': 'V10',
        'color': Colors.green[600],
        'icon': Icons.trending_up,
        'description': 'Fase pertumbuhan sangat cepat',
        'mainPhase': 'Vegetative',
        'expectedDays': '22-28 hari',
        'nextMilestone': 'V12 - 12 Helai Daun',
        'gduToNext': _gduThresholds['V12']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V14']!) {
      return {
        'status': 'V12 - 12 Helai Daun',
        'phase': 'V12',
        'color': Colors.green[700],
        'icon': Icons.agriculture,
        'description': 'Tongkol utama mulai terbentuk dan berkembang',
        'mainPhase': 'Vegetative',
        'expectedDays': '28-35 hari',
        'nextMilestone': 'V14 - 14 Helai Daun',
        'gduToNext': _gduThresholds['V14']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['V16']!) {
      return {
        'status': 'V14 - 14 Helai Daun',
        'phase': 'V14',
        'color': Colors.amber[400],
        'icon': Icons.nature,
        'description': 'Rambut jagung (silk) mulai berkembang di dalam tongkol',
        'mainPhase': 'Generative',
        'expectedDays': '35-42 hari',
        'nextMilestone': 'V16 - 16 Helai Daun',
        'gduToNext': _gduThresholds['V16']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['VT']!) {
      return {
        'status': 'V16 - 16 Helai Daun',
        'phase': 'V16',
        'color': Colors.amber[500],
        'icon': Icons.emoji_nature,
        'description': 'Malai mulai terlihat di ujung pucuk tanaman',
        'mainPhase': 'Generative',
        'expectedDays': '42-50 hari',
        'nextMilestone': 'VT - Keluar Malai',
        'gduToNext': _gduThresholds['VT']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['R2']!) {
      return {
        'status': 'VT - Keluar Malai',
        'phase': 'VT',
        'color': Colors.orange[400],
        'icon': Icons.local_florist,
        'description': 'Malai keluar, penyerbukan terjadi (serbuk sari jatuh ke rambut)',
        'mainPhase': 'Generative',
        'expectedDays': '50-60 hari',
        'nextMilestone': 'R2 - Biji Bembung',
        'gduToNext': _gduThresholds['R2']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['R4']!) {
      return {
        'status': 'R2 - Biji Bembung',
        'phase': 'R2',
        'color': Colors.orange[500],
        'icon': Icons.bubble_chart,
        'description': 'Biji terbentuk awal, berisi cairan bening (blister)',
        'mainPhase': 'Pre-Harvest',
        'expectedDays': '60-70 hari',
        'nextMilestone': 'R4 - Lembek',
        'gduToNext': _gduThresholds['R4']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['R5']!) {
      return {
        'status': 'R4 - Lembek',
        'phase': 'R4',
        'color': Colors.orange[600],
        'icon': Icons.water_drop,
        'description': 'Isi biji berubah seperti pasta/adonan lembek (dough)',
        'mainPhase': 'Pre-Harvest',
        'expectedDays': '70-80 hari',
        'nextMilestone': 'R5 - Biji Bergigi',
        'gduToNext': _gduThresholds['R5']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['R5.5']!) {
      return {
        'status': 'R5 - Biji Bergigi',
        'phase': 'R5',
        'color': Colors.deepOrange[500],
        'icon': Icons.grain,
        'description': 'Biji mulai membentuk ceruk/lekukan (denting start)',
        'mainPhase': 'Pre-Harvest',
        'expectedDays': '80-90 hari',
        'nextMilestone': 'R5.5 - Biji Bergigi Penuh',
        'gduToNext': _gduThresholds['R5.5']! - cumulativeGDU,
      };
    } else if (cumulativeGDU < _gduThresholds['R6']!) {
      return {
        'status': 'R5.5 - Biji Bergigi Penuh',
        'phase': 'R5.5',
        'color': Colors.deepOrange[600],
        'icon': Icons.stars,
        'description': 'Lekukan pada biji telah sepenuhnya terbentuk (full dent)',
        'mainPhase': 'Pre-Harvest',
        'expectedDays': '90-100 hari',
        'nextMilestone': 'R6 - Masak Fisiologis',
        'gduToNext': _gduThresholds['R6']! - cumulativeGDU,
      };
    } else {
      return {
        'status': 'R6 - Masak Fisiologis',
        'phase': 'R6',
        'color': Colors.brown[600],
        'icon': Icons.celebration,
        'description': 'Kematangan penuh, biji keras, siap dipanen',
        'mainPhase': 'Harvest',
        'expectedDays': '100-110 hari',
        'nextMilestone': 'Panen Sekarang',
        'gduToNext': 0.0,
      };
    }
  }

  Map<String, dynamic> getCHUStatus(double cumulativeCHU, int dap) {
    double targetCHU = dap * _avgDailyCHU;
    double percentage = (cumulativeCHU / targetCHU * 100).clamp(0, 150);

    if (percentage >= 90) {
      return {
        'status': 'Optimal',
        'color': Colors.green,
        'percentage': percentage,
        'description': 'Akumulasi panas sangat baik',
        'icon': Icons.check_circle,
      };
    } else if (percentage >= 70) {
      return {
        'status': 'Good',
        'color': Colors.lightGreen,
        'percentage': percentage,
        'description': 'Akumulasi panas baik',
        'icon': Icons.thumb_up,
      };
    } else if (percentage >= 50) {
      return {
        'status': 'Fair',
        'color': Colors.orange,
        'percentage': percentage,
        'description': 'Akumulasi panas cukup - Perhatian',
        'icon': Icons.warning,
      };
    } else {
      return {
        'status': 'Low',
        'color': Colors.red,
        'percentage': percentage,
        'description': 'Akumulasi panas rendah - Tindakan diperlukan',
        'icon': Icons.error,
      };
    }
  }

  String? checkHeatUnitAlert(double gdu, double chu, int dap) {
    double expectedGDU = dap * 12.0;

    if (gdu < expectedGDU * 0.7) {
      return '⚠️ Heat Deficit: Pertumbuhan tertinggal karena suhu rendah';
    }

    if (dap > 35 && gdu < _gduThresholds['V12']!) {
      return '⚠️ Slow Growth: GDU rendah untuk umur $dap hari';
    }

    if (dap > 60 && gdu < _gduThresholds['VT']!) {
      return '⚠️ Development Delay: Fase flowering terlambat';
    }

    if (dap > 90 && gdu < _gduThresholds['R5']!) {
      return '⚠️ Maturity Delay: Perkembangan biji terlambat';
    }

    return null;
  }

  DateTime? estimateHarvestDate(
      DateTime plantingDate,
      double currentGDU,
      int currentDAP,
      ) {
    const double targetGDU = 1500.0;

    if (currentDAP <= 0 || currentGDU <= 0) {
      return null;
    }

    double actualAvgGDUPerDay = currentGDU / currentDAP;

    if (actualAvgGDUPerDay < 5.0) {
      actualAvgGDUPerDay = _avgDailyGDU;
    }

    int totalEstimatedDaysToHarvest = (targetGDU / actualAvgGDUPerDay).round();

    return plantingDate.add(Duration(days: totalEstimatedDaysToHarvest));
  }

  double getPhaseProgress(double cumulativeGDU) {
    final status = getGDUStatus(cumulativeGDU, 0);
    final phase = status['phase'] as String;

    final thresholdKeys = _gduThresholds.keys.toList();
    final currentIndex = thresholdKeys.indexOf(phase);

    if (currentIndex == -1 || currentIndex == thresholdKeys.length - 1) {
      return 100.0;
    }

    final currentThreshold = _gduThresholds[phase]!;
    final nextThreshold = _gduThresholds[thresholdKeys[currentIndex + 1]]!;
    final range = nextThreshold - currentThreshold;
    final progress = cumulativeGDU - currentThreshold;

    return ((progress / range) * 100).clamp(0, 100);
  }

  String _getCacheKey(double latitude, double longitude, DateTime plantingDate) {
    final latStr = latitude.toStringAsFixed(4);
    final lonStr = longitude.toStringAsFixed(4);
    final dateStr = DateFormat('yyyy-MM-dd').format(plantingDate);
    return 'heat_units_${latStr}_${lonStr}_$dateStr';
  }

  Future<Map<String, double>?> _loadFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(key);

      if (cachedData != null) {
        final data = json.decode(cachedData);
        final cachedTime = DateTime.parse(data['timestamp']);

        if (DateTime.now().difference(cachedTime).inHours < _cacheDurationHours) {
          return {
            'gdu': data['gdu'] as double,
            'chu': data['chu'] as double,
          };
        }
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
    }
    return null;
  }

  Future<void> _saveToCache(String key, Map<String, double> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'gdu': data['gdu'],
        'chu': data['chu'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(key, json.encode(cacheData));
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('heat_units_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}

class HeatUnitData {
  final double gdu;
  final double chu;
  final Map<String, dynamic> gduStatus;
  final Map<String, dynamic> chuStatus;
  final String? alert;
  final DateTime? estimatedHarvestDate;
  final bool isEstimated;

  HeatUnitData({
    required this.gdu,
    required this.chu,
    required this.gduStatus,
    required this.chuStatus,
    this.alert,
    this.estimatedHarvestDate,
    this.isEstimated = false,
  });

  factory HeatUnitData.empty() {
    return HeatUnitData(
      gdu: 0.0,
      chu: 0.0,
      gduStatus: {
        'status': 'Unknown',
        'phase': 'Unknown',
        'color': Colors.grey,
        'icon': Icons.help_outline,
        'description': 'Data tidak tersedia',
        'mainPhase': '-',
        'expectedDays': '-',
        'nextMilestone': '-',
        'gduToNext': 0.0,
      },
      chuStatus: {
        'status': 'Unknown',
        'color': Colors.grey,
        'percentage': 0.0,
        'description': 'Data tidak tersedia',
        'icon': Icons.help_outline,
      },
      isEstimated: true,
    );
  }
}