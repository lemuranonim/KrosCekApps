import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/config_manager.dart';

class AbsensiDashboard extends StatefulWidget {
  const AbsensiDashboard({super.key});

  @override
  State<AbsensiDashboard> createState() => _AbsensiDashboardState();
}

class _AbsensiDashboardState extends State<AbsensiDashboard> {
  List<AbsensiData> _absensiData = [];
  List<AbsensiData> _filteredData = [];
  String _selectedFilter = 'Semua';
  String _selectedRegion = '';
  bool _isLoading = false;

  final List<String> _filterOptions = ['Semua', 'Hari Ini', 'Minggu Ini', 'Bulan Ini'];

  @override
  void initState() {
    super.initState();
    _initializeApp().catchError((e) {
      _showErrorMessage('Gagal inisialisasi: ${e.toString()}');
    });
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeServices();
    } catch (e) {
      debugPrint('Initialization error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await ConfigManager.loadConfig();
  }

  // Fetch data dari Firestore untuk satu region
  Future<List<AbsensiData>> _fetchSingleRegionData(String region) async {
    try {
      final now = DateTime.now();
      final startDate = _getStartDateByFilter();

      final querySnapshot = await FirebaseFirestore.instance
          .collection('absen_logs')
          .where('region', isEqualTo: region)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThan: DateTime(now.year, now.month, now.day + 1))
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(const Duration(seconds: 20));

      final absensiList = <AbsensiData>[];
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp).toDate();

          absensiList.add(AbsensiData(
            name: data['userName'] ?? '',
            date: timestamp,
            time: TimeOfDay(hour: timestamp.hour, minute: timestamp.minute),
            location: data['location'] ?? '',
            region: region,
          ));
        } catch (e) {
          debugPrint('Error parsing document for region $region: $e');
        }
      }
      return absensiList;
    } catch (e) {
      debugPrint('Error fetching data for region $region: $e');
      return [];
    }
  }

  // Fetch data dari Firestore untuk semua region
  Future<void> _fetchAllRegionsData() async {
    try {
      final now = DateTime.now();
      final startDate = _getStartDateByFilter();

      final querySnapshot = await FirebaseFirestore.instance
          .collection('absen_logs')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThan: DateTime(now.year, now.month, now.day + 1))
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(const Duration(seconds: 30));

      final absensiList = <AbsensiData>[];
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp).toDate();

          absensiList.add(AbsensiData(
            name: data['userName'] ?? '',
            date: timestamp,
            time: TimeOfDay(hour: timestamp.hour, minute: timestamp.minute),
            location: data['location'] ?? '',
            region: data['region'] ?? 'Unknown',
          ));
        } catch (e) {
          debugPrint('Error parsing document: $e');
        }
      }

      if (mounted) {
        setState(() {
          _absensiData = absensiList;
          _filterData();
        });
      }
    } catch (e) {
      debugPrint('Error fetching all regions data: $e');
      _showErrorMessage('Gagal memuat data: ${e.toString()}');
    }
  }

  DateTime _getStartDateByFilter() {
    final now = DateTime.now();
    if (_selectedFilter == 'Hari Ini') {
      return DateTime(now.year, now.month, now.day);
    } else if (_selectedFilter == 'Minggu Ini') {
      return now.subtract(Duration(days: now.weekday - 1));
    } else if (_selectedFilter == 'Bulan Ini') {
      return DateTime(now.year, now.month, 1);
    }
    // Default: 3 bulan terakhir untuk 'Semua'
    return DateTime(now.year, now.month - 3, now.day);
  }

  void _filterData() {
    final now = DateTime.now();
    _absensiData.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    _filteredData = _absensiData.where((data) {
      bool matchesFilter = true;
      if (_selectedFilter == 'Hari Ini') {
        matchesFilter = data.date.day == now.day &&
            data.date.month == now.month &&
            data.date.year == now.year;
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text(
            'Absensi Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          actions: [
            if (_selectedRegion.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _handleRefresh,
              )
          ],
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
            const Text('Silakan pilih region terlebih dahulu',
                style: TextStyle(fontSize: 16)),
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
            const Text('Tidak ada data untuk ditampilkan',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }
    return _buildBoxPlotChart();
  }

  Widget _buildBoxPlotChart() {
    final chartData = _prepareChartData();
    if (chartData.isEmpty) return const SizedBox.shrink();

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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: SfCartesianChart(
        title: ChartTitle(
          text: chartTitle,
          textStyle: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        primaryXAxis: const CategoryAxis(
          majorGridLines: MajorGridLines(width: 0),
          labelStyle: TextStyle(fontWeight: FontWeight.w500),
        ),
        primaryYAxis: NumericAxis(
          axisLabelFormatter: (AxisLabelRenderDetails details) {
            final double value = details.value.toDouble();
            final int hours = value.truncate();
            final int minutes = ((value - hours) * 60).round();
            final String formattedTime =
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
            return ChartAxisLabel(formattedTime, details.textStyle);
          },
          interval: 2,
          minimum: 5,
          maximum: 17,
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

  Widget _buildRegionDropdown() {
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
          hint: Text(
            'Pilih Region',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          value: _selectedRegion.isEmpty ? null : _selectedRegion,
          items: regionItems.map((String region) {
            return DropdownMenuItem<String>(
              value: region,
              child: Text(region),
            );
          }).toList(),
          onChanged: _handleRegionChange,
        ),
      ),
    );
  }

  Future<void> _handleRegionChange(String? value) async {
    if (value == null || value == _selectedRegion) return;

    setState(() {
      _isLoading = true;
      _selectedRegion = value;
      _absensiData.clear();
      _filteredData.clear();
    });

    try {
      if (value == 'Semua Region') {
        await _fetchAllRegionsData();
      } else {
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
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFilter = value;
                        _isLoading = true;
                      });
                      // Re-fetch dengan filter baru
                      _handleRegionChange(_selectedRegion);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_BoxPlotChartData> _prepareChartData() {
    if (_filteredData.isEmpty) return [];

    if (_selectedRegion == 'Semua Region') {
      final groupedByRegion = groupBy(_filteredData, (AbsensiData data) => data.region);
      final chartData = groupedByRegion.entries.map((entry) {
        final regionName = entry.key;
        final checkInTimes = entry.value
            .map((data) => data.time.hour + data.time.minute / 60.0)
            .toList();
        return _BoxPlotChartData(regionName, checkInTimes);
      }).toList();
      chartData.sort((a, b) => a.category.compareTo(b.category));
      return chartData;
    } else {
      const monthNames = {
        1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'Mei', 6: 'Jun',
        7: 'Jul', 8: 'Ags', 9: 'Sep', 10: 'Okt', 11: 'Nov', 12: 'Des'
      };
      final groupedByMonth = groupBy(
        _filteredData,
            (AbsensiData data) => '${data.date.year}-${data.date.month}',
      );
      final chartData = groupedByMonth.entries.map((entry) {
        final year = entry.key.split('-')[0];
        final month = int.parse(entry.key.split('-')[1]);
        final monthName = monthNames[month] ?? '';
        final checkInTimes = entry.value
            .map((data) => data.time.hour + data.time.minute / 60.0)
            .toList();
        return _BoxPlotChartData('$monthName\n$year', checkInTimes);
      }).toList();
      chartData.sort((a, b) {
        final aParts = a.category.split('\n');
        final bParts = b.category.split('\n');
        final aYear = int.parse(aParts[1]);
        final bYear = int.parse(bParts[1]);
        if (aYear != bYear) return aYear.compareTo(bYear);
        final aMonth = monthNames.entries.firstWhere((e) => e.value == aParts[0]).key;
        final bMonth = monthNames.entries.firstWhere((e) => e.value == bParts[0]).key;
        return aMonth.compareTo(bMonth);
      });
      return chartData;
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
  }
}

class _BoxPlotChartData {
  _BoxPlotChartData(this.category, this.checkInTimes);
  final String category;
  final List<double> checkInTimes;
}

class AbsensiData {
  final String name;
  final DateTime date;
  final TimeOfDay time;
  final String location;
  final String region;

  AbsensiData({
    required this.name,
    required this.date,
    required this.time,
    required this.location,
    required this.region,
  });

  DateTime get dateTime => DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );

  String get dateFormatted => DateFormat('dd/MM/yyyy').format(date);
  String get timeFormatted =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'name': name,
    'date': date.millisecondsSinceEpoch,
    'hour': time.hour,
    'minute': time.minute,
    'location': location,
    'region': region,
  };

  factory AbsensiData.fromMap(Map<String, dynamic> map) {
    return AbsensiData(
      name: map['name'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      time: TimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int),
      location: map['location'] as String,
      region: map['region'] as String? ?? '',
    );
  }
}