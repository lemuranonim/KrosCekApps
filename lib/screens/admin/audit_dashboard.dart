import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import 'package:collection/collection.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

// Ganti path ini sesuai dengan struktur proyek Anda
import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';
// import 'generative_detail_screen.dart'; //
import 'dashboard_widgets.dart'; // Pastikan file ini ada dan berisi CustomCard

class AuditDashboard extends StatefulWidget {
  const AuditDashboard({super.key});

  @override
  State<AuditDashboard> createState() => _AuditDashboardState();
}

class _AuditDashboardState extends State<AuditDashboard> {
  // === STATE MANAGEMENT ===

  // UI State
  bool _isLoading = false;
  String? _error;

  // Raw Data from Sheets
  List<List<String>> _allGenerativeData = [];
  final Map<String, int> _activityCounts = {};
  final Map<String, List<DateTime>> _activityTimestamps = {};

  // Filtered Data
  List<List<String>> _filteredData = [];

  // Filter Controls State
  String? _selectedRegion;
  String? _selectedQaSpv;
  String? _selectedSeason;
  final List<int> _selectedWeeks = [];
  String _searchQuery = '';
  // ✅ State untuk filter worksheet baru
  String _selectedWorksheetTitle = 'Generative';
  final List<String> _worksheetTitles = ['Generative', 'Vegetative', 'Pre Harvest', 'Harvest'];

  // Filter Options
  List<String> _regionOptions = [];
  List<String> _qaSpvOptions = [];
  List<String> _seasonOptions = [];
  List<int> _weekOptions = [];

  // API Instances
  GoogleSheetsApi? _googleSheetsApi;

