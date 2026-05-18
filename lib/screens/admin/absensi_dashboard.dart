import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kroscek/widgets/advanta_loading_state.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  String _selectedRegionGroup = '';
  bool _isLoading = false;
  final Map<String, List<String>> _regionGroups = {};

  final List<String> _filterOptions = ['Semua', 'Hari Ini', 'Minggu Ini', 'Bulan Ini', '3 Bulan Terakhir'];
  static const String _allRegionsSentinel = "Semua Region";
  static const List<String> _excludedRegions = ['PSP', 'PSP QA', 'QA Plant Inspection', 'HSP SWC', 'SWC'];

  // Cache system
  static final Map<String, Map<String, List<AbsensiData>>> _dataCache = {};
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  String _selectedSort = 'A - Z'; // Default sorting
  final List<String> _sortOptions = [
    'A - Z',
    'Z - A',
    'Paling Pagi (Rajin)',
    'Paling Siang (Telat)'
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp().catchError((e) {
      _showErrorMessage('Gagal inisialisasi: ${e.toString()}');
    });
  }

  void _applyFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      var rawFiltered = _absensiData.where((data) {
        // --- 1. Filter Region (Logika Grouping) ---
        bool regionPass = false;

        if (_selectedRegionGroup.isEmpty || _selectedRegionGroup == _allRegionsSentinel) {
          regionPass = true;
        } else {
          // Cek apakah region data ini ada di dalam list anggota grup yang dipilih
          List<String>? allowedSubRegions = _regionGroups[_selectedRegionGroup];
          if (allowedSubRegions != null && allowedSubRegions.contains(data.region)) {
            regionPass = true;
          }
        }

        if (!regionPass) return false;

        // --- 2. Filter Waktu (Sama seperti sebelumnya) ---
        final dataDate = DateTime(data.date.year, data.date.month, data.date.day);

        if (_selectedFilter == 'Hari Ini') return dataDate.isAtSameMomentAs(today);
        if (_selectedFilter == 'Minggu Ini') {
          final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          return (dataDate.isAtSameMomentAs(startOfWeek) || dataDate.isAfter(startOfWeek)) &&
              (dataDate.isAtSameMomentAs(endOfWeek) || dataDate.isBefore(endOfWeek));
        }
        if (_selectedFilter == 'Bulan Ini') return dataDate.year == now.year && dataDate.month == now.month;
        if (_selectedFilter == '3 Bulan Terakhir') {
          final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);
          return dataDate.isAtSameMomentAs(threeMonthsAgo) || dataDate.isAfter(threeMonthsAgo);
        }

        return true;
      }).toList();

      rawFiltered.sort((a, b) => b.date.compareTo(a.date));

      // Optimasi: Potong jika data terlalu banyak saat mode 'Semua'
      if (_selectedFilter == 'Semua' &&
          _selectedRegionGroup == _allRegionsSentinel &&
          rawFiltered.length > 2000) {
        _filteredData = rawFiltered.take(2000).toList();
      } else {
        _filteredData = rawFiltered;
      }
    });
  }

  Future<void> _fetchMultipleRegions(List<String> targetRegions) async {
    // 1. Setup Cache Key
    final filterKey = _selectedFilter;

    // Pastikan wadah cache siap
    if (!_dataCache.containsKey(filterKey)) {
      _dataCache[filterKey] = {};
    }

    final allData = <AbsensiData>[];
    final regionsToFetch = <String>[];

    // 2. Cek Cache per Region (Hemat kuota & waktu)
    for (var region in targetRegions) {
      if (_isCacheValid() &&
          _dataCache[filterKey]!.containsKey(region) &&
          _dataCache[filterKey]![region]!.isNotEmpty) {
        allData.addAll(_dataCache[filterKey]![region]!);
      } else {
        regionsToFetch.add(region);
      }
    }

    int successCount = 0;
    const int batchSize = 5; // Proses 5 region sekaligus

    // 3. Fetch hanya yang belum ada di cache
    if (regionsToFetch.isNotEmpty) {
      debugPrint('⬇️ [Fetch] Perlu download data untuk ${regionsToFetch.length} region...');

      for (int i = 0; i < regionsToFetch.length; i += batchSize) {
        final int end = (i + batchSize < regionsToFetch.length) ? i + batchSize : regionsToFetch.length;
        final batch = regionsToFetch.sublist(i, end);

        debugPrint('🔄 [Fetch] Processing batch ${(i / batchSize).floor() + 1} (${batch.length} regions)...');

        final List<Future<Map<String, dynamic>>> batchFutures = batch.map((regionName) {
          final spreadId = ConfigManager.getSpreadsheetId(regionName);
          if (spreadId != null) {
            return _fetchSingleRegionData(regionName, spreadId);
          }
          return Future.value({'regionName': regionName, 'data': <AbsensiData>[]});
        }).toList();

        final results = await Future.wait(batchFutures);

        for (final result in results) {
          if (result.isNotEmpty && result.containsKey('data')) {
            final regionName = result['regionName'] as String;
            final data = result['data'] as List<AbsensiData>;

            if (data.isNotEmpty) {
              allData.addAll(data);
              // Simpan hasil ke cache
              _dataCache[filterKey]![regionName] = data;
              successCount++;
            }
          }
        }

        // Istirahat sebentar biar Google tidak marah (Rate Limit)
        if (end < regionsToFetch.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      _lastCacheTime = DateTime.now();
    } else {
      debugPrint('⚡ [Fetch] Semua data diambil dari cache!');
    }

    debugPrint('✅ [Fetch] Selesai. Sukses fetch baru: $successCount region.');

    if (mounted) {
      setState(() {
        _absensiData = allData;
        _isLoading = false;
      });
      _applyFilter();
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeServices();
      // Panggil fungsi ini saat start
      _generateRegionGroups();
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

  // --- FUNGSI PEMBANTU BARU: Parse Tanggal Cerdas (Serial & Text) ---
  DateTime? _parseSheetDate(String dateStr, String timeStr) {
    try {
      dateStr = dateStr.trim();
      timeStr = timeStr.trim();

      // 1. Cek apakah Date adalah Serial Number (Angka Excel)
      double? dateSerial = double.tryParse(dateStr);

      DateTime dateResult;

      if (dateSerial != null) {
        // Konversi Excel Serial Date (Base date: 30 Des 1899)
        dateResult = DateTime(1899, 12, 30).add(Duration(days: dateSerial.toInt()));
      } else {
        // Coba parsing format teks biasa
        try {
          dateResult = DateFormat("d/M/yyyy").parse(dateStr);
        } catch (_) {
          try {
            dateResult = DateTime.parse(dateStr);
          } catch (_) {
            return null; // Gagal total
          }
        }
      }

      // 2. Cek apakah Time adalah Serial Number
      double? timeSerial = double.tryParse(timeStr);

      if (timeSerial != null) {
        if (timeSerial >= 1) timeSerial = timeSerial - timeSerial.floor();
        int millisOfDay = (timeSerial * 24 * 60 * 60 * 1000).round();
        return dateResult.add(Duration(milliseconds: millisOfDay));
      }
      // 3. Jika Time adalah format teks "HH:mm"
      else if (timeStr.contains(':')) {
        List<String> parts = timeStr.split(':');
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        int s = parts.length > 2 ? int.tryParse(parts[2].split('.')[0]) ?? 0 : 0;

        return DateTime(dateResult.year, dateResult.month, dateResult.day, h, m, s);
      }

      return dateResult;

    } catch (e) {
      return null;
    }
  }

  void _generateRegionGroups() {
    final rawRegions = ConfigManager.regions.keys
        .where((r) => !_excludedRegions.contains(r))
        .toList();

    _regionGroups.clear();

    for (var fullRegionName in rawRegions) {
      // Ambil kata sebelum tanda " - " pertama sebagai nama grup
      String groupName = fullRegionName.split(' - ').first.trim();

      if (!_regionGroups.containsKey(groupName)) {
        _regionGroups[groupName] = [];
      }
      _regionGroups[groupName]!.add(fullRegionName);
    }
  }

  // --- FUNGSI FETCH UTAMA ---
  Future<Map<String, dynamic>> _fetchSingleRegionData(
      String regionName, String spreadsheetId) async {
    try {
      // debugPrint('📋 [Fetch] Fetching data for $regionName...');

      final googleSheetsApi = GoogleSheetsApi(spreadsheetId);
      final initSuccess = await googleSheetsApi.init();

      if (!initSuccess) {
        return {'regionName': regionName, 'data': <AbsensiData>[]};
      }

      final rows = await googleSheetsApi.getSpreadsheetData('Absen Log');

      if (rows.isEmpty || rows.length <= 1) {
        return {'regionName': regionName, 'data': <AbsensiData>[]};
      }

      // 1. CARI INDEX BERDASARKAN HEADER
      final headers = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();

      int nameIdx = headers.indexWhere((h) => h == 'nama');
      int dateIdx = headers.indexWhere((h) => h.contains('tanggal'));
      int timeIdx = headers.indexWhere((h) => h.contains('waktu'));
      int locationIdx = headers.indexWhere((h) => h.contains('lokasi'));

      // Fallback index
      if (nameIdx == -1) nameIdx = 0;
      if (dateIdx == -1) dateIdx = 1;
      if (timeIdx == -1) timeIdx = 2;
      if (locationIdx == -1) locationIdx = 3;

      final absensiList = <AbsensiData>[];
      final dataRows = rows.skip(1);
      final now = DateTime.now();
      final startDate = _getStartDateByFilter();

      for (final row in dataRows) {
        if (row.isEmpty) continue;

        try {
          final nameStr = _getValue(row, nameIdx, '');
          final dateStr = _getValue(row, dateIdx, '');
          final timeStr = _getValue(row, timeIdx, '');
          final locationStr = _getValue(row, locationIdx, '');

          if (nameStr.isEmpty || dateStr.isEmpty) continue;
          if (nameStr.toLowerCase() == 'nama') continue;

          DateTime? timestamp = _parseSheetDate(dateStr, timeStr);

          if (timestamp == null) continue;

          // Filter range tanggal
          if (timestamp.isBefore(startDate) ||
              timestamp.isAfter(DateTime(now.year, now.month, now.day + 1))) {
            continue;
          }

          absensiList.add(AbsensiData(
            name: nameStr,
            date: timestamp,
            time: TimeOfDay(hour: timestamp.hour, minute: timestamp.minute),
            location: locationStr,
            region: regionName,
          ));

        } catch (e) {
          continue;
        }
      }
      return {
        'regionName': regionName,
        'data': absensiList,
      };
    } catch (e) {
      debugPrint('❌ [Fetch] Error fetching $regionName: $e');
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

  DateTime _getStartDateByFilter() {
    // KEMBALIKAN TANGGAL YANG CUKUP LAMA
    return DateTime(2024, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Jika Web boleh pop (kembali), Jika Mobile dikunci (false)
      canPop: kIsWeb,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Logic mobile tetap sama
        context.go('/admin');
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (kIsWeb) {
                // Jika Web, kembali ke menu sebelumnya (Dashboard)
                Navigator.of(context).pop();
              } else {
                // Jika Mobile, pakai routing admin
                context.go('/admin');
              }
            },
          ),
          title: const Text(
            'Absensi Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          actions: [
            // 1. INDIKATOR CACHE PREMIUM (ANIMATED)
            if (_isCacheValid())
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.orange.shade400,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withAlpha(102),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.offline_bolt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // 2. TOMBOL MENU PREMIUM (CONTAINER STYLE)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withAlpha(77),
                  width: 1,
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                elevation: 8,
                offset: const Offset(0, 50),
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
                      SnackBar(
                        content: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(51),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Cache berhasil dihapus',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.white,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withAlpha(77),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Refresh Data',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Muat ulang data terbaru',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isCacheValid())
                    PopupMenuItem(
                      value: 'clear_cache',
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withAlpha(77),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hapus Cache',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Bersihkan data tersimpan',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildRegionDropdown(),
            const SizedBox(height: 10),
            if (_selectedRegionGroup.isNotEmpty) _buildControlSection(),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? AdvantaLoadingState(
                      title: 'Memuat absensi',
                      subtitle: _selectedRegionGroup == _allRegionsSentinel
                          ? 'Mengambil data semua region'
                          : 'Mengambil data region terpilih',
                      accentColor: Colors.green,
                      icon: Icons.fact_check_rounded,
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // PERBAIKAN: Cek _selectedRegionGroup
    if (_selectedRegionGroup.isEmpty) {
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
    if (_selectedRegionGroup == _allRegionsSentinel) {
      chartTitle = 'Analisis Waktu Absensi per Region';
    } else {
      chartTitle = 'Analisis Waktu Absensi Region $_selectedRegionGroup';
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
          maximum: 22,
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
    return _buildPremiumRegionSelector();
  }

  Widget _buildPremiumRegionSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(13),
        child: InkWell(
          onTap: _isLoading ? null : _showRegionBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // PERBAIKAN: Cek _selectedRegionGroup
                    color: _selectedRegionGroup == _allRegionsSentinel
                        ? Colors.amber.withAlpha(26)
                        : Colors.green.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    // PERBAIKAN: Cek _selectedRegionGroup
                    _selectedRegionGroup == _allRegionsSentinel
                        ? Icons.public_rounded
                        : Icons.location_on_rounded,
                    color: _selectedRegionGroup == _allRegionsSentinel
                        ? Colors.amber.shade700
                        : Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Region Terpilih',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // PERBAIKAN: Tampilkan _selectedRegionGroup
                        _selectedRegionGroup.isEmpty ? 'Pilih Region' : _selectedRegionGroup,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegionBottomSheet() {
    final groupOptions = [_allRegionsSentinel, ..._regionGroups.keys.toList()..sort()];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.map_rounded, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pilih Kelompok Region',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groupOptions.length,
                  itemBuilder: (context, index) {
                    final regionGroup = groupOptions[index];
                    final isSelected = _selectedRegionGroup == regionGroup;
                    final isAll = regionGroup == _allRegionsSentinel;

                    // Variabel ini yang sebelumnya kena warning
                    int subCount = 0;
                    if (!isAll && _regionGroups.containsKey(regionGroup)) {
                      subCount = _regionGroups[regionGroup]!.length;
                    }

                    Color bgColor = Colors.transparent;
                    Color borderColor = Colors.transparent;

                    if (isSelected) {
                      if (isAll) {
                        bgColor = Colors.amber.withAlpha(26);
                        borderColor = Colors.amber;
                      } else {
                        bgColor = Colors.green.withAlpha(26);
                        borderColor = Colors.green;
                      }
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _handleRegionChange(regionGroup);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSelected ? borderColor : Colors.transparent,
                              width: 1.5
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAll ? Icons.public_rounded : Icons.folder_open_rounded,
                              size: 20,
                              color: isSelected
                                  ? (isAll ? Colors.amber.shade700 : Colors.green)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    regionGroup,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.black87 : Colors.grey.shade700,
                                    ),
                                  ),

                                  // --- PERBAIKAN: SUBCOUNT DIGUNAKAN DI SINI ---
                                  if (!isAll && subCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '$subCount Wilayah', // Menampilkan jumlah wilayah
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  // ---------------------------------------------
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: isAll ? Colors.amber : Colors.green,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRegionChange(String? groupName) async {
    if (groupName == null || groupName == _selectedRegionGroup) return;

    setState(() {
      _isLoading = true;
      _selectedRegionGroup = groupName;
      _absensiData.clear();
      _filteredData.clear();
    });

    try {
      if (groupName == _allRegionsSentinel) {
        // Jika pilih "Semua", ambil seluruh region yang ada di config
        final allRegions = ConfigManager.regions.keys
            .where((r) => !_excludedRegions.contains(r))
            .toList();
        await _fetchMultipleRegions(allRegions);
      } else {
        // Jika pilih Grup, ambil sub-region anggotanya saja
        final subRegions = _regionGroups[groupName] ?? [];
        if (subRegions.isNotEmpty) {
          await _fetchMultipleRegions(subRegions);
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      _showErrorMessage('Gagal memuat data: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    // PERBAIKAN: Gunakan _selectedRegionGroup
    await _handleRegionChange(_selectedRegionGroup);
  }

  Widget _buildControlSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // --- DROPDOWN 1: FILTER WAKTU (Hari Ini, Minggu Ini, dll) ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text("Filter Waktu", style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      isDense: true,
                      items: _filterOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedFilter = value;
                          });
                          _applyFilter();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // --- DROPDOWN 2: SORTING (A-Z, Paling Pagi, dll) ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text("Urutkan", style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSort,
                      isExpanded: true,
                      isDense: true,
                      items: _sortOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSort = value;
                          });
                          // Tidak perlu fetch ulang, cukup rebuild chart
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_BoxPlotChartData> _prepareChartData() {
    if (_filteredData.isEmpty) return [];

    bool isGroupingMode = _selectedRegionGroup == _allRegionsSentinel;

    // 1. Grouping Data (Sama seperti sebelumnya)
    final groupedMap = groupBy(_filteredData, (AbsensiData data) {
      if (isGroupingMode) {
        return data.region.split(' - ').first.trim();
      } else {
        List<String> parts = data.region.split(' - ');
        if (parts.length > 1) {
          return parts.last.trim();
        }
        return data.region;
      }
    });

    // 2. Mapping ke Chart Data
    final chartData = groupedMap.entries.map((entry) {
      final label = entry.key;
      final checkInTimes = entry.value
          .map((data) => data.time.hour + data.time.minute / 60.0)
          .toList();

      return _BoxPlotChartData(label, checkInTimes);
    }).toList();

    // 3. LOGIKA SORTING BARU (DYNAMIC)
    chartData.sort((a, b) {
      // Helper: Hitung Rata-rata Jam (untuk sort Pagi/Siang)
      double getAverage(List<double> times) {
        if (times.isEmpty) return 0;
        return times.reduce((a, b) => a + b) / times.length;
      }

      // Helper: Ekstrak Angka dari Nama (untuk sort A-Z pintar, misal: Region 2 < Region 10)
      int? getNumber(String text) {
        final match = RegExp(r'(\d+)').firstMatch(text);
        return match != null ? int.parse(match.group(0)!) : null;
      }

      switch (_selectedSort) {
        case 'Paling Pagi (Rajin)':
        // Sort berdasarkan rata-rata jam terkecil (Ascending)
          return getAverage(a.checkInTimes).compareTo(getAverage(b.checkInTimes));

        case 'Paling Siang (Telat)':
        // Sort berdasarkan rata-rata jam terbesar (Descending)
          return getAverage(b.checkInTimes).compareTo(getAverage(a.checkInTimes));

        case 'Z - A':
        // Sort Nama Terbalik
        // Cek angka dulu
          final numA = getNumber(a.category);
          final numB = getNumber(b.category);
          if (numA != null && numB != null) {
            return numB.compareTo(numA); // Angka Descending
          }
          return b.category.compareTo(a.category); // String Descending

        case 'A - Z':
        default:
        // Sort Nama Normal
        // Cek angka dulu (Biar Region 2 ada sebelum Region 10)
          final numA = getNumber(a.category);
          final numB = getNumber(b.category);
          if (numA != null && numB != null) {
            return numA.compareTo(numB); // Angka Ascending
          }
          return a.category.compareTo(b.category); // String Ascending
      }
    });

    return chartData;
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
