import 'dart:async'; // Import untuk debounce

import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Masih diperlukan

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'pre_harvest_filter_options.dart';
import 'pre_harvest_listview_builder.dart';
import 'preharvest_detail_screen.dart';

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
  late final GoogleSheetsApi _googleSheetsApi;
  late String region;
  final _worksheetTitle = 'Pre Harvest';
  String? _selectedSeason;
  List<String> _seasonsList = [];
  final List<List<String>> _sheetData = []; // Ubah menjadi final
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

  List<String> _selectedWeeks = []; // Menyimpan minggu yang dipilih
  List<String> _weekOfPreHarvestList = []; // Daftar unik minggu dari data

  List<String> _faNames = []; // Daftar nama FA unik
  List<String> _selectedFA = []; // Daftar nama FA yang dipilih

  List<String> _fiNames = [];
  List<String> _selectedFIs = [];

  double _totalEffectiveArea = 0.0; // Variabel untuk menyimpan total Effective Area (Ha)

  bool _showAuditedOnly = false;
  bool _showNotAuditedOnly = false;

  @override
  void initState() {
    super.initState();
    final spreadsheetId = ConfigManager.getSpreadsheetId(widget.region ?? "Default Region") ?? '';
    selectedRegion = widget.region ?? "Unknown Region";
    _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
    _loadSheetData();
    _loadFilterPreferences(); // Memuat filter FA yang tersimpan
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSheetData({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _sheetData.clear();
      _totalEffectiveArea = 0.0; // Reset total Effective Area saat refresh
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _progress = 0.0; // Reset progres saat mulai mengambil data
    });

    try {
      await _googleSheetsApi.init();
      final totalDataCount = 12000; // Estimasi jumlah total data (bisa dinamis)
      final data = await _googleSheetsApi.getSpreadsheetDataWithPagination(
          _worksheetTitle, (_currentPage - 1) * _rowsPerPage + 1, _rowsPerPage);

      setState(() {
        _sheetData.addAll(data);
        _filteredData = List.from(_sheetData);
        _isLoading = false;
        _extractUniqueFA(); // Ekstrak nama-nama FA dari data
        _extractUniqueFIs(); // Ekstrak nama-nama FI dari data
        _extractUniqueSeasons(); // Ekstrak unique seasons
        _extractUniqueWeeks(); // Ekstrak unique weeks
        _filterData();
        _currentPage++;
        _progress = (_sheetData.length / totalDataCount).clamp(0.0, 1.0); // Perbarui progres

        // Update total Effective Area (Ha)
        _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
          final effectiveAreaStr = getValue(row, 8, '0').replaceAll(',', '.'); // Handle decimal separators
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

  // Ekstrak nama-nama FA yang unik dari data
  void _extractUniqueFA() {
    final faSet = <String>{}; // Menggunakan set untuk menyimpan nama unik
    for (var row in _sheetData) {
      final fa = getValue(row, 16, '').toLowerCase(); // FA ada di row 16
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
      _weekOfPreHarvestList = weeksSet.toList()..sort(); // Sort the weeks
    });
  }

  void _filterData() {
    setState(() {
      _filteredData = _sheetData.where((row) {
        final qaSpv = getValue(row, 28, '');
        final district = getValue(row, 13, '').toLowerCase();
        final season = getValue(row, 1, '');
        final weekOfPreHarvest = getValue(row, 27, ''); // Ambil nilai minggu pre-harvest dari kolom 27

        bool matchesSeasonFilter = (_selectedSeason == null || season == _selectedSeason);
        bool matchesQAFilter = (_selectedQA == null || qaSpv == _selectedQA);
        bool matchesDistrictFilter =
            widget.selectedDistrict == null ||
                district == widget.selectedDistrict!.toLowerCase();
        bool matchesWeekFilter =
            _selectedWeeks.isEmpty || _selectedWeeks.contains(weekOfPreHarvest);
        final statusAudit = getValue(row, 39, "NOT Audited").toLowerCase() == "audited";
        bool matchesAuditFilter = true;

        if (_showAuditedOnly && !statusAudit) {
          matchesAuditFilter = false;
        }
        if (_showNotAuditedOnly && statusAudit) {
          matchesAuditFilter = false;
        }

        final fa = getValue(row, 16, '').toLowerCase(); // FA berada di row 16
        final fi = getValue(row, 29, '').toLowerCase();

        bool matchesFAFilter =
            _selectedFA.isEmpty ||
                _selectedFA.contains(toTitleCase(fa)); // Filter berdasarkan FA yang dipilih

        bool matchesFIFilter =
            _selectedFIs.isEmpty ||
                _selectedFIs.contains(toTitleCase(fi));

        final fieldNumber = getValue(row, 2, '').toLowerCase();
        final farmer = getValue(row, 3, '').toLowerCase();
        final grower = getValue(row, 4, '').toLowerCase();
        final hybrid = getValue(row, 5, '').toLowerCase();
        final desa = getValue(row, 11, '').toLowerCase();
        final kecamatan = getValue(row, 12, '').toLowerCase();
        final fieldSpv = getValue(row, 15, '').toLowerCase();

        bool matchesSearchQuery = fieldNumber.contains(_searchQuery) ||
            farmer.contains(_searchQuery) ||
            grower.contains(_searchQuery) ||
            hybrid.contains(_searchQuery) ||
            desa.contains(_searchQuery) ||
            kecamatan.contains(_searchQuery) ||
            district.contains(_searchQuery) ||
            fa.contains(_searchQuery) ||
            fi.contains(_searchQuery) ||
            fieldSpv.contains(_searchQuery);

        return matchesQAFilter &&
            matchesDistrictFilter &&
            matchesFAFilter &&
            matchesFIFilter &&
            matchesSeasonFilter &&
            matchesWeekFilter &&
            matchesSearchQuery &&
            matchesAuditFilter;

      }).toList();

      _seasonsList = _filteredData
          .map((row) => getValue(row, 1, '')) // Mengambil Week of Generative dari kolom 27
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort();

      _weekOfPreHarvestList = _filteredData
          .map((row) => getValue(row, 27, '')) // Mengambil nilai minggu dari kolom 27
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir dari yang terkecil ke yang terbesar

      _faNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 16, '').toLowerCase())) // Mengambil FA dari kolom 16
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir FA

      _fiNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 29, '').toLowerCase())) // Mengambil FI dari kolom 31
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir FI

      // Calculate total effective area
      _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
        final effectiveAreaStr = getValue(row, 8, '0').replaceAll(',', '.');
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
      backgroundColor: Colors.transparent, // Keep transparent for rounded corners
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

              selectedFI: _selectedFIs, // Pass selected FIs
              fiNames: _fiNames,
              onFIChanged: (selected) {
                _selectedFIs = selected; // Update selected FIs
              },

              onResetAll: () {
                _selectedSeason = null;
                _selectedWeeks.clear();
                _selectedFA.clear();
                _selectedFIs.clear(); // Reset selected FIs
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
              const Icon(Icons.eco_rounded, size: 24),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pre-Harvest Data',
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
                  ),
                ],
              ),
            ],
          )
              : TextField(
            onChanged: _onSearchChanged,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Search field number, farmer, grower...',
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _filterData();
                  });
                },
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
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
              icon: const Icon(Icons.cancel, color: Colors.white),
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
                  const Icon(Icons.filter_list_rounded, color: Colors.white),
                  if (_selectedSeason != null || _selectedWeeks.isNotEmpty || _selectedFA.isNotEmpty || _selectedFIs.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Filter Options',
              onPressed: _showFilterOptions,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'refresh') {
                  _loadSheetData(refresh: true);
                } else if (value == 'help') {
                  // Show help dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Bantuan!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: const Text('Koco iki nampilake data Pre-Harvest. Sampeyan biso nggoleki, nyaring, lan ndeleng rincian kanthi nutul item sing pengin dideleng.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
            ),
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
                                '${_filteredData.length} Data',
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
                                'Σ Effective Area:${_totalEffectiveArea.toStringAsFixed(1)} Ha',
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                    child: Text(
                      'Filter Audit Status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _showAuditedOnly
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
                                  _showAuditedOnly = !_showAuditedOnly;
                                  if (_showAuditedOnly) _showNotAuditedOnly = false;
                                  _filterData();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: _showAuditedOnly
                                      ? LinearGradient(
                                    colors: [Colors.green.shade400, Colors.green.shade500],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                      : null,
                                  color: _showAuditedOnly ? null : Colors.white,
                                  border: Border.all(
                                    color: _showAuditedOnly ? Colors.transparent : Colors.green.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: _showAuditedOnly ? Colors.white : Colors.green.shade700,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sampun',
                                      style: TextStyle(
                                        color: _showAuditedOnly ? Colors.white : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                            boxShadow: _showNotAuditedOnly
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
                                  _showNotAuditedOnly = !_showNotAuditedOnly;
                                  if (_showNotAuditedOnly) _showAuditedOnly = false;
                                  _filterData();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: _showNotAuditedOnly
                                      ? LinearGradient(
                                    colors: [Colors.red.shade400, Colors.red.shade600],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                      : null,
                                  color: _showNotAuditedOnly ? null : Colors.white,
                                  border: Border.all(
                                    color: _showNotAuditedOnly ? Colors.transparent : Colors.red.shade200,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pending_outlined,
                                      color: _showNotAuditedOnly ? Colors.white : Colors.red.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Dereng',
                                      style: TextStyle(
                                        color: _showNotAuditedOnly ? Colors.white : Colors.red.shade600,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
              ),
            ),
            // Main Content
            Expanded(
              child: LiquidPullToRefresh(
                  onRefresh: () async {
                    // Reset filters and load data
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
                              _showAuditedOnly = false;
                              _showNotAuditedOnly = false;
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
                              _selectedFIs.clear(); // Reset selected FIs
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
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : PreHarvestListviewBuilder(
                    filteredData: _filteredData,
                    selectedRegion: selectedRegion,
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
                  )
              ),
            ),
          ],
        ),
      ),
    );
  }
}