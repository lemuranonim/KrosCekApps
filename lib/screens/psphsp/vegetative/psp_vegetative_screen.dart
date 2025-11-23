// ignore_for_file: deprecated_member_use

import 'dart:async';
// Import dart:ui dihapus karena tidak digunakan

import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'psp_vegetative_detail_screen.dart';
import 'psp_vegetative_filter_options.dart';
import 'psp_vegetative_listview_builder.dart';
import 'psp_vegetative_map_view.dart';
import 'psp_vegetative_activity_analysis_screen.dart';
import 'package:intl/intl.dart';

class PspVegetativeScreen extends StatefulWidget {
  final String spreadsheetId;
  final String? selectedDistrict;
  final String? selectedQA;
  final String? selectedSeason;
  final String? region;
  final List<String> seasonList;

  const PspVegetativeScreen({
    super.key,
    required this.spreadsheetId,
    this.selectedDistrict,
    this.selectedQA,
    this.selectedSeason,
    this.region,
    required this.seasonList,
  });

  @override
  PspVegetativeScreenState createState() => PspVegetativeScreenState();
}

class PspVegetativeScreenState extends State<PspVegetativeScreen> {
  late final GoogleSheetsApi _googleSheetsApi;
  late String region;
  final _worksheetTitle = 'Vegetative';
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
  List<String> _weekOfPspVegetativeList = [];
  List<String> _faNames = [];
  List<String> _selectedFA = [];
  List<String> _fiNames = [];
  List<String> _selectedFIs = [];
  double _totalEffectiveArea = 0.0;

  final List<String> _selectedStatuses = [];
  final Map<String, int> _activityCounts = {};
  final Map<String, List<DateTime>> _activityTimestamps = {};
  bool _showMapView = false;

  // --- Theme Colors ---
  final Color _primaryPurple = Colors.purple.shade800;
  final Color _secondaryPurple = Colors.purple.shade600;
  final Color _darkPurple = Colors.purple.shade900;
  final Color _accentCyan = const Color(0xFF00E5FF);

  String getPspVegetativeStatus(
      String cekResult, String cekProses, String cekCF, String cekCH) {
    int auditedCount = 0;
    if (cekResult.toLowerCase() == "audited") auditedCount++;
    if (cekProses.toLowerCase() == "audited") auditedCount++;
    if (cekCF.toLowerCase() == "audited") auditedCount++;
    if (cekCH.toLowerCase() == "audited") auditedCount++;

    if (auditedCount == 4) {
      return "Sampun";
    } else if (auditedCount > 0) {
      return "Dereng Jangkep";
    } else {
      return "Dereng Blas";
    }
  }

