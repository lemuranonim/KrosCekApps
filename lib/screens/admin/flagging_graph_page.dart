import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class FlaggingGraphPage extends StatefulWidget {
  const FlaggingGraphPage({super.key});

  @override
  State<FlaggingGraphPage> createState() => _FlaggingGraphPageState();
}

class _FlaggingGraphPageState extends State<FlaggingGraphPage> {
  // === STATE UI ===
  bool _isLoading = false;
  String? _loadingStatus;
  String? _error;

  // === DATA ===
  // _rawData akan menyimpan data sheet + kolom tambahan di akhir (Nama Region)
  List<List<String>> _rawData = [];

  // Data untuk Grafik (Agregat Total)
  List<_FlagDataPoint> _chartData = [];

  // Data untuk Tabel Pivot (Detail per Region & Bulan)
  // Struktur: Region -> FlagType -> MonthIndex -> TotalArea
  Map<String, Map<String, Map<int, double>>> _pivotData = {};
  // Daftar index bulan yang tersedia di data (untuk kolom tabel)
  List<int> _availableMonthIndices = [];

  // === FILTER CONTROLS ===
  String? _selectedRegionGroup;
  String? _selectedQaSpv;

  static const String _allRegionsSentinel = "Semua Region";
  static const String _allSpvSentinel = "Semua SPV";

  // Options
  List<String> _regionGroupOptions = [];
  List<String> _qaSpvOptions = [];

  // Daftar Region yang dikecualikan
  static const List<String> _excludedRegions = [
    'PSP',
    'PSP QA',
    'SWC',
    'HSP SWC',
    'QA Plant Inspection'
  ];

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
      if (mounted) setState(() => _error = "Gagal memuat konfigurasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER INDEX KOLOM ---
  int _colToIndex(String col) {
    int num = 0;
    for (int i = 0; i < col.length; i++) {
      num = num * 26 + (col.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1);
    }
    return num - 1;
  }

  String _safeGet(List<String> row, int index) {
    if (index < 0 || index >= row.length) return "";
    return row[index].trim();
  }

  // --- HELPER PARSE AREA (KOLOM I) ---
  double _parseArea(String val) {
    if (val.isEmpty) return 0.0;
    val = val.replaceAll(',', '.');
    return double.tryParse(val) ?? 0.0;
  }

  // --- HELPER NAMA BULAN ---
  String _getMonthName(int index) {
    const List<String> manualMonths = [
      "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
      "Jul", "Agu", "Sep", "Okt", "Nov", "Des"
    ];
    if (index >= 1 && index <= 12) {
      return manualMonths[index - 1];
    }
    return "Unk";
  }

  // --- HELPER KONVERSI MINGGU KE BULAN ---
  Map<String, dynamic> _getMonthFromWeek(String weekVal) {
    String cleanVal = weekVal.replaceAll(RegExp(r'[^0-9]'), '');
    int weekNum = int.tryParse(cleanVal) ?? 0;

    if (weekNum <= 0) return {'index': 0, 'name': 'Unknown'};

    DateTime date = DateTime(DateTime.now().year, 1, 1).add(Duration(days: (weekNum - 1) * 7));
    int monthIndex = date.month;

    // Nama bulan lengkap untuk Chart
    String monthNameFull = DateFormat('MMMM', 'id_ID').format(date);

    // Fallback jika locale gagal
    const List<String> manualMonthsFull = [
      "Januari", "Februari", "Maret", "April", "Mei", "Juni",
      "Juli", "Agustus", "September", "Oktober", "November", "Desember"
    ];
    if (monthIndex >= 1 && monthIndex <= 12) {
      monthNameFull = manualMonthsFull[monthIndex - 1];
    }

    return {'index': monthIndex, 'name': monthNameFull};
  }

  // --- INIT REGION ---
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

    final sortedGroups = groups.toList()..sort();

    setState(() {
      _regionGroupOptions = [_allRegionsSentinel, ...sortedGroups];
    });
  }

