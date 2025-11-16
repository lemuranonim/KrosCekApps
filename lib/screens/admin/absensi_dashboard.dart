import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  String _selectedFilter = 'Semua';
  String _selectedRegion = '';
  bool _isLoading = false;

  final List<String> _filterOptions = ['Semua', 'Hari Ini', 'Minggu Ini', 'Bulan Ini'];
  static const String _allRegionsSentinel = "Semua Region";

  // Cache system
  static final Map<String, Map<String, List<AbsensiData>>> _dataCache = {};
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

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

  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheDuration;
  }

  // Fetch data dari Google Sheets untuk satu region
  Future<Map<String, dynamic>> _fetchSingleRegionData(
      String regionName, String spreadsheetId) async {
    try {
      debugPrint('📋 [Fetch] Fetching data for $regionName from spreadsheet: $spreadsheetId');

      final googleSheetsApi = GoogleSheetsApi(spreadsheetId);
      final initSuccess = await googleSheetsApi.init();

      if (!initSuccess) {
        debugPrint('⚠️ [Fetch] Failed to init GoogleSheetsApi for $regionName');
        return {
          'regionName': regionName,
          'data': <AbsensiData>[],
        };
      }

      final rows = await googleSheetsApi.getSpreadsheetData('Absen Log');

      if (rows.isEmpty || rows.length <= 1) {
        debugPrint('⚠️ [Fetch] No data in Absen Log for $regionName');
        return {
          'regionName': regionName,
          'data': <AbsensiData>[],
        };
      }

      final absensiList = <AbsensiData>[];
      final dataRows = rows.skip(1);
      final now = DateTime.now();
      final startDate = _getStartDateByFilter();

      for (final row in dataRows) {
        if (row.isEmpty) continue;

        try {
          // Parse data dari row
          final timestampStr = _getValue(row, 0, ''); // Kolom Timestamp
          final userName = _getValue(row, 1, ''); // Kolom User Name
          final location = _getValue(row, 2, ''); // Kolom Location

          if (timestampStr.isEmpty || userName.isEmpty) continue;

          // Parse timestamp dengan berbagai format
          DateTime timestamp;
          try {
            // Coba format standar ISO 8601
            timestamp = DateTime.parse(timestampStr);
          } catch (e) {
            try {
              // Coba format Indonesia: dd/MM/yyyy HH:mm:ss
              final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
              timestamp = formatter.parse(timestampStr);
            } catch (e2) {
              try {
                // Coba format alternatif: dd-MM-yyyy HH:mm:ss
                final formatter = DateFormat('dd-MM-yyyy HH:mm:ss');
                timestamp = formatter.parse(timestampStr);
              } catch (e3) {
                try {
                  // Coba format tanpa detik: dd/MM/yyyy HH:mm
                  final formatter = DateFormat('dd/MM/yyyy HH:mm');
                  timestamp = formatter.parse(timestampStr);
                } catch (e4) {
                  debugPrint('⚠️ [Parse] Invalid timestamp format: $timestampStr');
                  debugPrint('Tried formats: ISO 8601, dd/MM/yyyy HH:mm:ss, dd-MM-yyyy HH:mm:ss, dd/MM/yyyy HH:mm');
                  continue;
                }
              }
            }
          }

          // Filter by date range
          if (timestamp.isBefore(startDate) ||
              timestamp.isAfter(DateTime(now.year, now.month, now.day + 1))) {
            continue;
          }

          absensiList.add(AbsensiData(
            name: userName,
            date: timestamp,
            time: TimeOfDay(hour: timestamp.hour, minute: timestamp.minute),
            location: location,
            region: regionName,
          ));
        } catch (e) {
          debugPrint('⚠️ [Parse] Error parsing row in $regionName: $e');
          continue;
        }
      }

      debugPrint('✅ [Fetch] $regionName: ${absensiList.length} records');

      return {
        'regionName': regionName,
        'data': absensiList,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ [Fetch] Error fetching $regionName: $e');
      debugPrint('Stack trace: $stackTrace');
      return {
        'regionName': regionName,
        'data': <AbsensiData>[],
      };
    }
  }

  String _getValue(List<String> row, int index, String defaultValue) {
    return row.isNotEmpty && index >= 0 && index < row.length
        ? row[index]
        : defaultValue;
  }

  // Fetch data dari Google Sheets untuk semua region (PARALLEL)
  Future<void> _fetchAllRegionsData() async {
    try {
      final filterKey = _selectedFilter;

      // Check cache first
      if (_isCacheValid() && _dataCache.containsKey(filterKey)) {
        debugPrint('⚡ [Cache] Using cached data for $filterKey');
        if (mounted) {
          setState(() {
            _absensiData = List.from(_dataCache[filterKey]!.values.expand((x) => x));
            _filterData();
          });
        }
        return;
      }

      debugPrint('📋 [Fetch] Fetching ALL regions data in parallel...');

      final regions = ConfigManager.regions;
      debugPrint('📋 [Fetch] Total regions to fetch: ${regions.length}');

      // ✨ PARALLEL FETCHING
      final List<Future<Map<String, dynamic>>> fetchFutures = [];

      for (final entry in regions.entries) {
        final regionName = entry.key;
        final spreadsheetId = entry.value;
        fetchFutures.add(_fetchSingleRegionData(regionName, spreadsheetId));
      }

      // Wait for ALL regions
      final results = await Future.wait(
        fetchFutures,
        eagerError: false,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint('⏱️ [Fetch] Timeout reached, using partial results');
          return fetchFutures.map((f) => f.then((v) => v).catchError((e) => <String, dynamic>{})).toList() as List<Map<String, dynamic>>;
        },
      );

      // Collect all data
      final allData = <AbsensiData>[];
      final Map<String, List<AbsensiData>> regionDataMap = {};
      int successCount = 0;

      for (final result in results) {
        if (result.isNotEmpty && result.containsKey('regionName')) {
          final regionName = result['regionName'] as String;
          final data = result['data'] as List<AbsensiData>;

          if (data.isNotEmpty) {
            regionDataMap[regionName] = data;
            allData.addAll(data);
            successCount++;
            debugPrint('✅ [Fetch] Region: $regionName - ${data.length} rows');
          }
        }
      }

      // Save to cache
      _dataCache[filterKey] = regionDataMap;
      _lastCacheTime = DateTime.now();

      debugPrint('🎉 [Fetch] Parallel fetch completed!');
      debugPrint('✅ [Fetch] Success: $successCount/${regions.length} regions');
      debugPrint('📦 [Fetch] Total rows collected: ${allData.length}');

      if (mounted) {
        setState(() {
          _absensiData = allData;
          _filterData();
        });
      }
    } catch (e) {
      debugPrint('❌ [Fetch] Error fetching all regions data: $e');
      _showErrorMessage('Gagal memuat data: ${e.toString()}');
    }
  }

  // Fetch single region dengan cache
  Future<void> _fetchSingleRegionDataWithCache(String region) async {
    final filterKey = _selectedFilter;

    // Check cache
    if (_isCacheValid() &&
        _dataCache.containsKey(filterKey) &&
        _dataCache[filterKey]!.containsKey(region)) {
      debugPrint('⚡ [Cache] Using cached data for $region - $filterKey');
      if (mounted) {
        setState(() {
          _absensiData = List.from(_dataCache[filterKey]![region]!);
          _filterData();
        });
      }
      return;
    }

    // Get spreadsheet ID
    final spreadsheetId = ConfigManager.getSpreadsheetId(region);
    if (spreadsheetId == null) {
      debugPrint('❌ [Fetch] No spreadsheet ID found for region: $region');
      _showErrorMessage('Spreadsheet ID tidak ditemukan untuk region: $region');
      return;
    }

    // Fetch new data
    final result = await _fetchSingleRegionData(region, spreadsheetId);
    final data = result['data'] as List<AbsensiData>;

    // Save to cache
    if (!_dataCache.containsKey(filterKey)) {
      _dataCache[filterKey] = {};
    }
    _dataCache[filterKey]![region] = data;
    _lastCacheTime = DateTime.now();

    if (mounted) {
      setState(() {
        _absensiData = data;
        _filterData();
      });
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
            // Cache indicator
            if (_isCacheValid())
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.offline_bolt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            if (_selectedRegion.isNotEmpty)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'refresh') {
                    _dataCache.clear();
                    _lastCacheTime = null;
                    _handleRefresh();
                  } else if (value == 'clear_cache') {
                    setState(() {
                      _dataCache.clear();
                      _lastCacheTime = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache berhasil dihapus'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 8),
                        Text('Refresh Data'),
                      ],
                    ),
                  ),
                  if (_isCacheValid())
                    const PopupMenuItem(
                      value: 'clear_cache',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep),
                          SizedBox(width: 8),
                          Text('Hapus Cache'),
                        ],
                      ),
                    ),
                ],
              ),
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
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      _selectedRegion == _allRegionsSentinel
                          ? 'Memuat data dari semua region...'
                          : 'Memuat data absensi...',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              )
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
    if (_selectedRegion == _allRegionsSentinel) {
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
    final List<String> regionItems = [
      _allRegionsSentinel,
      ...ConfigManager.regions.keys.toList()..sort()
    ];

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
              child: Row(
                children: [
                  Icon(
                    region == _allRegionsSentinel
                        ? Icons.public_rounded
                        : Icons.location_on_rounded,
                    size: 18,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(region),
                ],
              ),
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
      if (value == _allRegionsSentinel) {
        await _fetchAllRegionsData();
      } else {
        await _fetchSingleRegionDataWithCache(value);
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

    if (_selectedRegion == _allRegionsSentinel) {
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