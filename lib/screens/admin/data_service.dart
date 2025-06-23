import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';
import 'vegetative_audit_data.dart';

class DataService {
  // Cache mechanism
  final Map<String, dynamic> _cache = {};
  final Duration _cacheDuration = Duration(minutes: 15);
  final Map<String, DateTime> _cacheTimestamps = {};

  // Region data
  List<String> _regions = [];
  String _selectedRegion = '';
  String? _spreadsheetId;
  GoogleSheetsApi? _googleSheetsApi;

  Future<void> initialize() async {
    await ConfigManager.loadConfig();
    await _loadRegions();
    await _loadSelectedRegion();
    await _initializeGoogleSheetsApi();
  }

  Future<void> _loadRegions() async {
    try {
      // Get regions from ConfigManager instead of directly from Firestore
      _regions = ConfigManager.getAllRegionNames();
      if (_regions.isNotEmpty && _selectedRegion.isEmpty) {
        _selectedRegion = _regions.first;
      }
    } catch (e) {
      debugPrint('Error loading regions: $e');
      _regions = [];
    }
  }

  Future<void> _loadSelectedRegion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _selectedRegion = prefs.getString('selectedRegion') ?? '';
    if (_selectedRegion.isEmpty && _regions.isNotEmpty) {
      _selectedRegion = _regions.first;
      await prefs.setString('selectedRegion', _selectedRegion);
    }
  }

  Future<void> _initializeGoogleSheetsApi() async {
    if (_selectedRegion.isNotEmpty) {
      _spreadsheetId = ConfigManager.getSpreadsheetId(_selectedRegion);
      if (_spreadsheetId != null && _spreadsheetId!.isNotEmpty) {
        _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
        await _googleSheetsApi!.init();
      }
    }
  }

  Future<void> setSelectedRegion(String region) async {
    if (_selectedRegion == region) return;

    _selectedRegion = region;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedRegion', region);

    // Update spreadsheet ID and Google Sheets API
    _spreadsheetId = ConfigManager.getSpreadsheetId(region);
    if (_spreadsheetId != null && _spreadsheetId!.isNotEmpty) {
      _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
      await _googleSheetsApi!.init();
    } else {
      _googleSheetsApi = null;
    }

    // Clear cache when region changes
    _cache.clear();
    _cacheTimestamps.clear();
  }

  String getSelectedRegion() {
    return _selectedRegion;
  }

  Future<List<String>> getAvailableRegions() async {
    if (_regions.isEmpty) {
      await _loadRegions();
    }
    return _regions;
  }

  Future<Map<String, dynamic>> _fetchWithCache(String key, Future<Map<String, dynamic>> Function() fetchFunction) async {
    // Check if data is in cache and not expired
    if (_cache.containsKey(key) &&
        _cacheTimestamps.containsKey(key) &&
        DateTime.now().difference(_cacheTimestamps[key]!) < _cacheDuration) {
      return _cache[key];
    }

    // Fetch fresh data
    final data = await fetchFunction();

    // Update cache
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();

    return data;
  }

  Future<Map<String, dynamic>> _fetchAbsensiData() async {
    if (_googleSheetsApi == null) {
      return {'error': 'Google Sheets API not initialized'};
    }

    try {
      await _googleSheetsApi!.init();
      final rows = await _googleSheetsApi!.getSpreadsheetData('Absen Log')
          .timeout(const Duration(seconds: 15));

      return _processAbsensiData(rows);
    } catch (e) {
      debugPrint('Error fetching absensi data: $e');
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _fetchAktivitasData() async {
    if (_googleSheetsApi == null) {
      return {'error': 'Google Sheets API not initialized'};
    }

    try {
      await _googleSheetsApi!.init();
      final rows = await _googleSheetsApi!.getSpreadsheetData('Aktivitas')
          .timeout(const Duration(seconds: 15));

      return _processAktivitasData(rows);
    } catch (e) {
      debugPrint('Error fetching aktivitas data: $e');
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _processAbsensiData(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return {
        'absensiList': <AbsensiData>[],
        'statusCounts': <String, int>{},
        'dailyCounts': <String, int>{},
      };
    }

    final List<AbsensiData> absensiList = [];
    final Map<String, int> statusCounts = {};
    final Map<String, int> dailyCounts = {};

    for (int i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.length < 4) continue;

        final name = row[0].toString().trim();
        final dateStr = row[1].toString().trim();
        final timeStr = row[2].toString().trim();
        final location = row[3].toString().trim();

        final date = _parseDate(dateStr);
        final time = _parseTime(timeStr);

        if (date != null && time != null) {
          final absensi = AbsensiData(
            id: i.toString(),
            name: name,
            email: '', // Not available in the data
            region: _selectedRegion,
            district: '', // Not available in the data
            status: 'Masuk', // Default status
            timestamp: DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            ),
            location: location,
          );

          absensiList.add(absensi);

          // Count by status
          statusCounts[absensi.status] = (statusCounts[absensi.status] ?? 0) + 1;

          // Count by date
          final dateKey = DateFormat('yyyy-MM-dd').format(absensi.timestamp);
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      } catch (e) {
        debugPrint('Error parsing absensi row: $e');
      }
    }

    return {
      'absensiList': absensiList,
      'statusCounts': statusCounts,
      'dailyCounts': dailyCounts,
    };
  }

  Map<String, dynamic> _processAktivitasData(List<List<dynamic>> rows) {
    if (rows.isEmpty) {
      return {
        'aktivitasList': <AktivitasData>[],
        'typeCounts': <String, int>{},
        'dailyCounts': <String, int>{},
      };
    }

    final List<AktivitasData> aktivitasList = [];
    final Map<String, int> typeCounts = {};
    final Map<String, int> dailyCounts = {};

    for (int i = 1; i < rows.length; i++) {
      try {
        final row = rows[i];
        if (row.length < 8) continue;

        final email = row[0].toString().trim();
        final name = row[1].toString().trim();
        final status = row[2].toString().trim();
        final region = row[3].toString().trim();
        final aksi = row[4].toString().trim();
        final sheet = row[5].toString().trim();
        final fieldNumber = row[6].toString().trim();
        final timestampStr = row[7].toString().trim();

        final timestamp = _parseDateTime(timestampStr);

        if (timestamp != null && region == _selectedRegion) {
          final aktivitas = AktivitasData(
            id: i.toString(),
            name: name,
            email: email,
            region: region,
            district: '', // Not available in the data
            type: status, // Using status as type
            status: status,
            aksi: aksi,
            sheet: sheet,
            fieldNumber: fieldNumber,
            timestamp: timestamp,
          );

          aktivitasList.add(aktivitas);

          // Count by type
          typeCounts[aktivitas.type] = (typeCounts[aktivitas.type] ?? 0) + 1;

          // Count by date
          final dateKey = DateFormat('yyyy-MM-dd').format(aktivitas.timestamp);
          dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
        }
      } catch (e) {
        debugPrint('Error parsing aktivitas row: $e');
      }
    }

    return {
      'aktivitasList': aktivitasList,
      'typeCounts': typeCounts,
      'dailyCounts': dailyCounts,
    };
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final serial = double.tryParse(dateStr);
      if (serial != null) {
        return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
      }

      final formats = [
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('yyyy-MM-dd'),
      ];

      for (final format in formats) {
        try {
          return format.parse(dateStr);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return null;
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }

      final decimalTime = double.tryParse(timeStr);
      if (decimalTime != null) {
        final totalSeconds = (decimalTime * 86400).round();
        final hour = totalSeconds ~/ 3600;
        final minute = (totalSeconds % 3600) ~/ 60;
        return TimeOfDay(hour: hour, minute: minute);
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return null;
    }
  }

  DateTime? _parseDateTime(String dateTimeStr) {
    try {
      // Try various formats
      final formats = [
        DateFormat('dd/MM/yyyy HH:mm:ss'),
        DateFormat('MM/dd/yyyy HH:mm:ss'),
        DateFormat('yyyy-MM-dd HH:mm:ss'),
        DateFormat('dd/MM/yyyy'),
      ];

      for (final format in formats) {
        try {
          return format.parse(dateTimeStr);
        } catch (_) {}
      }

      // Try Excel serial number format
      final serial = double.tryParse(dateTimeStr);
      if (serial != null) {
        return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing datetime: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getAbsensiSummary() async {
    return await _fetchWithCache('absensi_$_selectedRegion', _fetchAbsensiData);
  }

  Future<Map<String, dynamic>> getAktivitasSummary() async {
    return await _fetchWithCache('aktivitas_$_selectedRegion', _fetchAktivitasData);
  }

  Future<List<AbsensiData>> getAbsensiData() async {
    final data = await getAbsensiSummary();
    return data['absensiList'] ?? [];
  }

  Future<List<AktivitasData>> getAktivitasData() async {
    final data = await getAktivitasSummary();
    return data['aktivitasList'] ?? [];
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final absensiData = await getAbsensiSummary();
    final aktivitasData = await getAktivitasSummary();

    // Get today's date in yyyy-MM-dd format
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Calculate today's counts
    final absensiToday = absensiData['dailyCounts']?[today] ?? 0;
    final aktivitasToday = aktivitasData['dailyCounts']?[today] ?? 0;

    // Calculate total users
    final Set<String> uniqueUsers = {};
    for (var absensi in absensiData['absensiList'] ?? []) {
      if (absensi.email.isNotEmpty) {
        uniqueUsers.add(absensi.email);
      }
    }
    for (var aktivitas in aktivitasData['aktivitasList'] ?? []) {
      if (aktivitas.email.isNotEmpty) {
        uniqueUsers.add(aktivitas.email);
      }
    }

    // Explicitly convert maps to Map<String, dynamic>
    final Map<String, dynamic> absensiStatusCounts =
    Map<String, dynamic>.from(absensiData['statusCounts'] ?? {});
    final Map<String, dynamic> aktivitasTypeCounts =
    Map<String, dynamic>.from(aktivitasData['typeCounts'] ?? {});
    final Map<String, dynamic> absensiDailyCounts =
    Map<String, dynamic>.from(absensiData['dailyCounts'] ?? {});
    final Map<String, dynamic> aktivitasDailyCounts =
    Map<String, dynamic>.from(aktivitasData['dailyCounts'] ?? {});

    return {
      'totalUsers': uniqueUsers.length,
      'absensiToday': absensiToday,
      'aktivitasToday': aktivitasToday,
      'absensiStatusCounts': absensiStatusCounts,
      'aktivitasTypeCounts': aktivitasTypeCounts,
      'absensiDailyCounts': absensiDailyCounts,
      'aktivitasDailyCounts': aktivitasDailyCounts,
    };
  }

  Future<List<FlSpot>> getActivityTrendData() async {
    final aktivitasData = await getAktivitasSummary();
    final dailyCounts = aktivitasData['dailyCounts'] ?? {};

    // Sort dates
    final sortedDates = dailyCounts.keys.toList()..sort();

    // Take last 7 days
    final last7Days = sortedDates.length > 7
        ? sortedDates.sublist(sortedDates.length - 7)
        : sortedDates;

    // Create spots
    List<FlSpot> spots = [];
    for (int i = 0; i < last7Days.length; i++) {
      spots.add(FlSpot(i.toDouble(), (dailyCounts[last7Days[i]] ?? 0).toDouble()));
    }

    return spots;
  }

  Future<List<AktivitasData>> getRecentActivities() async {
    final data = await getAktivitasSummary();
    final List<AktivitasData> activities = data['aktivitasList'] ?? [];

    // Sort by timestamp (newest first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Return top 5
    return activities.take(5).toList();
  }

  Future<void> refreshAllData() async {
    // Clear cache to force refresh
    _cache.clear();
    _cacheTimestamps.clear();

    // Reload data
    await getAbsensiSummary();
    await getAktivitasSummary();
  }

  // Check if the Google Sheets API is properly initialized
  bool isGoogleSheetsApiInitialized() {
    return _googleSheetsApi != null && _spreadsheetId != null && _spreadsheetId!.isNotEmpty;
  }

  // Get the current spreadsheet ID
  String? getSpreadsheetId() {
    return _spreadsheetId;
  }

  // Update the spreadsheet ID and reinitialize the Google Sheets API
  Future<void> updateSpreadsheetId(String? newId) async {
    if (newId == null || newId.isEmpty) {
      _spreadsheetId = null;
      _googleSheetsApi = null;
      return;
    }

    if (_spreadsheetId != newId) {
      _spreadsheetId = newId;
      _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
      await _googleSheetsApi!.init();

      // Clear cache when spreadsheet ID changes
      _cache.clear();
      _cacheTimestamps.clear();
    }
  }

  Future<List<VegetativeAuditData>> getVegetativeAuditData() async {
    List<VegetativeAuditData> allAuditData = [];

    // Ambil semua konfigurasi region dari ConfigManager
    // ConfigManager.regions adalah Map<String, String>
    final Map<String, String> regionConfigs = ConfigManager.regions;

    // Loop melalui setiap region (key = nama region, value = spreadsheetId)
    for (var entry in regionConfigs.entries) {
      final String regionName = entry.key;
      final String spreadsheetId = entry.value;

      try {
        // 1. Buat instance GoogleSheetsApi untuk spreadsheetId saat ini
        final api = GoogleSheetsApi(spreadsheetId);
        await api.init(); // Inisialisasi koneksi

        // 2. Ambil semua data dari worksheet 'Generative'
        // getSpreadsheetData akan mengembalikan List<List<String>>
        final rows = await api.getSpreadsheetData('Generative');

        // 3. Lewati baris header (baris pertama) dan proses sisanya
        if (rows.length > 1) {
          final dataRows = rows.sublist(1); // Ambil semua baris kecuali header

          for (var row in dataRows) {
            // Filter baris yang tidak relevan (misal, tidak punya data week)
            if (row.length > 10 && row[10].isNotEmpty && int.tryParse(row[10]) != null) {
              final auditData = VegetativeAuditData.fromGSheetRow(row);
              allAuditData.add(auditData);
            }
          }
        }
      } catch (e) {
        // Jika terjadi error pada satu region, cetak pesan dan lanjut ke region berikutnya
        debugPrint("Gagal memuat data untuk region '$regionName': $e");
        continue;
      }
    }

    debugPrint("Total data audit vegetatif yang berhasil dimuat: ${allAuditData.length} baris.");
    return allAuditData;
  }
}

class AbsensiData {
  final String id;
  final String name;
  final String email;
  final String region;
  final String district;
  final String status;
  final DateTime timestamp;
  final String location;

  AbsensiData({
    required this.id,
    required this.name,
    required this.email,
    required this.region,
    required this.district,
    required this.status,
    required this.timestamp,
    required this.location,
  });

  String get dateFormatted => DateFormat('dd/MM/yyyy').format(timestamp);
  String get timeFormatted => DateFormat('HH:mm').format(timestamp);

  factory AbsensiData.fromMap(Map<String, dynamic> map) {
    return AbsensiData(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      region: map['region'] ?? '',
      district: map['district'] ?? '',
      status: map['status'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      location: map['location'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'region': region,
      'district': district,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
    };
  }
}

class AktivitasData {
  final String id;
  final String name;
  final String email;
  final String region;
  final String district;
  final String type;
  final String status;
  final String aksi;
  final String sheet;
  final String fieldNumber;
  final DateTime timestamp;

  AktivitasData({
    required this.id,
    required this.name,
    required this.email,
    required this.region,
    required this.district,
    required this.type,
    required this.status,
    required this.aksi,
    required this.sheet,
    required this.fieldNumber,
    required this.timestamp,
  });

  String get dateFormatted => DateFormat('dd/MM/yyyy').format(timestamp);
  String get timeFormatted => DateFormat('HH:mm').format(timestamp);

  factory AktivitasData.fromMap(Map<String, dynamic> map) {
    return AktivitasData(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      region: map['region'] ?? '',
      district: map['district'] ?? '',
      type: map['type'] ?? '',
      status: map['status'] ?? '',
      aksi: map['aksi'] ?? '',
      sheet: map['sheet'] ?? '',
      fieldNumber: map['fieldNumber'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'region': region,
      'district': district,
      'type': type,
      'status': status,
      'aksi': aksi,
      'sheet': sheet,
      'fieldNumber': fieldNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}