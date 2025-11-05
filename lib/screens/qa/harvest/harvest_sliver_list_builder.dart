import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'harvest_detail_screen.dart';
import '../../gdu/heat_unit_service.dart';
import '../../gdu/premium_gdu_screen.dart';

import 'package:flutter/services.dart'; // ✅ Untuk HapticFeedback
import '../../services/config_manager.dart'; // ✅ Import ConfigManager
import '../pre_harvest/pre_harvest_screen.dart'; // ✅ Import Pre Harvest Screen
import '../generative/generative_screen.dart'; // ✅ Import Generative Screen
import '../vegetative/vegetative_screen.dart'; // ✅ Import Vegetative Screen

class HarvestSliverListBuilder extends StatefulWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Function(String) onItemTap;
  final Map<String, int> activityCounts;
  final String? selectedQA; // 🆕 Selected QA dari parent
  final String? selectedSeason; // 🆕 Selected Season dari parent
  final List<String> seasonList; // 🆕 Daftar season untuk navigasi

  const HarvestSliverListBuilder({
    super.key,
    required this.filteredData,
    this.selectedRegion,
    required this.onItemTap,
    this.activityCounts = const {},
    this.selectedQA, // 🆕
    this.selectedSeason, // 🆕
    this.seasonList = const [], // 🆕
  });

  @override
  State<HarvestSliverListBuilder> createState() => _HarvestSliverListBuilderState();
}

class _HarvestSliverListBuilderState extends State<HarvestSliverListBuilder> {
  final HeatUnitService _heatUnitService = HeatUnitService();
  final Map<String, HeatUnitData> _heatUnitCache = {};
  final Map<String, Future<HeatUnitData>> _futureCache = {};

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  String getValue(List<String> row, int index, String defaultValue) {
    if (index < row.length) {
      return row[index];
    }
    return defaultValue;
  }

  int _calculateDAP(List<String> row) {
    try {
      final plantingDate = getValue(row, 9, '');
      if (plantingDate.isEmpty) return 0;

      final parsedDate = DateFormat('dd/MM/yyyy').parse(_convertToDateIfNecessary(plantingDate));
      final today = DateTime.now();
      return today.difference(parsedDate).inDays;
    } catch (e) {
      return 0;
    }
  }

  DateTime? _getPlantingDateTime(List<String> row) {
    try {
      final plantingDate = getValue(row, 9, '');
      if (plantingDate.isEmpty) return null;
      return DateFormat('dd/MM/yyyy').parse(_convertToDateIfNecessary(plantingDate));
    } catch (e) {
      return null;
    }
  }

