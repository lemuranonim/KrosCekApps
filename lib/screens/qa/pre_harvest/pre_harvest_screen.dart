import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'pre_harvest_filter_options.dart';
import 'pre_harvest_sliver_list_builder.dart';
import 'pre_harvest_detail_screen.dart';
import 'pre_harvest_map_view.dart';
import 'pre_harvest_activity_analysis_screen.dart';

class PreHarvestScreen extends StatefulWidget {
  final String spreadsheetId;
  final String? selectedDistrict;
  final String? selectedQA;
  final String? selectedSeason;
  final String? region;
  final List<String> seasonList;

  const PreHarvestScreen({
    super.key,
    required this.spreadsheetId,
    this.selectedDistrict,
    this.selectedQA,
    this.selectedSeason,
    this.region,
    required this.seasonList,
  });

  @override
  PreHarvestScreenState createState() => PreHarvestScreenState();
}

class PreHarvestScreenState extends State<PreHarvestScreen> {
  // Core API and Configuration
  late final GoogleSheetsApi _googleSheetsApi;
  late String region;
  final _worksheetTitle = 'Pre Harvest';

  // Data Management
  final List<List<String>> _sheetData = [];
  List<List<String>> _filteredData = [];

  // Loading and Error States
  bool _isLoading = true;
  String? _errorMessage;
  double _progress = 0.0;

  // Pagination
  int _currentPage = 1;
  final int _rowsPerPage = 100;

  // Search and Filter
  String _searchQuery = '';
  bool _isSearching = false;
  Timer? _debounce;

  // Filter States
  String? _selectedSeason;
  List<String> _seasonsList = [];
  String? _selectedQA;
  List<String> _selectedWeeks = [];
  List<String> _weekOfPreHarvestList = [];
  List<String> _faNames = [];
  List<String> _selectedFA = [];
  List<String> _fiNames = [];
  List<String> _selectedFIs = [];

  // Audit Filters
  bool _showAuditedOnly = false;
  bool _showNotAuditedOnly = false;
  bool _showDiscardedFaseItems = false;
  bool _showFilterChipsContainer = false;

  // Activity Tracking
  final Map<String, int> _activityCounts = {};
  final Map<String, List<DateTime>> _activityTimestamps = {};

  // View States
  String? selectedRegion;
  bool _showMapView = false;
  double _totalEffectiveArea = 0.0;

