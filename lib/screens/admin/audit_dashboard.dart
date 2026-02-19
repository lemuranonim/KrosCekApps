// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:async';
import 'dart:convert'; // Wajib untuk utf8 & jsonEncode
import 'package:archive/archive.dart'; // Wajib untuk GZIP
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class AuditDashboard extends StatefulWidget {
  const AuditDashboard({super.key});

  @override
  State<AuditDashboard> createState() => _AuditDashboardState();
}

class _AuditDashboardState extends State<AuditDashboard> {
  // === STATE MANAGEMENT ===
  bool _isLoading = false;
  String? _loadingStatus;
  String? _error;

  // Data
  List<List<String>> _allCombinedData = [];
  Map<String, List<String>> _qaActivityMap = {};

  List<List<String>> _filteredData = [];
  List<_AuditMonthlyData> _chartData = [];

  // Statistik Total
  double _totalSampunArea = 0;
  double _totalDerengJangkepArea = 0;
  double _totalDerengBlasArea = 0;
  double _totalDerengArea = 0;
  double _totalVisitedArea = 0;
  double _totalNotVisitedArea = 0;

  // Filter Controls
  String? _selectedRegionGroup;
  static const String _allRegionsSentinel = "Semua Region";

  String? _selectedQaSpv;
  String? _selectedDistrictFilter;
  String _selectedWorksheetTitle = 'Generative';

  final List<String> _worksheetTitles = ['Generative', 'Vegetative', 'Pre Harvest', 'Harvest'];
  List<String> _regionGroupOptions = [];
  List<String> _qaSpvOptions = [];
  List<String> _districtFilterOptions = [];

  static const List<String> _excludedRegions = [
    'PSP', 'PSP QA', 'SWC', 'HSP SWC', 'QA Plant Inspection'
  ];

