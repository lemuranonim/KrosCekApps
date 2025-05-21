import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'generative_detail_screen.dart';
import 'generative_filter_options.dart';
import 'generative_listview_builder.dart';
import 'generative_map_view.dart';
import 'generative_activity_analysis_screen.dart';

class GenerativeScreen extends StatefulWidget {
  final String spreadsheetId;
  final String? selectedDistrict;
  final String? selectedQA;
  final String? selectedSeason;
  final String? region;
  final List<String> seasonList;

  const GenerativeScreen({
    super.key,
    required this.spreadsheetId,
    this.selectedDistrict,
    this.selectedQA,
    this.selectedSeason,
    this.region,
    required this.seasonList,
  });

  @override
  GenerativeScreenState createState() => GenerativeScreenState();
}

class GenerativeScreenState extends State<GenerativeScreen> {
  late final GoogleSheetsApi _googleSheetsApi;
  late String region;
  final _worksheetTitle = 'Generative';
  String? _selectedSeason;
  List<String> _seasonsList = [];
  final List<List<String>> _sheetData = [];
  List<List<String>> _filteredData = [];
  bool _isLoading = true;
  String? selectedRegion;
  String? _errorMessage;
  String? _selectedQA;
  String _searchQuery = '';
  bool _isSearching = false;
  int _currentPage = 1;
  final int _rowsPerPage = 100;
  Timer? _debounce;
  double _progress = 0.0;
  bool _showFilterChipsContainer = false;

  List<String> _selectedWeeks = [];
  List<String> _weekOfGenerativeList = [];

  List<String> _faNames = [];
  List<String> _selectedFA = [];

  List<String> _fiNames = [];
  List<String> _selectedFIs = [];

  double _totalEffectiveArea = 0.0;

  final Map<String, int> _activityCounts = {};
  final Map<String, List<DateTime>> _activityTimestamps = {};
  bool _showMapView = false;

  final List<String> _selectedStatuses = [];

  String getGenerativeStatus(String cekResult, String cekProses) {
    if (cekResult.toLowerCase() == "audited" && cekProses.toLowerCase() == "audited") {
      return "Sampun";
    } else if ((cekResult.toLowerCase() == "audited" && cekProses.toLowerCase() == "not audited") ||
        (cekResult.toLowerCase() == "not audited" && cekProses.toLowerCase() == "audited")) {
      return "Dereng Jangkep";
    } else if (cekResult.toLowerCase() == "not audited" && cekProses.toLowerCase() == "not audited") {
      return "Dereng Blas";
    }
    return "Unknown";
  }

