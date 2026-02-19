// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PspHarvestListViewBuilder extends StatelessWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Function(String) onItemTap;

  const PspHarvestListViewBuilder({
    super.key,
    required this.filteredData,
    this.selectedRegion,
    required this.onItemTap,
  });

  // --- HELPER FUNCTIONS ---

  String getValue(List<String> row, int index, String defaultValue) {
    if (index >= 0 && index < row.length) {
      final val = row[index].trim();
      return val.isEmpty ? defaultValue : val;
    }
    return defaultValue;
  }

  int _calculateDAP(List<String> row) {
    try {
      final plantingDateStr = getValue(row, 12, ''); // Sheet Generative Index 12
      if (plantingDateStr.isEmpty || plantingDateStr.toLowerCase() == "unknown") return 0;
      late DateTime plantingDate;
      final excelSerial = double.tryParse(plantingDateStr);
      if (excelSerial != null) {
        plantingDate = DateTime(1899, 12, 30).add(Duration(days: excelSerial.round()));
      } else {
        try {
          plantingDate = DateFormat('dd/MM/yyyy').parse(plantingDateStr);
        } catch (_) {
          plantingDate = DateFormat('yyyy-MM-dd').parse(plantingDateStr);
        }
      }
      final today = DateTime.now();
      final date1 = DateTime(today.year, today.month, today.day);
      final date2 = DateTime(plantingDate.year, plantingDate.month, plantingDate.day);
      return date1.difference(date2).inDays;
    } catch (e) {
      return 0;
    }
  }

  String _formatPlantingDate(String dateStr) {
    if (dateStr.isEmpty || dateStr.toLowerCase() == "unknown") return "-";
    try {
      final parsedNumber = double.tryParse(dateStr);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.round()));
        return DateFormat('dd MMM yyyy').format(date);
      }
      final parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  // --- LOGIKA GDU ---
  double _calculateEstimatedGDU(int dap) {
    if (dap <= 0) return 0.0;
    // Vegetative: 0 - 50 DAP  --> GDU: 0 - 555.6
    // Generative: 51 - 79 DAP --> GDU: 555.6 - 922.2
    // Pre-Harvest: 80 - 99 DAP --> GDU: 922.2 - 1500.0
    // Harvest: > 100 DAP --> GDU > 1500.0

    if (dap <= 50) {
      return (dap / 50.0) * 555.6;
    } else if (dap <= 79) {
      double progress = (dap - 50) / 29.0;
      return 555.6 + (progress * (922.2 - 555.6));
    } else if (dap <= 99) {
      double progress = (dap - 79) / 20.0;
      return 922.2 + (progress * (1500.0 - 922.2));
    } else {
      // Logic sederhana untuk Harvest: tambah terus
      double progress = (dap - 99) / 10.0;
      return 1500.0 + (progress * 150.0);
    }
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

  // --- GOLD/AMBER THEME GRADIENT FOR HARVEST ---
  List<Color> _getDapGradient(int dap) {
    if (dap <= 90) return [Colors.orange.shade300, Colors.orange.shade500];
    if (dap <= 105) return [Colors.amber.shade600, Colors.amber.shade800];
    if (dap <= 115) return [Colors.orange.shade800, Colors.brown.shade700];
    return [Colors.brown.shade600, Colors.brown.shade900]; // Sangat Tua/Kering
  }

  // --- UI WIDGETS ---

  Widget _buildHeatUnitMetrics(double gdu, int dap) {
    final currentPhase = _getPhaseByGDU(gdu);

    // Di Screen Harvest, targetnya adalah Harvest.
    final bool isReadyHarvest = (currentPhase == 'Harvest');

    // Colors: Ready = Gold/Green, Not Ready = Grey/Orange
    final Color statusColor = isReadyHarvest
        ? Colors.amber.shade900
        : Colors.grey.shade600;

    final Color bgColor = isReadyHarvest
        ? Colors.amber.shade50
        : Colors.grey.shade100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: statusColor, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Harvest Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Phase Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isReadyHarvest ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Fase: $currentPhase',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // GDU Value Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: statusColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.thermostat_rounded, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'Accumulated',
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
                      gdu.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                // Progress Circular
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        // Target Harvest dimulai 1500. Jika > 1500, full 100%
                        value: (gdu / 1500.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: statusColor,
                        strokeWidth: 4,
                      ),
                    ),
                    if (isReadyHarvest)
                      Icon(Icons.check, size: 20, color: statusColor)
                    else
                      Text(
                        "${((gdu / 1500.0).clamp(0.0, 1.0) * 100).toInt()}%",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Warning Banner for Harvest
  Widget _buildPhaseWarningBanner(double gdu, int dap) {
    final currentPhase = _getPhaseByGDU(gdu);

    // Jika sudah Harvest, Tampilkan Info "Siap Panen"
    if (currentPhase == 'Harvest') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'FIELD READY FOR HARVEST ($dap DAP)',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Jika belum Harvest (Vegetative/Generative/Pre-Harvest)
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum mencapai GDU Harvest. ($dap DAP)',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (filteredData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text("No Data Found"),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: filteredData.length,
      itemBuilder: (context, index) {
        final row = filteredData[index];
        if (row.isEmpty) return const SizedBox.shrink();

        final dap = _calculateDAP(row);
        final dapGradient = _getDapGradient(dap);
        final fieldNumber = getValue(row, 2, "-");
        final farmerName = getValue(row, 4, "-");
        final effectiveArea = getValue(row, 10, "0");
        final plantingDateDisplay = _formatPlantingDate(getValue(row, 12, ""));
        final desa = getValue(row, 14, "-");
        final fieldSpv = getValue(row, 18, "-");
        final estimatedGdu = _calculateEstimatedGDU(dap);

        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 400 + (index % 5 * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, double val, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - val)),
              child: Opacity(opacity: val, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.shade900.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                splashColor: Colors.amber.withOpacity(0.1),
                onTap: () {
                  onItemTap(fieldNumber);
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // --- TOP INFO ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: dapGradient,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: dapGradient.first.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dap',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'DAP',
                                  style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fieldNumber,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_rounded, size: 14, color: Colors.amber.shade900),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        farmerName,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // --- GDU SECTION (HARVEST THEME) ---
                      _buildPhaseWarningBanner(estimatedGdu, dap),
                      _buildHeatUnitMetrics(estimatedGdu, dap),

                      const SizedBox(height: 16),

                      // Info Pills
                      Container(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildPremiumInfoPill(Icons.calendar_today_rounded, 'Planted', plantingDateDisplay, Colors.deepOrange.shade600, Colors.deepOrange.shade50),
                          const SizedBox(width: 10),
                          _buildPremiumInfoPill(Icons.aspect_ratio_rounded, 'Area', '$effectiveArea Ha', Colors.green.shade700, Colors.green.shade50),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildPremiumInfoPill(Icons.location_on_rounded, 'Loc', desa, Colors.brown.shade600, Colors.brown.shade50),
                          const SizedBox(width: 10),
                          _buildPremiumInfoPill(Icons.badge_rounded, 'SPV', fieldSpv, Colors.blueGrey.shade700, Colors.blueGrey.shade50),
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
    );
  }

  Widget _buildPremiumInfoPill(IconData icon, String label, String value, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.withOpacity(0.7))),
                  Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}