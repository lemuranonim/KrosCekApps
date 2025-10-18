import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class PspKalkulatorTKDPage extends StatefulWidget {
  final String selectedRegion;

  const PspKalkulatorTKDPage({super.key, required this.selectedRegion});

  @override
  PspKalkulatorTKDPageState createState() => PspKalkulatorTKDPageState();
}

class PspKalkulatorTKDPageState extends State<PspKalkulatorTKDPage> {
  List<String> fnList = [];
  List<String> farmerList = [];
  List<String> villageList = [];
  List<String> psCodeList = [];
  String? selectedFN;
  String? selectedFarmer;
  String? selectedVillage;
  String? selectedPsCode;
  double luasLahan = 0.0;
  int tkdPerHektar = 15;
  int totalTKD = 0;
  bool isLoading = true;

  final Map<String, Map<String, dynamic>> fnDataMap = {};
  final SearchController _fnSearchController = SearchController();
  final TextEditingController _tkdController = TextEditingController(text: '15');
  String _currentSearchFilter = 'Field Number'; // Default search filter

  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color lightRed = Color(0xFFFF6659);
  static const Color darkRed = Color(0xFF9A0007);
  static const Color backgroundRed = Color(0xFFFFEBEE);
  static const Color textOnRed = Colors.white;

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
      psCodeList.clear();

      for (int i = 1; i < data.length; i++) {
        final row = data[i];
        if (row.length >= 11) { // Ensure we have enough columns for all data
          final fn = row[2];
          final farmer = row[4];
          final psCode = row[6];
          final area = double.tryParse(row[7].replaceAll(',', '.')) ?? 0.0;
          final village = row[14];

          if (!fnDataMap.containsKey(fn)) {
            fnDataMap[fn] = {
              'farmers': [farmer],
              'area': area,
              'psCode': psCode,
              'village': village,
            };
            fnList.add(fn);
          } else {
            if (!fnDataMap[fn]!['farmers'].contains(farmer)) {
              fnDataMap[fn]!['farmers'].add(farmer);
            }
          }

          if (!villageList.contains(village)) villageList.add(village);
          if (!psCodeList.contains(psCode)) psCodeList.add(psCode);
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
      selectedPsCode = null;
      return;
    }

    final data = fnDataMap[selectedFN]!;
    farmerList = data['farmers'] as List<String>;
    selectedFarmer = farmerList.isNotEmpty ? farmerList.first : null;
    selectedVillage = data['village'] as String;
    selectedPsCode = data['psCode'] as String;
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
                  ? textOnRed
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
          selectedColor: Colors.orange[200],
          backgroundColor: Colors.white,
          side: BorderSide(color: lightRed),
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
                  ? textOnRed
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
          selectedColor: Colors.orange[200],
          backgroundColor: Colors.white,
          side: BorderSide(color: lightRed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define red color palette
    const Color primaryRed = Color(0xFFD32F2F);
    const Color lightRed = Color(0xFFFF6659);
    const Color darkRed = Color(0xFF9A0007);
    const Color backgroundRed = Color(0xFFFFEBEE);
    const Color textOnRed = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estimasi TKD',
          style: TextStyle(
            color: textOnRed,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryRed,
        iconTheme: const IconThemeData(color: textOnRed),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      backgroundColor: backgroundRed,
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
                color: darkRed,
              ),
            ),
          ],
        ),
      )
          : LiquidPullToRefresh(
        onRefresh: _refreshData,
        color: primaryRed,
        backgroundColor: backgroundRed,
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
                        color: primaryRed,
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
                                color: darkRed,
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
                      color: primaryRed,
                    ),
                    trailing: const [
                      Icon(
                        Icons.arrow_drop_down,
                        color: primaryRed,
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
                        side: const BorderSide(color: lightRed),
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
                          color: darkRed,
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
                                  text: 'PS Code: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: fnDataMap[fn]?['psCode'] ?? '-',
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
                          color: darkRed,
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
                                  text: 'PS Code: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black
                                  ),
                                ),
                                TextSpan(
                                  text: entry.value['psCode'] ?? '-',
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
                      color: lightRed,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.tag,
                            color: primaryRed,
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
                                      color: primaryRed,
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
                            color: primaryRed,
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
                                      color: primaryRed,
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
                            color: primaryRed,
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
                                      color: primaryRed,
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
                            color: primaryRed,
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
                                    text: 'PS Code: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  TextSpan(
                                    text: selectedPsCode ?? 'Tidak tersedia',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryRed,
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
                  color: darkRed,
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
                              color: lightRed,
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
                            prefixIcon: const Icon(Icons.clear_rounded, color: primaryRed, size: 28),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: lightRed),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: lightRed),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: primaryRed,
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
                  side: BorderSide(color: lightRed, width: 1), // Add border
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
                          color: darkRed,
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
                              color: primaryRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryRed.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total Kebutuhan: $totalTKD Orang',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryRed,
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
    );
  }
}