  @override
  void initState() {
    super.initState();
    final spreadsheetId = ConfigManager.getSpreadsheetId(widget.region ?? "Default Region") ?? '';
    selectedRegion = widget.region ?? "Unknown Region";
    _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
    _loadSheetData();
    _loadFilterPreferences();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadActivityData() async {
    try {
      await _googleSheetsApi.init();
      final activityData = await _googleSheetsApi.getSpreadsheetData('Aktivitas');

      // Clear existing counts and timestamps
      _activityCounts.clear();
      _activityTimestamps.clear();

      // Count activities for each field number, but only for Generative sheet
      for (var row in activityData) {
        if (row.length > 7) { // Ensure we have enough columns
          final sheetName = row.length > 5 ? row[5] : ''; // Sheet name is in column F (index 5)

          // Only process rows related to the Generative sheet
          if (sheetName.toLowerCase().contains('generative')) {
            final fieldNumber = row[6]; // Field Number is in column G (index 6)
            if (fieldNumber.isNotEmpty) {
              // Update activity count
              _activityCounts[fieldNumber] = (_activityCounts[fieldNumber] ?? 0) + 1;

              // Extract timestamp from column H (index 7)
              final timestampStr = row[7];
              DateTime? timestamp;

              if (timestampStr.isNotEmpty) {
                // Try to parse the timestamp
                try {
                  // First try to parse as Excel numeric date
                  final excelDateValue = double.tryParse(timestampStr);
                  if (excelDateValue != null) {
                    // Convert Excel date to DateTime
                    final baseDate = DateTime(1899, 12, 30);
                    final days = excelDateValue.floor();
                    final millisInDay = (excelDateValue - days) * 24 * 60 * 60 * 1000;
                    timestamp = baseDate.add(Duration(days: days, milliseconds: millisInDay.round()));
                  } else {
                    // Try standard date formats
                    try {
                      // Try dd/MM/yyyy HH:mm:ss format
                      timestamp = DateFormat("dd/MM/yyyy HH:mm:ss").parse(timestampStr);
                    } catch (e) {
                      // Try standard DateTime.parse
                      try {
                        timestamp = DateTime.parse(timestampStr);
                      } catch (e) {
                        // Try dd/MM/yyyy format
                        try {
                          final parts = timestampStr.split(' ')[0].split('/');
                          if (parts.length == 3) {
                            final month = int.tryParse(parts[0]) ?? 1;
                            final day = int.tryParse(parts[1]) ?? 1;
                            final year = int.tryParse(parts[2]) ?? DateTime.now().year;

                            // Try to parse time if available
                            int hour = 0, minute = 0, second = 0;
                            if (timestampStr.contains(' ') && timestampStr.split(' ').length > 1) {
                              final timeParts = timestampStr.split(' ')[1].split(':');
                              if (timeParts.length >= 2) {
                                hour = int.tryParse(timeParts[0]) ?? 0;
                                minute = int.tryParse(timeParts[1]) ?? 0;
                                if (timeParts.length > 2) {
                                  second = int.tryParse(timeParts[2]) ?? 0;
                                }
                              }
                            }

                            timestamp = DateTime(year, month, day, hour, minute, second);
                          }
                        } catch (e) {
                          // Try MM/dd/yyyy format
                        }
                      }
                    }
                  }
                } catch (e) {
                  // Handle parsing error
                }
              }

              // If we successfully parsed a timestamp, add it to the map
              if (timestamp != null) {
                _activityTimestamps[fieldNumber] ??= [];
                _activityTimestamps[fieldNumber]!.add(timestamp);
              }
            } else {
              // Handle empty field number
            }
          }
        }
      }

      // Sort timestamps for each field (newest first)
      for (var fieldNumber in _activityTimestamps.keys) {
        _activityTimestamps[fieldNumber]!.sort((a, b) => b.compareTo(a));
      }
      setState(() {
        // Update state to trigger rebuild with new activity data
      });
    } catch (e) {
      // Error handling
    }
  }

  void _toggleViewMode() {
    setState(() {
      _showMapView = !_showMapView;
    });
  }

  Future<void> _loadSheetData({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _sheetData.clear();
      _totalEffectiveArea = 0.0;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      await _googleSheetsApi.init();
      final totalDataCount = 12000;
      final data = await _googleSheetsApi.getSpreadsheetDataWithPagination(
          _worksheetTitle, (_currentPage - 1) * _rowsPerPage + 1, _rowsPerPage);

      // Load activity data
      await _loadActivityData();

      setState(() {
        _sheetData.addAll(data);
        _filteredData = List.from(_sheetData);
        _isLoading = false;
        _extractUniqueFA();
        _extractUniqueFIs();
        _extractUniqueSeasons(); // Ekstrak unique seasons
        _extractUniqueWeeks(); // Ekstrak unique weeks
        _filterData();
        _currentPage++;
        _progress = (_sheetData.length / totalDataCount).clamp(0.0, 1.0);

        _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
          final effectiveAreaStr = getValue(row, 8, '0').replaceAll(',', '.');
          final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
          return sum + effectiveArea;
        });
      });
      _filterData();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading data: $e";
      });
    }
  }

  Future<void> _loadFilterPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedQA = prefs.getString('selectedQA');
    });
    _filterData(); // Call filter data after preferences are loaded
  }

  void _extractUniqueFA() {
    final faSet = <String>{};
    for (var row in _sheetData) {
      final fa = getValue(row, 16, '').toLowerCase();
      if (fa.isNotEmpty && fa != 'fa') {
        faSet.add(fa);
      }
    }
    setState(() {
      _faNames = faSet.map((fa) => toTitleCase(fa)).toList();
      _faNames.sort();
    });
  }

  void _extractUniqueFIs() {
    final fiSet = <String>{}; // Using set to store unique FIs
    for (var row in _sheetData) {
      final fi = getValue(row, 31, '').toLowerCase(); // Change to column AF (index 31)
      if (fi.isNotEmpty) { // Ensure FI is not empty
        fiSet.add(fi);
      }
    }
    setState(() {
      _fiNames = fiSet.map((fi) => toTitleCase(fi)).toList();
      _fiNames.sort(); // Sort A to Z
    });
  }

  void _extractUniqueSeasons() {
    final seasonsSet = <String>{};
    for (var row in _sheetData) {
      final season = getValue(row, 1, ''); // Assuming season is in column 1
      if (season.isNotEmpty) {
        seasonsSet.add(season);
      }
    }
    setState(() {
      _seasonsList = seasonsSet.toList()..sort(); // Sort the seasons
    });
  }

  void _extractUniqueWeeks() {
    final weeksSet = <String>{};
    for (var row in _sheetData) {
      final week = getValue(row, 29, ''); // Assuming week is in column 29
      if (week.isNotEmpty) {
        weeksSet.add(week);
      }
    }
    setState(() {
      _weekOfGenerativeList = weeksSet.toList()..sort(); // Sort the weeks
    });
  }

  void _filterData() {
    setState(() {
      _filteredData = _sheetData.where((row) {
        final qaSpv = getValue(row, 30, '');
        final district = getValue(row, 13, '').toLowerCase();
        final season = getValue(row, 1, '');
        final weekOfGenerative = getValue(row, 28, '');

        bool matchesSeasonFilter = (_selectedSeason == null || season == _selectedSeason);
        bool matchesQAFilter = (_selectedQA == null || qaSpv == _selectedQA);
        bool matchesDistrictFilter =
            widget.selectedDistrict == null ||
                district == widget.selectedDistrict!.toLowerCase();
        bool matchesWeekFilter =
            _selectedWeeks.isEmpty || _selectedWeeks.contains(weekOfGenerative);

        final fa = getValue(row, 16, '').toLowerCase();
        final fi = getValue(row, 31, '').toLowerCase();

        bool matchesFAFilter =
            _selectedFA.isEmpty ||
                _selectedFA.contains(toTitleCase(fa));

        bool matchesFIFilter =
            _selectedFIs.isEmpty ||
                _selectedFIs.contains(toTitleCase(fi));

        final fieldNumber = getValue(row, 2, '').toLowerCase();
        final farmerName = getValue(row, 3, '').toLowerCase();
        final grower = getValue(row, 4, '').toLowerCase();
        final hybrid = getValue(row, 5, '').toLowerCase();
        final desa = getValue(row, 11, '').toLowerCase();
        final kecamatan = getValue(row, 12, '').toLowerCase();
        final fieldSpv = getValue(row, 15, '').toLowerCase();

        final status = getGenerativeStatus(
            getValue(row, 71, ""),
            getValue(row, 72, "")
        );

        bool matchesStatusFilter = _selectedStatuses.isEmpty || _selectedStatuses.contains(status);

        bool matchesSearchQuery = fieldNumber.contains(_searchQuery) ||
            farmerName.contains(_searchQuery) ||
            grower.contains(_searchQuery) ||
            hybrid.contains(_searchQuery) ||
            desa.contains(_searchQuery) ||
            kecamatan.contains(_searchQuery) ||
            district.contains(_searchQuery) ||
            fa.contains(_searchQuery) ||
            fi.contains(_searchQuery) ||
            fieldSpv.contains(_searchQuery) ||
            getGenerativeStatus(
                getValue(row, 71, ""),
                getValue(row, 72, "")
            ).toLowerCase().contains(_searchQuery);

        return matchesQAFilter &&
            matchesDistrictFilter &&
            matchesFAFilter &&
            matchesFIFilter &&
            matchesSeasonFilter &&
            matchesWeekFilter &&
            matchesSearchQuery &&
            matchesStatusFilter;
      }).toList();
      _updateUniqueValues();
    });
  }

  void _updateUniqueValues() {
    _seasonsList = _filteredData
        .map((row) => getValue(row, 1, ''))
        .toSet()
        .toList()
      ..sort();

    _weekOfGenerativeList = _filteredData
        .map((row) => getValue(row, 28, ''))
        .toSet()
        .toList()
      ..sort();

    _faNames = _filteredData
        .map((row) => toTitleCase(getValue(row, 16, '').toLowerCase()))
        .toSet()
        .toList()
      ..sort();

    _fiNames = _filteredData
        .map((row) => toTitleCase(getValue(row, 31, '').toLowerCase()))
        .toSet()
        .toList()
      ..sort();

    _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
      final effectiveAreaStr = getValue(row, 8, '0').replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
      return sum + effectiveArea;
    });
  }

  String getValue(List<String> row, int index, String defaultValue) {
    if (index < row.length) {
      return row[index];
    }
    return defaultValue;
  }

  String toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isNotEmpty) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      return word;
    }).join(' ');
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.toLowerCase();
      });
      _filterData();
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Keep transparent for rounded corners
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return GenerativeFilterOptions(
              selectedSeason: _selectedSeason,
              seasonsList: _seasonsList,
              onSeasonChanged: (value) {
                _selectedSeason = value;
              },

              selectedWeekOfGenerative: _selectedWeeks,
              weekOfGenerativeList: _weekOfGenerativeList,
              onWeekOfGenerativeChanged: (value) {
                _selectedWeeks = value;
              },

              selectedFA: _selectedFA,
              faNames: _faNames,
              onFAChanged: (selected) {
                _selectedFA = selected;
              },

              selectedFIs: _selectedFIs,
              fiNames: _fiNames,
              onFIChanged: (selected) {
                _selectedFIs = selected;
              },

              onResetAll: () {
                _selectedSeason = null;
                _selectedWeeks.clear();
                _selectedFA.clear();
                _selectedFIs.clear();
              },

              onApplyFilters: () {
                _filterData();
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _onWillPop() async {
    _navigateBackToHome();
    return false; // Return false to prevent default back button behavior
  }

  void _navigateBackToHome() {
    // Simpan context dalam variabel lokal
    final currentContext = context;

    // Tampilkan loading overlay sebelum kembali
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Lottie.asset(
                'assets/loading.json',
                width: 150,
                height: 150,
              ),
            ),
          ),
        );
      },
    );

    // Delay sebentar untuk menampilkan loading
    Timer(const Duration(milliseconds: 600), () {
      // Navigasi kembali ke HomeScreen
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Tutup dialog loading
        Navigator.of(context).pop(); // Kembali ke HomeScreen
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _navigateBackToHome,
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade800, Colors.green.shade600],
              ),
            ),
          ),
          title: !_isSearching
              ? Row(
            children: [
              const Icon(Icons.eco_rounded, size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generative',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      selectedRegion ?? 'Unknown Region',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          )
              : TextField(
            onChanged: _onSearchChanged,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: 'Search field, farmer, grower...',
              hintStyle: TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.white),
              contentPadding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          actions: [
            !_isSearching
                ? IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              tooltip: 'Search',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            )
                : IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              tooltip: 'Cancel Search',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _filterData();
                });
              },
            ),

            IconButton(
              icon: Badge(
                isLabelVisible: _selectedSeason != null ||
                    _selectedWeeks.isNotEmpty ||
                    _selectedFA.isNotEmpty ||
                    _selectedFIs.isNotEmpty,
                backgroundColor: Colors.red,
                child: const Icon(Icons.filter_list_rounded, color: Colors.white),
              ),
              tooltip: 'Filter Options',
              onPressed: _showFilterOptions,
            ),

            IconButton(
              icon: Icon(
                _showMapView ? Icons.view_list : Icons.map,
                color: Colors.white,
              ),
              tooltip: _showMapView ? 'Show List View' : 'Show Map View',
              onPressed: _toggleViewMode,
            ),

            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'refresh') {
                  _loadSheetData(refresh: true);
                } else if (value == 'help') {
                  // Show help dialog
                } else if (value == 'analysis') {
                  // Navigate to analysis screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => GenerativeActivityAnalysisScreen(
                        activityCounts: _activityCounts,
                        activityTimestamps: _activityTimestamps,
                        generativeData: _filteredData,
                        selectedRegion: selectedRegion,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Refresh Data'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'analysis',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Analysis Aktivitas'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Bantuan'),
                    ],
                  ),
                ),
              ],
            )
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80.0),
            child: Container(
              padding: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade800, Colors.green.shade600],
                ),
              ),
              child: Column(
                children: [
                  _isLoading
                      ? LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.green.shade300.withAlpha(76),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                      : const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.format_list_numbered, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${_filteredData.length} Lahan',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.crop, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Σ Area:${_totalEffectiveArea.toStringAsFixed(1)} Ha',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Filter Chips Container
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade800, Colors.green.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              width: double.infinity, // Ensure container takes full width
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity, // Make button take full width
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.green.shade700, Colors.green.shade500],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showFilterChipsContainer = !_showFilterChipsContainer;
                        });
                      },
                      icon: Icon(
                        _showFilterChipsContainer
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      label: Text(
                        _showFilterChipsContainer
                            ? 'Hide Filter Audit Status'
                            : 'Show Filter Audit Status',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (_showFilterChipsContainer) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedStatuses.contains("Sampun")
                                  ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(38),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (_selectedStatuses.contains("Sampun")) {
                                      _selectedStatuses.remove("Sampun");
                                    } else {
                                      _selectedStatuses.add("Sampun");
                                    }
                                    _filterData();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: _selectedStatuses.contains("Sampun")
                                        ? LinearGradient(
                                      colors: [Colors.green.shade400, Colors.green.shade500 ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: _selectedStatuses.contains("Sampun") ? null : Colors.white,
                                    border: Border.all(
                                      color: _selectedStatuses.contains("Sampun") ? Colors.transparent : Colors.green.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: _selectedStatuses.contains("Sampun") ? Colors.white : Colors.green.shade700,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Sampun',
                                          style: TextStyle(
                                            color: _selectedStatuses.contains("Sampun") ? Colors.white : Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedStatuses.contains("Dereng Jangkep")
                                  ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(38),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (_selectedStatuses.contains("Dereng Jangkep")) {
                                      _selectedStatuses.remove("Dereng Jangkep");
                                    } else {
                                      _selectedStatuses.add("Dereng Jangkep");
                                    }
                                    _filterData();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: _selectedStatuses.contains("Dereng Jangkep")
                                        ? LinearGradient(
                                      colors: [Colors.orange.shade400, Colors.orange.shade500],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: _selectedStatuses.contains("Dereng Jangkep") ? null : Colors.white,
                                    border: Border.all(
                                      color: _selectedStatuses.contains("Dereng Jangkep") ? Colors.transparent : Colors.orange.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.hourglass_empty,
                                        color: _selectedStatuses.contains("Dereng Jangkep") ? Colors.white : Colors.orange.shade700,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Dereng Jangkep',
                                          style: TextStyle(
                                            color: _selectedStatuses.contains("Dereng Jangkep") ? Colors.white : Colors.orange.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: _selectedStatuses.contains("Dereng Blas")
                                  ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(38),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    if (_selectedStatuses.contains("Dereng Blas")) {
                                      _selectedStatuses.remove("Dereng Blas");
                                    } else {
                                      _selectedStatuses.add("Dereng Blas");
                                    }
                                    _filterData();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: _selectedStatuses.contains("Dereng Blas")
                                        ? LinearGradient(
                                      colors: [Colors.red.shade400, Colors.red.shade500],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: _selectedStatuses.contains("Dereng Blas") ? null : Colors.white,
                                    border: Border.all(
                                      color: _selectedStatuses.contains("Dereng Blas") ? Colors.transparent : Colors.red.shade200,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        color: _selectedStatuses.contains("Dereng Blas") ? Colors.white : Colors.red.shade600,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Dereng Blas',
                                          style: TextStyle(
                                            color: _selectedStatuses.contains("Dereng Blas") ? Colors.white : Colors.red.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: _showMapView
                  ? GenerativeMapView(
                filteredData: _filteredData,
                selectedRegion: selectedRegion,
                activityCounts: _activityCounts,
              )
                  : LiquidPullToRefresh(
                  onRefresh: () async {
                    // Reset filters and load data
                    setState(() {
                      _selectedSeason = null;
                      _selectedWeeks = [];
                      _selectedFA.clear();
                      _selectedFIs.clear();
                      _searchQuery = '';
                      _selectedStatuses.clear();
                      _filterData();
                    });
                    await _loadSheetData(refresh: true);
                  },
                  color: Colors.green,
                  backgroundColor: Colors.white,
                  height: 150,
                  showChildOpacityTransition: false,
                  child: _isLoading
                      ? Center(child: Lottie.asset('assets/loading.json'))
                      : _errorMessage != null
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedSeason = null;
                              _selectedWeeks = [];
                              _selectedFA.clear();
                              _selectedFIs.clear();
                              _searchQuery = '';
                              _selectedStatuses.clear();
                              _filterData();
                              _loadSheetData(refresh: true);
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : _filteredData.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset('assets/empty.json', height: 180),
                        const SizedBox(height: 16),
                        const Text(
                          'Ora ono data sing kasedhiya',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cobo ganti saringan utowo kritéria telusuran',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedSeason = null;
                              _selectedWeeks = [];
                              _selectedFA.clear();
                              _selectedFIs.clear();
                              _searchQuery = '';
                              _selectedStatuses.clear();
                              _filterData();
                            });
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Reset Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : GenerativeListViewBuilder(
                    filteredData: _filteredData,
                    selectedRegion: selectedRegion,
                    activityCounts: _activityCounts,
                    onItemTap: (fieldNumber) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GenerativeDetailScreen(
                            fieldNumber: fieldNumber,
                            region: selectedRegion ?? 'Unknown Region',
                          ),
                        ),
                      );
                    },
                  )
              ),
            ),
          ],
        ),
      ),
    );
  }
}