import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'vegetative_detail_screen.dart';
import 'vegetative_filter_options.dart';
import 'vegetative_sliver_list_builder.dart';
import 'vegetative_map_view.dart';
import 'vegetative_activity_analysis_screen.dart';

class VegetativeScreen extends StatefulWidget {
  final String spreadsheetId;
  final String? selectedDistrict;
  final String? selectedQA;
  final String? selectedSeason;
  final String? region;
  final List<String> seasonList;

  const VegetativeScreen({
    super.key,
    required this.spreadsheetId,
    this.selectedDistrict,
    this.selectedQA,
    this.selectedSeason,
    this.region,
    required this.seasonList,
  });

  @override
  VegetativeScreenState createState() => VegetativeScreenState();
}

class VegetativeScreenState extends State<VegetativeScreen> {
  late final GoogleSheetsApi _googleSheetsApi;
  late String region; // Deklarasikan sebagai variabel instance
  final _worksheetTitle = 'Vegetative';
  String? _selectedSeason; // Nilai season yang dipilih
  List<String> _seasonsList = [];
  final List<List<String>> _sheetData = [];
  List<List<String>> _filteredData = [];
  bool _isLoading = true;
  String? selectedRegion;
  String? _errorMessage;
  String? _selectedQA;
  String _searchQuery = '';
  bool _isSearching = false; // Menyimpan status apakah sedang dalam mode pencarian
  int _currentPage = 1;
  final int _rowsPerPage = 100;
  Timer? _debounce;
  double _progress = 0.0; // Variabel untuk menyimpan progres
  bool _showFilterChipsContainer = false;

  List<String> _selectedWeeks = []; // Variabel untuk menyimpan minggu yang dipilih
  List<String> _weekOfVegetativeList = []; // Daftar unik untuk "Week of Vegetative"
  List<String> _faNames = []; // Daftar nama FA unik
  List<String> _selectedFA = []; // Daftar nama FA yang dipilih
  List<String> _fiNames = [];
  List<String> _selectedFIs = [];
  double _totalEffectiveArea = 0.0; // Variabel untuk menyimpan total Effective Area (Ha)

  final Map<String, int> _activityCounts = {};
  final Map<String, List<DateTime>> _activityTimestamps = {};
  bool _showMapView = false;

  bool _showAuditedOnly = false;
  bool _showNotAuditedOnly = false;
  bool _showDiscardedFaseItems = false;

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