  String _convertToDateIfNecessary(String value) {
    try {
      final parsedNumber = double.tryParse(value);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return value;
  }

  String _formatPlantingDate(String dateStr) {
    try {
      final parsedNumber = double.tryParse(dateStr);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd MMM yyyy').format(date);
      }

      final parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getDapColor(int dap) {
    if (dap <= 70) return Colors.lightGreen;
    if (dap <= 80) return Colors.lime;
    if (dap <= 90) return Colors.amber;
    if (dap <= 100) return Colors.orange;
    return Colors.red;
  }

  Map<String, double?>? _parseCoordinate(String coordinateString) {
    if (coordinateString.isEmpty) return null;

    try {
      final parts = coordinateString.split(',');
      if (parts.length < 2) return null;

      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());

      if (lat == null || lon == null) return null;
      if (lat < -90 || lat > 90) return null;
      if (lon < -180 || lon > 180) return null;

      return {'latitude': lat, 'longitude': lon};
    } catch (e) {
      debugPrint('Error parsing coordinate: $coordinateString - $e');
      return null;
    }
  }

  // ============================================================================
  // 🆕 FUNGSI CEK FASE BERDASARKAN DAP (UNTUK HARVEST)
  // ============================================================================

  String _getCurrentMainPhase(int dap) {
    if (dap >= 0 && dap <= 50) {
      return 'Vegetative';
    } else if (dap >= 51 && dap <= 79) {
      return 'Generative';
    } else if (dap >= 80 && dap <= 99) {
      return 'Pre-Harvest';
    } else {
      return 'Harvest';
    }
  }

  bool _isCorrectPhase(int dap) {
    return dap >= 100; // Untuk harvest screen
  }

  String _getPhaseByGDU(double gdu) {
    if (gdu < 555.6) {
      return 'Vegetative';
    } else if (gdu < 922.2) {
      return 'Generative';
    } else if (gdu < 1500.0) {
      return 'Pre-Harvest';
    } else {
      return 'Harvest';
    }
  }

  // ============================================================================
  // UI COMPONENTS
  // ============================================================================

  Widget _buildPhaseWarningBanner(String currentPhase, int currentDAP, double currentGDU, List<String> row) {
    if (currentPhase == 'Harvest') {
      return const SizedBox.shrink();
    }

    IconData icon;
    Color color;
    String message;
    String buttonText;
    final plantingDateTime = _getPlantingDateTime(row);
    final phaseByGDU = _getPhaseByGDU(currentGDU);
    final isSynced = currentPhase == phaseByGDU;
    final selectedRegion = widget.selectedRegion;
    final spreadsheetId = selectedRegion != null
        ? ConfigManager.getSpreadsheetId(selectedRegion)
        : null;
    final selectedQA = widget.selectedQA ?? getValue(row, 30, "Unknown"); // Kolom 30 = QA SPV
    final selectedDistrict = getValue(row, 13, "Unknown"); // Kolom 13 = District/Kabupaten
    final selectedSeason = widget.selectedSeason;
    final seasonList = widget.seasonList;

    // Cek apakah masih di fase sebelumnya
    if (currentPhase == 'Vegetative') {
      icon = Icons.eco;
      color = Colors.green.shade700;
      message = 'ℹ️ Tanaman masih dalam Fase Vegetative ($currentDAP DAP). Tanaman belum siap panen, pertimbangkan untuk memindahkan ke monitoring Vegetative.';
      buttonText = 'Pindah ke Vegetative';
    } else if (currentPhase == 'Generative') {
      icon = Icons.local_florist;
      color = Colors.amber.shade700;
      message = 'ℹ️ Tanaman masih dalam Fase Generative ($currentDAP DAP). Tanaman belum siap panen, pertimbangkan untuk memindahkan ke monitoring Generative.';
      buttonText = 'Pindah ke Generative';
    } else if (currentPhase == 'Pre-Harvest') {
      icon = Icons.grain;
      color = Colors.orange.shade700;
      message = 'ℹ️ Tanaman masih dalam Fase Pre-Harvest ($currentDAP DAP). Tanaman hampir siap panen, pertimbangkan untuk memindahkan ke monitoring Pre-Harvest.';
      buttonText = 'Pindah ke Pre-Harvest';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(51), color.withAlpha(25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(102), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(38),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fase: $currentPhase',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: color.withAlpha(229),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    if (!isSynced) ...[
                      const SizedBox(height: 4),
                      Text(
                        '📊 GDU menunjukkan: $phaseByGDU (${currentGDU.toStringAsFixed(0)}°C)',
                        style: TextStyle(
                          color: color.withAlpha(204),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 🆕 Tombol Navigasi
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withAlpha(204)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(76),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  HapticFeedback.mediumImpact();

                  // Validasi data
                  if (plantingDateTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.warning_amber, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Data tanggal tanam tidak tersedia',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }

                  if (spreadsheetId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.warning_amber, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Spreadsheet ID tidak ditemukan untuk region ini',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    return;
                  }

                  // ✅ SIMPAN context sebelum async gap
                  final navigator = Navigator.of(context);

                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => PopScope(
                      canPop: false,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Colors.green.shade700),
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Memuat data fase...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mohon tunggu sebentar',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 300));

                  if (!mounted) return;

                  Widget targetScreen;

                  // ✅ DEBUG: Print parameter
                  debugPrint('\n🚀 Navigating from Generative to $currentPhase:');
                  debugPrint('   spreadsheetId: $spreadsheetId');
                  debugPrint('   selectedDistrict: $selectedDistrict');
                  debugPrint('   selectedQA: $selectedQA');
                  debugPrint('   selectedSeason: $selectedSeason\n');

                  switch (currentPhase) {
                    case 'Vegetative':
                      targetScreen = VegetativeScreen(
                        spreadsheetId: spreadsheetId,
                        selectedDistrict: selectedDistrict, // ✅ Sekarang sudah benar
                        selectedQA: selectedQA,
                        selectedSeason: selectedSeason,
                        region: selectedRegion ?? 'Unknown Region',
                        seasonList: seasonList,
                      );
                      break;
                    case 'Generative':
                      targetScreen = GenerativeScreen(
                        spreadsheetId: spreadsheetId,
                        selectedDistrict: selectedDistrict, // ✅ Sekarang sudah benar
                        selectedQA: selectedQA,
                        selectedSeason: selectedSeason,
                        region: selectedRegion ?? 'Unknown Region',
                        seasonList: seasonList,
                      );
                      break;
                    case 'Pre-Harvest':
                      targetScreen = PreHarvestScreen(
                        spreadsheetId: spreadsheetId,
                        selectedDistrict: selectedDistrict,
                        selectedQA: selectedQA,
                        selectedSeason: selectedSeason,
                        region: selectedRegion ?? 'Unknown Region',
                        seasonList: seasonList,
                      );
                      break;

                    default:
                      navigator.pop(); // Close loading
                      return;
                  }

                  navigator.pop(); // Close loading
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => targetScreen,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestStatusWidget(DateTime? estimatedHarvestDate, int currentDAP, double currentGDU) {
    // 🆕 Cek berdasarkan DAP terlebih dahulu
    if (currentDAP >= 100) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade800],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade900),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(76),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.celebration, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: Siap Panen',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tanaman telah mencapai umur panen ($currentDAP DAP)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withAlpha(229),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (estimatedHarvestDate == null) {
      return const SizedBox.shrink();
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final harvestDay = DateUtils.dateOnly(estimatedHarvestDate);

    final bool hasHarvestPassed = harvestDay.isBefore(today);
    final int daysDifference = harvestDay.difference(today).inDays;
    final String formattedDate = DateFormat('dd MMM yyyy').format(estimatedHarvestDate);

    String title;
    String subtitle;
    Color color;
    Color lightColor;
    IconData icon;

    if (hasHarvestPassed) {
      title = 'Seharusnya Panen';
      subtitle = '${daysDifference.abs()} hari yang lalu';
      color = Colors.brown.shade800;
      lightColor = Colors.brown.shade50;
      icon = Icons.agriculture;
    } else {
      title = 'Estimasi Panen';
      color = Colors.amber.shade800;
      lightColor = Colors.amber.shade50;
      icon = Icons.event_available;

      if (daysDifference == 0) {
        subtitle = 'Hari ini!';
      } else if (daysDifference == 1) {
        subtitle = 'Besok!';
      } else {
        subtitle = 'Dalam $daysDifference hari';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: $formattedDate',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withAlpha(204),
                    fontWeight: FontWeight.w500,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // HEAT UNIT WIDGET
  // ============================================================================

  Widget _buildHeatUnitMetrics(
      String fieldNumber,
      double? latitude,
      double? longitude,
      DateTime? plantingDate,
      int dap,
      List<String> row,
      ) {
    final cachedFuture = _futureCache.putIfAbsent(
      fieldNumber,
          () => _fetchHeatUnitData(fieldNumber, latitude, longitude, plantingDate),
    );

    return FutureBuilder<HeatUnitData>(
      future: cachedFuture,
      builder: (context, snapshot) {
        final heatUnitData = snapshot.data ?? HeatUnitData.empty();
        final gduStatus = heatUnitData.gduStatus;
        final chuStatus = heatUnitData.chuStatus;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // 🆕 GUNAKAN DAP sebagai acuan utama
        final currentMainPhase = _getCurrentMainPhase(dap);
        final isCorrectPhase = _isCorrectPhase(dap);
        final isOutOfPhase = !isCorrectPhase;

        return Column(
          children: [
            if (isOutOfPhase && !isLoading)
              _buildPhaseWarningBanner(currentMainPhase, dap, heatUnitData.gdu, row),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown.shade50, Colors.amber.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.brown.shade200,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          heatUnitData.isEstimated ? 'Heat Unit (Estimasi)' : 'Heat Unit (Real-time)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOutOfPhase ? Colors.orange.shade100 : Colors.brown.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOutOfPhase ? Colors.orange.shade300 : Colors.brown.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOutOfPhase ? Icons.warning_amber : Icons.agriculture,
                          size: 14,
                          color: isOutOfPhase ? Colors.orange.shade700 : Colors.brown.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Fase: $currentMainPhase ($dap DAP)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOutOfPhase ? Colors.orange.shade700 : Colors.brown.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (gduStatus['color'] as Color).withAlpha(102),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.thermostat, color: gduStatus['color'], size: 16),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'GDU',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                heatUnitData.gdu.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: gduStatus['color'],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(gduStatus['icon'], size: 12, color: gduStatus['color']),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      gduStatus['status'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: gduStatus['color'],
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (chuStatus['color'] as Color).withAlpha(102),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.wb_incandescent, color: chuStatus['color'], size: 16),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'CHU',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                heatUnitData.chu.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: chuStatus['color'],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: (chuStatus['percentage'] / 100).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: chuStatus['color'],
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      chuStatus['status'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: chuStatus['color'],
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (heatUnitData.alert != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              heatUnitData.alert!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 12, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              gduStatus['description'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildHarvestStatusWidget(heatUnitData.estimatedHarvestDate, dap, heatUnitData.gdu),

                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.brown.shade400, Colors.amber.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.brown.withAlpha(76),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (latitude != null && longitude != null && plantingDate != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GDUMonitoringPage(
                                  latitude: latitude,
                                  longitude: longitude,
                                  plantingDate: plantingDate,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.warning_amber, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Data koordinat atau tanggal tanam tidak tersedia',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.orange.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Lihat Detail GDU & CHU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // FETCH HEAT UNIT DATA
  // ============================================================================

  Future<HeatUnitData> _fetchHeatUnitData(
      String fieldNumber,
      double? latitude,
      double? longitude,
      DateTime? plantingDate,
      ) async {
    if (_heatUnitCache.containsKey(fieldNumber)) {
      return _heatUnitCache[fieldNumber]!;
    }

    if (plantingDate == null) {
      return HeatUnitData.empty();
    }

    final int dap = DateTime.now().difference(plantingDate).inDays;

    try {
      final result = await _heatUnitService.fetchHistoricalHeatUnits(
        latitude: latitude ?? 0.0,
        longitude: longitude ?? 0.0,
        plantingDate: plantingDate,
      );

      final gdu = result['gdu'] ?? 0.0;
      final chu = result['chu'] ?? 0.0;

      final heatUnitData = HeatUnitData(
        gdu: gdu,
        chu: chu,
        gduStatus: _heatUnitService.getGDUStatus(gdu, dap),
        chuStatus: _heatUnitService.getCHUStatus(chu, dap),
        alert: _heatUnitService.checkHeatUnitAlert(gdu, chu, dap),
        estimatedHarvestDate: _heatUnitService.estimateHarvestDate(plantingDate, gdu, dap),
      );

      _heatUnitCache[fieldNumber] = heatUnitData;
      return heatUnitData;

    } catch (e) {
      debugPrint("Error tak terduga di builder saat fetch heat unit: $e");
      return HeatUnitData.empty();
    }
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final row = widget.filteredData[index];
          final isAudited = getValue(row, 43, "NOT Audited") == "Audited";
          final dap = _calculateDAP(row);
          final fieldNumber = getValue(row, 2, "Unknown");
          final farmerName = getValue(row, 3, "Unknown");
          final growerName = getValue(row, 4, "Unknown");
          final hybrid = getValue(row, 5, "Unknown");
          final effectiveArea = getValue(row, 8, "0");
          final rawPlantingDate = getValue(row, 9, "Unknown");
          final plantingDate = _formatPlantingDate(rawPlantingDate);
          final plantingDateTime = _getPlantingDateTime(row);
          final desa = getValue(row, 11, "Unknown");
          final kecamatan = getValue(row, 12, "Unknown");
          final kabupaten = getValue(row, 13, "Unknown");
          final fa = getValue(row, 14, "Unknown");
          final fieldSpv = getValue(row, 15, "Unknown");
          final weekOfHarvest = getValue(row, 27, "Unknown");
          final fi = getValue(row, 29, "Unknown");

          final coordinateString = getValue(row, 16, '');
          final coordinate = _parseCoordinate(coordinateString);
          final latitude = coordinate?['latitude'];
          final longitude = coordinate?['longitude'];

          final activityCount = widget.activityCounts[fieldNumber] ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAudited
                      ? [Colors.white, Colors.green.shade50]
                      : [Colors.white, Colors.red.shade50],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isAudited
                        ? Colors.green.withAlpha(25)
                        : Colors.red.withAlpha(25),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: isAudited
                      ? Colors.green.withAlpha(102)
                      : Colors.red.withAlpha(102),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => HarvestDetailScreen(
                          fieldNumber: fieldNumber,
                          region: widget.selectedRegion ?? 'Unknown Region',
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Hero(
                                    tag: 'harvest_$fieldNumber',
                                    child: Image.asset(
                                      'assets/harvest.png',
                                      height: 40,
                                      width: 40,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getDapColor(dap),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$dap DAP',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fieldNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isAudited
                                                ? [Colors.green.shade400, Colors.green.shade600]
                                                : [Colors.red.shade400, Colors.red.shade600],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isAudited
                                                  ? Colors.green.withAlpha(60)
                                                  : Colors.red.withAlpha(60),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isAudited
                                                  ? Icons.check_circle
                                                  : Icons.pending,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAudited ? "Sampun" : "Dereng",
                                              style: const TextStyle(
                                                fontFamily: 'Manrope',
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: RichText(
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Farmer: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              TextSpan(text: farmerName),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Grower: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              TextSpan(text: growerName),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: RichText(
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Hybrid: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              TextSpan(text: hybrid),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: RichText(
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Area: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              TextSpan(text: '$effectiveArea Ha'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        _buildHeatUnitMetrics(
                          fieldNumber,
                          latitude,
                          longitude,
                          plantingDateTime,
                          dap,
                          row,
                        ),

                        const SizedBox(height: 12),

                        Container(
                          height: 1,
                          color: isAudited
                              ? Colors.green.withAlpha(51)
                              : Colors.red.withAlpha(51),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Location & Planting',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(
                                    icon: Icons.calendar_today,
                                    label: 'Planted',
                                    value: plantingDate,
                                    iconColor: Colors.green,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(
                                    icon: Icons.location_on,
                                    label: 'Desa',
                                    value: desa,
                                    iconColor: Colors.green,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(
                                    icon: Icons.location_city,
                                    label: 'Kec',
                                    value: kecamatan,
                                    iconColor: Colors.green,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(
                                    icon: Icons.map,
                                    label: 'Kab',
                                    value: kabupaten,
                                    iconColor: Colors.green,
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Personnel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildInfoRow(
                                    icon: Icons.person,
                                    label: 'F.SPV',
                                    value: fieldSpv,
                                    iconColor: Colors.blue,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(
                                    icon: Icons.people,
                                    label: 'FA',
                                    value: fa,
                                    iconColor: Colors.blue,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(
                                    icon: Icons.people,
                                    label: 'FI',
                                    value: fi,
                                    iconColor: Colors.blue,
                                  ),
                                  const SizedBox(height: 2),
                                  _buildInfoRow(
                                    icon: Icons.calendar_month,
                                    label: 'Week',
                                    value: weekOfHarvest,
                                    iconColor: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: activityCount == 0
                                      ? [Colors.red.shade50, Colors.red.shade100]
                                      : (activityCount < 2
                                      ? [Colors.orange.shade50, Colors.orange.shade100]
                                      : [Colors.green.shade50, Colors.green.shade100]),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: activityCount == 0
                                      ? Colors.red.shade200
                                      : (activityCount < 2 ? Colors.orange.shade200 : Colors.green.shade200),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activityCount == 0
                                        ? Icons.history_toggle_off
                                        : (activityCount < 2 ? Icons.history : Icons.history_edu),
                                    color: activityCount == 0
                                        ? Colors.red.shade700
                                        : (activityCount < 2 ? Colors.orange.shade700 : Colors.green.shade700),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    activityCount == 0 ? 'Not Visited' : 'Visited $activityCount kali',
                                    style: TextStyle(
                                      color: activityCount == 0
                                          ? Colors.red.shade700
                                          : (activityCount < 2 ? Colors.orange.shade700 : Colors.green.shade700),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isAudited
                                      ? [Colors.green.shade400, Colors.green.shade600]
                                      : [Colors.red.shade400, Colors.red.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: isAudited
                                        ? Colors.green.withAlpha(60)
                                        : Colors.red.withAlpha(60),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    widget.onItemTap(fieldNumber);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.visibility, size: 16, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'View Details',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
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
                ),
              ),
            ),
          );
        },
        childCount: widget.filteredData.length,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
      ),
    );
  }

  @override
  void dispose() {
    _heatUnitCache.clear();
    _futureCache.clear();
    super.dispose();
  }
}