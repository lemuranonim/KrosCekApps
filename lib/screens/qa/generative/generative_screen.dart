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
import 'generative_sliver_list_builder.dart';
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
  bool _showDiscardedFaseItems = false;

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
        final fase = getValue(row, 26, '').toLowerCase();
        final weekOfGenerative = getValue(row, 28, '');
        final qaSpv = getValue(row, 30, '');
        final fi = getValue(row, 31, '').toLowerCase();

        // 1. Pecah query pencarian menjadi beberapa kata kunci (keywords)
        final searchKeywords = _searchQuery.toLowerCase().split(' ').where((s) => s.isNotEmpty).toList();

        // 2. Logika pencocokan baru: setiap keyword HARUS ada di dalam baris data
        final bool matchesSearchQuery = searchKeywords.isEmpty || searchKeywords.every((keyword) {
          // Sebuah keyword dianggap cocok jika ada di SALAH SATU kolom berikut
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
            _selectedWeeks.isEmpty || _selectedWeeks.contains(weekOfGenerative);
        bool matchesFaseFilter = true; // Defaultnya true (lolos filter)
        if (!_showDiscardedFaseItems) { // Jika _showDiscardedFaseItems adalah false (default)
          matchesFaseFilter = fase != 'discard'; // Maka, hanya tampilkan yang BUKAN "discard"
        }


        bool matchesFAFilter =
            _selectedFA.isEmpty ||
                _selectedFA.contains(toTitleCase(fa));

        bool matchesFIFilter =
            _selectedFIs.isEmpty ||
                _selectedFIs.contains(toTitleCase(fi));



        final status = getGenerativeStatus(
            getValue(row, 72, ""),
            getValue(row, 73, "")
        );

        bool matchesStatusFilter = _selectedStatuses.isEmpty || _selectedStatuses.contains(status);

        return matchesQAFilter &&
            matchesDistrictFilter &&
            matchesFAFilter &&
            matchesFIFilter &&
            matchesSeasonFilter &&
            matchesWeekFilter &&
            matchesSearchQuery &&
            matchesStatusFilter &&
            matchesFaseFilter;
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
        .map((row) => toTitleCase(getValue(row, 14, '').toLowerCase()))
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

                initialShowDiscardedFase: _showDiscardedFaseItems,
                onShowDiscardedFaseChanged: (newValue) {
                  _showDiscardedFaseItems = newValue;
                },

              onResetAll: () {
                // Fungsi ini akan dipanggil ketika tombol "Reset All" di dalam modal ditekan
                setState(() { // Ini adalah setState dari GenerativeScreenState
                  _selectedSeason = null;
                  _selectedWeeks.clear();
                  _selectedFA.clear();
                  _selectedFIs.clear();
                  _showDiscardedFaseItems = false; // Reset ke default
                  _selectedStatuses.clear();
                });
                _filterData(); // Panggil filter data setelah reset
                Navigator.pop(context); // Tutup modal setelah reset
              },

                onApplyFilters: () {
                  _filterData();
                }
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

  // Helper widget untuk membuat satu chip filter
  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required MaterialColor activeColor, // <<< PERUBAIKAN DI SINI
    required List<Color> activeGradient,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Kode ini sekarang valid karena activeColor adalah MaterialColor
    final Color inactiveColor = activeColor.shade700;
    final Color inactiveBorderColor = activeColor.shade200;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: activeColor.withAlpha(50),
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
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: isSelected
                    ? LinearGradient(
                    colors: activeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                    : null,
                color: isSelected ? null : Colors.white,
                border: Border.all(
                  color: isSelected ? Colors.transparent : inactiveBorderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : inactiveColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : inactiveColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
    );
  }

  // Kontainer untuk semua chip filter status audit
  Widget _buildFilterChipsContainer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade800, Colors.green.shade600.withAlpha(204)],
        ),
      ),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tombol untuk expand/collapse
          Container(
            width: double.infinity,
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
                _showFilterChipsContainer ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
              label: Text(
                _showFilterChipsContainer ? 'Hide Filter Audit Status' : 'Show Filter Audit Status',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Baris yang berisi chip-chip filter
          if (_showFilterChipsContainer) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildFilterChip(
                  label: "Sampun",
                  icon: Icons.check_circle_outline,
                  activeColor: Colors.green,
                  activeGradient: [Colors.green.shade400, Colors.green.shade500],
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
                const SizedBox(width: 12),
                _buildFilterChip(
                  label: "Jangkep", // Disingkat agar muat
                  icon: Icons.hourglass_empty,
                  activeColor: Colors.orange,
                  activeGradient: [Colors.orange.shade400, Colors.orange.shade500],
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
                const SizedBox(width: 12),
                _buildFilterChip(
                  label: "Blas", // Disingkat agar muat
                  icon: Icons.cancel_outlined,
                  activeColor: Colors.red,
                  activeGradient: [Colors.red.shade400, Colors.red.shade500],
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Konstanta untuk mengelola tinggi AppBar yang bisa membesar
    const double summaryInfoHeight = 60.0;
    const double filterSectionHeight = 90.0; // Sedikit lebih tinggi untuk 3 chip

    // Hitung tinggi AppBar yang diperluas secara dinamis
    final double expandedAppBarHeight = 100.0 +
        summaryInfoHeight +
        (_showFilterChipsContainer ? filterSectionHeight : 10.0);

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: LiquidPullToRefresh(
          onRefresh: () async {
            // Reset semua filter dan muat ulang data
            setState(() {
              _selectedSeason = null;
              _selectedWeeks.clear();
              _selectedFA.clear();
              _selectedFIs.clear();
              _searchQuery = '';
              _selectedStatuses.clear();
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
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _navigateBackToHome,
                ),
                pinned: true,
                floating: true,
                elevation: 0,
                backgroundColor: Colors.green.shade800,
                expandedHeight: expandedAppBarHeight,
                title: _isSearching
                    ? TextField(
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: 'Cari lahan, petani...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                )
                    : const Text(
                  'Generative Inspection',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                    onPressed: () => setState(() {
                      if (_isSearching) _searchQuery = '';
                      _isSearching = !_isSearching;
                      _filterData();
                    }),
                  ),
                  if (!_isSearching)
                    IconButton(
                      icon: Badge(
                        isLabelVisible: _selectedSeason != null ||
                            _selectedWeeks.isNotEmpty ||
                            _selectedFA.isNotEmpty ||
                            _showDiscardedFaseItems ||
                            _selectedFIs.isNotEmpty,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.filter_list_rounded, color: Colors.white),
                      ),
                      tooltip: 'Filter Options',
                      onPressed: _showFilterOptions,
                    ),
                  if (!_isSearching)
                    IconButton(
                      icon: Icon(_showMapView ? Icons.view_list : Icons.map_outlined, color: Colors.white),
                      onPressed: _toggleViewMode,
                    ),
                  if (!_isSearching)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      tooltip: 'More options',
                      onSelected: (value) {
                        if (value == 'refresh') {
                          _loadSheetData(refresh: true);
                        } else if (value == 'analysis') {
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
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.green.shade800, Colors.green.shade600],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Opacity(
                          opacity: (1 - (_progress.clamp(0.0, 1.0) * 2)).clamp(0.0, 1.0),
                          child: Text(
                            selectedRegion ?? 'Unknown Region',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSummaryInfo(Icons.format_list_numbered, '${_filteredData.length} Lahan'),
                              _buildSummaryInfo(Icons.crop, 'Σ Area: ${_totalEffectiveArea.toStringAsFixed(1)} Ha'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Menggunakan widget container filter yang sudah kita buat
                        _buildFilterChipsContainer(),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(4.0),
                  child: _isLoading
                      ? LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.green.shade300.withAlpha(76),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                      : const SizedBox.shrink(),
                ),
              ),

              // === BAGIAN KONTEN UTAMA ===
              if (_showMapView)
                SliverFillRemaining(
                  child: GenerativeMapView(
                    filteredData: _filteredData,
                    selectedRegion: selectedRegion,
                    activityCounts: _activityCounts,
                  ),
                )
              else if (_isLoading)
                _buildSliverCenteredContent(child: Lottie.asset('assets/loading.json', height: 200))
              else if (_errorMessage != null)
                  _buildSliverCenteredContent(child: _buildErrorState())
                else if (_filteredData.isEmpty)
                    _buildSliverCenteredContent(child: _buildEmptyState())
                  else
                  // Menggunakan GenerativeSliverListBuilder
                    GenerativeSliverListBuilder(
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
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper untuk info ringkasan
  Widget _buildSummaryInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Helper untuk menempatkan widget di tengah sebagai sliver
  Widget _buildSliverCenteredContent({required Widget child}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }

  // Helper untuk tampilan error
  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          style: TextStyle(color: Colors.red.shade700, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _loadSheetData(refresh: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Helper untuk tampilan data kosong
  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset('assets/empty.json', height: 180),
        const SizedBox(height: 16),
        const Text('Data tidak ditemukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('Coba ubah filter atau kata kunci pencarian.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _selectedSeason = null;
              _selectedWeeks.clear();
              _selectedFA.clear();
              _selectedFIs.clear();
              _searchQuery = '';
              _selectedStatuses.clear();
              _filterData();
            });
          },
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('Reset Filter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}