  @override
  void initState() {
    super.initState();

    final spreadsheetId = widget.spreadsheetId.isNotEmpty
        ? widget.spreadsheetId
        : ConfigManager.getSpreadsheetId(widget.region ?? "Default Region") ?? '';

    if (spreadsheetId.isEmpty) {
      setState(() {
        _errorMessage = "Spreadsheet ID tidak ditemukan untuk region ${widget.region}";
        _isLoading = false;
      });
      return;
    }

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

  // ==================== DATA LOADING ====================

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
      if (!_googleSheetsApi.isInitialized) {
        final initSuccess = await _googleSheetsApi.init();
        if (!initSuccess) {
          throw Exception('Gagal menginisialisasi koneksi ke Google Sheets');
        }
        debugPrint("✅ Inisialisasi berhasil!");
      } else {
        debugPrint("✅ GoogleSheetsApi sudah diinisialisasi sebelumnya");
      }

      debugPrint("\n🔥 Mengambil data dari Google Sheets...");
      debugPrint("   Start row: ${(_currentPage - 1) * _rowsPerPage + 1}");
      debugPrint("   Rows per page: $_rowsPerPage");

      final totalDataCount = 12000;
      final data = await _googleSheetsApi.getSpreadsheetDataWithPagination(
          _worksheetTitle,
          (_currentPage - 1) * _rowsPerPage + 1,
          _rowsPerPage
      );

      debugPrint("✅ Data berhasil diambil: ${data.length} baris");

      debugPrint("\n📊 Memuat data aktivitas...");
      await _loadActivityData();
      debugPrint("✅ Data aktivitas berhasil dimuat");

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
          final effectiveAreaStr = getValue(row, 8, '0').replaceAll(',', '.');
          final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
          return sum + effectiveArea;
        });
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading data: $e";
      });
    }
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

          if (sheetName.toLowerCase() == 'pre harvest') {
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
                    try {
                      timestamp = DateFormat("dd/MM/yyyy HH:mm:ss").parse(timestampStr);
                    } catch (e) {
                      try {
                        timestamp = DateTime.parse(timestampStr);
                      } catch (e) {
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
                        } catch (e) {
                          // Ignore parsing error
                        }
                      }
                    }
                  }
                } catch (e) {
                  // Ignore parsing error
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

      setState(() {});
    } catch (e) {
      debugPrint("Error loading activity data: $e");
    }
  }

  Future<void> _loadFilterPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedQA = prefs.getString('selectedQA');
    });
    _filterData();
  }

  // ==================== DATA EXTRACTION ====================

  void _extractUniqueFA() {
    final faSet = <String>{};
    for (var row in _sheetData) {
      final fa = getValue(row, 14, '').toLowerCase();
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
      final fi = getValue(row, 29, '').toLowerCase(); // Column AF for Pre Harvest
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
      final week = getValue(row, 27, ''); // Column AB for Pre Harvest
      if (week.isNotEmpty) {
        weeksSet.add(week);
      }
    }
    setState(() {
      _weekOfPreHarvestList = weeksSet.toList()..sort();
    });
  }

  // ==================== FILTERING ====================

  void _filterData() {
    setState(() {
      _filteredData = _sheetData.where((row) {
        final season = getValue(row, 1, '');
        final fieldNumber = getValue(row, 2, '').toLowerCase();
        final farmerName = getValue(row, 3, '').toLowerCase();
        final grower = getValue(row, 4, '').toLowerCase();
        final hybrid = getValue(row, 5, '').toLowerCase();
        final desa = getValue(row, 11, '').toLowerCase();
        final kecamatan = getValue(row, 12, '').toLowerCase();
        final district = getValue(row, 13, '').toLowerCase();
        final fa = getValue(row, 14, '').toLowerCase();
        final fieldSpv = getValue(row, 15, '').toLowerCase();
        final fase = getValue(row, 25, '').toLowerCase(); // Column Z for Pre Harvest
        final weekOfPreHarvest = getValue(row, 27, ''); // Column AB
        final qaSpv = getValue(row, 28, ''); // Column AC
        final fi = getValue(row, 29, '').toLowerCase(); // Column AD
        final statusAudit = getValue(row, 39, "NOT Audited").toLowerCase() == "audited"; // Column AN

        bool matchesAuditFilter = true;

        // Split search query into keywords
        final searchKeywords = _searchQuery.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();

        // Each keyword must match at least one field
        final bool matchesSearchQuery = searchKeywords.isEmpty || searchKeywords.every((keyword) {
          return fieldNumber.contains(keyword) ||
              farmerName.contains(keyword) ||
              grower.contains(keyword) ||
              hybrid.contains(keyword) ||
              desa.contains(keyword) ||
              kecamatan.contains(keyword) ||
              district.contains(keyword) ||
              fa.contains(keyword) ||
              fi.contains(keyword) ||
              fieldSpv.contains(keyword);
        });

        bool matchesSeasonFilter = (_selectedSeason == null || season == _selectedSeason);
        bool matchesQAFilter = (_selectedQA == null || qaSpv == _selectedQA);
        bool matchesDistrictFilter =
            widget.selectedDistrict == null ||
                district == widget.selectedDistrict!.toLowerCase();
        bool matchesWeekFilter =
            _selectedWeeks.isEmpty || _selectedWeeks.contains(weekOfPreHarvest);

        bool matchesFaseFilter = true;
        if (!_showDiscardedFaseItems) {
          matchesFaseFilter = fase != 'discard';
        }

        if (_showAuditedOnly && !statusAudit) {
          matchesAuditFilter = false;
        }
        if (_showNotAuditedOnly && statusAudit) {
          matchesAuditFilter = false;
        }

        bool matchesFAFilter =
            _selectedFA.isEmpty ||
                _selectedFA.contains(toTitleCase(fa));

        bool matchesFIFilter =
            _selectedFIs.isEmpty ||
                _selectedFIs.contains(toTitleCase(fi));

        return matchesQAFilter &&
            matchesDistrictFilter &&
            matchesFAFilter &&
            matchesFIFilter &&
            matchesSeasonFilter &&
            matchesWeekFilter &&
            matchesSearchQuery &&
            matchesAuditFilter &&
            matchesFaseFilter;
      }).toList();

      // Update unique values for dropdowns based on filtered data
      _seasonsList = _filteredData
          .map((row) => getValue(row, 1, ''))
          .toSet()
          .toList()
        ..sort();

      _weekOfPreHarvestList = _filteredData
          .map((row) => getValue(row, 27, ''))
          .toSet()
          .toList()
        ..sort();

      _faNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 14, '').toLowerCase()))
          .toSet()
          .toList()
        ..sort();

      _fiNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 29, '').toLowerCase()))
          .toSet()
          .toList()
        ..sort();

      // Calculate total effective area
      _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
        final effectiveAreaStr = getValue(row, 8, '0').replaceAll(',', '.');
        final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
        return sum + effectiveArea;
      });
    });
  }

  // ==================== HELPER METHODS ====================

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

  void _toggleViewMode() {
    setState(() {
      _showMapView = !_showMapView;
    });
  }

  // ==================== UI ACTIONS ====================

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return PreHarvestFilterOptions(
              selectedSeason: _selectedSeason,
              seasonsList: _seasonsList,
              onSeasonChanged: (value) {
                _selectedSeason = value;
              },

              selectedWeekOfPreHarvest: _selectedWeeks,
              weekOfPreHarvestList: _weekOfPreHarvestList,
              onWeekOfPreHarvestChanged: (value) {
                _selectedWeeks = value;
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

              initialShowDiscardedFase: _showDiscardedFaseItems,
              onShowDiscardedFaseChanged: (newValue) {
                _showDiscardedFaseItems = newValue;
              },

              onResetAll: () {
                setState(() {
                  _selectedSeason = null;
                  _selectedWeeks.clear();
                  _selectedFA.clear();
                  _selectedFIs.clear();
                  _showDiscardedFaseItems = false;
                });
                Navigator.pop(context);
                _filterData();
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

    Timer(const Duration(milliseconds: 600), () {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      }
    });
  }

  // ==================== BUILD METHOD ====================

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: LiquidPullToRefresh(
          onRefresh: () async {
            setState(() {
              _selectedSeason = null;
              _selectedWeeks = [];
              _selectedFA.clear();
              _selectedFIs.clear();
              _searchQuery = '';
              _showAuditedOnly = false;
              _showNotAuditedOnly = false;
              _filterData();
            });
            await _loadSheetData(refresh: true);
          },
          color: Colors.green.shade700,
          backgroundColor: Colors.white,
          height: 150,
          showChildOpacityTransition: false,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              _buildFilterHeader(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      expandedHeight: 220,
      backgroundColor: Colors.green.shade800,

      // Leading
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _navigateBackToHome,
          padding: EdgeInsets.zero,
        ),
      ),

      // Title or Search
      title: _isSearching
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: _onSearchChanged,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Cari lahan, petani...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white70),
          ),
        ),
      )
          : Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pre Harvest',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),

      // Actions
      actions: [
        _buildSearchButton(),
        if (!_isSearching) _buildFilterButton(),
        if (!_isSearching) _buildMapToggleButton(),
        if (!_isSearching) _buildMoreMenu(),
      ],

      // Progress Indicator
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4.0),
        child: _isLoading
            ? LinearProgressIndicator(
          value: _progress > 0 ? _progress : null,
          backgroundColor: Colors.white.withAlpha(51),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        )
            : const SizedBox.shrink(),
      ),

      // Flexible Space
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade800,
                Colors.green.shade900,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 60),
                _buildRegionBadge(),
                const SizedBox(height: 16),
                _buildSummaryCards(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          _isSearching ? Icons.close_rounded : Icons.search_rounded,
          color: Colors.white,
        ),
        onPressed: () => setState(() {
          if (_isSearching) _searchQuery = '';
          _isSearching = !_isSearching;
          _filterData();
        }),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: _showFilterOptions,
          ),
          if (_selectedSeason != null ||
              _selectedWeeks.isNotEmpty ||
              _selectedFA.isNotEmpty ||
              _showDiscardedFaseItems ||
              _selectedFIs.isNotEmpty)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapToggleButton() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(
          _showMapView ? Icons.view_list_rounded : Icons.map_rounded,
          color: Colors.white,
        ),
        onPressed: _toggleViewMode,
      ),
    );
  }

  Widget _buildMoreMenu() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onSelected: (value) {
          if (value == 'refresh') {
            _loadSheetData(refresh: true);
          } else if (value == 'analysis') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PreHarvestActivityAnalysisScreen(
                  activityCounts: _activityCounts,
                  activityTimestamps: _activityTimestamps,
                  preHarvestData: _filteredData,
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
                Icon(Icons.refresh_rounded, color: Colors.green),
                SizedBox(width: 12),
                Text('Refresh Data'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'analysis',
            child: Row(
              children: [
                Icon(Icons.analytics_rounded, color: Colors.green),
                SizedBox(width: 12),
                Text('Analysis Aktivitas'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionBadge() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(38),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withAlpha(76),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Colors.white.withAlpha(229),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  selectedRegion ?? 'Unknown Region',
                  style: TextStyle(
                    color: Colors.white.withAlpha(229),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildEnhancedSummaryCard(
              icon: Icons.grid_view_rounded,
              label: 'Total Lahan',
              value: '${_filteredData.length}',
              gradient: [Colors.blue.shade400, Colors.blue.shade600],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildEnhancedSummaryCard(
              icon: Icons.landscape_rounded,
              label: 'Total Area',
              value: '${_totalEffectiveArea.toStringAsFixed(1)} Ha',
              gradient: [Colors.orange.shade400, Colors.orange.shade600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withAlpha(229),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterHeaderDelegate(
        child: Container(
          color: Colors.green.shade800,
          child: _buildEnhancedFilterChipsContainer(),
        ),
        height: _showFilterChipsContainer ? 125.0 : 75.0,
      ),
    );
  }

  Widget _buildEnhancedFilterChipsContainer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toggle Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(51),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showFilterChipsContainer = !_showFilterChipsContainer;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white.withAlpha(229),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _showFilterChipsContainer
                              ? 'Sembunyikan Status Audit'
                              : 'Tampilkan Status Audit',
                          style: TextStyle(
                            color: Colors.white.withAlpha(229),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _showFilterChipsContainer
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withAlpha(229),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Filter Chips
          if (_showFilterChipsContainer) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedFilterChip(isAudited: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnhancedFilterChip(isAudited: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterChip({required bool isAudited}) {
    final bool isActive = isAudited ? _showAuditedOnly : _showNotAuditedOnly;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isAudited) {
            _showAuditedOnly = !_showAuditedOnly;
            if (_showAuditedOnly) _showNotAuditedOnly = false;
          } else {
            _showNotAuditedOnly = !_showNotAuditedOnly;
            if (_showNotAuditedOnly) _showAuditedOnly = false;
          }
          _filterData();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
            colors: isAudited
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.red.shade400, Colors.red.shade600],
          )
              : null,
          color: isActive ? null : Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withAlpha(76),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: (isAudited ? Colors.green : Colors.red).withAlpha(76),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAudited ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isActive ? Colors.white : Colors.white.withAlpha(229),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isAudited ? 'Sampun' : 'Dereng',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withAlpha(229),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_showMapView) {
      return SliverFillRemaining(
        child: PreHarvestMapView(
          filteredData: _filteredData,
          selectedRegion: selectedRegion,
          activityCounts: _activityCounts,
        ),
      );
    } else if (_isLoading) {
      return _buildSliverCenteredContent(
        child: Lottie.asset('assets/loading.json'),
      );
    } else if (_errorMessage != null) {
      return _buildSliverCenteredContent(
        child: _buildErrorState(),
      );
    } else if (_filteredData.isEmpty) {
      return _buildSliverCenteredContent(
        child: _buildEmpty(),
      );
    } else {
      return PreHarvestSliverListBuilder(
        filteredData: _filteredData,
        selectedRegion: selectedRegion,
        activityCounts: _activityCounts,
        onItemTap: (fieldNumber) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreHarvestDetailScreen(
                fieldNumber: fieldNumber,
                region: selectedRegion ?? 'Unknown Region',
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildSliverCenteredContent({required Widget child}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: child,
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset('assets/empty.json', height: 180),
        const SizedBox(height: 16),
        const Text(
          'Data tidak ditemukan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Coba ubah filter atau kata kunci pencarian.',
          style: TextStyle(color: Colors.grey),
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
              _showAuditedOnly = false;
              _showNotAuditedOnly = false;
              _filterData();
            });
          },
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Reset Filters'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
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
          onPressed: () => _loadSheetData(refresh: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ==================== FILTER HEADER DELEGATE ====================

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _FilterHeaderDelegate({required this.child, this.height = 80.0});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}