  // Calculated Statistics
  int _sampunCount = 0;
  int _derengJangkepCount = 0;
  int _derengBlasCount = 0;
  int _derengCount = 0; // ✅ Statistik baru untuk 'Dereng'
  double _sampunArea = 0.0;
  double _derengJangkepArea = 0.0;
  double _derengBlasArea = 0.0;
  int _fieldsWithActivity = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // === DATA & FILTER LOGIC ===

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    try {
      await ConfigManager.loadConfig();
      setState(() {
        _regionOptions = ConfigManager.getAllRegionNames()..sort();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Gagal memuat konfigurasi: $e");
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onRegionChanged(String? newRegion) async {
    if (newRegion == null || newRegion == _selectedRegion) return;

    setState(() {
      _selectedRegion = newRegion;
      // Jangan reset worksheet, tapi panggil refetch
    });

    _fetchData();
  }

  Future<void> _onWorksheetChanged(String? newWorksheet) async {
    if(newWorksheet == null || newWorksheet == _selectedWorksheetTitle) return;

    setState(() {
      _selectedWorksheetTitle = newWorksheet;
    });

    _fetchData();
  }

  Future<void> _fetchData() async {
    if(_selectedRegion == null) return;

    setState(() {
      _isLoading = true;
      _clearAllData();
      _resetSubFilters();
    });

    try {
      final spreadsheetId = ConfigManager.getSpreadsheetId(_selectedRegion!);
      if (spreadsheetId == null) throw Exception("Spreadsheet ID untuk '$_selectedRegion' tidak ditemukan.");

      _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
      await _googleSheetsApi!.init();

      final results = await Future.wait([
        _googleSheetsApi!.getSpreadsheetData(_selectedWorksheetTitle),
        _googleSheetsApi!.getSpreadsheetData('Aktivitas'),
      ]);

      _allGenerativeData = results[0];
      _processActivityData(results[1]);
      _populateSubFilterOptions();
      _applyFilters();

    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Gagal memuat data dari worksheet '$_selectedWorksheetTitle'. Pastikan sheet tersebut ada. Error: ${e.toString()}");
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _processActivityData(List<List<String>> activityRows) {
    _activityCounts.clear();
    _activityTimestamps.clear();
    if (activityRows.length <= 1) return;
    for (var row in activityRows.sublist(1)) {
      final fieldNumber = _getValue(row, 1, "");
      if (fieldNumber.isEmpty) continue;
      _activityCounts[fieldNumber] = (_activityCounts[fieldNumber] ?? 0) + 1;
      final timestamp = _parseDate(_getValue(row, 0, ""));
      if(timestamp != null) _activityTimestamps.putIfAbsent(fieldNumber, () => []).add(timestamp);
    }
    _activityTimestamps.forEach((key, value) => value.sort((a, b) => b.compareTo(a)));
  }

  void _populateSubFilterOptions() {
    if (_allGenerativeData.length <= 1) return;
    final data = _allGenerativeData.sublist(1);
    final int weekColumn = _getWeekColumn();

    _qaSpvOptions = data.map((row) => _getValue(row, 4, "")).where((spv) => spv.isNotEmpty).toSet().toList()..sort();
    _seasonOptions = data.map((row) => _getValue(row, 1, "")).where((s) => s.isNotEmpty).toSet().toList()..sort();
    _weekOptions = data.map((row) => int.tryParse(_getValue(row, weekColumn, ""))).whereType<int>().toSet().toList()..sort();
  }

  void _resetSubFilters() {
    _selectedQaSpv = null;
    _selectedSeason = null;
    _selectedWeeks.clear();
    _qaSpvOptions.clear();
    _seasonOptions.clear();
    _weekOptions.clear();
  }

  void _clearAllData() {
    _allGenerativeData.clear();
    _filteredData.clear();
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _resetSubFilters();
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (_allGenerativeData.length <= 1) {
      setState(() {
        _filteredData = [];
        _calculateStatistics();
      });
      return;
    }
    final int weekColumn = _getWeekColumn();
    List<List<String>> tempFilteredData = _allGenerativeData.sublist(1);
    tempFilteredData = tempFilteredData.where((row) {
      final qaSpv = _getValue(row, 4, "");
      final season = _getValue(row, 1, "");
      final week = int.tryParse(_getValue(row, weekColumn, ""));
      final qaSpvMatch = _selectedQaSpv == null || qaSpv == _selectedQaSpv;
      final seasonMatch = _selectedSeason == null || season == _selectedSeason;
      final weekMatch = _selectedWeeks.isEmpty || (week != null && _selectedWeeks.contains(week));
      return qaSpvMatch && seasonMatch && weekMatch;
    }).toList();
    if (_searchQuery.isNotEmpty) {
      tempFilteredData = tempFilteredData.where((row) {
        final farmerName = _getValue(row, 3, "").toLowerCase();
        final fieldNumber = _getValue(row, 2, "").toLowerCase();
        return farmerName.contains(_searchQuery.toLowerCase()) || fieldNumber.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {
      _filteredData = tempFilteredData;
      _calculateStatistics();
    });
  }

  // ✅ KALKULASI STATISTIK KONDISIONAL
  void _calculateStatistics() {
    int sampun = 0, derengJangkep = 0, derengBlas = 0, dereng = 0;
    double sampunA = 0, derengJangkepA = 0, derengBlasA = 0;
    int withActivity = 0;

    for (var row in _filteredData) {
      final fieldNumber = _getValue(row, 2, "");
      final auditStatus = _getAuditStatus(row);
      if (_activityCounts.containsKey(fieldNumber)) withActivity++;
      final effectiveArea = double.tryParse(_getValue(row, 8, "0").replaceAll(',', '.')) ?? 0.0;

      if (_selectedWorksheetTitle == 'Generative') {
        switch (auditStatus) {
          case "Sampun": sampun++; sampunA += effectiveArea; break;
          case "Dereng Jangkep": derengJangkep++; derengJangkepA += effectiveArea; break;
          default: derengBlas++; derengBlasA += effectiveArea; break;
        }
      } else { // For Vegetative, Pre Harvest, Harvest
        if (auditStatus == "Sampun") {
          sampun++;
          sampunA += effectiveArea;
        } else {
          dereng++;
          // Semua yang tidak sampun dianggap area dereng
          derengJangkepA += effectiveArea;
          derengBlasA += effectiveArea;
        }
      }
    }

    setState(() {
      _sampunCount = sampun;
      _derengJangkepCount = derengJangkep;
      _derengBlasCount = derengBlas;
      _derengCount = dereng;
      _sampunArea = sampunA;
      // Gabungkan area dereng untuk tampilan sederhana
      _derengJangkepArea = derengJangkepA;
      _derengBlasArea = derengBlasA;
      _fieldsWithActivity = withActivity;
    });
  }

  // === UI BUILDERS ===

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) => context.go('/admin'),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.go('/admin')),
          title: const Text('Audit Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.primaryDark, // Menggunakan warna dari AppTheme
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _selectedRegion == null ? null : _fetchData,
            )
          ],
        ),
        body: Column(
          children: [
            _buildRegionSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Error: $_error", textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.error)), // Menggunakan warna dari AppTheme
              ))
                  : _selectedRegion == null
                  ? _buildInitialPrompt()
                  : _buildDashboardContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ KODE PERBAIKAN
  Widget _buildDashboardContent() {
    // Langsung gunakan SingleChildScrollView sebagai widget utama untuk seluruh konten
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Padding dipindahkan ke sini
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartu filter sekarang menjadi bagian dari konten yang bisa di-scroll
            _buildFilterCard(),
            const SizedBox(height: 24), // Beri jarak antar elemen
            Text('Ringkasan Dashboard', style: AppTheme.heading2),
            const SizedBox(height: 16),
            _buildSummaryCards(),
            const SizedBox(height: 24),
            Text('Analisis Area (Ha)', style: AppTheme.heading2),
            const SizedBox(height: 16),
            _buildAreaAnalysisCard(),
            const SizedBox(height: 24),
            Text('Update Terbaru', style: AppTheme.heading2),
            const SizedBox(height: 16),
            _buildRecentActivitiesCard(context),
            const SizedBox(height: 24),
            Text('Lahan Visited Terbanyak', style: AppTheme.heading2),
            const SizedBox(height: 16),
            _buildTopFieldsTable(context),
          ],
        ),
      ),
    );
  }

  // ✅ Tampilan kartu ringkasan dinamis
  Widget _buildSummaryCards() {
    return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: _selectedWorksheetTitle == 'Generative' ? 2 : 3,
        childAspectRatio: _selectedWorksheetTitle == 'Generative' ? 1.3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: _selectedWorksheetTitle == 'Generative'
            ? [ // Tampilan untuk Generative
          _buildDashboardCard(title: 'Visited', value: '$_fieldsWithActivity', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.analytics, color: AppTheme.info, percentage: _formatPercentage(_fieldsWithActivity, _filteredData.length)),
          _buildDashboardCard(title: 'Sampun', value: '$_sampunCount', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.check_circle, color: AppTheme.success, percentage: _formatPercentage(_sampunCount, _filteredData.length)),
          _buildDashboardCard(title: 'Dereng Jangkep', value: '$_derengJangkepCount', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.warning, color: AppTheme.warning, percentage: _formatPercentage(_derengJangkepCount, _filteredData.length)),
          _buildDashboardCard(title: 'Dereng Blas', value: '$_derengBlasCount', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.cancel, color: AppTheme.error, percentage: _formatPercentage(_derengBlasCount, _filteredData.length)),
        ]
            : [ // Tampilan untuk worksheet lain
          _buildDashboardCard(title: 'Visited', value: '$_fieldsWithActivity', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.analytics, color: AppTheme.info, percentage: _formatPercentage(_fieldsWithActivity, _filteredData.length)),
          _buildDashboardCard(title: 'Sampun', value: '$_sampunCount', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.check_circle, color: AppTheme.success, percentage: _formatPercentage(_sampunCount, _filteredData.length)),
          _buildDashboardCard(title: 'Dereng', value: '$_derengCount', total: _filteredData.length, subtitle: 'Lahan', icon: Icons.warning, color: AppTheme.error, percentage: _formatPercentage(_derengCount, _filteredData.length)),
        ]
    );
  }

  // ✅ KARTU BARU UNTUK ANALISIS AREA
  Widget _buildAreaAnalysisCard() {
    double totalArea = _sampunArea + _derengJangkepArea + _derengBlasArea;
    if (_selectedWorksheetTitle != 'Generative') {
      totalArea = _sampunArea + (_derengJangkepArea + _derengBlasArea);
    }

    return CustomCard(
        title: "Distribusi Area Efektif",
        child: Column(
          children: [
            Row(
              children: [
                _buildAreaAnalysisItem(title: 'Total Area', value: '${totalArea.toStringAsFixed(2)} Ha', color: AppTheme.accent),
                const SizedBox(width: 16),
                _buildAreaAnalysisItem(title: 'Sampun', value: '${_sampunArea.toStringAsFixed(2)} Ha', color: AppTheme.success, percentage: _formatPercentage(_sampunArea.round(), totalArea.round())),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedWorksheetTitle == 'Generative')
              Row(
                children: [
                  _buildAreaAnalysisItem(title: 'Dereng Jangkep', value: '${_derengJangkepArea.toStringAsFixed(2)} Ha', color: AppTheme.warning, percentage: _formatPercentage(_derengJangkepArea.round(), totalArea.round())),
                  const SizedBox(width: 16),
                  _buildAreaAnalysisItem(title: 'Dereng Blas', value: '${_derengBlasArea.toStringAsFixed(2)} Ha', color: AppTheme.error, percentage: _formatPercentage(_derengBlasArea.round(), totalArea.round())),
                ],
              )
            else
              Row(
                children: [
                  _buildAreaAnalysisItem(title: 'Dereng', value: '${(_derengJangkepArea + _derengBlasArea).toStringAsFixed(2)} Ha', color: AppTheme.error, percentage: _formatPercentage((_derengJangkepArea + _derengBlasArea).round(), totalArea.round())),
                ],
              )
          ],
        )
    );
  }

  Widget _buildAreaAnalysisItem({ required String title, required String value, String? percentage, required Color color, }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            if (percentage != null) ...[
              const SizedBox(height: 2),
              Text('$percentage%', style: TextStyle(fontSize: 12, color: color.withAlpha(204))),
            ],
          ],
        ),
      ),
    );
  }

  // Widget lainnya tidak banyak berubah
  Widget _buildDashboardCard({ required String title, required String value, int? total, required String subtitle, required IconData icon, required Color color, required String percentage, }) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))] // Efek bayangan
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Menyesuaikan penempatan konten
          children: [
            Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMedium))]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                if (total != null) Text(' / $total', style: const TextStyle(fontSize: 14, color: AppTheme.textMedium)),
              ]),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
            ]),
          ],
        ),
      ),
    );
  }
  Widget _buildRecentActivitiesCard(BuildContext context) {
    final List<MapEntry<String, DateTime>> allActivities = [];
    for (var row in _filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      if (_activityTimestamps.containsKey(fieldNumber)) {
        for (var timestamp in _activityTimestamps[fieldNumber]!) {
          allActivities.add(MapEntry(fieldNumber, timestamp));
        }
      }
    }
    allActivities.sort((a, b) => b.value.compareTo(a.value));
    final recentActivities = allActivities.take(5).toList();
    return CustomCard(
      title: "Update Terbaru",
      child: recentActivities.isEmpty
          ? const Center(child: Text('No recent activities.'))
          : Column(
        children: recentActivities.map((activity) {
          final fieldData = _filteredData.firstWhere((row) => _getValue(row, 2, "") == activity.key, orElse: () => []);
          final farmerName = fieldData.isNotEmpty ? _getValue(fieldData, 3, "Unknown") : "Unknown";
          final auditStatus = fieldData.isNotEmpty ? _getAuditStatus(fieldData) : "Dereng Blas";
          return ListTile(
            leading: Icon(_getAuditStatusIcon(auditStatus), color: _getAuditStatusColor(auditStatus)),
            title: Text('Lahan ${activity.key}'),
            subtitle: Text('Farmer: $farmerName'),
            trailing: Text(DateFormat('dd MMM, HH:mm').format(activity.value), style: const TextStyle(fontSize: 12)),
            onTap: () { /* Navigasi dinonaktifkan sementara */ },
          );
        }).toList(),
      ),
    );
  }
  Widget _buildTopFieldsTable(BuildContext context) {
    final List<MapEntry<String, int>> sortedFields = _activityCounts.entries.toList()
      ..removeWhere((entry) => !_filteredData.any((row) => _getValue(row, 2, "") == entry.key))
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFields = sortedFields.take(5).toList();
    return CustomCard(
      title: 'Lahan Visited Terbanyak',
      padding: EdgeInsets.zero, // Mengatur padding menjadi nol agar DataTable bisa mengisi penuh
      child: topFields.isEmpty
          ? const Center(heightFactor: 2, child: Text('No activities found.'))
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [ DataColumn(label: Text('Lahan')), DataColumn(label: Text('Visited')), DataColumn(label: Text('Status')), DataColumn(label: Text('DAP')), DataColumn(label: Text('Area (Ha)')) ],
          rows: topFields.map((entry) {
            final fieldData = _filteredData.firstWhere((row) => _getValue(row, 2, "") == entry.key, orElse: () => []);
            final auditStatus = fieldData.isNotEmpty ? _getAuditStatus(fieldData) : "Dereng Blas";
            final dap = fieldData.isNotEmpty ? _calculateDAP(fieldData) : 0;
            final effectiveArea = double.tryParse(_getValue(fieldData, 8, "0").replaceAll(',', '.')) ?? 0.0;
            return DataRow(cells: [
              DataCell(Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { /* Navigasi dinonaktifkan sementara */ }),
              DataCell(Text('${entry.value}')), DataCell(Text(auditStatus)),
              DataCell(Text('$dap')), DataCell(Text(effectiveArea.toStringAsFixed(2))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
  Widget _buildInitialPrompt() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.location_on_outlined, size: 60, color: Colors.grey.shade400), const SizedBox(height: 20), Text('Silakan Pilih Region', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)) ])); }
  Widget _buildRegionSelector() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppTheme.background, // Menggunakan warna background dari AppTheme
        child: DropdownButton2<String>(
            isExpanded: true,
            hint: Text('Pilih Region', style: TextStyle(color: AppTheme.textMedium)), // Menggunakan warna dari AppTheme
            value: _selectedRegion,
            items: _regionOptions.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: _onRegionChanged,
            buttonStyleData: ButtonStyleData(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.textLight) // Menggunakan warna dari AppTheme
                )
            ),
            dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14))
            )
        )
    );
  }
  Widget _buildFilterCard() {
    return CustomCard( // Menggunakan CustomCard
      title: 'Filter Data',
      child: Column(
        children: [
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 4.5 // Menyesuaikan rasio aspek untuk tampilan yang lebih baik
            ),
            children: [
              // ✅ Filter Worksheet ditambahkan di sini
              CustomDropdown<String>(
                labelText: 'Worksheet', value: _selectedWorksheetTitle, hintText: 'Pilih Worksheet',
                items: _worksheetTitles.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: _onWorksheetChanged,
              ),
              CustomDropdown<String>(
                labelText: 'QA SPV', value: _selectedQaSpv, hintText: 'Semua SPV',
                items: [ const DropdownMenuItem(value: null, child: Text("Semua SPV")), ..._qaSpvOptions.map((spv) => DropdownMenuItem(value: spv, child: Text(spv))) ],
                onChanged: (val) => setState(() { _selectedQaSpv = val; _applyFilters(); }),
              ),
              CustomDropdown<String>(
                labelText: 'Season', value: _selectedSeason, hintText: 'Semua Season',
                items: [ const DropdownMenuItem(value: null, child: Text("Semua Season")), ..._seasonOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))) ],
                onChanged: (val) => setState(() { _selectedSeason = val; _applyFilters(); }),
              ),
              _buildWeekMultiSelectDropdown(),
              TextField(
                onChanged: (value) { setState(() { _searchQuery = value; _applyFilters(); }); },
                decoration: InputDecoration(
                    labelText: 'Cari Farmer / Lahan',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(), // Menggunakan OutlineInputBorder
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)) // Warna border saat fokus
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(),
              TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, color: AppTheme.textMedium), // Menggunakan warna dari AppTheme
                  label: const Text("Reset Semua Filter", style: TextStyle(color: AppTheme.textMedium)) // Menggunakan warna dari AppTheme
              ),
            ],
          )
        ],
      ),
    );
  }
  Widget _buildWeekMultiSelectDropdown() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Weeks", style: TextStyle(fontSize: 12, color: AppTheme.textMedium)), // Menggunakan warna dari AppTheme
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
              child: DropdownButton2<int>(
                  isExpanded: true,
                  customButton: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 50,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.textLight) // Menggunakan warna dari AppTheme
                      ),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                              _selectedWeeks.isEmpty ? "Semua Minggu" : "Terpilih: ${_selectedWeeks.join(', ')}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: AppTheme.textDark) // Menggunakan warna dari AppTheme
                          )
                      )
                  ),
                  items: _weekOptions.map((week) {
                    return DropdownMenuItem<int>(
                        value: week,
                        enabled: false,
                        child: StatefulBuilder(
                            builder: (context, menuSetState) {
                              final isSelected = _selectedWeeks.contains(week);
                              return InkWell(
                                  onTap: () {
                                    isSelected ? _selectedWeeks.remove(week) : _selectedWeeks.add(week);
                                    setState(() {});
                                    menuSetState(() {});
                                  },
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Row(
                                          children: [
                                            if (isSelected) const Icon(Icons.check_box_outlined, color: AppTheme.primary) else const Icon(Icons.check_box_outline_blank, color: AppTheme.textMedium), // Menggunakan warna dari AppTheme
                                            const SizedBox(width: 16),
                                            Expanded(child: Text("Minggu ke-$week", style: const TextStyle(color: AppTheme.textDark))) // Menggunakan warna dari AppTheme
                                          ]
                                      )
                                  )
                              );
                            }
                        )
                    );
                  }).toList(),
                  value: null,
                  onChanged: (value) {},
                  onMenuStateChange: (isOpen) { if (!isOpen) _applyFilters(); },
                  dropdownStyleData: DropdownStyleData(maxHeight: 200, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14))),
                  menuItemStyleData: const MenuItemStyleData(height: 40, padding: EdgeInsets.zero)
              )
          )
        ]
    );
  }

  // === HELPER METHODS ===
  String _getValue(List<String> row, int index, String defaultValue) => (row.length > index && row[index].isNotEmpty) ? row[index] : defaultValue;
  int _calculateDAP(List<String> row) { try { final date = _parseDate(_getValue(row, 9, '')); return date != null ? DateTime.now().difference(date).inDays : 0; } catch (e) { return 0; } }
  DateTime? _parseDate(String dateStr) { try { final serial = double.tryParse(dateStr); if (serial != null) return DateTime(1899, 12, 30).add(Duration(days: serial.toInt())); return DateFormat('dd/MM/yyyy').parse(dateStr); } catch(e) { return null; } }
  String _formatPercentage(int part, int total) => total == 0 ? '0.0' : ((part / total) * 100).toStringAsFixed(1);
  String _getAuditStatus(List<String> row) { final auditFinding = _getValue(row, 12, "").toLowerCase(); if (auditFinding.isEmpty || auditFinding == "n/a") return "Dereng Blas"; if (auditFinding == "pass") return "Sampun"; return "Dereng Jangkep"; }
  Color _getAuditStatusColor(String status) { switch (status) { case "Sampun": return AppTheme.success; case "Dereng Jangkep": return AppTheme.warning; default: return AppTheme.error; } }
  IconData _getAuditStatusIcon(String status) { switch (status) { case "Sampun": return Icons.check_circle; case "Dereng Jangkep": return Icons.warning; default: return Icons.cancel; } }
  int _getWeekColumn() { switch(_selectedWorksheetTitle) { case 'Vegetative': return 29; case 'Generative': return 10; case 'Pre Harvest': return 10; case 'Harvest': return 10; default: return 10; } }
}

// DEFINISI CLASS AppTheme
class AppTheme {
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent = Color(0xFF1976D2);
  static const Color accentLight = Color(0xFF42A5F5);
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color background = Color(0xFFF5F5F5);

  static const TextStyle heading1 = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark);
  static const TextStyle heading2 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark);
  static const TextStyle heading3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark);
  static const TextStyle subtitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textMedium);
  static const TextStyle body = TextStyle(fontSize: 14, color: textDark);
  static const TextStyle caption = TextStyle(fontSize: 12, color: textMedium);
}