  @override
  void initState() {
    super.initState();
    final spreadsheetId =
        ConfigManager.getSpreadsheetId(widget.region ?? "Default Region") ?? '';
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
      _activityCounts.clear();
      _activityTimestamps.clear();

      for (var row in activityData) {
        if (row.length > 7) {
          final sheetName = row.length > 5 ? row[5] : '';
          if (sheetName.toLowerCase().contains('generative')) {
            final fieldNumber = row[6];
            if (fieldNumber.isNotEmpty) {
              _activityCounts[fieldNumber] = (_activityCounts[fieldNumber] ?? 0) + 1;
              final timestampStr = row[7];
              DateTime? timestamp;
              if (timestampStr.isNotEmpty) {
                try {
                  final excelDateValue = double.tryParse(timestampStr);
                  if (excelDateValue != null) {
                    final baseDate = DateTime(1899, 12, 30);
                    final days = excelDateValue.floor();
                    final millisInDay = (excelDateValue - days) * 24 * 60 * 60 * 1000;
                    timestamp = baseDate.add(Duration(days: days, milliseconds: millisInDay.round()));
                  } else {
                    // Nested try-catch blocks for fallback parsing
                    try {
                      timestamp = DateFormat("dd/MM/yyyy HH:mm:ss").parse(timestampStr);
                    } catch (_) {
                      try {
                        timestamp = DateTime.parse(timestampStr);
                      } catch (_) {
                        try {
                          final parts = timestampStr.split(' ')[0].split('/');
                          if (parts.length == 3) {
                            final month = int.tryParse(parts[0]) ?? 1;
                            final day = int.tryParse(parts[1]) ?? 1;
                            final year = int.tryParse(parts[2]) ?? DateTime.now().year;
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
                        } catch (_) {
                          // Format tidak dikenali, abaikan
                        }
                      }
                    }
                  }
                } catch (_) {
                  // Gagal parsing total, abaikan
                }
              }
              if (timestamp != null) {
                _activityTimestamps[fieldNumber] ??= [];
                _activityTimestamps[fieldNumber]!.add(timestamp);
              }
            }
          }
        }
      }
      for (var fieldNumber in _activityTimestamps.keys) {
        _activityTimestamps[fieldNumber]!.sort((a, b) => b.compareTo(a));
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading activity data: $e");
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

      await _loadActivityData();

      setState(() {
        _sheetData.addAll(data);
        _filteredData = List.from(_sheetData);
        _isLoading = false;
        _extractUniqueFA();
        _extractUniqueFIs();
        _extractUniqueSeasons();
        _extractUniqueWeeks();
        _filterData();
        _currentPage++;
        _progress = (_sheetData.length / totalDataCount).clamp(0.0, 1.0);

        _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
          final effectiveAreaStr = getValue(row, 9, '0').replaceAll(',', '.');
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
    _filterData();
  }

  void _extractUniqueFA() {
    final faSet = <String>{};
    for (var row in _sheetData) {
      final fa = getValue(row, 19, '').toLowerCase();
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
    final fiSet = <String>{};
    for (var row in _sheetData) {
      final fi = getValue(row, 26, '').toLowerCase();
      if (fi.isNotEmpty) {
        fiSet.add(fi);
      }
    }
    setState(() {
      _fiNames = fiSet.map((fi) => toTitleCase(fi)).toList();
      _fiNames.sort();
    });
  }

  void _extractUniqueSeasons() {
    final seasonsSet = <String>{};
    for (var row in _sheetData) {
      final season = getValue(row, 1, '');
      if (season.isNotEmpty) {
        seasonsSet.add(season);
      }
    }
    setState(() {
      _seasonsList = seasonsSet.toList()..sort();
    });
  }

  void _extractUniqueWeeks() {
    final weeksSet = <String>{};
    for (var row in _sheetData) {
      final week = getValue(row, 31, '');
      if (week.isNotEmpty) {
        weeksSet.add(week);
      }
    }
    setState(() {
      _weekOfPspVegetativeList = weeksSet.toList()..sort();
    });
  }

  void _filterData() {
    setState(() {
      _filteredData = _sheetData.where((row) {
        final qaSpv = getValue(row, 25, '');
        final district = getValue(row, 16, '').toLowerCase();
        final season = getValue(row, 1, '');
        final weekOfPspVegetative = getValue(row, 31, '');

        bool matchesSeasonFilter =
        (_selectedSeason == null || season == _selectedSeason);
        bool matchesQAFilter = (_selectedQA == null || qaSpv == _selectedQA);
        bool matchesDistrictFilter = widget.selectedDistrict == null ||
            district == widget.selectedDistrict!.toLowerCase();
        bool matchesWeekFilter = _selectedWeeks.isEmpty ||
            _selectedWeeks.contains(weekOfPspVegetative);

        final fa = getValue(row, 19, '').toLowerCase();
        final fi = getValue(row, 26, '').toLowerCase();

        bool matchesFAFilter =
            _selectedFA.isEmpty || _selectedFA.contains(toTitleCase(fa));

        bool matchesFIFilter =
            _selectedFIs.isEmpty || _selectedFIs.contains(toTitleCase(fi));

        final fieldNumber = getValue(row, 2, '').toLowerCase();
        final farmerName = getValue(row, 4, '').toLowerCase();
        final grower = getValue(row, 5, '').toLowerCase();
        final psCode = getValue(row, 6, '').toLowerCase();
        final desa = getValue(row, 14, '').toLowerCase();
        final kecamatan = getValue(row, 15, '').toLowerCase();
        final fieldSpv = getValue(row, 18, '').toLowerCase();

        bool matchesSearchQuery = fieldNumber.contains(_searchQuery) ||
            farmerName.contains(_searchQuery) ||
            grower.contains(_searchQuery) ||
            psCode.contains(_searchQuery) ||
            desa.contains(_searchQuery) ||
            kecamatan.contains(_searchQuery) ||
            district.contains(_searchQuery) ||
            fa.contains(_searchQuery) ||
            fi.contains(_searchQuery) ||
            fieldSpv.contains(_searchQuery) ||
            getPspVegetativeStatus(
                getValue(row, 83, ""),
                getValue(row, 85, ""),
                getValue(row, 87, ""),
                getValue(row, 89, "")
            )
                .toLowerCase()
                .contains(_searchQuery);

        bool matchesStatusFilter = _selectedStatuses.isEmpty ||
            _selectedStatuses.contains(getPspVegetativeStatus(
                getValue(row, 83, ""),
                getValue(row, 85, ""),
                getValue(row, 87, ""),
                getValue(row, 89, "")
            ));

        return matchesQAFilter &&
            matchesDistrictFilter &&
            matchesFAFilter &&
            matchesFIFilter &&
            matchesSeasonFilter &&
            matchesWeekFilter &&
            matchesSearchQuery &&
            matchesStatusFilter;
      }).toList();

      _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
        final effectiveAreaStr = getValue(row, 9, '0').replaceAll(',', '.');
        final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
        return sum + effectiveArea;
      });
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return PspVegetativeFilterOptions(
              selectedSeason: _selectedSeason,
              seasonsList: _seasonsList,
              onSeasonChanged: (value) {
                _selectedSeason = value;
              },
              selectedWeekOfPspVegetative: _selectedWeeks,
              weekOfPspVegetativeList: _weekOfPspVegetativeList,
              onWeekOfPspVegetativeChanged: (selectedWeeks) {
                _selectedWeeks = selectedWeeks;
              },
              selectedFA: _selectedFA,
              faNames: _faNames,
              onFAChanged: (selected) {
                _selectedFA = selected;
              },
              selectedFI: _selectedFIs,
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
    return false;
  }

  void _navigateBackToHome() {
    final currentContext = context;
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // ignore: duplicate_ignore
        // ignore: deprecated_member_use
        return WillPopScope(
          onWillPop: () async => false,
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

    Timer(const Duration(milliseconds: 600), () {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: duplicate_ignore
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 8,
          shadowColor: Colors.purple.withOpacity(0.3),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: _navigateBackToHome,
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_darkPurple, _secondaryPurple, _primaryPurple],
              ),
            ),
          ),
          title: !_isSearching
              ? Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vegetative',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      selectedRegion ?? 'Unknown Region',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
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
            cursorColor: _accentCyan,
            decoration: InputDecoration(
              hintText: 'Search field, farmer...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          actions: [
            !_isSearching
                ? IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white),
              tooltip: 'Search',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            )
                : IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
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
              icon: Stack(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white),
                  if (_selectedSeason != null ||
                      _selectedWeeks.isNotEmpty ||
                      _selectedFA.isNotEmpty ||
                      _selectedFIs.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.cyanAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filter Options',
              onPressed: _showFilterOptions,
            ),

            IconButton(
              icon: Icon(
                _showMapView ? Icons.view_list_rounded : Icons.map_rounded,
                color: Colors.white,
              ),
              tooltip: _showMapView ? 'Show List View' : 'Show Map View',
              onPressed: _toggleViewMode,
            ),

            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'refresh') {
                  _loadSheetData(refresh: true);
                } else if (value == 'analysis') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PspVegetativeActivityAnalysisScreen(
                        activityCounts: _activityCounts,
                        activityTimestamps: _activityTimestamps,
                        pspVegetativeData: _filteredData,
                        selectedRegion: selectedRegion,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: _primaryPurple),
                      const SizedBox(width: 12),
                      const Text('Refresh Data'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'analysis',
                  child: Row(
                    children: [
                      Icon(Icons.analytics_rounded, color: _primaryPurple),
                      const SizedBox(width: 12),
                      const Text('Analysis Aktivitas'),
                    ],
                  ),
                ),
              ],
            )
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80.0),
            child: Container(
              padding: const EdgeInsets.only(bottom: 12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_darkPurple, _secondaryPurple, _primaryPurple],
                ),
              ),
              child: Column(
                children: [
                  _isLoading
                      ? LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(_accentCyan),
                  )
                      : const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.data_usage_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${_filteredData.length} Rows',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.area_chart_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Σ Area: ${_totalEffectiveArea.toStringAsFixed(1)} Ha',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_primaryPurple, Colors.purple.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            _showFilterChipsContainer = !_showFilterChipsContainer;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _showFilterChipsContainer
                                    ? 'Hide Audit Filters'
                                    : 'Show Audit Filters',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _showFilterChipsContainer
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.9),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_showFilterChipsContainer) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusChip(
                            label: 'Completed',
                            icon: Icons.check_circle_rounded,
                            color: Colors.green,
                            isSelected: _selectedStatuses.contains("Sampun"),
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
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatusChip(
                            label: 'Incomplete',
                            icon: Icons.timelapse_rounded,
                            color: Colors.orange,
                            isSelected: _selectedStatuses.contains("Dereng Jangkep"),
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
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatusChip(
                            label: 'Empty',
                            icon: Icons.cancel_rounded,
                            color: Colors.red,
                            isSelected: _selectedStatuses.contains("Dereng Blas"),
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
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: _showMapView
                  ? PspVegetativeMapView(
                filteredData: _filteredData,
                selectedRegion: selectedRegion,
                activityCounts: _activityCounts,
              )
                  : LiquidPullToRefresh(
                  onRefresh: () async {
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
                  color: _primaryPurple,
                  backgroundColor: Colors.white,
                  height: 120,
                  showChildOpacityTransition: false,
                  animSpeedFactor: 2.0,
                  child: _isLoading
                      ? Center(child: Lottie.asset('assets/loading.json', width: 200))
                      : _errorMessage != null
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style:
                          TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _loadSheetData(refresh: true);
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.filter_alt_off_rounded, size: 48, color: Colors.purple.shade300),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No data found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search query',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
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
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white),
                          label: const Text('Reset Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryPurple,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: _primaryPurple.withOpacity(0.4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : PspVegetativeListViewBuilder(
                    filteredData: _filteredData,
                    selectedRegion: selectedRegion,
                    onItemTap: (fieldNumber) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              PspVegetativeDetailScreen(
                                fieldNumber: fieldNumber,
                                region: selectedRegion ??
                                    'Unknown Region',
                              ),
                        ),
                      );
                    },
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isSelected
                  ? LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isSelected ? null : Colors.white.withOpacity(0.15),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}