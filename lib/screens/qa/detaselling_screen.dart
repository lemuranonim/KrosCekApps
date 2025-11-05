import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _currentSearchFilter = 'Field Number';

  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF81C784);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color backgroundGreen = Color(0xFFE8F5E9);

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
        if (row.length >= 11) {
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightGreen.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip('Field Number', Icons.tag_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip('Petani', Icons.person_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _currentSearchFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _currentSearchFilter = label;
          _fnSearchController.text = '';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [primaryGreen, darkGreen],
          )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundGreen,
        body: isLoading
            ? Container(
          color: Colors.white,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.white.withAlpha(204),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/loading.json',
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          primaryGreen,
                          darkGreen,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Ngrantos sekedap...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
            : LiquidPullToRefresh(
          onRefresh: _refreshData,
          color: primaryGreen,
          backgroundColor: backgroundGreen,
          height: 120,
          animSpeedFactor: 1.5,
          showChildOpacityTransition: true,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Enhanced App Bar
              SliverAppBar(
                expandedHeight: 140,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: _navigateBackToHome,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryGreen,
                          darkGreen,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(70, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(51),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calculate_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Estimasi TKD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Hitung kebutuhan tenaga kerja',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Content dalam Sliver
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Region Card
                    _buildInfoCard(
                      icon: Icons.location_on_rounded,
                      title: 'Lokasi',
                      value: widget.selectedRegion,
                      gradient: [primaryGreen, darkGreen],
                    ),
                    const SizedBox(height: 20),

                    // Search Filter Chips
                    _buildSearchFilterChips(),
                    const SizedBox(height: 16),

                    // Enhanced Search Bar
                    _buildEnhancedSearchBar(),
                    const SizedBox(height: 24),

                    // Selected Field Details
                    if (selectedFN != null) ...[
                      _buildFieldDetailsCard(),
                      const SizedBox(height: 24),
                    ],

                    // Calculation Section
                    _buildCalculationSection(),
                    const SizedBox(height: 24),

                    // Results Card
                    _buildResultsCard(),

                    // Extra padding at bottom
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withAlpha(76),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSearchBar() {
    return SearchAnchor(
      searchController: _fnSearchController,
      builder: (BuildContext context, SearchController controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lightGreen.withAlpha(100), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SearchBar(
            controller: controller,
            padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onTap: () => controller.openView(),
            onChanged: (_) => controller.openView(),
            leading: Icon(Icons.search_rounded, color: primaryGreen, size: 24),
            trailing: [
              Icon(Icons.arrow_drop_down_rounded, color: primaryGreen, size: 28),
            ],
            hintText: 'Cari $_currentSearchFilter',
            hintStyle: WidgetStateProperty.all(
              TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
            backgroundColor: WidgetStateProperty.all(Colors.white),
            elevation: const WidgetStatePropertyAll(0),
          ),
        );
      },
      suggestionsBuilder: (context, controller) {
        final query = controller.text.toLowerCase();

        if (_currentSearchFilter == 'Field Number') {
          return fnList
              .where((fn) => fn.toLowerCase().contains(query))
              .map((fn) => _buildSearchSuggestion(fn, fnDataMap[fn]!, true))
              .toList();
        } else {
          return fnDataMap.entries
              .expand((entry) => (entry.value['farmers'] as List<String>)
              .where((farmer) => farmer.toLowerCase().contains(query))
              .map((farmer) => _buildSearchSuggestion(
            farmer,
            entry.value,
            false,
            fieldNumber: entry.key,
          )))
              .toList();
        }
      },
    );
  }

  Widget _buildSearchSuggestion(
      String title,
      Map<String, dynamic> data,
      bool isFieldNumber, {
        String? fieldNumber,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightGreen.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryGreen, darkGreen]),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isFieldNumber ? Icons.tag_rounded : Icons.person_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: darkGreen,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            if (!isFieldNumber)
              _buildDetailRow('Field', fieldNumber ?? '-'),
            _buildDetailRow(
              'Petani',
              isFieldNumber ? data['farmers']?.join(', ') ?? '-' : title,
            ),
            _buildDetailRow('Desa', data['village'] ?? '-'),
            _buildDetailRow('Hybrid', data['hybrid'] ?? '-'),
            _buildDetailRow('Luas', '${data['area']?.toStringAsFixed(2) ?? '-'} Ha'),
          ],
        ),
        onTap: () {
          if (isFieldNumber) {
            _onFNChanged(title);
          } else {
            _onFNChanged(fieldNumber);
            setState(() => selectedFarmer = title);
          }
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightGreen.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withAlpha(15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryGreen, darkGreen]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Detail Field',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFieldDetailItem(Icons.tag_rounded, 'Field Number', selectedFN ?? '-'),
          _buildFieldDetailItem(Icons.person_rounded, 'Farmer', selectedFarmer ?? '-'),
          _buildFieldDetailItem(Icons.home_rounded, 'Desa', selectedVillage ?? '-'),
          _buildFieldDetailItem(Icons.grass_rounded, 'Hybrid', selectedHybrid ?? '-'),
        ],
      ),
    );
  }

  Widget _buildFieldDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryGreen.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(30),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Parameter Perhitungan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Luas Lahan (Ha)',
                  value: NumberFormat("#,##0.00").format(luasLahan),
                  icon: Icons.landscape_rounded,
                  isReadOnly: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: 'TKD/Ha',
                  controller: _tkdController,
                  icon: Icons.people_rounded,
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
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    String? value,
    TextEditingController? controller,
    required IconData icon,
    bool isReadOnly = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: isReadOnly
              ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          )
              : TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.blue.shade600, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGreen, darkGreen],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withAlpha(100),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ESTIMASI KEBUTUHAN TKD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),

          // Formula Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withAlpha(76),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFormulaItem(NumberFormat("#,##0.00").format(luasLahan)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                _buildFormulaItem(tkdPerHektar.toString()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '=',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                _buildFormulaItem(
                  totalTKD.toString(),
                  isResult: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Final Result Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_rounded,
                  color: primaryGreen,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Kebutuhan',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalTKD Orang',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info Text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withAlpha(204),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimasi berdasarkan data terkini',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(204),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaItem(String value, {bool isResult = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isResult ? 16 : 12,
        vertical: isResult ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: isResult
            ? Colors.white
            : Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isResult
              ? Colors.white
              : Colors.white.withAlpha(76),
          width: isResult ? 2 : 1,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: isResult ? 20 : 16,
          fontWeight: FontWeight.bold,
          color: isResult ? primaryGreen : Colors.white,
        ),
      ),
    );
  }
}