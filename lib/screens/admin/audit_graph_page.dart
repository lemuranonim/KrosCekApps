import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:go_router/go_router.dart';

// Ganti dengan path yang benar untuk impor Anda
import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';
import 'vegetative_audit_data.dart';
import 'dashboard_widgets.dart';

class AuditGraphPage extends StatefulWidget {
  const AuditGraphPage({super.key});

  @override
  State<AuditGraphPage> createState() => _AuditGraphPageState();
}

class _AuditGraphPageState extends State<AuditGraphPage> {
  // State untuk data dan UI
  bool _isLoading = true;
  String? _error;

  // Data utama, sekarang hanya untuk satu region
  List<VegetativeAuditData> _dataForSelectedRegion = [];
  List<VegetativeAuditData> _filteredData = [];

  // State untuk region dan API
  String? _selectedRegion;
  String? _spreadsheetId;
  GoogleSheetsApi? _googleSheetsApi;

  // Nilai filter yang dipilih
  String? _selectedQaSpv;
  String? _selectedSeason;
  int? _selectedWeek;

  // Opsi untuk dropdown filter
  List<String> _regionOptions = [];
  List<String> _qaSpvOptions = [];
  List<String> _seasonOptions = [];
  List<int> _weekOptions = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    try {
      await ConfigManager.loadConfig();
      setState(() {
        _regionOptions = ConfigManager.getAllRegionNames()..sort();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Gagal memuat konfigurasi region: $e");
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onRegionChanged(String? newRegion) async {
    if (newRegion == null || newRegion == _selectedRegion) return;

    setState(() {
      _isLoading = true;
      _selectedRegion = newRegion;
      _dataForSelectedRegion.clear();
      _filteredData.clear();
      _resetSubFilters(); // Reset filter lain saat region berubah
    });

    try {
      _spreadsheetId = ConfigManager.getSpreadsheetId(newRegion);
      if (_spreadsheetId == null) {
        throw Exception("Spreadsheet ID untuk region '$newRegion' tidak ditemukan.");
      }
      _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
      await _fetchDataForSelectedRegion();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDataForSelectedRegion() async {
    if (_googleSheetsApi == null) return;

    await _googleSheetsApi!.init(); // Menggunakan retry logic dari dalam
    final rows = await _googleSheetsApi!.getSpreadsheetData('Generative');

    final List<VegetativeAuditData> newAuditData = [];
    if (rows.length > 1) {
      final dataRows = rows.sublist(1);
      for (var row in dataRows) {
        if (row.length > 10 && row[10].isNotEmpty && int.tryParse(row[10]) != null) {
          newAuditData.add(VegetativeAuditData.fromGSheetRow(row));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _dataForSelectedRegion = newAuditData;
      _populateSubFilterOptions();
      _applyFilters();
    });
  }

  void _populateSubFilterOptions() {
    _qaSpvOptions = _dataForSelectedRegion.map((d) => d.qaSpv).where((spv) => spv.isNotEmpty).toSet().toList()..sort();
    _seasonOptions = _dataForSelectedRegion.map((d) => d.season).toSet().toList()..sort();
    _weekOptions = _dataForSelectedRegion.map((d) => d.week).where((w) => w != 0).toSet().toList()..sort();
  }

  void _resetSubFilters() {
    _selectedQaSpv = null;
    _selectedSeason = null;
    _selectedWeek = null;
    _qaSpvOptions.clear();
    _seasonOptions.clear();
    _weekOptions.clear();
  }

  void _applyFilters() {
    setState(() {
      _filteredData = _dataForSelectedRegion.where((data) {
        final qaSpvMatch = _selectedQaSpv == null || data.qaSpv == _selectedQaSpv;
        final seasonMatch = _selectedSeason == null || data.season == _selectedSeason;
        final weekMatch = _selectedWeek == null || data.week == _selectedWeek;
        return qaSpvMatch && seasonMatch && weekMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return PopScope(
      // Callback saat pengguna menekan tombol back
      canPop: false, // Mencegah pop langsung
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        // didPop akan false karena canPop: false
        context.go('/admin');
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text('Vegetative Audit Graph',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade700,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _selectedRegion == null ? null : () => _onRegionChanged(_selectedRegion),
            )
          ],
        ),
        body: Column(
          children: [
            _buildRegionSelector(), // Selector Region utama
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Error: $_error", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ))
                  : _selectedRegion == null
                  ? _buildInitialPrompt()
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'Silakan Pilih Region',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          Text(
            'untuk memuat data audit vegetatif.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFilterCard(),
        const SizedBox(height: 24),
        _buildChartCard(),
        const SizedBox(height: 24),
        _buildDataTableCard(),
      ],
    );
  }

  Widget _buildRegionSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade50,
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text('Pilih Region', style: TextStyle(color: Colors.grey.shade700)),
        value: _selectedRegion,
        items: _regionOptions.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: _onRegionChanged,
        buttonStyleData: ButtonStyleData(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300)
          ),
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return CustomCard(
      title: 'Filter Data untuk Region: $_selectedRegion',
      child: Column(
        children: [
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 3.5,
            ),
            children: [
              CustomDropdown<String>(
                labelText: 'QA SPV', value: _selectedQaSpv, hintText: 'Semua SPV',
                items: [
                  const DropdownMenuItem(value: null, child: Text("Semua SPV")),
                  ..._qaSpvOptions.map((spv) => DropdownMenuItem(value: spv, child: Text(spv))),
                ],
                onChanged: (val) => setState(() { _selectedQaSpv = val; _applyFilters(); }),
              ),
              CustomDropdown<String>(
                labelText: 'Season', value: _selectedSeason, hintText: 'Semua Season',
                items: [
                  const DropdownMenuItem(value: null, child: Text("Semua Season")),
                  ..._seasonOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (val) => setState(() { _selectedSeason = val; _applyFilters(); }),
              ),
              CustomDropdown<int>(
                labelText: 'Weeks of Vegetative', value: _selectedWeek, hintText: 'Semua Minggu',
                items: [
                  const DropdownMenuItem(value: null, child: Text("Semua Minggu")),
                  ..._weekOptions.map((w) => DropdownMenuItem(value: w, child: Text("Minggu ke-$w"))),
                ],
                onChanged: (val) => setState(() { _selectedWeek = val; _applyFilters(); }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () { setState(() { _resetSubFilters(); _applyFilters(); }); },
              icon: const Icon(Icons.clear_all),
              label: const Text("Reset Filter"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    // ... (Fungsi _buildChartCard, _prepareChartData, _buildDataTableCard, dan _buildDataRows
    // tetap sama seperti di jawaban sebelumnya, tidak perlu diubah)

    final chartData = _prepareChartData();

    return CustomCard(
      title: 'Grafik Audit',
      child: chartData.isEmpty
          ? const Center(heightFactor: 3, child: Text("Tidak ada data untuk ditampilkan."))
          : SfCartesianChart(
        primaryXAxis: CategoryAxis(title: AxisTitle(text: 'Minggu Vegetatif')),
        primaryYAxis: NumericAxis(title: AxisTitle(text: 'Hektar (Ha)')),
        legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap),
        tooltipBehavior: TooltipBehavior(enable: true, header: "Minggu", format: 'point.x'),
        series: <CartesianSeries>[
          LineSeries<MapEntry<int, dynamic>, String>(
            name: 'Workload (Ha)',
            dataSource: chartData,
            xValueMapper: (data, _) => data.key.toString(),
            yValueMapper: (data, _) => data.value['workloadHa'],
            markerSettings: const MarkerSettings(isVisible: true),
          ),
          LineSeries<MapEntry<int, dynamic>, String>(
            name: 'Audited Veg (Ha)',
            dataSource: chartData,
            xValueMapper: (data, _) => data.key.toString(),
            yValueMapper: (data, _) => data.value['auditedVegHa'],
            markerSettings: const MarkerSettings(isVisible: true),
          ),
          StackedColumnSeries<MapEntry<int, dynamic>, String>(
              name: 'NC Male Split', dataSource: chartData,
              xValueMapper: (data, _) => data.key.toString(),
              yValueMapper: (data, _) => data.value['ncMaleSplitHa'],
              groupName: 'NC_Data'
          ),
          StackedColumnSeries<MapEntry<int, dynamic>, String>(
              name: 'NC Field Size (Ha)', dataSource: chartData,
              xValueMapper: (data, _) => data.key.toString(),
              yValueMapper: (data, _) => data.value['ncFieldSizeHa'],
              groupName: 'NC_Data'
          ),
          StackedColumnSeries<MapEntry<int, dynamic>, String>(
              name: 'NC Planting Date (Ha)', dataSource: chartData,
              xValueMapper: (data, _) => data.key.toString(),
              yValueMapper: (data, _) => data.value['ncPlantingDateHa'],
              groupName: 'NC_Data'
          ),
          StackedColumnSeries<MapEntry<int, dynamic>, String>(
              name: 'POI Non Valid (Ha)', dataSource: chartData,
              xValueMapper: (data, _) => data.key.toString(),
              yValueMapper: (data, _) => data.value['poiNonValidHa'],
              groupName: 'NC_Data'
          ),
          StackedColumnSeries<MapEntry<int, dynamic>, String>(
              name: 'Potential Isolation', dataSource: chartData,
              xValueMapper: (data, _) => data.key.toString(),
              yValueMapper: (data, _) => data.value['potentialIsolationHa'],
              groupName: 'NC_Data'
          ),
        ],
      ),
    );
  }

  List<MapEntry<int, dynamic>> _prepareChartData() {
    if (_filteredData.isEmpty) return [];

    final groupedByWeek = groupBy(_filteredData, (VegetativeAuditData data) => data.week);
    final aggregatedData = groupedByWeek.map((week, dataList) {
      return MapEntry(week, {
        'workloadHa': dataList.map((d) => d.workloadHa).sum,
        'auditedVegHa': dataList.map((d) => d.auditedVegHa).sum,
        'ncMaleSplitHa': dataList.map((d) => d.ncMaleSplitHa).sum,
        'ncFieldSizeHa': dataList.map((d) => d.ncFieldSizeHa).sum,
        'ncPlantingDateHa': dataList.map((d) => d.ncPlantingDateHa).sum,
        'poiNonValidHa': dataList.map((d) => d.poiNonValidHa).sum,
        'potentialIsolationHa': dataList.map((d) => d.potentialIsolationHa).sum,
      });
    });

    final sortedData = aggregatedData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedData;
  }

  Widget _buildDataTableCard() {
    final tableData = _prepareChartData();

    return CustomCard(
      title: 'Detail Data',
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
          columns: [
            const DataColumn(label: Text('Metric')),
            ...tableData.map((data) => DataColumn(label: Text('Week ${data.key}'))),
          ],
          rows: _buildDataRows(tableData),
        ),
      ),
    );
  }

  List<DataRow> _buildDataRows(List<MapEntry<int, dynamic>> tableData) {
    if(tableData.isEmpty) return [];

    DataRow createRow(String title, String key, {bool isPercentage = false}) {
      return DataRow(
        cells: [
          DataCell(Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          ...tableData.map((data) {
            final workload = data.value['workloadHa'];
            final value = data.value[key];
            String cellText;
            if (isPercentage) {
              final percentage = workload > 0 ? (value / workload) * 100 : 0;
              cellText = '${percentage.toStringAsFixed(1)}%';
            } else {
              cellText = value.toStringAsFixed(2);
            }
            return DataCell(Text(cellText));
          }),
        ],
      );
    }

    return [
      createRow('Workload (Ha)', 'workloadHa'),
      createRow('Audited Veg (Ha)', 'auditedVegHa'),
      createRow('% Audited Vegetative', 'auditedVegHa', isPercentage: true),
      createRow('NC Male Split (Ha)', 'ncMaleSplitHa'),
      createRow('% NC Male Split', 'ncMaleSplitHa', isPercentage: true),
      createRow('NC Field Size (Ha)', 'ncFieldSizeHa'),
      createRow('% NC Field Size', 'ncFieldSizeHa', isPercentage: true),
      createRow('NC Planting Date (Ha)', 'ncPlantingDateHa'),
      createRow('% NC Planting Date', 'ncPlantingDateHa', isPercentage: true),
      createRow('POI Non Valid (Ha)', 'poiNonValidHa'),
      createRow('% POI Non Valid', 'poiNonValidHa', isPercentage: true),
      createRow('Potential Isolation (Ha)', 'potentialIsolationHa'),
      createRow('% Potential Isolation', 'potentialIsolationHa', isPercentage: true),
    ];
  }
}