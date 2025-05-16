import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class KalkulatorTKDPage extends StatefulWidget {
  final String selectedRegion;

  const KalkulatorTKDPage({super.key, required this.selectedRegion});

  @override
  KalkulatorTKDPageState createState() => KalkulatorTKDPageState();
}

class KalkulatorTKDPageState extends State<KalkulatorTKDPage> {
  List<String> fnList = [];
  List<String> farmerList = [];
  List<String> villageList = [];
  List<String> hybridList = [];
  String? selectedFN;
  String? selectedFarmer;
  String? selectedVillage;
  String? selectedHybrid;
  double luasLahan = 0.0;
  int tkdPerHektar = 15;
  int totalTKD = 0;
  bool isLoading = true;

  final Map<String, Map<String, dynamic>> fnDataMap = {};
  final SearchController _fnSearchController = SearchController();
  final TextEditingController _tkdController = TextEditingController(text: '15');
  String _currentSearchFilter = 'Field Number'; // Default search filter

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF81C784);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color backgroundGreen = Color(0xFFE8F5E9);
  static const Color textOnGreen = Colors.white;

  @override
  void initState() {
    super.initState();
    _tkdController.text = '15';
    _loadDataFromSpreadsheet();
  }

  @override
  void dispose() {
    _tkdController.dispose();
    _fnSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      selectedFN = fnList.isNotEmpty ? fnList.first : null;
      _updateDetailsForSelectedFN();
      luasLahan = selectedFN != null ? (fnDataMap[selectedFN]?['area'] ?? 0.0) : 0.0;
      _tkdController.text = '15';
      tkdPerHektar = 15;
      totalTKD = 0;
    });

    await _loadDataFromSpreadsheet();
  }

  Future<void> _loadDataFromSpreadsheet() async {
    setState(() => isLoading = true);

    try {
      final String? spreadsheetId = ConfigManager.getSpreadsheetId(widget.selectedRegion);
      if (spreadsheetId == null) throw Exception("Spreadsheet ID not found");

      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData('Generative');

      fnList.clear();
      fnDataMap.clear();
      villageList.clear();
      hybridList.clear();

      for (int i = 1; i < data.length; i++) {
        final row = data[i];
        if (row.length >= 11) { // Ensure we have enough columns for all data
          final fn = row[2];
          final farmer = row[3];
          final hybrid = row[5];
          final area = double.tryParse(row[6].replaceAll(',', '.')) ?? 0.0;
          final village = row[11];

          if (!fnDataMap.containsKey(fn)) {
            fnDataMap[fn] = {
              'farmers': [farmer],
              'area': area,
              'hybrid': hybrid,
              'village': village,
            };
            fnList.add(fn);
          } else {
            if (!fnDataMap[fn]!['farmers'].contains(farmer)) {
              fnDataMap[fn]!['farmers'].add(farmer);
            }
          }

          if (!villageList.contains(village)) villageList.add(village);
          if (!hybridList.contains(hybrid)) hybridList.add(hybrid);
        }
      }

      setState(() {
        if (fnList.isNotEmpty) {
          selectedFN = fnList.first;
          _updateDetailsForSelectedFN();
          luasLahan = fnDataMap[selectedFN]?['area'] ?? 0.0;
        }
        _calculateTKD();
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateDetailsForSelectedFN() {
    if (selectedFN == null || !fnDataMap.containsKey(selectedFN)) {
      farmerList = [];
      selectedFarmer = null;
      selectedVillage = null;
      selectedHybrid = null;
      return;
    }

    final data = fnDataMap[selectedFN]!;
    farmerList = data['farmers'] as List<String>;
    selectedFarmer = farmerList.isNotEmpty ? farmerList.first : null;
    selectedVillage = data['village'] as String;
    selectedHybrid = data['hybrid'] as String;
  }

  void _onFNChanged(String? newFN) {
    if (newFN == null) return;

    setState(() {
      selectedFN = newFN;
      _updateDetailsForSelectedFN();
      luasLahan = fnDataMap[newFN]?['area'] ?? 0.0;
      _calculateTKD();
      _fnSearchController.closeView(newFN);
    });
  }

  void _calculateTKD() {
    setState(() {
      totalTKD = (luasLahan * tkdPerHektar).ceil();
    });
  }

  Widget _buildSearchFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(
            'Field Number',
            style: TextStyle(
              fontWeight: _currentSearchFilter == 'Field Number'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _currentSearchFilter == 'Field Number'
                  ? darkGreen
                  : Colors.black,
            ),
          ),
          selected: _currentSearchFilter == 'Field Number',
          onSelected: (selected) {
            setState(() {
              _currentSearchFilter = 'Field Number';
              _fnSearchController.text = '';
            });
          },
          selectedColor: Colors.green[200],
          backgroundColor: Colors.white,
          side: BorderSide(color: lightGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        ChoiceChip(
          label: Text(
            'Petani',
            style: TextStyle(
              fontWeight: _currentSearchFilter == 'Petani'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _currentSearchFilter == 'Petani'
                  ? darkGreen
                  : Colors.black,
            ),
          ),
          selected: _currentSearchFilter == 'Petani',
          onSelected: (selected) {
            setState(() {
              _currentSearchFilter = 'Petani';
              _fnSearchController.text = '';
            });
          },
          selectedColor: Colors.green[200],
          backgroundColor: Colors.white,
          side: BorderSide(color: lightGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
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
    // Define green color palette
    const Color primaryGreen = Color(0xFF2E7D32);
    const Color lightGreen = Color(0xFF81C784);
    const Color darkGreen = Color(0xFF1B5E20);
    const Color backgroundGreen = Color(0xFFE8F5E9);
    const Color textOnGreen = Colors.white;

    // ignore: deprecated_member_use
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: _navigateBackToHome,
    ),
        title: const Text(
          'Estimasi TKD',
          style: TextStyle(
            color: textOnGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryGreen,
        iconTheme: const IconThemeData(color: textOnGreen),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      backgroundColor: backgroundGreen,
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/loading.json',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ngrantos sekedap...',
              style: TextStyle(
                fontSize: 16,
                color: darkGreen,
              ),
            ),
          ],
        ),
      )
          : LiquidPullToRefresh(
        onRefresh: _refreshData,
        color: primaryGreen,
        backgroundColor: backgroundGreen,
        height: 120,
        animSpeedFactor: 1.5,
        showChildOpacityTransition: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Region Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: primaryGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lokasi',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.selectedRegion,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: darkGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Search Filter Chips
              _buildSearchFilterChips(),
              const SizedBox(height: 12),

              // Searchable Dropdown
              SearchAnchor(
                searchController: _fnSearchController,
                builder: (BuildContext context, SearchController controller) {
                  return SearchBar(
                    controller: controller,
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 16)),
                    onTap: () => controller.openView(),
                    onChanged: (_) => controller.openView(),
                    leading: const Icon(
                      Icons.search,
                      color: primaryGreen,
                    ),
                    trailing: const [
                      Icon(
                        Icons.arrow_drop_down,
                        color: primaryGreen,
                      )
                    ],
                    hintText: 'Cari $_currentSearchFilter',
                    hintStyle: WidgetStateProperty.all(
                      const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.all(Colors.white), // Add this line
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: lightGreen),
                      ),
                    ),
                    elevation: const WidgetStatePropertyAll(1),
                  );
                },
                suggestionsBuilder: (context, controller) {
                  final query = controller.text.toLowerCase();

                  if (_currentSearchFilter == 'Field Number') {
                    return fnList
                        .where((fn) => fn.toLowerCase().contains(query))
                        .map((fn) => ListTile(
                      title: Text(fn,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Petani: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: fnDataMap[fn]?['farmers']?.join(', ') ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Desa: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: fnDataMap[fn]?['village'] ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Hybrid: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: fnDataMap[fn]?['hybrid'] ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Luas: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: fnDataMap[fn]?['area']?.toStringAsFixed(2) ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: ' Ha',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _onFNChanged(fn),
                    ))
                        .toList();
                  } else if (_currentSearchFilter == 'Petani') {
                    return fnDataMap.entries
                        .expand((entry) => (entry.value['farmers'] as List<String>)
                        .where((farmer) => farmer.toLowerCase().contains(query))
                        .map((farmer) => ListTile(
                      title: Text(farmer,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Field: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: entry.key,
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Desa: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: entry.value['village'] ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Hybrid: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: entry.value['hybrid'] ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Luas: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: entry.value['area']?.toStringAsFixed(2) ?? '-',
                                  style: TextStyle(color: Colors.black),
                                ),
                                TextSpan(
                                  text: ' Ha',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        _onFNChanged(entry.key);
                        setState(() {
                          selectedFarmer = farmer;
                        });
                      },
                    )))
                        .toList();
                  }
                  return [];
                },
              ),
              const SizedBox(height: 20),

              // Current FN and Farmer Display
              if (selectedFN != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: lightGreen,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.tag,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Field Number: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  TextSpan(
                                    text: selectedFN!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Farmer: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  TextSpan(
                                    text: selectedFarmer ?? 'Tidak tersedia',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.home,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Desa: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  TextSpan(
                                    text: selectedVillage ?? 'Tidak tersedia',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.grass,
                            color: primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Hybrid: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  TextSpan(
                                    text: selectedHybrid ?? 'Tidak tersedia',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Rest of the code remains the same...
              // Calculation Input Section
              const Text(
                'Parameter Perhitungan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Luas Lahan
                  Expanded(
                    flex: 2, // Diubah dari 3 menjadi 2
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Luas Lahan (Ha)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: lightGreen,
                            ),
                          ),
                          child: Center( // Tambahkan Center untuk alignment yang konsisten
                            child: Text(
                              NumberFormat("#,##0.00").format(luasLahan),
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // Tambahkan spacing antara kolom

                  // TKD/Ha
                  Expanded(
                    flex: 2, // Tetap 2
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TKD/Ha',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _tkdController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            prefixIcon: const Icon(Icons.clear_rounded, color: primaryGreen, size: 28),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: lightGreen),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: lightGreen),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryGreen,
                                width: 2,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final newValue = int.tryParse(value) ?? 0;
                            setState(() {
                              tkdPerHektar = newValue;
                              _calculateTKD();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Results Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: lightGreen, width: 1), // Add border
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'ESTIMASI KEBUTUHAN TKD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            NumberFormat("#,##0.00").format(luasLahan),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '×',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tkdPerHektar.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '=',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            totalTKD.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryGreen.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total Kebutuhan: $totalTKD Orang',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
    );
  }
}