  // Supabase Client Access
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    try {
      await ConfigManager.loadConfig();
      _initRegionGroups();
    } catch (e) {
      if (mounted) _showErrorMessage("Gagal memuat konfigurasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER KOMPRESI & DEKOMPRESI ---

  // Mengubah Data Object -> JSON String -> GZIP Bytes
  List<int>? _compressData(dynamic data) {
    if (data == null) return null;
    try {
      final jsonString = jsonEncode(data);
      final List<int> bytes = utf8.encode(jsonString);
      return GZipEncoder().encode(bytes);
    } catch (e) {
      debugPrint("Gagal kompresi: $e");
      return null;
    }
  }

  // Mengubah Raw Response (Hex String/Bytes) -> GZIP Decode -> JSON -> Data Object
  dynamic _decompressData(dynamic rawData) {
    if (rawData == null) return null;
    try {
      List<int> compressedBytes;

      // Handle jika Supabase mengembalikan Hex String (format Postgres bytea)
      if (rawData is String) {
        String cleanHex = rawData;
        if (cleanHex.startsWith(r'\x')) {
          cleanHex = cleanHex.substring(2);
        }
        // Convert Hex String ke List<int>
        compressedBytes = [];
        for (int i = 0; i < cleanHex.length; i += 2) {
          compressedBytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
        }
      } else if (rawData is List) {
        compressedBytes = List<int>.from(rawData);
      } else {
        return null;
      }

      // Decompress GZIP
      final List<int> decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      final String jsonString = utf8.decode(decompressedBytes);
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint("Gagal dekompresi: $e");
      return null;
    }
  }

  // --- SUPABASE CACHE MANAGERS ---

  Future<bool> _loadDataFromSupabase(String region, String worksheet) async {
    try {
      setState(() => _loadingStatus = "Mengambil ringkasan data...");

      // 1. Ambil RINGKASAN dulu (Sangat Cepat, JSONB biasa)
      final responseSummary = await _supabase
          .from('audit_cache')
          .select('chart_summary, updated_at')
          .eq('region', region)
          .eq('worksheet', worksheet)
          .maybeSingle();

      if (responseSummary == null) return false;

      // 2. Jika ada summary, langsung tampilkan CHART!
      if (responseSummary['chart_summary'] != null) {
        final List<dynamic> rawSummary = responseSummary['chart_summary'];
        final summaryData = rawSummary.map((e) => _AuditMonthlyData.fromJson(e)).toList();

        if (mounted) {
          setState(() {
            _chartData = summaryData;
            _recalculateTotalsFromSummary(summaryData);
            _isLoading = false;
          });
        }
      }

      // 3. (BACKGROUND) Sekarang ambil Data Mentah (BINARY COMPRESSED)
      _loadHeavyDataInBackground(region, worksheet);

      return true;
    } catch (e) {
      debugPrint("Error reading cache: $e");
      return false;
    }
  }

  void _recalculateTotalsFromSummary(List<_AuditMonthlyData> summary) {
    double s = 0, dj = 0, db = 0, v = 0, nv = 0;
    for (var item in summary) {
      s += item.sampunHa;
      dj += item.derengJangkepHa;
      db += item.derengBlasHa;
      v += item.visitedHa;
      nv += item.notVisitedHa;
    }
    setState(() {
      _totalSampunArea = s;
      _totalDerengJangkepArea = dj;
      _totalDerengBlasArea = db;
      _totalDerengArea = dj + db;
      _totalVisitedArea = v;
      _totalNotVisitedArea = nv;
    });
  }

  Future<void> _loadHeavyDataInBackground(String region, String worksheet) async {
    try {
      // Ambil kolom bytea (binary)
      final response = await _supabase
          .from('audit_cache')
          .select('data, activity_map')
          .eq('region', region)
          .eq('worksheet', worksheet)
          .maybeSingle();

      if (response == null) return;

      // DEKOMPRESI DATA (Level 1 Optimization)
      final List<dynamic> rawMainData = _decompressData(response['data']) ?? [];
      final List<List<String>> mainData = rawMainData
          .map((row) => (row as List).map((e) => e.toString()).toList())
          .toList();

      final Map<String, dynamic> rawActivity = _decompressData(response['activity_map']) ?? {};
      final Map<String, List<String>> activityMap = rawActivity.map(
            (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );

      if (mounted) {
        setState(() {
          _allCombinedData = mainData;
          _qaActivityMap = activityMap;
          _extractFilterOptions();
        });
      }
    } catch (e) {
      debugPrint("Background load error: $e");
    }
  }

  Future<void> _saveDataToSupabase(String region, String worksheet) async {
    try {
      // 1. KOMPRESI DATA (Level 1 Optimization)
      final List<int>? compressedData = _compressData(_allCombinedData);
      final List<int>? compressedActivityMap = _compressData(_qaActivityMap);

      // 2. Pre-Calc Summary (Tetap JSONB agar bisa dibaca cepat)
      final summaryJson = _chartData.map((e) => e.toJson()).toList();

      // 3. Simpan Binary ke Supabase
      if (compressedData != null) {
        await _supabase.from('audit_cache').upsert({
          'region': region,
          'worksheet': worksheet,
          'data': compressedData, // Kirim Bytes
          'activity_map': compressedActivityMap, // Kirim Bytes
          'chart_summary': summaryJson,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'region, worksheet');

        debugPrint("Compressed Data synced to Supabase for $region");
      }
    } catch (e) {
      debugPrint("Error saving to Supabase: $e");
    }
  }

  // --- DATA FETCHING ---

  Future<void> _onRegionGroupChanged(String? newGroup, {bool forceRefresh = false}) async {
    if (newGroup == null) return;

    setState(() {
      _selectedRegionGroup = newGroup;
      _isLoading = true;
      _error = null;
      _selectedQaSpv = null;
      _selectedDistrictFilter = null;
    });

    if (!forceRefresh) {
      setState(() => _loadingStatus = "Mengecek database...");
      final count = await _supabase
          .from('audit_cache')
          .count(CountOption.exact)
          .eq('region', newGroup)
          .eq('worksheet', _selectedWorksheetTitle);

      if (count > 0) {
        setState(() => _loadingStatus = "Cache ditemukan! Mengunduh data...");
        bool loadedFromDb = await _loadDataFromSupabase(newGroup, _selectedWorksheetTitle);
        if (loadedFromDb) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }
    }

    await _fetchFromApi(newGroup);
  }

  Future<void> _fetchFromApi(String groupName) async {
    setState(() {
      _allCombinedData.clear();
      _qaActivityMap.clear();
      _filteredData.clear();
      _chartData.clear();
      _loadingStatus = "Mempersiapkan data...";
    });

    try {
      final allKeys = ConfigManager.getAllRegionNames()
          .where((r) => !_excludedRegions.contains(r))
          .where((r) => r.startsWith('Region'))
          .toList();

      List<String> targetKeys = [];
      if (groupName == _allRegionsSentinel) {
        targetKeys = allKeys;
      } else {
        targetKeys = allKeys.where((key) {
          String keyGroup = key.contains(" - ") ? key.split(" - ")[0].trim() : key.trim();
          return keyGroup == groupName;
        }).toList();
      }

      if (targetKeys.isEmpty) throw Exception("Tidak ada data spreadsheet.");

      List<List<String>> combinedMainData = [];
      List<String> headers = [];
      Map<String, List<String>> combinedActivityMap = {};

      int totalRegions = targetKeys.length;
      int processedCount = 0;

      for (String regionKey in targetKeys) {
        processedCount++;
        setState(() => _loadingStatus = "Memproses $regionKey ($processedCount/$totalRegions)...");

        // 1. COBA AMBIL DARI SUPABASE (DEKOMPRESI)
        var (localData, localActivity) = await _getRegionDataFromSupabase(regionKey, _selectedWorksheetTitle);

        if (localData != null && localData.isNotEmpty) {
          debugPrint("✅ $regionKey diambil dari Cache Supabase");

          if (headers.isEmpty && localData.isNotEmpty) headers = localData[0];

          if (headers.isNotEmpty && localData[0].join() == headers.join()) {
            combinedMainData.addAll(localData.sublist(1));
          } else {
            combinedMainData.addAll(localData);
          }

          if (localActivity != null) combinedActivityMap.addAll(localActivity);

        } else {
          // 2. DOWNLOAD DARI API
          debugPrint("⬇️ $regionKey tidak ada di cache, download dari Sheets API...");
          final sheetId = ConfigManager.getSpreadsheetId(regionKey);

          if (sheetId != null) {
            try {
              final gSheets = GoogleSheetsApi(sheetId);
              await gSheets.init();
              final results = await Future.wait([
                gSheets.getSpreadsheetData(_selectedWorksheetTitle),
                gSheets.getSpreadsheetData('Aktivitas')
              ]);

              final mainRows = results[0];
              if (mainRows.isNotEmpty) {
                if (headers.isEmpty) headers = mainRows[0];
                if (mainRows.length > 1) combinedMainData.addAll(mainRows.sublist(1));
              }

              final activityRows = results[1];
              if (activityRows.length > 1) {
                for (var row in activityRows.skip(1)) {
                  final qaName = _safeGet(row, 1);
                  final fieldNumber = _safeGet(row, 6);
                  if (qaName.isNotEmpty && fieldNumber.isNotEmpty) {
                    combinedActivityMap.putIfAbsent(qaName, () => []).add(fieldNumber);
                  }
                }
              }
            } catch (e) {
              debugPrint("Gagal download $regionKey: $e");
            }
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) {
        setState(() {
          _allCombinedData = combinedMainData;
          _qaActivityMap = combinedActivityMap;
          _loadingStatus = "Menghitung Total...";
        });

        await Future.delayed(const Duration(milliseconds: 100));

        setState(() {
          _extractFilterOptions();
          _applyFilters();
          _loadingStatus = "Mengompres & Menyimpan Cache...";
        });

        // Simpan versi terkompresi
        await _saveDataToSupabase(groupName, _selectedWorksheetTitle);

        setState(() {
          _isLoading = false;
          _loadingStatus = null;
        });
      }

    } catch (e) {
      if (mounted) setState(() { _error = "Terjadi kesalahan: $e"; _isLoading = false; });
    }
  }

  // --- HELPER UNTUK MENGAMBIL DATA CACHE PER REGION (DEKOMPRESI) ---
  Future<(List<List<String>>?, Map<String, List<String>>?)> _getRegionDataFromSupabase(String region, String worksheet) async {
    try {
      final response = await _supabase
          .from('audit_cache')
          .select('data, activity_map')
          .eq('region', region)
          .eq('worksheet', worksheet)
          .maybeSingle();

      if (response == null) return (null, null);

      // DEKOMPRESI GZIP
      final List<dynamic> rawMainData = _decompressData(response['data']) ?? [];
      final List<List<String>> mainData = rawMainData
          .map((row) => (row as List).map((e) => e.toString()).toList())
          .toList();

      final Map<String, dynamic> rawActivity = _decompressData(response['activity_map']) ?? {};
      final Map<String, List<String>> activityMap = rawActivity.map(
            (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
      );

      return (mainData, activityMap);
    } catch (e) {
      return (null, null);
    }
  }

  // --- HELPERS LAINNYA ---
  String _safeGet(List<String> row, int index) {
    if (index < 0 || index >= row.length) return "";
    return row[index].trim();
  }

  double _parseArea(String val) {
    if (val.isEmpty) return 0.0;
    val = val.replaceAll(',', '.');
    return double.tryParse(val) ?? 0.0;
  }

  Map<String, dynamic> _getMonthFromWeek(String weekVal) {
    String cleanVal = weekVal.replaceAll(RegExp(r'[^0-9]'), '');
    int weekNum = int.tryParse(cleanVal) ?? 0;
    if (weekNum <= 0) return {'index': 99, 'name': 'Unset'};
    DateTime date = DateTime(DateTime.now().year, 1, 1).add(Duration(days: (weekNum - 1) * 7));
    int monthIndex = date.month;
    const List<String> manualMonths = [
      "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    ];
    String monthName = (monthIndex >= 1 && monthIndex <= 12) ? manualMonths[monthIndex - 1] : 'Unknown';
    return {'index': monthIndex, 'name': monthName};
  }

  void _initRegionGroups() {
    final allKeys = ConfigManager.getAllRegionNames()
        .where((r) => !_excludedRegions.contains(r))
        .where((r) => r.startsWith('Region'))
        .toList();
    final Set<String> groups = {};
    for (var key in allKeys) {
      if (key.contains(" - ")) {
        groups.add(key.split(" - ")[0].trim());
      } else {
        groups.add(key.trim());
      }
    }
    setState(() {
      _regionGroupOptions = [_allRegionsSentinel, ...groups.toList()..sort()];
    });
  }

  void _extractFilterOptions() {
    Set<String> uniqueSpv = {};
    Set<String> uniqueDistricts = {};
    if (_allCombinedData.isNotEmpty) {
      for (var row in _allCombinedData) {
        int spvIndex = (_selectedWorksheetTitle == 'Vegetative' || _selectedWorksheetTitle == 'Generative') ? 30 : 28;
        final qaSpv = _safeGet(row, spvIndex);
        if (qaSpv.isNotEmpty && qaSpv != "-" && qaSpv != "0") uniqueSpv.add(qaSpv);
        final districtVal = _safeGet(row, 13);
        if (districtVal.isNotEmpty && districtVal != "-" && districtVal != "0") uniqueDistricts.add(districtVal);
      }
    }
    setState(() {
      _qaSpvOptions = uniqueSpv.toList()..sort();
      _districtFilterOptions = uniqueDistricts.toList()..sort();
      if (_selectedQaSpv != null && !_qaSpvOptions.contains(_selectedQaSpv)) _selectedQaSpv = null;
      if (_selectedDistrictFilter != null && !_districtFilterOptions.contains(_selectedDistrictFilter)) _selectedDistrictFilter = null;
    });
  }

  void _applyFilters() {
    if (_allCombinedData.isEmpty) {
      setState(() => _filteredData = []);
      return;
    }
    final filtered = _allCombinedData.where((row) {
      int spvIndex = (_selectedWorksheetTitle == 'Vegetative' || _selectedWorksheetTitle == 'Generative') ? 30 : 28;
      final qaSpv = _safeGet(row, spvIndex);
      final spvMatch = _selectedQaSpv == null || _selectedQaSpv == "Semua SPV" || qaSpv == _selectedQaSpv;
      final districtVal = _safeGet(row, 13);
      final districtMatch = _selectedDistrictFilter == null || _selectedDistrictFilter == "Semua District" || districtVal == _selectedDistrictFilter;
      return spvMatch && districtMatch;
    }).toList();
    setState(() {
      _filteredData = filtered;
      _calculateChartData();
    });
  }

  void _calculateChartData() {
    Map<int, _AuditMonthlyData> groupedData = {};
    double tempSampun = 0;
    double tempDerengJangkep = 0;
    double tempDerengBlas = 0;
    double tempDereng = 0;
    double tempVisited = 0;
    double tempNotVisited = 0;

    int weekIdx = _selectedWorksheetTitle == 'Vegetative' ? 10 : 28;
    int areaIdx = 8;

    for (var row in _filteredData) {
      final fieldNumber = _safeGet(row, 2);
      final areaVal = _parseArea(_safeGet(row, areaIdx));
      final auditStatus = _getAuditStatus(row);
      bool visited = false;
      for (var listFn in _qaActivityMap.values) {
        if (listFn.contains(fieldNumber)) {
          visited = true;
          break;
        }
      }
      if (auditStatus == "Sampun") tempSampun += areaVal;
      else if (auditStatus == "Dereng Jangkep") tempDerengJangkep += areaVal;
      else if (auditStatus == "Dereng Blas") tempDerengBlas += areaVal;
      else tempDereng += areaVal;

      if (visited) tempVisited += areaVal;
      else tempNotVisited += areaVal;

      String weekRaw = _safeGet(row, weekIdx);
      Map<String, dynamic> monthInfo = _getMonthFromWeek(weekRaw);
      int monthIdx = monthInfo['index'];
      String monthName = monthInfo['name'];
      if (monthIdx == 99) continue;
      if (!groupedData.containsKey(monthIdx)) {
        groupedData[monthIdx] = _AuditMonthlyData(monthIdx, monthName);
      }
      if (auditStatus == "Sampun") groupedData[monthIdx]!.sampunHa += areaVal;
      else if (auditStatus == "Dereng Jangkep") groupedData[monthIdx]!.derengJangkepHa += areaVal;
      else groupedData[monthIdx]!.derengBlasHa += areaVal;
      if (visited) groupedData[monthIdx]!.visitedHa += areaVal;
      else groupedData[monthIdx]!.notVisitedHa += areaVal;
      groupedData[monthIdx]!.totalHa += areaVal;
    }
    List<_AuditMonthlyData> result = groupedData.values.toList();
    result.sort((a, b) => a.monthIndex.compareTo(b.monthIndex));
    setState(() {
      _chartData = result;
      _totalSampunArea = tempSampun;
      _totalDerengJangkepArea = tempDerengJangkep;
      _totalDerengBlasArea = tempDerengBlas;
      _totalDerengArea = tempDereng;
      _totalVisitedArea = tempVisited;
      _totalNotVisitedArea = tempNotVisited;
    });
  }

  String _getAuditStatus(List<String> row) {
    switch (_selectedWorksheetTitle) {
      case 'Vegetative':
        return _safeGet(row, 55).toLowerCase() == "audited" ? "Sampun" : "Dereng";
      case 'Generative':
        final r = _safeGet(row, 72).toLowerCase();
        final p = _safeGet(row, 73).toLowerCase();
        if (r == "audited" && p == "audited") return "Sampun";
        if (r == "audited" || p == "audited") return "Dereng Jangkep";
        return "Dereng Blas";
      case 'Pre Harvest':
        return _safeGet(row, 39).toLowerCase() == "audited" ? "Sampun" : "Dereng";
      case 'Harvest':
        return _safeGet(row, 43).toLowerCase() == "audited" ? "Sampun" : "Dereng";
      default:
        return "Dereng";
    }
  }

  // === UI WIDGETS ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildEmptyState(_error!, Icons.error_outline, isError: true)
                : _selectedRegionGroup == null
                ? _buildInitialState()
                : _filteredData.isEmpty
                ? _buildEmptyState("Data tidak ditemukan untuk filter ini", Icons.search_off)
                : _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedRegionGroup != null) {
          await _onRegionGroupChanged(_selectedRegionGroup, forceRefresh: true);
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Graph 1: Ringkasan Audit (Total Ha)"),
            const SizedBox(height: 16),
            _buildAuditStatusChart(),
            const SizedBox(height: 16),
            _buildGraph1Summary(),
            const SizedBox(height: 32),
            _buildSectionTitle("Graph 2: Analisis Area (Visited vs Not Visited)"),
            const SizedBox(height: 16),
            _buildVisitedAreaChart(),
            const SizedBox(height: 16),
            _buildGraph2Summary(),
          ],
        ),
      ),
    );
  }

  Widget _buildGraph1Summary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem("Sampun", _totalSampunArea, const Color(0xFFA5D6A7)),
          if (_selectedWorksheetTitle == 'Generative') ...[
            _buildSummaryItem("Dereng Jangkep", _totalDerengJangkepArea, const Color(0xFFFFB74D)),
            _buildSummaryItem("Dereng Blas", _totalDerengBlasArea, const Color(0xFFD94545)),
          ] else
            _buildSummaryItem("Dereng", _totalDerengArea, const Color(0xFFD94545)),
        ],
      ),
    );
  }

  Widget _buildGraph2Summary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem("Visited", _totalVisitedArea, const Color(0xFF64B5F6)),
          _buildSummaryItem("Not Visited", _totalNotVisitedArea, Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text("${value.toStringAsFixed(1)} Ha", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))]);
  }

  Widget _buildAuditStatusChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(title: AxisTitle(text: 'Bulan'), majorGridLines: const MajorGridLines(width: 0), labelStyle: const TextStyle(fontWeight: FontWeight.bold)),
          primaryYAxis: NumericAxis(title: AxisTitle(text: 'Luasan (Ha)')),
          legend: Legend(isVisible: true, position: LegendPosition.bottom),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries>[
            StackedColumnSeries<_AuditMonthlyData, String>(name: _selectedWorksheetTitle == 'Generative' ? 'Dereng Blas' : 'Dereng', dataSource: _chartData, xValueMapper: (data, _) => data.monthName, yValueMapper: (data, _) => data.derengBlasHa, color: const Color(0xFFD94545), animationDuration: 1500, dataLabelSettings: const DataLabelSettings(isVisible: false)),
            if (_selectedWorksheetTitle == 'Generative') StackedColumnSeries<_AuditMonthlyData, String>(name: 'Dereng Jangkep', dataSource: _chartData, xValueMapper: (data, _) => data.monthName, yValueMapper: (data, _) => data.derengJangkepHa, color: const Color(0xFFFFB74D), animationDuration: 1500, dataLabelSettings: const DataLabelSettings(isVisible: false)),
            StackedColumnSeries<_AuditMonthlyData, String>(name: 'Sampun', dataSource: _chartData, xValueMapper: (data, _) => data.monthName, yValueMapper: (data, _) => data.sampunHa, color: const Color(0xFFA5D6A7), borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), animationDuration: 1500, dataLabelSettings: const DataLabelSettings(isVisible: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitedAreaChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(title: AxisTitle(text: 'Bulan'), majorGridLines: const MajorGridLines(width: 0), labelStyle: const TextStyle(fontWeight: FontWeight.bold)),
          primaryYAxis: NumericAxis(title: AxisTitle(text: 'Luasan (Ha)')),
          legend: Legend(isVisible: true, position: LegendPosition.bottom),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries>[
            StackedColumnSeries<_AuditMonthlyData, String>(name: 'Not Visited', dataSource: _chartData, xValueMapper: (data, _) => data.monthName, yValueMapper: (data, _) => data.notVisitedHa, color: Colors.grey.shade400, animationDuration: 1500, dataLabelSettings: const DataLabelSettings(isVisible: false)),
            StackedColumnSeries<_AuditMonthlyData, String>(name: 'Visited Area', dataSource: _chartData, xValueMapper: (data, _) => data.monthName, yValueMapper: (data, _) => data.visitedHa, color: const Color(0xFF64B5F6), borderRadius: const BorderRadius.vertical(top: Radius.circular(6)), animationDuration: 1500, dataLabelSettings: const DataLabelSettings(isVisible: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade900]), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 3))]),
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () { if (kIsWeb) Navigator.of(context).pop(); else context.go('/admin'); }),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Audit Dashboard', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), Text(_selectedRegionGroup ?? 'Data Gabungan Seluruh Region', style: const TextStyle(color: Colors.white70, fontSize: 13))]))
          ]),
          const SizedBox(height: 16),
          _buildRegionSelector(),
        ]),
      ),
    );
  }

  Widget _buildRegionSelector() {
    return Row(children: [
      Expanded(child: Container(height: 45, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedRegionGroup, hint: const Text("Pilih Region", style: TextStyle(fontSize: 13, color: Colors.grey)), isExpanded: true, items: _regionGroupOptions.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold)))).toList(), onChanged: _isLoading ? null : (val) => _onRegionGroupChanged(val))))),
      const SizedBox(width: 8),
      if (_selectedRegionGroup != null) InkWell(onTap: _isLoading ? null : () => _onRegionGroupChanged(_selectedRegionGroup, forceRefresh: true), child: Container(height: 45, width: 45, decoration: BoxDecoration(color: Colors.white.withAlpha(51), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white54)), child: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.refresh_rounded, color: Colors.white)))
    ]);
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Column(children: [
        Row(children: [
          Expanded(flex: 3, child: _buildModernDropdown(label: "Worksheet", value: _selectedWorksheetTitle, items: _worksheetTitles, icon: Icons.table_chart_rounded, onChanged: (val) { if (val != null && val != _selectedWorksheetTitle) { setState(() => _selectedWorksheetTitle = val); if (_selectedRegionGroup != null) _onRegionGroupChanged(_selectedRegionGroup); } })),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _buildModernDropdown(label: "QA SPV", value: _selectedQaSpv, items: ["Semua SPV", ..._qaSpvOptions], icon: Icons.supervisor_account_rounded, onChanged: (val) { setState(() { _selectedQaSpv = (val == "Semua SPV") ? null : val; _applyFilters(); }); })),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _buildModernDropdown(label: "District", value: _selectedDistrictFilter, items: ["Semua District", ..._districtFilterOptions], icon: Icons.location_city_rounded, onChanged: (val) { setState(() { _selectedDistrictFilter = (val == "Semua District") ? null : val; _applyFilters(); }); })),
        ]),
      ]),
    );
  }

  Widget _buildModernDropdown({required String label, required String? value, required List<String> items, required IconData icon, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value ?? items.first, isExpanded: true, icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.shade600), style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w600), items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Row(children: [Icon(icon, size: 16, color: Colors.blue.shade700), const SizedBox(width: 8), Expanded(child: Text(item, overflow: TextOverflow.ellipsis))]))).toList(), onChanged: onChanged)),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(children: [Container(width: 4, height: 18, color: Colors.green.shade700, margin: const EdgeInsets.only(right: 8)), Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800))]);
  }

  Widget _buildLoadingState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: Colors.green), const SizedBox(height: 16), Text(_loadingStatus ?? "Memuat data...", style: const TextStyle(color: Colors.grey))]));
  }

  Widget _buildInitialState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.touch_app, size: 60, color: Colors.grey.shade300), const SizedBox(height: 20), Text("Pilih Region untuk memulai.", style: TextStyle(fontSize: 16, color: Colors.grey.shade500))]));
  }

  Widget _buildEmptyState(String message, IconData icon, {bool isError = false}) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 60, color: isError ? Colors.red.shade200 : Colors.grey.shade300), const SizedBox(height: 20), Text(message, style: TextStyle(fontSize: 16, color: isError ? Colors.red.shade400 : Colors.grey.shade500))]));
  }

  void _showErrorMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}

// Model Class (Tetap sama, karena Summary tetap disimpan sebagai JSONB)
class _AuditMonthlyData {
  final int monthIndex;
  final String monthName;
  double sampunHa = 0;
  double derengJangkepHa = 0;
  double derengBlasHa = 0;
  double visitedHa = 0;
  double notVisitedHa = 0;
  double totalHa = 0;

  _AuditMonthlyData(this.monthIndex, this.monthName);

  Map<String, dynamic> toJson() => {
    'mi': monthIndex,
    'mn': monthName,
    's': sampunHa,
    'dj': derengJangkepHa,
    'db': derengBlasHa,
    'v': visitedHa,
    'nv': notVisitedHa,
    't': totalHa,
  };

  factory _AuditMonthlyData.fromJson(Map<String, dynamic> json) {
    var data = _AuditMonthlyData(json['mi'], json['mn']);
    data.sampunHa = (json['s'] as num).toDouble();
    data.derengJangkepHa = (json['dj'] as num).toDouble();
    data.derengBlasHa = (json['db'] as num).toDouble();
    data.visitedHa = (json['v'] as num).toDouble();
    data.notVisitedHa = (json['nv'] as num).toDouble();
    data.totalHa = (json['t'] as num).toDouble();
    return data;
  }
}