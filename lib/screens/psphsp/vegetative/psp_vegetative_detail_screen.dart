// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

import 'psp_visit1_screen.dart';
import 'psp_visit2_screen.dart';
import 'psp_visit3_screen.dart';
import 'psp_visit4_screen.dart';
import 'psp_visit5_screen.dart';
import 'psp_visit6_screen.dart';
import 'psp_visit7_screen.dart';


class PspVegetativeDetailScreen extends StatefulWidget {
  final String fieldNumber;
  final String region;

  const PspVegetativeDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  PspVegetativeDetailScreenState createState() => PspVegetativeDetailScreenState();
}

class PspVegetativeDetailScreenState extends State<PspVegetativeDetailScreen> with TickerProviderStateMixin {
  late final GoogleSheetsApi _googleSheetsApi;
  bool _isLoading = true;
  String? _errorMessage;
  List<String>? _fieldData;
  final _fabKey = GlobalKey<ExpandableFabState>();

  // Premium Theme Colors
  final Color _primaryPurple = Colors.purple.shade800;
  final Color _bgGradientTop = const Color(0xFFF3E5F5);
  final Color _bgGradientBottom = const Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    final spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? '';
    _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
    _fetchFieldDetails();
  }

  // Gradient colors untuk setiap visit
  List<Color> _getVisitGradient(int visitNum) {
    switch (visitNum) {
      case 1:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case 2:
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case 3:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case 4:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case 5:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case 6:
        return [const Color(0xFF30cfd0), const Color(0xFF330867)];
      case 7:
        return [const Color(0xFFa8edea), const Color(0xFFfed6e3)];
      default:
        return [Colors.grey, Colors.grey.shade600];
    }
  }

  Widget _buildVisitFAB(int visitNum, String label, IconData icon) {
    final gradientColors = _getVisitGradient(visitNum);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 3,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            _navigateToVisit(visitNum);
            // Auto-close FAB setelah navigasi
            final state = _fabKey.currentState;
            if (state != null && state.isOpen) {
              state.toggle();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visit $visitNum',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToVisit(int visitNumber) async {
    if (_fieldData == null) return;

    final spreadsheetId = ConfigManager.getSpreadsheetId(widget.region);
    if (spreadsheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Spreadsheet ID not found."))
      );
      return;
    }

    Widget targetScreen;
    switch (visitNumber) {
      case 1:
        targetScreen = PspVisit1Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
        break;
      case 2:
        targetScreen = PspVisit2Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
        break;
      case 3:
        targetScreen = PspVisit3Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
        break;
      case 4:
        targetScreen = PspVisit4Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
        break;
      case 5:
        targetScreen = PspVisit5Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
        break;
      case 6:
        targetScreen = PspVisit6Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
        break;
      case 7:
        targetScreen = PspVisit7Screen(spreadsheetId: spreadsheetId, fieldNumber: widget.fieldNumber, region: widget.region);
      default:
        return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );

    if (result == true) {
      _fetchFieldDetails();
    }
  }

  Future<void> _fetchFieldDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _googleSheetsApi.init();
      final allData = await _googleSheetsApi.getSpreadsheetDataWithPagination(
          'Vegetative', 1, 3000
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
          // Background Gradient
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

          // Decorative Blob
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.shade200.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(color: Colors.purple.shade300.withOpacity(0.2), blurRadius: 80, spreadRadius: 20),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
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
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryPurple, size: 20),
                        ),
                      ),
                      const Text(
                        "Field Details",
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
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 50, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  )
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
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Expandable FAB Configuration
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: ExpandableFab(
        key: _fabKey,
        type: ExpandableFabType.up,
        distance: 80,
        duration: const Duration(milliseconds: 400),

        // Overlay ketika FAB terbuka
        overlayStyle: ExpandableFabOverlayStyle(
          color: Colors.black.withOpacity(0.6),
          blur: 8,
        ),

        // Tombol utama (close state) - LEBIH BESAR
        openButtonBuilder: RotateFloatingActionButtonBuilder(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryPurple, Colors.purple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryPurple.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 34),
          ),
          fabSize: ExpandableFabSize.large,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
        ),

        // Tombol close (open state) - LEBIH BESAR
        closeButtonBuilder: DefaultFloatingActionButtonBuilder(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade400.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 34),
          ),
          fabSize: ExpandableFabSize.large,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
        ),

        // Children - Visit buttons
        children: [
          _buildVisitFAB(7, "Final", Icons.check_circle_rounded),
          _buildVisitFAB(6, "Phase", Icons.filter_6_rounded),
          _buildVisitFAB(5, "Phase", Icons.filter_5_rounded),
          _buildVisitFAB(4, "Phase", Icons.filter_4_rounded),
          _buildVisitFAB(3, "Phase", Icons.filter_3_rounded),
          _buildVisitFAB(2, "Phase", Icons.filter_2_rounded),
          _buildVisitFAB(1, "Initial", Icons.filter_1_rounded),
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
          colors: [_primaryPurple, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: _primaryPurple.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(Icons.grass_rounded, size: 150, color: Colors.white.withOpacity(0.1)),
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
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farmer,
                          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          grower,
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                        ),
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
        _buildStatCard("Planted", plantingDate, Icons.calendar_today_rounded, Colors.blue.shade600, Colors.blue.shade50),
        const SizedBox(width: 12),
        _buildStatCard("Area", "$area Ha", Icons.aspect_ratio_rounded, const Color(0xFF00BFA5), const Color(0xFFE0F2F1)),
        const SizedBox(width: 12),
        _buildStatCard("Week", week, Icons.date_range_rounded, Colors.orange.shade700, Colors.orange.shade50),
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
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
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
              Icon(icon, size: 18, color: _primaryPurple),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    letterSpacing: 1.0),
              ),
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
      _buildInfoTile("Village (Desa)", desa, Icons.home_work_rounded, Colors.indigo),
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1)),
      _buildInfoTile("District (Kecamatan)", kec, Icons.location_city_rounded, Colors.teal),
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1)),
      _buildInfoTile("Regency (Kabupaten)", kab, Icons.map_rounded, Colors.brown),
      Divider(height: 1, indent: 60, color: Colors.grey.withOpacity(0.1)),
      _buildInfoTile("Zone Area", zone, Icons.flag_rounded, Colors.redAccent),
    ];
  }

  List<Widget> _buildPersonnelList() {
    final fa = getValue(_fieldData!, 18, "-");
    return [
      _buildInfoTile("Field Assistant (FA)", fa, Icons.badge_rounded, Colors.purple),
    ];
  }

  Widget _buildInfoTile(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}