      // Count activities for each field number, but only for Vegetative sheet
      for (var row in activityData) {
        if (row.length > 7) { // Ensure we have enough columns
          final sheetName = row.length > 5 ? row[5] : ''; // Sheet name is in column F (index 5)

          // Only process rows related to the Vegetative sheet
          if (sheetName.toLowerCase() == 'vegetative') {
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
    final faSet = <String>{}; // Menggunakan set untuk menyimpan nama unik
    for (var row in _sheetData) {
      final fa = getValue(row, 14, '').toLowerCase(); // FA ada di row 14
      if (fa.isNotEmpty && fa != 'fa') { // Hapus "Fa" dari daftar
        faSet.add(fa);
      }
    }
    setState(() {
      _faNames = faSet.map((fa) => toTitleCase(fa)).toList();
      _faNames.sort(); // Sorting A to Z
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
      _weekOfVegetativeList = weeksSet.toList()..sort(); // Sort the weeks
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
        final fase = getValue(row, 27, '').toLowerCase();
        final weekOfVegetative = getValue(row, 29, '');
        final qaSpv = getValue(row, 30, '');
        final fi = getValue(row, 31, '').toLowerCase();
        final statusAudit = getValue(row, 55, "NOT Audited").toLowerCase() == "audited";
        bool matchesAuditFilter = true;

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
            _selectedWeeks.isEmpty || _selectedWeeks.contains(weekOfVegetative);
        bool matchesFaseFilter = true; // Defaultnya true (lolos filter)
        if (!_showDiscardedFaseItems) { // Jika _showDiscardedFaseItems adalah false (default)
          matchesFaseFilter = fase != 'discard'; // Maka, hanya tampilkan yang BUKAN "discard"
        }
        if (_showAuditedOnly && !statusAudit) {
          matchesAuditFilter = false;
        }
        if (_showNotAuditedOnly && statusAudit) {
          matchesAuditFilter = false;
        }
        bool matchesFAFilter =
            _selectedFA.isEmpty ||
                _selectedFA.contains(toTitleCase(fa)); // Tambahkan filter FA
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
          .map((row) => getValue(row, 1, '')) // Mengambil Season dari kolom 1
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir dari yang terkecil ke yang terbesar

      _weekOfVegetativeList = _filteredData
          .map((row) => getValue(row, 29, '')) // Ambil dari kolom 29
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir dari yang terkecil ke yang terbesar

      _faNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 14, '').toLowerCase())) // Mengambil FA dari kolom 16
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir FA

      _fiNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 31, '').toLowerCase())) // Mengambil FI dari kolom 31
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir FI

      // Calculate total effective area
      _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
        final effectiveAreaStr = getValue(row , 8, '0').replaceAll(',', '.');
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
      _filterData(); // Lakukan filtering setelah search query diubah
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
            return VegetativeFilterOptions(
              selectedSeason: _selectedSeason,
              seasonsList: _seasonsList,
              onSeasonChanged: (value) {
                _selectedSeason = value;
              },

              selectedWeekOfVegetative: _selectedWeeks,
              weekOfVegetativeList: _weekOfVegetativeList,
              onWeekOfVegetativeChanged: (value) {
                _selectedWeeks = value;
              },

              selectedFA: _selectedFA,
              faNames: _faNames,
              onFAChanged: (selected) {
                _selectedFA = selected;
              },

              selectedFI: _selectedFIs, // Pass selected FIs
              fiNames: _fiNames,
              onFIChanged: (selected) {
                _selectedFIs = selected; // Update selected FIs
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
                  // BARU: Pastikan filter FASE juga di-reset
                  _showDiscardedFaseItems = false;
                });
                Navigator.pop(context); // Tutup modal setelah reset
                _filterData(); // Panggil filter data setelah reset
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

  // Widget Helper untuk filter audit status
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
                Expanded(child: _buildFilterChip(isAudited: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildFilterChip(isAudited: false)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Widget Helper untuk chip filter individual
  Widget _buildFilterChip({required bool isAudited}) {
    final bool isActive = isAudited ? _showAuditedOnly : _showNotAuditedOnly;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
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
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: isActive
                  ? LinearGradient(
                colors: isAudited
                    ? [Colors.green.shade400, Colors.green.shade500]
                    : [Colors.red.shade400, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isActive ? null : Colors.white,
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : (isAudited ? Colors.green.shade200 : Colors.red.shade200),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAudited
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  color: isActive
                      ? Colors.white
                      : (isAudited ? Colors.green.shade700 : Colors.red.shade600),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isAudited ? 'Sampun' : 'Dereng',
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : (isAudited ? Colors.green.shade700 : Colors.red.shade600),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Konstanta untuk mengelola tinggi AppBar
    const double baseAppBarHeight = 100.0;
    // PERUBAIKAN 1: Menambah tinggi area ringkasan untuk memberi ruang vertikal ekstra.
    const double summaryInfoHeight = 60.0; // Dinaikkan dari 60.0
    const double filterSectionHeight = 90.0;

    // Hitung tinggi AppBar yang diperluas secara dinamis dengan nilai baru
    final double expandedAppBarHeight = baseAppBarHeight +
        summaryInfoHeight +
        (_showFilterChipsContainer ? filterSectionHeight : 10.0);

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
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _navigateBackToHome,
                ),
                pinned: true,
                floating: true,
                elevation: 0,
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
                    : const Text('Vegetative Inspection',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,

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
                expandedHeight: expandedAppBarHeight,
                backgroundColor: Colors.green.shade800,

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

                        // PERUBAIKAN 2: Menambah jarak vertikal untuk mendorong ringkasan info ke bawah.
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

                        _buildFilterChipsContainer(),
                      ],
                    ),
                  ),
                ),
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
                    // IconButton(
                    //   icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
                    //   onPressed: _showFilterOptions,
                    // ),
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
                          // Navigate to analysis screen
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => VegetativeActivityAnalysisScreen(
                                activityCounts: _activityCounts,
                                activityTimestamps: _activityTimestamps,
                                vegetativeData: _filteredData,
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
                    )
                ],
              ),

              // Konten lainnya tidak berubah
              if (_showMapView)
                SliverFillRemaining(
                  child: VegetativeMapView(
                    filteredData: _filteredData,
                    selectedRegion: selectedRegion,
                    activityCounts: _activityCounts,
                  ),
                )
              else if (_isLoading)
                _buildSliverCenteredContent(child: Lottie.asset('assets/loading.json'))
              else if (_errorMessage != null)
                  _buildSliverCenteredContent(child: _buildErrorState())
                else if (_filteredData.isEmpty)
                    _buildSliverCenteredContent(child: _buildEmpty())
                  else
                    VegetativeSliverListBuilder(
                      filteredData: _filteredData,
                      selectedRegion: selectedRegion,
                      activityCounts: _activityCounts,
                      onItemTap: (fieldNumber) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => VegetativeDetailScreen(
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

// Helper untuk tampilan data kosong
  Widget _buildEmpty() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Lottie.asset('assets/empty.json', height: 180),
        const SizedBox(height: 16),
        const Text('Data tidak ditemukan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('Coba ubah filter atau kata kunci pencarian.', style: TextStyle(color: Colors.grey)),
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

  // Helper widget untuk ringkasan data
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

  // Helper untuk menampilkan widget di tengah sebagai sliver
  Widget _buildSliverCenteredContent({required Widget child}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: child,
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