import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'config_manager.dart';

class KalkulatorTKDPage extends StatefulWidget {
  final String selectedRegion;

  const KalkulatorTKDPage({super.key, required this.selectedRegion});

  @override
  KalkulatorTKDPageState createState() => KalkulatorTKDPageState();
}

class KalkulatorTKDPageState extends State<KalkulatorTKDPage> {
  List<String> fnList = [];
  List<String> farmerList = [];
  String? selectedFN;
  String? selectedFarmer;
  double luasLahan = 0.0;
  int tkdPerHektar = 15;
  int totalTKD = 0;
  bool isLoading = true;

  final Map<String, List<String>> fnToFarmersMap = {};
  final Map<String, double> fnToAreaMap = {};
  final SearchController _fnSearchController = SearchController();
  final TextEditingController _tkdController = TextEditingController(text: '15');

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
    // Reset semua state ke nilai awal
    setState(() {
      isLoading = true;
      selectedFN = fnList.isNotEmpty ? fnList.first : null;
      _updateFarmersForSelectedFN();
      luasLahan = selectedFN != null ? (fnToAreaMap[selectedFN] ?? 0.0) : 0.0;
      _tkdController.text = '15';
      tkdPerHektar = 15;
      totalTKD = 0;
    });

    // Muat ulang data dari spreadsheet
    await _loadDataFromSpreadsheet();
  }

  Future<void> _loadDataFromSpreadsheet() async {
    setState(() => isLoading = false);

    try {
      final String? spreadsheetId = ConfigManager.getSpreadsheetId(widget.selectedRegion);
      if (spreadsheetId == null) throw Exception("Spreadsheet ID not found");

      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData('Generative');

      fnList.clear();
      fnToFarmersMap.clear();
      fnToAreaMap.clear();

      for (int i = 1; i < data.length; i++) {
        final row = data[i];
        if (row.length >= 7) {
          final fn = row[2];
          final farmer = row[3];
          final area = double.tryParse(row[6].replaceAll(',', '.')) ?? 0.0;

          if (!fnToFarmersMap.containsKey(fn)) {
            fnToFarmersMap[fn] = [];
            fnList.add(fn);
          }

          if (!fnToFarmersMap[fn]!.contains(farmer)) {
            fnToFarmersMap[fn]!.add(farmer);
          }

          fnToAreaMap[fn] = area;
        }
      }

      setState(() {
        if (fnList.isNotEmpty) {
          selectedFN = fnList.first;
          _updateFarmersForSelectedFN();
          luasLahan = fnToAreaMap[selectedFN] ?? 0.0;
          isLoading = false;
        }
        _calculateTKD();
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateFarmersForSelectedFN() {
    if (selectedFN == null || !fnToFarmersMap.containsKey(selectedFN)) {
      farmerList = [];
      selectedFarmer = null;
      return;
    }

    farmerList = fnToFarmersMap[selectedFN]!;
    selectedFarmer = farmerList.isNotEmpty ? farmerList.first : null;
  }

  void _onFNChanged(String? newFN) {
    if (newFN == null) return;

    setState(() {
      selectedFN = newFN;
      _updateFarmersForSelectedFN();
      luasLahan = fnToAreaMap[newFN] ?? 0.0;
      _calculateTKD();
      _fnSearchController.closeView(newFN);
    });
  }

  void _calculateTKD() {
    setState(() {
      totalTKD = (luasLahan * tkdPerHektar).ceil();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estimasi TKD',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    body: isLoading
    ? Center(child: Lottie.asset('assets/loading.json'))
        : LiquidPullToRefresh(
    onRefresh: _refreshData,  // Menentukan fungsi untuk refresh
      color: Colors.green,
      backgroundColor: Colors.white,
      showChildOpacityTransition: true,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Region
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          ' ${widget.selectedRegion}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Searchable FN Dropdown
                SearchAnchor(
                  searchController: _fnSearchController,
                  builder: (BuildContext context, SearchController controller) {
                    return SearchBar(
                      controller: controller,
                      padding: const WidgetStatePropertyAll<EdgeInsets>(
                          EdgeInsets.symmetric(horizontal: 16.0)),
                      onTap: () => controller.openView(),
                      onChanged: (_) => controller.openView(),
                      leading: const Icon(Icons.search),
                      trailing: const [Icon(Icons.arrow_drop_down)],
                      hintText: 'Cari Field Number',
                      hintStyle: WidgetStateProperty.all(
                          const TextStyle(color: Colors.grey)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    );
                  },
                  suggestionsBuilder: (context, controller) {
                    final query = controller.text.toLowerCase();
                    return fnList.where((fn) => fn.toLowerCase().contains(query))
                        .map((fn) => ListTile(
                      title: Text(fn),
                      onTap: () => _onFNChanged(fn),
                    )).toList();
                  },
                ),
                const SizedBox(height: 16),

                // Current FN and Farmer Display
                if (selectedFN != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tag, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 16, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Field Number: '),
                                  TextSpan(
                                    text: selectedFN!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 16, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Farmer: '),
                                  TextSpan(
                                    text: selectedFarmer ?? 'Tidak tersedia',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Calculation Input Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Luas Lahan
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Luas Lahan (Ha)',
                          labelStyle: const TextStyle(color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                        readOnly: true,
                        controller: TextEditingController(
                          text: NumberFormat("#,##0.00").format(luasLahan),
                        ),
                      ),
                    ),

                    // ×
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        '×',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                    ),

                    // TKD/Ha
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _tkdController,
                        decoration: InputDecoration(
                          labelText: 'TKD/Ha',
                          labelStyle: const TextStyle(color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final newValue = int.tryParse(value) ?? 0;
                          setState(() {
                            tkdPerHektar = newValue;
                            _calculateTKD();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Results Card
                Card(
                  elevation: 4,
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Estimasi Kebutuhan TKD',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              NumberFormat("#,##0.00").format(luasLahan),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text('×', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              tkdPerHektar.toString(),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            const Text('=', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              totalTKD.toString(),
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Kebutuhan TKD: $totalTKD Orang',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
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