  // --- FETCH DATA ---
  Future<void> _onRegionGroupChanged(String? newGroup) async {
    if (newGroup == null) return;

    setState(() {
      _selectedRegionGroup = newGroup;
      _selectedQaSpv = null;
      _qaSpvOptions.clear();
      _isLoading = true;
      _error = null;
      _loadingStatus = "Mengidentifikasi area...";
      _rawData.clear();
      _chartData.clear();
      _pivotData.clear();
    });

    try {
      final allKeys = ConfigManager.getAllRegionNames()
          .where((r) => !_excludedRegions.contains(r))
          .where((r) => r.startsWith('Region'))
          .toList();

      List<String> targetKeys = [];

      if (newGroup == _allRegionsSentinel) {
        targetKeys = allKeys;
      } else {
        targetKeys = allKeys.where((key) {
          String keyGroup = key.contains(" - ") ? key.split(" - ")[0].trim() : key.trim();
          return keyGroup == newGroup;
        }).toList();
      }

      if (targetKeys.isEmpty) {
        throw Exception("Tidak ada data spreadsheet untuk grup ini.");
      }

      // Batch Fetching
      List<List<String>> combinedData = [];
      List<String> headers = [];

      int batchSize = 5;
      for (int i = 0; i < targetKeys.length; i += batchSize) {
        int end = (i + batchSize < targetKeys.length) ? i + batchSize : targetKeys.length;
        List<String> batchKeys = targetKeys.sublist(i, end);

        setState(() {
          _loadingStatus = "Memuat data area ${i + 1} - $end dari ${targetKeys.length}...";
        });

        // Fetch dan tandai data dengan nama Region
        List<Future<List<List<String>>>> futures = batchKeys.map((key) async {
          final sheetId = ConfigManager.getSpreadsheetId(key);
          if (sheetId == null) return <List<String>>[];

          try {
            final gSheets = GoogleSheetsApi(sheetId);
            await gSheets.init();
            var rows = await gSheets.getSpreadsheetData('Generative');

            // PENTING: Tambahkan Nama Region ke setiap baris agar bisa dipisahkan nanti
            // Kita skip header (index 0) saat penandaan nanti di penggabungan
            // Tapi untuk amannya, kita modifikasi list row nya disini
            if (rows.isNotEmpty) {
              // Tambah region name ke header juga (meski nanti header pertama yg dipakai)
              rows[0].add("SOURCE_REGION");
              for (int r = 1; r < rows.length; r++) {
                rows[r].add(key); // Menambahkan Key Region di kolom terakhir
              }
            }
            return rows;
          } catch (e) {
            debugPrint("Gagal load $key: $e");
            return <List<String>>[];
          }
        }).toList();

        final results = await Future.wait(futures);

        for (var rows in results) {
          if (rows.isNotEmpty) {
            if (headers.isEmpty) {
              headers = rows[0]; // Header sudah termasuk kolom SOURCE_REGION
              combinedData.add(headers);
            }
            if (rows.length > 1) {
              combinedData.addAll(rows.sublist(1));
            }
          }
        }

        if (end < targetKeys.length) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      if (mounted) {
        setState(() {
          _rawData = combinedData;
          _extractQaSpvOptions();
          _processData(); // Proses Chart dan Tabel Pivot sekaligus
          _isLoading = false;
          _loadingStatus = null;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Terjadi kesalahan: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _extractQaSpvOptions() {
    if (_rawData.isEmpty) return;
    final Set<String> spvSet = {};
    final int spvIdx = _colToIndex("AE");

    for (var row in _rawData.skip(1)) {
      final val = _safeGet(row, spvIdx);
      if (val.isNotEmpty && val != "-" && val != "0") {
        spvSet.add(val);
      }
    }

    setState(() {
      _qaSpvOptions = [_allSpvSentinel, ...spvSet.toList()..sort()];
      if (_selectedQaSpv == null || !_qaSpvOptions.contains(_selectedQaSpv)) {
        _selectedQaSpv = _allSpvSentinel;
      }
    });
  }

  void _onQaSpvChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedQaSpv = newValue;
      _processData();
    });
  }

  // --- LOGIC PENGOLAHAN DATA (CHART & TABLE) ---
  void _processData() {
    if (_rawData.length <= 1) {
      setState(() {
        _chartData = [];
        _pivotData = {};
        _availableMonthIndices = [];
      });
      return;
    }

    final int idxArea = _colToIndex("I");
    final int idxPeriod = _colToIndex("AC");
    final int idxFlag = _colToIndex("BL");
    final int idxSpv = _colToIndex("AE");

    // Aggregator untuk Chart (Global per bulan)
    Map<int, _FlagDataPoint> chartGrouped = {};

    // Aggregator untuk Pivot Table (Region -> Flag -> Month -> Area)
    Map<String, Map<String, Map<int, double>>> pivotGrouped = {};
    Set<int> foundMonths = {};

    for (var row in _rawData.skip(1)) {
      // 1. Filter SPV
      final String spvVal = _safeGet(row, idxSpv);
      if (_selectedQaSpv != _allSpvSentinel && spvVal != _selectedQaSpv) {
        continue;
      }

      String flagVal = _safeGet(row, idxFlag).toUpperCase();
      if (flagVal.isEmpty || flagVal.contains("DISCARD")) continue;

      // Normalize Flag Name
      String flagType = "";
      if (flagVal.contains("GF")) {
        flagType = "GF";
      } else if (flagVal.contains("RFD")) {
        flagType = "RFD";
      } else if (flagVal.contains("RFI")) {
        flagType = "RFI";
      } else {
        continue;
      }

      // 2. Parse Data
      String rawWeek = _safeGet(row, idxPeriod);
      Map<String, dynamic> monthInfo = _getMonthFromWeek(rawWeek);
      int monthIdx = monthInfo['index'];
      if (monthIdx == 0) continue;

      double area = _parseArea(_safeGet(row, idxArea));

      // --- PERBAIKAN NAMA REGION ---
      // Ambil nama raw dari kolom terakhir, lalu bersihkan agar sesuai Dropdown
      String rawRegionName = row.last;
      String regionName = rawRegionName;

      // Logika penyederhanaan nama (sama seperti logic dropdown)
      if (rawRegionName.contains(" - ")) {
        regionName = rawRegionName.split(" - ")[0].trim();
      } else {
        regionName = rawRegionName.trim();
      }

      foundMonths.add(monthIdx);

      // --- ISI DATA CHART ---
      if (!chartGrouped.containsKey(monthIdx)) {
        chartGrouped[monthIdx] = _FlagDataPoint(monthIdx, monthInfo['name']);
      }

      if (flagType == "GF") {
        chartGrouped[monthIdx]!.gf += area;
      } else if (flagType == "RFD") {
        chartGrouped[monthIdx]!.rfd += area;
      } else if (flagType == "RFI") {
        chartGrouped[monthIdx]!.rfi += area;
      }

      // --- ISI DATA PIVOT TABLE ---
      pivotGrouped.putIfAbsent(regionName, () => {});
      pivotGrouped[regionName]!.putIfAbsent(flagType, () => {});

      double currentVal = pivotGrouped[regionName]![flagType]![monthIdx] ?? 0.0;
      // Otomatis menjumlahkan area jika nama Regionnya sudah disamakan
      pivotGrouped[regionName]![flagType]![monthIdx] = currentVal + area;
    }

    // Sort Chart Data
    List<_FlagDataPoint> chartResult = chartGrouped.values.toList();
    chartResult.sort((a, b) => a.monthIndex.compareTo(b.monthIndex));

    // Sort Available Months for Table Columns
    List<int> sortedMonths = foundMonths.toList()..sort();

    setState(() {
      _chartData = chartResult;
      _pivotData = pivotGrouped;
      _availableMonthIndices = sortedMonths;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (kIsWeb) {
              Navigator.of(context).pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        title: const Text('Flagging Graph',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade800,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTopFilterSection(),

          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ))
                : _selectedRegionGroup == null
                ? _buildInitialState()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade800,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Filter Data", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildWhiteDropdown(
                  value: _selectedRegionGroup,
                  hint: "Pilih Region",
                  items: _regionGroupOptions,
                  onChanged: _isLoading ? null : _onRegionGroupChanged,
                  icon: Icons.map,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildWhiteDropdown(
                  value: _selectedQaSpv,
                  hint: "Pilih QA SPV",
                  items: _qaSpvOptions,
                  onChanged: (_isLoading || _selectedRegionGroup == null) ? null : _onQaSpvChanged,
                  icon: Icons.supervisor_account,
                  isDisabled: _selectedRegionGroup == null || _qaSpvOptions.isEmpty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text("Tidak ada data valid untuk filter ini.",
                style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartCard(),
          const SizedBox(height: 24),
          _buildPivotTableCard(),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Area Flagging per Bulan",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Region: $_selectedRegionGroup | SPV: ${_selectedQaSpv ?? '-'}",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            SfCartesianChart(
              primaryXAxis: CategoryAxis(
                majorGridLines: const MajorGridLines(width: 0),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'Luasan (Ha)'),
              ),
              legend: Legend(isVisible: true, position: LegendPosition.bottom),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: <CartesianSeries>[
                StackedColumnSeries<_FlagDataPoint, String>(
                  name: 'RFD',
                  dataSource: _chartData,
                  xValueMapper: (data, _) => data.monthName,
                  yValueMapper: (data, _) => data.rfd,
                  color: const Color(0xFFD94545),
                ),
                StackedColumnSeries<_FlagDataPoint, String>(
                  name: 'RFI',
                  dataSource: _chartData,
                  xValueMapper: (data, _) => data.monthName,
                  yValueMapper: (data, _) => data.rfi,
                  color: const Color(0xFFE57373),
                ),
                StackedColumnSeries<_FlagDataPoint, String>(
                  name: 'GF',
                  dataSource: _chartData,
                  xValueMapper: (data, _) => data.monthName,
                  yValueMapper: (data, _) => data.gf,
                  color: const Color(0xFFA5D6A7),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPivotTableCard() {
    // Siapkan Row Data Table
    List<DataRow> rows = [];
    List<String> sortedRegions = _pivotData.keys.toList()..sort();
    const List<String> flagTypes = ["GF", "RFI", "RFD"];

    // Style Variables
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade700,
      letterSpacing: 0.5,
    );

    final cellStyle = TextStyle(fontSize: 13, color: Colors.grey.shade800);
    final totalStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87);

    for (String region in sortedRegions) {
      Map<String, Map<int, double>> regionFlags = _pivotData[region]!;

      double regionGrandTotal = 0;
      Map<int, double> regionSubtotalByMonth = {};

      // Hitung Subtotal
      for (var monthIdx in _availableMonthIndices) {
        double monthSum = 0;
        for (var flag in flagTypes) {
          monthSum += (regionFlags[flag]?[monthIdx] ?? 0.0);
        }
        regionSubtotalByMonth[monthIdx] = monthSum;
        regionGrandTotal += monthSum;
      }

      // --- BARIS DATA (GF, RFI, RFD) ---
      for (int i = 0; i < flagTypes.length; i++) {
        String flag = flagTypes[i];
        List<DataCell> cells = [];

        // 1. Region Name (Bold & Sticky look)
        if (i == 0) {
          cells.add(DataCell(
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(right: 10),
                child: Text(region, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              )
          ));
        } else {
          cells.add(DataCell.empty);
        }

        // 2. Flag Badge (Premium Look)
        Color badgeColor = flag == "GF" ? Colors.green : (flag == "RFD" ? Colors.red : Colors.orange);
        cells.add(DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: badgeColor.withAlpha(25), // Transparan halus
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withAlpha(50))
              ),
              child: Text(flag, style: TextStyle(
                  color: badgeColor.withAlpha(255), // Solid text
                  fontWeight: FontWeight.bold,
                  fontSize: 11
              )),
            )
        ));

        // 3. Data Bulanan
        double rowTotal = 0;
        for (int monthIdx in _availableMonthIndices) {
          double val = regionFlags[flag]?[monthIdx] ?? 0.0;
          rowTotal += val;
          cells.add(DataCell(
            Text(val == 0 ? "-" : val.toStringAsFixed(2), style: cellStyle),
          ));
        }

        // 4. Total Baris
        cells.add(DataCell(Text(rowTotal.toStringAsFixed(2), style: totalStyle)));

        // 5. Persentase
        double percentage = (regionGrandTotal == 0) ? 0.0 : (rowTotal / regionGrandTotal * 100);
        cells.add(DataCell(_buildPercentageBadge(percentage)));

        rows.add(DataRow(cells: cells));
      }

      // --- BARIS SUBTOTAL (Premium Divider Look) ---
      List<DataCell> subCells = [];
      subCells.add(const DataCell(Text("TOTAL", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 11, letterSpacing: 1))));
      subCells.add(DataCell.empty);

      for (int monthIdx in _availableMonthIndices) {
        double val = regionSubtotalByMonth[monthIdx] ?? 0.0;
        subCells.add(DataCell(Text(val.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))));
      }
      subCells.add(DataCell(Text(regionGrandTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))));
      subCells.add(DataCell(_buildPercentageBadge(100.0, isTotal: true)));

      rows.add(DataRow(
          color: WidgetStateProperty.all(Colors.grey.withAlpha(15)), // Sangat tipis abu-abunya
          cells: subCells
      ));
    }

    // -- HEADER KOLOM --
    List<DataColumn> columns = [
      DataColumn(label: Text("REGION", style: headerStyle)),
      DataColumn(label: Text("FLAG", style: headerStyle)),
    ];

    for (int monthIdx in _availableMonthIndices) {
      columns.add(DataColumn(
        label: Text(_getMonthName(monthIdx).toUpperCase(), style: headerStyle),
        numeric: true,
      ));
    }
    columns.add(DataColumn(label: Text("TOTAL", style: headerStyle), numeric: true));
    columns.add(DataColumn(label: Text("% AREA", style: headerStyle), numeric: true));

    // --- STRUKTUR UI UTAMA ---
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.table_chart_outlined, color: Colors.green.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Detail Breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("Data luasan per region dan bulan", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // Table Area with Horizontal Scroll
          Theme(
            data: Theme.of(context).copyWith(
                dividerColor: Colors.grey.shade100, // Garis pemisah baris lebih halus
                dataTableTheme: DataTableThemeData(
                  headingRowColor: WidgetStateProperty.all(Colors.white),
                  dataRowMinHeight: 48, // Tinggi baris lebih lega
                  dataRowMaxHeight: 52,
                  columnSpacing: 24, // Spasi antar kolom lebih lega
                  dividerThickness: 1,
                )
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
                child: DataTable(
                  horizontalMargin: 20,
                  columns: columns,
                  rows: rows,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Helper Widget untuk Badge Persentase
  Widget _buildPercentageBadge(double value, {bool isTotal = false}) {
    Color bg, text;
    if (isTotal) {
      bg = Colors.blue.withAlpha(30);
      text = Colors.blue.shade800;
    } else if (value > 50) {
      bg = Colors.green.withAlpha(30);
      text = Colors.green.shade800;
    } else if (value > 20) {
      bg = Colors.orange.withAlpha(30);
      text = Colors.orange.shade800;
    } else {
      bg = Colors.grey.withAlpha(30);
      text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "${value.toStringAsFixed(1)}%",
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.green),
          const SizedBox(height: 16),
          Text(_loadingStatus ?? "Memuat data...", style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text("Pilih Region untuk memulai.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildWhiteDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?)? onChanged,
    required IconData icon,
    bool isDisabled = false,
  }) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDisabled ? Colors.white24 : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(children: [
            Icon(icon, size: 16, color: isDisabled ? Colors.white30 : Colors.green.shade700),
            const SizedBox(width: 8),
            Text(hint, style: TextStyle(fontSize: 13, color: isDisabled ? Colors.white30 : Colors.grey), overflow: TextOverflow.ellipsis),
          ]),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: isDisabled ? Colors.white30 : Colors.green.shade800),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// === MODEL DATA CHART ===
class _FlagDataPoint {
  final int monthIndex; // 1-12
  final String monthName; // "Januari", "Februari"
  double gf = 0;
  double rfi = 0;
  double rfd = 0;

  _FlagDataPoint(this.monthIndex, this.monthName);
}