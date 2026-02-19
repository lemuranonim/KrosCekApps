// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class PspHarvestDetailScreen extends StatefulWidget {
  final String fieldNumber;
  final String region;

  const PspHarvestDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  PspHarvestDetailScreenState createState() => PspHarvestDetailScreenState();
}

class PspHarvestDetailScreenState extends State<PspHarvestDetailScreen> {
  late final GoogleSheetsApi _googleSheetsApi;
  bool _isLoading = true;
  String? _errorMessage;
  List<String>? _fieldData;

  // --- THEME COLORS: HARVEST (Gold / Amber / Deep Green) ---
  final Color _primaryColor = Colors.amber.shade800; // Warna Emas/Amber
  final Color _bgGradientTop = const Color(0xFFFFF8E1); // Amber 50
  final Color _bgGradientBottom = const Color(0xFFFAFAFA); // White

  @override
  void initState() {
    super.initState();
    final spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? '';
    _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
    _fetchFieldDetails();
  }

  Future<void> _fetchFieldDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _googleSheetsApi.init();
      // TARGET SHEET: GENERATIVE
      final allData = await _googleSheetsApi.getSpreadsheetDataWithPagination(
          'Generative', 1, 3000
      );

      final foundRow = allData.firstWhere(
            (row) => getValue(row, 2, '') == widget.fieldNumber,
        orElse: () => [],
      );

      setState(() {
        if (foundRow.isNotEmpty) {
          _fieldData = foundRow;
        } else {
          _errorMessage = "Data for Field ${widget.fieldNumber} not found.";
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading details: $e";
      });
    }
  }

  String getValue(List<String> row, int index, String defaultValue) {
    if (index >= 0 && index < row.length) {
      final val = row[index].trim();
      return val.isEmpty ? defaultValue : val;
    }
    return defaultValue;
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty || dateStr.toLowerCase() == "unknown") return "-";
    try {
      final excelSerial = double.tryParse(dateStr);
      if (excelSerial != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: excelSerial.round()));
        return DateFormat('dd MMM yyyy').format(date);
      }
      final parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateDAP(String dateStr) {
    if (dateStr.isEmpty || dateStr.toLowerCase() == "unknown") return 0;
    try {
      late DateTime plantingDate;
      final excelSerial = double.tryParse(dateStr);
      if (excelSerial != null) {
        plantingDate = DateTime(1899, 12, 30).add(Duration(days: excelSerial.round()));
      } else {
        try {
          plantingDate = DateFormat('dd/MM/yyyy').parse(dateStr);
        } catch (_) {
          plantingDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        }
      }
      final today = DateTime.now();
      final date1 = DateTime(today.year, today.month, today.day);
      final date2 = DateTime(plantingDate.year, plantingDate.month, plantingDate.day);
      return date1.difference(date2).inDays;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      ),
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgGradientTop, _bgGradientBottom],
                stops: const [0.0, 0.4],
              ),
            ),
          ),

          // 2. Decorative Blob (Gold)
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.shade200.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(color: Colors.amber.shade300.withOpacity(0.2), blurRadius: 80, spreadRadius: 20),
                ],
              ),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                // --- CUSTOM APP BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
                        ),
                      ),
                      const Text(
                        "Harvest Detail",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoading
                      ? Center(child: Lottie.asset('assets/loading.json', width: 150))
                      : _errorMessage != null
                      ? Center(child: Text(_errorMessage!))
                      : _fieldData == null
                      ? const Center(child: Text("No Data"))
                      : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildMainHeaderCard(),
                        const SizedBox(height: 24),
                        _buildStatsGrid(),
                        const SizedBox(height: 24),
                        _buildDetailSection("LOCATION INFO", Icons.map_rounded, _buildLocationList()),
                        const SizedBox(height: 20),
                        _buildDetailSection("PERSONNEL", Icons.people_alt_rounded, _buildPersonnelList()),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeaderCard() {
    final fieldNo = getValue(_fieldData!, 2, "-");
    final farmer = getValue(_fieldData!, 4, "-");
    final grower = getValue(_fieldData!, 5, "-");
    final plantingDateStr = getValue(_fieldData!, 12, "");
    final dap = _calculateDAP(plantingDateStr);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern (Truck/Agri)
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.agriculture_rounded, size: 150, color: Colors.white.withOpacity(0.1)),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        "$dap Days After Planting",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  fieldNo,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(farmer, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(grower, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final plantingDate = _formatDate(getValue(_fieldData!, 12, "-"));
    final area = getValue(_fieldData!, 10, "0");
    final week = getValue(_fieldData!, 40, "-");

    return Row(
      children: [
        _buildStatCard("Planted", plantingDate, Icons.calendar_today_rounded, Colors.deepOrange.shade600, Colors.deepOrange.shade50),
        const SizedBox(width: 12),
        _buildStatCard("Area", "$area Ha", Icons.aspect_ratio_rounded, Colors.green.shade700, Colors.green.shade50),
        const SizedBox(width: 12),
        _buildStatCard("Week", week, Icons.date_range_rounded, Colors.brown.shade700, Colors.brown.shade50),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _primaryColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey.shade600, letterSpacing: 1.0)),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
            ],
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  List<Widget> _buildLocationList() {
    final desa = getValue(_fieldData!, 14, "-");
    final kec = getValue(_fieldData!, 15, "-");
    final kab = getValue(_fieldData!, 16, "-");
    final zone = getValue(_fieldData!, 17, "-");

    return [
      _buildInfoTile("Village (Desa)", desa, Icons.home_work_rounded, Colors.amber.shade900),
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1)),
      _buildInfoTile("District (Kecamatan)", kec, Icons.location_city_rounded, Colors.brown.shade600),
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1)),
      _buildInfoTile("Regency (Kabupaten)", kab, Icons.map_rounded, Colors.orange.shade800),
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1)),
      _buildInfoTile("Zone Area", zone, Icons.flag_rounded, Colors.green.shade800),
    ];
  }

  List<Widget> _buildPersonnelList() {
    final fa = getValue(_fieldData!, 18, "-");
    return [
      _buildInfoTile("Field Assistant (FA)", fa, Icons.badge_rounded, Colors.blueGrey),
    ];
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}