import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class AbsensiDashboard extends StatefulWidget {
  const AbsensiDashboard({super.key});

  @override
  State<AbsensiDashboard> createState() => _AbsensiDashboardState();
}

class _AbsensiDashboardState extends State<AbsensiDashboard> {
  List<AbsensiData> _absensiData = [];
  List<AbsensiData> _filteredData = [];
  // String _searchQuery = '';
  String _selectedFilter = 'Semua';
  String _selectedRegion = '';
  bool _isLoading = false;
  // late Box _absensiBox;

  final List<String> _filterOptions = ['Semua', 'Hari Ini', 'Minggu Ini', 'Bulan Ini'];
  String? _spreadsheetId;
  // Dibuat menjadi Map untuk handle multi-region
  final Map<String, GoogleSheetsApi> _apiInstances = {};

  @override
  void initState() {
    super.initState();
    _initializeApp().catchError((e) {
      _showErrorMessage('Gagal inisialisasi: ${e.toString()}');
    });
  }

  Future<void> _initializeApp() async {
    try {
      // await _initializeHive();
      await _initializeServices();
    } catch (e) {
      debugPrint('Initialization error: $e');
      rethrow;
    }
  }

  // Future<void> _initializeHive() async {
  //   try {
  //     _absensiBox = await Hive.openBox('absensiData');
  //   } catch (e) {
  //     debugPrint('Error initializing Hive: $e');
  //   }
  // }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await ConfigManager.loadConfig();
  }

  Future<void> _determineSpreadsheetId(String region) async {
    if (region.isEmpty || region == 'Semua Region') {
      setState(() => _spreadsheetId = null);
      return;
    }
    final newId = ConfigManager.getSpreadsheetId(region);
    if (newId == null || newId.isEmpty) {
      throw Exception("Spreadsheet ID untuk region $region tidak ditemukan");
    }
    _spreadsheetId = newId;
    if (!_apiInstances.containsKey(region)) {
      _apiInstances[region] = GoogleSheetsApi(_spreadsheetId!);
    }
  }

  // Mengambil data untuk satu region
  Future<List<AbsensiData>> _fetchSingleRegionData(String region) async {
    await _determineSpreadsheetId(region);
    final api = _apiInstances[region];
    if (api == null) return [];

    await api.init();
    final rows = await api.getSpreadsheetData('Absen Log').timeout(const Duration(seconds: 20));
    final absensiList = <AbsensiData>[];
    for (final row in rows.skip(1)) {
      try {
        if (row.length < 4) continue;
        final name = row[0].toString().trim();
        final dateStr = row[1].toString().trim();
        final timeStr = row[2].toString().trim();
        final location = row[3].toString().trim();
        final date = _parseDate(dateStr);
        final time = _parseTime(timeStr);
        if (date != null && time != null) {
          // Tambahkan 'region' ke data
          absensiList.add(AbsensiData(name: name, date: date, time: time, location: location, region: region));
        }
      } catch (e) {
        debugPrint('Error parsing row for region $region: $e');
      }
    }
    return absensiList;
  }

  // Fungsi baru untuk mengambil data semua region
  Future<void> _fetchAllRegionsData() async {
    final allData = <AbsensiData>[];
    final regions = ConfigManager.regions.keys;

    // Menggunakan Future.wait untuk mengambil data secara paralel
    final List<Future<List<AbsensiData>>> futures = [];
    for (final region in regions) {
      futures.add(_fetchSingleRegionData(region));
    }

    final results = await Future.wait(futures);
    for (final regionData in results) {
      allData.addAll(regionData);
    }

    if (mounted) {
      setState(() {
        _absensiData = allData;
        _filterData();
      });
    }
  }

  void _filterData() {
    final now = DateTime.now();
    _absensiData.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    _filteredData = _absensiData.where((data) {
      // final matchesSearch = data.name.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesFilter = true;
      if (_selectedFilter == 'Hari Ini') {
        matchesFilter = data.date.day == now.day && data.date.month == now.month && data.date.year == now.year;
      } else if (_selectedFilter == 'Minggu Ini') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        matchesFilter = !data.date.isBefore(startOfWeek) && !data.date.isAfter(endOfWeek);
      } else if (_selectedFilter == 'Bulan Ini') {
        matchesFilter = data.date.month == now.month && data.date.year == now.year;
      }
      return matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) => context.go('/admin'),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/admin')),
          title: const Text('Absensi Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          actions: [if (_selectedRegion.isNotEmpty) IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _handleRefresh)],
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildRegionDropdown(),
            const SizedBox(height: 10),
            if (_selectedRegion.isNotEmpty) _buildControlSection(),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedRegion.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Silakan pilih region terlebih dahulu', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    if (!_isLoading && _filteredData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Tidak ada data untuk ditampilkan', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return _buildBoxPlotChart();
  }

  Widget _buildBoxPlotChart() {
    final chartData = _prepareChartData();
    if (chartData.isEmpty) return const SizedBox.shrink(); // Jangan tampilkan jika data kosong

    String chartTitle;
    if (_selectedRegion == 'Semua Region') {
      chartTitle = 'Analisis Waktu Absensi per Region';
    } else {
      chartTitle = 'Analisis Waktu Absensi Region $_selectedRegion';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withAlpha(51), spreadRadius: 2, blurRadius: 5, offset: const Offset(0, 3))],
      ),
      child: SfCartesianChart(
        title: ChartTitle(text: chartTitle, textStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 16)),
        primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0), labelStyle: TextStyle(fontWeight: FontWeight.w500)),
        primaryYAxis: NumericAxis(
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            final double value = details.value.toDouble();
            final int hours = value.truncate();
            final int minutes = ((value - hours) * 60).round();
            final String formattedTime = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
            return ChartAxisLabel(formattedTime, details.textStyle);
          },
          interval: 2, minimum: 5, maximum: 17,
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
        series: <CartesianSeries>[
          BoxAndWhiskerSeries<_BoxPlotChartData, String>(
            dataSource: chartData,
            name: 'Waktu Absen',
            xValueMapper: (_BoxPlotChartData data, _) => data.category,
            yValueMapper: (_BoxPlotChartData data, _) => data.checkInTimes,
            boxPlotMode: BoxPlotMode.normal,
            color: Colors.green.shade400,
          )
        ],
        tooltipBehavior: TooltipBehavior(enable: true),
      ),
    );
  }

  // ✅ DROPDOWN DENGAN OPSI 'Semua Region'
  Widget _buildRegionDropdown() {
    // Buat daftar region dengan 'Semua Region' di atas
    final List<String> regionItems = ['Semua Region', ...ConfigManager.regions.keys];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: Text('Pilih Region', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          value: _selectedRegion.isEmpty ? null : _selectedRegion,
          items: regionItems.map((String region) {
            return DropdownMenuItem<String>(value: region, child: Text(region));
          }).toList(),
          onChanged: _handleRegionChange,
        ),
      ),
    );
  }

  // ✅ LOGIKA BARU UNTUK MENANGANI PERUBAHAN REGION
  Future<void> _handleRegionChange(String? value) async {
    if (value == null || value == _selectedRegion) return;

    setState(() {
      _isLoading = true;
      _selectedRegion = value;
      _absensiData.clear();
      _filteredData.clear();
      _selectedFilter = 'Semua';
    });

    try {
      if (value == 'Semua Region') {
        await _fetchAllRegionsData();
      } else {
        await _determineSpreadsheetId(value);
        final data = await _fetchSingleRegionData(value);
        if (mounted) {
          setState(() {
            _absensiData = data;
            _filterData();
          });
        }
      }
    } catch (e) {
      _showErrorMessage('Gagal memuat data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Logika untuk tombol refresh
  Future<void> _handleRefresh() async {
    await _handleRegionChange(_selectedRegion);
  }

  Widget _buildControlSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  items: _filterOptions.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFilter = value;
                        _filterData();
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          // const SizedBox(width: 10),
          // Expanded(
          //   child: TextField(
          //     onChanged: (value) {
          //       setState(() {
          //         _searchQuery = value;
          //         _filterData();
          //       });
          //     },
          //     decoration: InputDecoration(
          //       hintText: 'Cari nama...',
          //       prefixIcon: const Icon(Icons.search),
          //       border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          //       filled: true,
          //       fillColor: Colors.grey.shade200,
          //       contentPadding: const EdgeInsets.symmetric(vertical: 0),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  // ✅ LOGIKA PERSIAPAN DATA CHART YANG ADAPTIF
  List<_BoxPlotChartData> _prepareChartData() {
    if (_filteredData.isEmpty) return [];

    // Jika 'Semua Region' dipilih, kelompokkan berdasarkan region
    if (_selectedRegion == 'Semua Region') {
      final groupedByRegion = groupBy(_filteredData, (AbsensiData data) => data.region);
      final chartData = groupedByRegion.entries.map((entry) {
        final regionName = entry.key;
        final checkInTimes = entry.value.map((data) => data.time.hour + data.time.minute / 60.0).toList();
        return _BoxPlotChartData(regionName, checkInTimes);
      }).toList();
      // Urutkan berdasarkan nama region
      chartData.sort((a,b) => a.category.compareTo(b.category));
      return chartData;
    }
    // Jika satu region dipilih, kelompokkan berdasarkan bulan (logika lama)
    else {
      const monthNames = {1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'Mei', 6: 'Jun', 7: 'Jul', 8: 'Ags', 9: 'Sep', 10: 'Okt', 11: 'Nov', 12: 'Des'};
      final groupedByMonth = groupBy(_filteredData, (AbsensiData data) => '${data.date.year}-${data.date.month}');
      final chartData = groupedByMonth.entries.map((entry) {
        final year = entry.key.split('-')[0];
        final month = int.parse(entry.key.split('-')[1]);
        final monthName = monthNames[month] ?? '';
        final checkInTimes = entry.value.map((data) => data.time.hour + data.time.minute / 60.0).toList();
        return _BoxPlotChartData('$monthName\n$year', checkInTimes);
      }).toList();
      chartData.sort((a,b) {
        final aParts = a.category.split('\n'); final bParts = b.category.split('\n');
        final aYear = int.parse(aParts[1]); final bYear = int.parse(bParts[1]);
        if (aYear != bYear) return aYear.compareTo(bYear);
        final aMonth = monthNames.entries.firstWhere((e) => e.value == aParts[0]).key;
        final bMonth = monthNames.entries.firstWhere((e) => e.value == bParts[0]).key;
        return aMonth.compareTo(bMonth);
      });
      return chartData;
    }
  }

  // Helper functions
  DateTime? _parseDate(String dateStr) {
    try {
      final serial = double.tryParse(dateStr);
      if (serial != null) return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
      final formats = [DateFormat('dd/MM/yyyy'), DateFormat('MM/dd/yyyy'), DateFormat('yyyy-MM-dd')];
      for (final format in formats) {
        try { return format.parse(dateStr); } catch (_) {}
      }
    } catch (e) { debugPrint('Error parsing date: $e'); }
    return null;
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      final decimalTime = double.tryParse(timeStr);
      if (decimalTime != null) {
        final totalSeconds = (decimalTime * 86400).round();
        return TimeOfDay(hour: totalSeconds ~/ 3600, minute: (totalSeconds % 3600) ~/ 60);
      }
    } catch (e) { debugPrint('Error parsing time: $e'); }
    return null;
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
  }

  // Caching tidak diimplementasikan untuk 'Semua Region' untuk menjaga kesederhanaan
  // Future<void> _saveDataToCache(List<AbsensiData> data) async {
  //   //
  // }
}

// ✅ Class data untuk chart diubah agar lebih generik
class _BoxPlotChartData {
  _BoxPlotChartData(this.category, this.checkInTimes);
  final String category; // Sebelumnya 'month', kini menjadi 'category'
  final List<double> checkInTimes;
}

// ✅ Class data absensi ditambah properti 'region'
class AbsensiData {
  final String name;
  final DateTime date;
  final TimeOfDay time;
  final String location;
  final String region; // Properti baru

  AbsensiData({
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.region, // Ditambahkan di constructor
  });

  DateTime get dateTime => DateTime(date.year, date.month, date.day, time.hour, time.minute);
  String get dateFormatted => DateFormat('dd/MM/yyyy').format(date);
  String get timeFormatted => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  // toMap dan fromMap bisa disesuaikan jika caching 'Semua Region' diperlukan
  Map<String, dynamic> toMap() => {'name': name, 'date': date.millisecondsSinceEpoch, 'hour': time.hour, 'minute': time.minute, 'location': location, 'region': region};

  factory AbsensiData.fromMap(Map<String, dynamic> map) {
    return AbsensiData(
      name: map['name'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      time: TimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int),
      location: map['location'] as String,
      region: map['region'] as String? ?? '', // Handle jika data lama tidak punya region
    );
  }
}