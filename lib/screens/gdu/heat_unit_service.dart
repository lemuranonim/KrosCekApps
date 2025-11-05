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

  // GDU Thresholds dengan definisi fase yang lebih jelas
  static const Map<String, double> _gduThresholds = {
    'PL': 0.0,
    'V2': 111.1,
    'V4': 191.7,
    'V6': 263.9,
    'V8': 338.9,
    'V10': 411.1,
    'V12': 483.3,
    'V14': 555.6,
    'V16': 630.6,
    'VT': 777.8,
    'R2': 922.2,
    'R4': 1069.4,
    'R5': 1216.7,
    'R5.5': 1361.1,
    'R6': 1500.0,
  };

  // 🆕 Definisi fase utama BERDASARKAN DAP (Days After Planting)
  static const Map<String, Map<String, dynamic>> _mainPhasesByDAP = {
    'Vegetative': {
      'minDAP': 0,
      'maxDAP': 50,
      'color': Colors.green,
      'icon': Icons.eco,
      'description': 'Fase pertumbuhan daun dan batang',
      'minGDU': 0.0,
      'maxGDU': 555.6,
      'idealGDU': 875.0, // 50 DAP × 17.5 GDU/hari
    },
    'Generative': {
      'minDAP': 51,
      'maxDAP': 79,
      'color': Colors.amber,
      'icon': Icons.local_florist,
      'description': 'Fase pembungaan dan penyerbukan',
      'minGDU': 555.6,
      'maxGDU': 922.2,
      'idealGDU': 1382.5, // 79 DAP × 17.5 GDU/hari
    },
    'Pre-Harvest': {
      'minDAP': 80,
      'maxDAP': 99,
      'color': Colors.orange,
      'icon': Icons.grain,
      'description': 'Fase pengisian dan pematangan biji',
      'minGDU': 922.2,
      'maxGDU': 1500.0,
      'idealGDU': 1732.5, // 99 DAP × 17.5 GDU/hari
    },
    'Harvest': {
      'minDAP': 100,
      'maxDAP': 999,
      'color': Colors.brown,
      'icon': Icons.agriculture,
      'description': 'Siap panen - Masak fisiologis',
      'minGDU': 1500.0,
      'maxGDU': double.infinity,
      'idealGDU': 1750.0, // 100 DAP × 17.5 GDU/hari
    },
  };

  // ============================================================================
  // 🆕 FUNGSI FASE BERDASARKAN DAP
  // ============================================================================

  /// Dapatkan nama fase utama berdasarkan DAP
  String getMainPhaseByDAP(int dap) {
    if (dap >= 0 && dap <= 50) {
      return 'Vegetative';
    } else if (dap >= 51 && dap <= 79) {
      return 'Generative';
    } else if (dap >= 80 && dap <= 99) {
      return 'Pre-Harvest';
    } else {
      return 'Harvest';
    }
  }

  /// Dapatkan informasi lengkap fase berdasarkan DAP
  Map<String, dynamic> getMainPhaseInfoByDAP(int dap, double cumulativeGDU) {
    final phaseName = getMainPhaseByDAP(dap);
    final phaseInfo = Map<String, dynamic>.from(_mainPhasesByDAP[phaseName]!);
    phaseInfo['name'] = phaseName;

    final minDAP = phaseInfo['minDAP'] as int;
    final maxDAP = phaseInfo['maxDAP'] as int;

    // Hitung progress dalam fase saat ini berdasarkan DAP
    if (maxDAP == 999) {
      phaseInfo['progress'] = 100.0;
    } else {
      final progress = ((dap - minDAP) / (maxDAP - minDAP) * 100).clamp(0.0, 100.0);
      phaseInfo['progress'] = progress;
    }

    phaseInfo['dapInPhase'] = dap - minDAP;
    phaseInfo['dapToNextPhase'] = maxDAP == 999 ? 0 : maxDAP - dap + 1;

    // Tambahkan info GDU untuk validasi
    phaseInfo['currentGDU'] = cumulativeGDU;
    phaseInfo['idealGDU'] = dap * _avgDailyGDU;
    phaseInfo['gduRange'] = '${phaseInfo['minGDU']?.toStringAsFixed(0) ?? '0'} - ${phaseInfo['maxGDU'] == double.infinity ? '∞' : phaseInfo['maxGDU']?.toStringAsFixed(0) ?? '0'}';

    // Status sinkronisasi DAP vs GDU
    final expectedPhaseByGDU = getMainPhaseByGDU(cumulativeGDU);
    phaseInfo['isSynced'] = expectedPhaseByGDU == phaseName;
    phaseInfo['expectedPhaseByGDU'] = expectedPhaseByGDU;

    // Hitung deviasi GDU dari ideal
    final idealGDU = dap * _avgDailyGDU;
    final gduDeviation = ((cumulativeGDU - idealGDU) / idealGDU * 100);
    phaseInfo['gduDeviation'] = gduDeviation;

    // Status akumulasi GDU
    if (gduDeviation >= 10) {
      phaseInfo['gduStatus'] = 'Ahead'; // GDU lebih tinggi (cuaca panas)
    } else if (gduDeviation <= -10) {
      phaseInfo['gduStatus'] = 'Behind'; // GDU lebih rendah (cuaca dingin)
    } else {
      phaseInfo['gduStatus'] = 'On Track'; // GDU sesuai ekspektasi
    }

    return phaseInfo;
  }

  /// Dapatkan nama fase berdasarkan GDU (untuk cross-check)
  String getMainPhaseByGDU(double cumulativeGDU) {
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

  /// 🆕 Cek apakah tanaman sudah keluar dari fase berdasarkan DAP
  bool isOutOfPhaseByDAP(int currentDAP, String targetPhase) {
    final currentPhase = getMainPhaseByDAP(currentDAP);

    final phaseOrder = ['Vegetative', 'Generative', 'Pre-Harvest', 'Harvest'];
    final currentIndex = phaseOrder.indexOf(currentPhase);
    final targetIndex = phaseOrder.indexOf(targetPhase);

    return currentIndex > targetIndex;
  }

  /// 🆕 Dapatkan pesan rekomendasi jika tanaman sudah keluar dari fase
  String? getPhaseTransitionMessageByDAP(int currentDAP, double currentGDU, String currentScreenPhase) {
    if (!isOutOfPhaseByDAP(currentDAP, currentScreenPhase)) {
      return null; // Masih dalam fase yang sesuai
    }

    final actualPhase = getMainPhaseByDAP(currentDAP);
    final phaseByGDU = getMainPhaseByGDU(currentGDU);

    // Cek sinkronisasi DAP vs GDU
    final isSynced = actualPhase == phaseByGDU;
    final syncInfo = isSynced
        ? ''
        : ' (GDU menunjukkan fase: $phaseByGDU - ${currentGDU.toStringAsFixed(0)}°C)';

    switch (actualPhase) {
      case 'Generative':
        return '⚠️ Tanaman telah memasuki fase Generative (DAP: $currentDAP)$syncInfo. '
            'Disarankan untuk memindahkan monitoring ke screen Generative untuk tracking yang lebih akurat.';

      case 'Pre-Harvest':
        return '⚠️ Tanaman telah memasuki fase Pre-Harvest (DAP: $currentDAP)$syncInfo. '
            'Segera pindahkan ke monitoring Pre-Harvest untuk memantau pematangan biji.';

      case 'Harvest':
        return '🎉 Tanaman telah mencapai masa panen (DAP: $currentDAP)$syncInfo. '
            'Siap untuk dipanen! Pindahkan ke screen Harvest.';

      default:
        return null;
    }
  }

  // ============================================================================
  // API & CALCULATION FUNCTIONS
  // ============================================================================

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

  // ============================================================================
  // GDU & CHU STATUS FUNCTIONS
  // ============================================================================

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
    // 🆕 Alert berdasarkan DAP dan GDU
    final expectedGDU = dap * _avgDailyGDU;
    final gduDeviation = ((gdu - expectedGDU) / expectedGDU * 100);

    // Alert jika GDU terlalu rendah
    if (gduDeviation < -30) {
      return '⚠️ Heat Deficit Kritis: Pertumbuhan sangat tertinggal karena suhu rendah';
    } else if (gduDeviation < -20) {
      return '⚠️ Heat Deficit: Pertumbuhan tertinggal karena suhu rendah';
    }

    // Alert berdasarkan fase DAP
    final currentPhase = getMainPhaseByDAP(dap);

    if (currentPhase == 'Vegetative' && dap > 35 && gdu < _gduThresholds['V12']!) {
      return '⚠️ Slow Growth: Pertumbuhan lambat untuk umur $dap hari';
    }

    if (currentPhase == 'Generative' && dap > 60 && gdu < _gduThresholds['VT']!) {
      return '⚠️ Development Delay: Fase flowering terlambat untuk umur $dap hari';
    }

    if (currentPhase == 'Pre-Harvest' && dap > 90 && gdu < _gduThresholds['R5']!) {
      return '⚠️ Maturity Delay: Perkembangan biji terlambat untuk umur $dap hari';
    }

    return null;
  }

  DateTime? estimateHarvestDate(
      DateTime plantingDate,
      double currentGDU,
      int currentDAP,
      ) {
    const int targetDAP = 100;
    const double targetGDU = 1750.0;

    if (currentDAP <= 0) return null;

    // ✅ Langsung return tanpa variable tidak perlu
    if (currentDAP < targetDAP) {
      return plantingDate.add(Duration(days: targetDAP));
    }

    // Jika sudah lewat 100 DAP, cek status GDU
    if (currentGDU >= targetGDU) {
      return plantingDate.add(Duration(days: currentDAP));
    }

    // Jika GDU belum cukup, estimasi berdasarkan laju GDU aktual
    double actualAvgGDUPerDay = currentGDU / currentDAP;
    if (actualAvgGDUPerDay < 10.0) {
      actualAvgGDUPerDay = _avgDailyGDU;
    }

    double gduRemaining = targetGDU - currentGDU;
    int estimatedDaysRemaining = (gduRemaining / actualAvgGDUPerDay).ceil();

    return plantingDate.add(Duration(days: currentDAP + estimatedDaysRemaining));
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

  // ============================================================================
  // 🆕 HELPER FUNCTIONS FOR DAP-BASED MONITORING
  // ============================================================================

  /// Dapatkan progress fase berdasarkan DAP
  double getPhaseProgressByDAP(int dap) {
    final phaseName = getMainPhaseByDAP(dap);
    final phaseData = _mainPhasesByDAP[phaseName]!;

    final minDAP = phaseData['minDAP'] as int;
    final maxDAP = phaseData['maxDAP'] as int;

    if (maxDAP == 999) {
      return 100.0;
    }

    final progress = ((dap - minDAP) / (maxDAP - minDAP) * 100).clamp(0.0, 100.0);
    return progress;
  }

  /// Dapatkan hari tersisa dalam fase saat ini
  int getDaysRemainingInPhase(int dap) {
    final phaseName = getMainPhaseByDAP(dap);
    final phaseData = _mainPhasesByDAP[phaseName]!;

    final maxDAP = phaseData['maxDAP'] as int;

    if (maxDAP == 999) {
      return 0;
    }

    return (maxDAP - dap + 1).clamp(0, 999);
  }

  /// Dapatkan fase berikutnya
  String? getNextPhase(int dap) {
    final currentPhase = getMainPhaseByDAP(dap);

    final phaseOrder = ['Vegetative', 'Generative', 'Pre-Harvest', 'Harvest'];
    final currentIndex = phaseOrder.indexOf(currentPhase);

    if (currentIndex == -1 || currentIndex >= phaseOrder.length - 1) {
      return null;
    }

    return phaseOrder[currentIndex + 1];
  }

  /// Dapatkan DAP untuk fase berikutnya
  int? getDAPForNextPhase(int dap) {
    final nextPhase = getNextPhase(dap);

    if (nextPhase == null) {
      return null;
    }

    final nextPhaseData = _mainPhasesByDAP[nextPhase]!;
    return nextPhaseData['minDAP'] as int;
  }

  /// Cek apakah GDU dan DAP sinkron
  bool isGDUDAPSynced(double gdu, int dap) {
    final phaseByDAP = getMainPhaseByDAP(dap);
    final phaseByGDU = getMainPhaseByGDU(gdu);
    return phaseByDAP == phaseByGDU;
  }

  /// Dapatkan rekomendasi berdasarkan sinkronisasi GDU-DAP
  String? getGDUDAPSyncRecommendation(double gdu, int dap) {
    if (isGDUDAPSynced(gdu, dap)) {
      return null;
    }

    final phaseByDAP = getMainPhaseByDAP(dap);
    final phaseByGDU = getMainPhaseByGDU(gdu);
    final expectedGDU = dap * _avgDailyGDU;
    final deviation = ((gdu - expectedGDU) / expectedGDU * 100);

    if (deviation > 20) {
      return '🌡️ GDU lebih tinggi dari normal (+${deviation.toStringAsFixed(0)}%). '
          'Cuaca lebih panas, tanaman tumbuh lebih cepat. Fase GDU: $phaseByGDU vs Fase DAP: $phaseByDAP.';
    } else if (deviation < -20) {
      return '❄️ GDU lebih rendah dari normal (${deviation.toStringAsFixed(0)}%). '
          'Cuaca lebih dingin, pertumbuhan lebih lambat. Fase GDU: $phaseByGDU vs Fase DAP: $phaseByDAP.';
    }

    return '📊 Fase berdasarkan DAP ($phaseByDAP) berbeda dengan fase GDU ($phaseByGDU). '
        'Kondisi cuaca mempengaruhi kecepatan pertumbuhan.';
  }

  /// Dapatkan milestone berdasarkan DAP
  List<Map<String, dynamic>> getMilestonesByDAP(int currentDAP, double currentGDU) {
    final milestones = [
      {'name': 'Akhir Vegetative', 'dap': 50, 'phase': 'Vegetative'},
      {'name': 'Akhir Generative', 'dap': 79, 'phase': 'Generative'},
      {'name': 'Akhir Pre-Harvest', 'dap': 99, 'phase': 'Pre-Harvest'},
      {'name': 'Target Panen', 'dap': 100, 'phase': 'Harvest'},
    ];

    return milestones.map((milestone) {
      final targetDAP = milestone['dap'] as int;
      final reached = currentDAP >= targetDAP;
      final daysRemaining = reached ? 0 : targetDAP - currentDAP;

      return {
        'name': milestone['name'],
        'phase': milestone['phase'],
        'targetDAP': targetDAP,
        'reached': reached,
        'daysRemaining': daysRemaining,
        'description': _getPhaseDescription(milestone['phase'] as String),
      };
    }).toList();
  }

  String _getPhaseDescription(String phase) {
    final phaseData = _mainPhasesByDAP[phase];
    return phaseData?['description'] ?? '';
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

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

// ============================================================================
// HEAT UNIT DATA CLASS
// ============================================================================

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

  /// 🆕 Factory untuk membuat HeatUnitData dengan info DAP
  factory HeatUnitData.withDAP({
    required double gdu,
    required double chu,
    required int dap,
    required HeatUnitService service,
    String? alert,
    DateTime? estimatedHarvestDate,
    bool isEstimated = false,
  }) {
    final gduStatus = service.getGDUStatus(gdu, dap);
    final chuStatus = service.getCHUStatus(chu, dap);

    // Tambahkan info fase berdasarkan DAP
    final phaseByDAP = service.getMainPhaseByDAP(dap);
    final phaseByGDU = service.getMainPhaseByGDU(gdu);

    gduStatus['phaseByDAP'] = phaseByDAP;
    gduStatus['phaseByGDU'] = phaseByGDU;
    gduStatus['isSynced'] = phaseByDAP == phaseByGDU;
    gduStatus['dap'] = dap;

    return HeatUnitData(
      gdu: gdu,
      chu: chu,
      gduStatus: gduStatus,
      chuStatus: chuStatus,
      alert: alert,
      estimatedHarvestDate: estimatedHarvestDate,
      isEstimated: isEstimated,
    );
  }

  /// Copy dengan update
  HeatUnitData copyWith({
    double? gdu,
    double? chu,
    Map<String, dynamic>? gduStatus,
    Map<String, dynamic>? chuStatus,
    String? alert,
    DateTime? estimatedHarvestDate,
    bool? isEstimated,
  }) {
    return HeatUnitData(
      gdu: gdu ?? this.gdu,
      chu: chu ?? this.chu,
      gduStatus: gduStatus ?? this.gduStatus,
      chuStatus: chuStatus ?? this.chuStatus,
      alert: alert ?? this.alert,
      estimatedHarvestDate: estimatedHarvestDate ?? this.estimatedHarvestDate,
      isEstimated: isEstimated ?? this.isEstimated,
    );
  }
}

// ============================================================================
// 🆕 EXTENSION HELPERS
// ============================================================================

extension HeatUnitServiceExtensions on HeatUnitService {
  /// Quick check: Apakah tanaman dalam fase yang benar untuk screen tertentu?
  bool isInCorrectScreen(int dap, String screenName) {
    final currentPhase = getMainPhaseByDAP(dap);
    return currentPhase.toLowerCase() == screenName.toLowerCase();
  }

  /// Dapatkan warna fase berdasarkan DAP
  Color getPhaseColor(int dap) {
    final phaseName = getMainPhaseByDAP(dap);
    final phaseData = HeatUnitService._mainPhasesByDAP[phaseName];
    return phaseData?['color'] ?? Colors.grey;
  }

  /// Dapatkan icon fase berdasarkan DAP
  IconData getPhaseIcon(int dap) {
    final phaseName = getMainPhaseByDAP(dap);
    final phaseData = HeatUnitService._mainPhasesByDAP[phaseName];
    return phaseData?['icon'] ?? Icons.help_outline;
  }

  /// Generate summary text untuk fase saat ini
  String getPhaseSummary(int dap, double gdu) {
    final phaseByDAP = getMainPhaseByDAP(dap);
    final phaseByGDU = getMainPhaseByGDU(gdu);
    final daysRemaining = getDaysRemainingInPhase(dap);
    final isSynced = isGDUDAPSynced(gdu, dap);

    String summary = 'Tanaman berada di fase $phaseByDAP ($dap DAP)';

    if (daysRemaining > 0) {
      summary += ', tersisa $daysRemaining hari dalam fase ini';
    }

    if (!isSynced) {
      summary += '. GDU menunjukkan fase: $phaseByGDU';
    }

    return summary;
  }
}