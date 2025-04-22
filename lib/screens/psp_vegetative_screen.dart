import 'dart:async'; // Import untuk debounce
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'google_sheets_api.dart';
import 'psp_vegetative_detail_screen.dart';
import 'config_manager.dart';

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

  String? _selectedWeekOfAuditSatu; // Variabel untuk menyimpan minggu yang dipilih
  List<String> _weekOfAuditSatuList = []; // Daftar unik untuk "Week of Vegetative"

  List<String> _faNames = []; // Daftar nama FA unik
  List<String> _selectedFA = []; // Daftar nama FA yang dipilih

  double _totalEffectiveArea = 0.0; // Variabel untuk menyimpan total Effective Area (Ha)

  String getMultiAuditStatus(String cekAudit1, String cekAudit2, String cekAudit3) {
    if (cekAudit1.toLowerCase() == "audited" && cekAudit2.toLowerCase() == "audited" && cekAudit3.toLowerCase() == "audited") {
      return "Sampun";
    } else if ((cekAudit1.toLowerCase() == "audited" && cekAudit2.toLowerCase() == "not audited" && cekAudit3.toLowerCase() == "not audited") ||
        (cekAudit1.toLowerCase() == "audited" && cekAudit2.toLowerCase() == "audited" && cekAudit3.toLowerCase() == "not audited") ||
        (cekAudit1.toLowerCase() == "not audited" && cekAudit2.toLowerCase() == "audited" && cekAudit3.toLowerCase() == "audited") ||
        (cekAudit1.toLowerCase() == "not audited" && cekAudit2.toLowerCase() == "audited" && cekAudit3.toLowerCase() == "not audited") ||
        (cekAudit1.toLowerCase() == "not audited" && cekAudit2.toLowerCase() == "not audited" && cekAudit3.toLowerCase() == "audited")) {
      return "Dereng Jangkep";
    } else if (cekAudit1.toLowerCase() == "not audited" && cekAudit2.toLowerCase() == "not audited" && cekAudit3.toLowerCase() == "not audited") {
      return "Dereng Blas";
    }
    return "Unknown"; // Default jika ada data yang tidak sesuai
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
          final effectiveArea = double.tryParse(row[9]) ?? 0.0;
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
      _selectedFA = prefs.getStringList('selectedFA') ?? [];
    });
    _filterData(); // Panggil filter data setelah preferensi diambil
  }

  // Future<void> _saveFilterPreferences() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   await prefs.setStringList('selectedFA', _selectedFA); // Simpan selectedFA sebagai List<String>
  //   await prefs.setString('selectedQA', _selectedQA ?? ''); // Simpan selectedQA sebagai String
  // }

  // Ekstrak nama-nama FA yang unik dari data
  void _extractUniqueFA() {
    final faSet = <String>{}; // Menggunakan set untuk menyimpan nama unik
    for (var row in _sheetData) {
      final fa = getValue(row, 19, '').toLowerCase();
      if (fa.isNotEmpty && fa != 'fa') {
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
        final qaSpv = getValue(row, 25, '');
        final district = getValue(row, 16, '').toLowerCase();
        final season = getValue(row, 1, '');
        final weekOfAuditSatu = getValue(row, 29, ''); // Ambil dari kolom 29 untuk "Week of Vegetative"

        bool matchesSeasonFilter = (_selectedSeason == null || season == _selectedSeason);
        bool matchesQAFilter = (_selectedQA == null || qaSpv == _selectedQA);
        bool matchesDistrictFilter =
            widget.selectedDistrict == null ||
                district == widget.selectedDistrict!.toLowerCase();
        bool matchesWeekFilter =
        (_selectedWeekOfAuditSatu == null || weekOfAuditSatu == _selectedWeekOfAuditSatu);

        final fa = getValue(row, 19, '').toLowerCase(); // FA ada di kolom 16

        bool matchesFAFilter =
            _selectedFA.isEmpty ||
                _selectedFA.contains(toTitleCase(fa)); // Tambahkan filter FA

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
            fieldSpv.contains(_searchQuery) ||
            getMultiAuditStatus(
                getValue(row, 82, ""), // Kolom "Cek Audit 1"
                getValue(row, 84, ""), // Kolom "Cek Audit 2"
                getValue(row, 86, "")  // Kolom "Cek Audit 3"
            ).toLowerCase().contains(_searchQuery); // Pencarian berdasarkan status

        return matchesQAFilter &&
            matchesDistrictFilter &&
            matchesFAFilter &&
            matchesSeasonFilter &&
            matchesWeekFilter &&
            matchesSearchQuery;
      }).toList();

      _seasonsList = _filteredData
          .map((row) => getValue(row, 1, '')) // Mengambil Week of Generative dari kolom 27
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir dari yang terkecil ke yang terbesar

      _weekOfAuditSatuList = _filteredData
          .map((row) => getValue(row, 29, '')) // Ambil dari kolom 27
          .toSet() // Menghapus duplikasi
          .toList()
        ..sort(); // Sortir dari yang terkecil ke yang terbesar

      _faNames = _filteredData
          .map((row) => toTitleCase(getValue(row, 19, '').toLowerCase())) // Mengambil FA dari kolom 16
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
                        'Filter by Seasons',
                        style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedSeason,
                      hint: const Text("Select Season"),
                      isExpanded: true,
                      items: _seasonsList.map((season) {
                        return DropdownMenuItem<String>(
                          value: season,
                          child: Text(season),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSeason = newValue; // Atur season yang dipilih
                          _filterData(); // Filter ulang data berdasarkan season
                        });
                      },
                      style: const TextStyle(
                        color: Colors.black, // Ubah warna teks
                        fontSize: 16.0, // Ubah ukuran teks
                      ),
                      decoration: InputDecoration(
                        labelText: 'Season',
                        labelStyle: TextStyle(
                          color: Colors.redAccent, // Warna teks label
                          fontWeight: FontWeight.bold, // Membuat teks label menjadi bold
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.redAccent, width: 2.0), // Ubah warna border
                          borderRadius: BorderRadius.circular(8.0), // Sudut melengkung
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.redAccent, width: 2.0), // Warna border saat fokus
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey, width: 2.0), // Warna border default
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Filter by Week of Vegetative',
                        style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedWeekOfAuditSatu,
                      hint: const Text("Select Week"),
                      isExpanded: true,
                      items: _weekOfAuditSatuList.map((week) {
                        return DropdownMenuItem<String>(
                          value: week,
                          child: Text(week),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedWeekOfAuditSatu = newValue; // Memperbarui nilai pilihan
                          _filterData(); // Filter ulang data berdasarkan pilihan baru
                        });
                      },
                      style: const TextStyle(
                        color: Colors.black, // Ubah warna teks
                        fontSize: 16.0, // Ubah ukuran teks
                      ),
                      decoration: InputDecoration(
                        labelText: 'Week of Vegetative',
                        labelStyle: TextStyle(
                          color: Colors.redAccent, // Warna teks label
                          fontWeight: FontWeight.bold, // Membuat teks label menjadi bold
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.redAccent, width: 2.0), // Ubah warna border
                          borderRadius: BorderRadius.circular(8.0), // Sudut melengkung
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.redAccent, width: 2.0), // Warna border saat fokus
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey, width: 2.0), // Warna border default
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Filter by FA',
                        style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
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
                          });
                        },
                        activeColor: Colors.redAccent,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          // Reset semua filter ke kondisi awal
                          _selectedSeason = null;
                          _selectedWeekOfAuditSatu = null;
                          _selectedFA.clear(); // Kosongkan list FA yang dipilih
                          _filterData();
                        });
                        // Tutup bottom sheet
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white), // Ikon reset dengan warna putih
                      label: const Text("Reset Filters", style: TextStyle(color: Colors.white)), // Teks dengan warna putih
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent, // Warna latar belakang tombol
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Padding dalam tombol
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // Ukuran dan gaya teks
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Membuat tombol dengan sudut melengkung
                        ),
                      ),
                    ),
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
        backgroundColor: Colors.redAccent,
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
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
        color: Colors.redAccent,
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
          itemCount: _filteredData.length,
          itemBuilder: (context, index) {

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
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        getValue(row, 2, "Unknown"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Agar teks tidak melampaui batas
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: getMultiAuditStatus(
                            getValue(row, 82, ""),
                            getValue(row, 84, ""),
                            getValue(row, 86, "")
                        ) == "Sampun"
                            ? Colors.green
                            : getMultiAuditStatus(
                            getValue(row, 82, ""),
                            getValue(row, 84, ""),
                            getValue(row, 86, "")
                        ) == "Dereng Lengkap"
                            ? Colors.orangeAccent
                            : Colors.red,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        getMultiAuditStatus(
                            getValue(row, 82, ""),
                            getValue(row, 84, ""),
                            getValue(row, 86, "")
                        ),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                subtitle: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style, // Style default untuk teks biasa
                    children: [
                      TextSpan(text: 'Farmer: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${getValue(row, 4, "Unknown")}, '),
                      TextSpan(text: 'Grower/Agent: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${getValue(row, 5, "Unknown")}, '),
                      TextSpan(text: 'Desa: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${getValue(row, 14, "Unknown")}, '),
                      TextSpan(text: 'Kec: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${getValue(row, 15, "Unknown")}, '),
                      TextSpan(text: 'Kab: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${getValue(row, 16, "Unknown")}, '),
                      TextSpan(text: 'Field SPV: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '${getValue(row, 18, "Unknown")}, '),
                      TextSpan(text: 'FA: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: getValue(row, 19, "Unknown")),
                    ],
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PspVegetativeDetailScreen(
                        fieldNumber: getValue(row, 2, "Unknown"),
                        region: selectedRegion ?? 'Unknown Region',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const BottomAppBar(
        color: Colors.redAccent,
        shape: CircularNotchedRectangle(),
        child: SizedBox(height: 50.0),
      ),
    );
  }
}
