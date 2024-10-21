import 'dart:async'; // Import untuk debounce
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'google_sheets_api.dart';
import 'vegetative_detail_screen.dart';

class VegetativeScreen extends StatefulWidget {
  final String? selectedDistrict;

  const VegetativeScreen({super.key, this.selectedDistrict});

  @override
  VegetativeScreenState createState() => VegetativeScreenState();
}

class VegetativeScreenState extends State<VegetativeScreen> {
  late final GoogleSheetsApi _googleSheetsApi;
  final _spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';
  final _worksheetTitle = 'Vegetative';

  final List<List<String>> _sheetData = [];
  List<List<String>> _filteredData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedQA;
  String _searchQuery = '';
  bool _isSearching = false; // Menyimpan status apakah sedang dalam mode pencarian
  int _currentPage = 1;
  final int _rowsPerPage = 100;
  Timer? _debounce;
  double _progress = 0.0; // Variabel untuk menyimpan progres

  // Daftar nama FA untuk filter
  List<String> _faNames = []; // Daftar nama FA unik
  List<String> _selectedFA = []; // Daftar nama FA yang dipilih

  double _totalEffectiveArea = 0.0; // Variabel untuk menyimpan total Effective Area (Ha)

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(_spreadsheetId);
    _loadSheetData();
    _loadFilterPreferences();
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
        _filterData();
        _currentPage++;
        _progress = (_sheetData.length / totalDataCount).clamp(0.0, 1.0); // Perbarui progres

        // Update total Effective Area (Ha)
        _totalEffectiveArea = _filteredData.fold(0.0, (sum, row) {
          final effectiveArea = double.tryParse(row[8]) ?? 0.0; // Row 8 adalah Effective Area
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

  Future<void> _loadFilterPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedQA = prefs.getString('selectedQA');
      _selectedFA = prefs.getStringList('selectedFA') ?? [];
    });
    _filterData(); // Panggil filter data setelah preferensi diambil
  }

  Future<void> _saveFilterPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedFA', _selectedFA); // Simpan selectedFA sebagai List<String>
    await prefs.setString('selectedQA', _selectedQA ?? ''); // Simpan selectedQA sebagai String
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

  void _filterData() {
    setState(() {
      _filteredData = _sheetData.where((row) {
        final qaSpv = getValue(row, 30, '');
        final district = getValue(row, 13, '').toLowerCase();
        final selectedDistrict = widget.selectedDistrict?.toLowerCase();

        bool matchesQAFilter = (_selectedQA == null || qaSpv == _selectedQA);
        bool matchesDistrictFilter = selectedDistrict == null || district == selectedDistrict;
        final fa = getValue(row, 16, '').toLowerCase(); // FA ada di kolom 16

        bool matchesFAFilter = _selectedFA.isEmpty || _selectedFA.contains(toTitleCase(fa)); // Tambahkan filter FA

        final fieldNumber = getValue(row, 2, '').toLowerCase();
        final farmerName = getValue(row, 3, '').toLowerCase();
        final grower = getValue(row, 4, '').toLowerCase();
        final desa = getValue(row, 11, '').toLowerCase();
        final kecamatan = getValue(row, 12, '').toLowerCase();
        final fieldSpv = getValue(row, 15, '').toLowerCase();

        bool matchesSearchQuery = fieldNumber.contains(_searchQuery) ||
            farmerName.contains(_searchQuery) ||
            grower.contains(_searchQuery) ||
            desa.contains(_searchQuery) ||
            kecamatan.contains(_searchQuery) ||
            district.contains(_searchQuery) ||
            fa.contains(_searchQuery) ||
            fieldSpv.contains(_searchQuery);

        return matchesQAFilter && matchesDistrictFilter && matchesFAFilter && matchesSearchQuery;
      }).toList();
      _faNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 16, '').toLowerCase())) // Mengambil FA dari kolom 16
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir FA
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
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Filter by FA',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Hanya tampilkan FA yang sesuai dengan QA SPV dan District yang dipilih
                    ..._faNames.map((fa) {
                      return CheckboxListTile(
                        title: Text(fa),
                        value: _selectedFA.contains(fa),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedFA.add(fa); // Tambahkan FA ke daftar yang dipilih
                            } else {
                              _selectedFA.remove(fa); // Hapus FA dari daftar yang dipilih
                            }
                            _filterData(); // Filter ulang data setelah FA diubah
                            _saveFilterPreferences(); // Simpan filter ke SharedPreferences
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: !_isSearching
            ? const Text('Vegetative Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : TextField(
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: const TextStyle(color: Colors.white60),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.white),
          ),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions, // Menampilkan opsi filter FA
          ),
          !_isSearching
              ? IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          )
              : IconButton(
            icon: const Icon(Icons.cancel),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
                _filterData();
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Column(
            children: [
              _isLoading
                  ? LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
              )
                  : const SizedBox.shrink(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'Jumlah data: ${_filteredData.length}', // Menampilkan jumlah data
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Total Effective Area: ${_totalEffectiveArea.toStringAsFixed(1)} Ha', // Menampilkan Total Effective Area
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: LiquidPullToRefresh(
        onRefresh: () => _loadSheetData(refresh: true),
        color: Colors.green,
        backgroundColor: Colors.white,
        height: 150,
        showChildOpacityTransition: false,
        child: _isLoading
            ? Center(child: Lottie.asset('assets/loading.json'))
            : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : _filteredData.isEmpty
            ? const Center(child: Text('No data available'))
            : ListView.builder(
          itemCount: _filteredData.length + 1,
          itemBuilder: (context, index) {
            if (index == _filteredData.length) {
              return _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : TextButton(
                onPressed: _loadSheetData,
                child: const Text('Load More'),
              );
            }
            final row = _filteredData[index];

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: Hero(
                  tag: 'vegetative_${getValue(row, 2, "Unknown")}', // Pastikan tag unik untuk tiap item
                  child: Image.asset(
                    'assets/vegetative.png',
                    height: 60,
                    width: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                title: Text(getValue(row, 2, "Unknown")),
                subtitle: Text(
                  'Farmer: ${getValue(row, 3, "Unknown")}, '
                      'Grower: ${getValue(row, 4, "Unknown")}, '
                      'Desa: ${getValue(row, 11, "Unknown")}, '
                      'Kec: ${getValue(row, 12, "Unknown")}, '
                      'Kab: ${getValue(row, 13, "Unknown")}, '
                      'Field SPV: ${getValue(row, 15, "Unknown")}, '
                      'FA: ${getValue(row, 16, "Unknown")}', // Menampilkan FA
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => VegetativeDetailScreen(fieldNumber: getValue(row, 2, "Unknown")), // Gunakan fieldNumber
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
