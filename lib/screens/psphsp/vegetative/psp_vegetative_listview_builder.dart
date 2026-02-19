// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PspVegetativeListViewBuilder extends StatelessWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Function(String) onItemTap;

  const PspVegetativeListViewBuilder({
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
      final plantingDateStr = getValue(row, 12, ''); // Pastikan index kolom Tgl Tanam benar (biasanya 12 atau 9)
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

  // --- LOGIKA GDU (Disinkronkan dengan QA Division) ---

  // 1. Hitung Estimasi GDU berdasarkan DAP (Interpolasi Linear)
  double _calculateEstimatedGDU(int dap) {
    if (dap <= 0) return 0.0;

    // Referensi Batas Fase dari File QA:
    // Vegetative: 0 - 50 DAP  --> Target GDU: 0 - 555.6
    // Generative: 51 - 79 DAP --> Target GDU: 555.6 - 922.2
    // Pre-Harvest: 80 - 99 DAP --> Target GDU: 922.2 - 1500.0

    if (dap <= 50) {
      // Fase Vegetative
      // Rumus: (DAP / 50) * 555.6
      return (dap / 50.0) * 555.6;
    } else if (dap <= 79) {
      // Fase Generative
      // Rumus: 555.6 + ((DAP - 50) / 29) * (922.2 - 555.6)
      double progress = (dap - 50) / 29.0;
      return 555.6 + (progress * (922.2 - 555.6));
    } else {
      // Fase Pre-Harvest / Harvest
      // Rumus: 922.2 + ((DAP - 79) / 20) * (1500.0 - 922.2)
      double progress = (dap - 79) / 20.0;
      return 922.2 + (progress * (1500.0 - 922.2));
    }
  }

  // 2. Tentukan Fase berdasarkan GDU (Logic QA)
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

  // Gradient Colors for DAP Badge
  List<Color> _getDapGradient(int dap) {
    if (dap <= 0) return [Colors.grey.shade400, Colors.grey.shade600];
    if (dap <= 40) return [Colors.lightGreen.shade400, Colors.lightGreen.shade700];
    if (dap <= 60) return [Colors.green.shade400, Colors.green.shade700];
    if (dap <= 90) return [Colors.orange.shade400, Colors.orange.shade700];
    return [Colors.red.shade400, Colors.red.shade700];
  }

  // --- WIDGET COMPONENTS ---

  // 1. Heat Unit Metrics Widget (Kotak GDU)
  Widget _buildHeatUnitMetrics(double gdu, int dap) {
    final currentPhase = _getPhaseByGDU(gdu);
    // Warning jika fase BUKAN Vegetative (karena ini screen Vegetative)
    final isOutOfPhase = currentPhase != 'Vegetative';

    final Color statusColor = isOutOfPhase ? Colors.orange.shade700 : Colors.purple.shade700;
    final Color bgColor = isOutOfPhase ? Colors.orange.shade50 : Colors.purple.shade50;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, Colors.blue.shade50],
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
              Icon(Icons.wb_sunny_rounded, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Heat Unit (Estimasi)', // Ditandai Estimasi
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
              color: isOutOfPhase ? Colors.orange.shade100 : Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isOutOfPhase ? Colors.orange.shade300 : Colors.green.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOutOfPhase ? Icons.warning_amber_rounded : Icons.eco_rounded,
                  size: 14,
                  color: isOutOfPhase ? Colors.orange.shade700 : Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Fase: $currentPhase',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOutOfPhase ? Colors.orange.shade700 : Colors.green.shade700,
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
                // Progress Circular Simple
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        // 922 adalah target Generative, jadi kalau lewat itu progress > 100%
                        value: (gdu / 922.2).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: statusColor,
                        strokeWidth: 4,
                      ),
                    ),
                    Text(
                      "${((gdu / 922.2).clamp(0.0, 1.0) * 100).toInt()}%",
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

  // 2. Warning Banner
  Widget _buildPhaseWarningBanner(double gdu, int dap) {
    final currentPhase = _getPhaseByGDU(gdu);

    if (currentPhase == 'Vegetative') {
      return const SizedBox.shrink();
    }

    String message = '';
    Color color = Colors.orange.shade700;
    IconData icon = Icons.warning_rounded;

    if (currentPhase == 'Generative') {
      message = 'Tanaman memasuki Fase Generative! ($dap DAP)';
      icon = Icons.energy_savings_leaf_rounded;
    } else if (currentPhase == 'Pre-Harvest') {
      message = 'Tanaman memasuki Fase Pre-Harvest! ($dap DAP)';
      color = Colors.red.shade700;
      icon = Icons.grain_rounded;
    } else {
      message = 'Tanaman sudah siap Harvest! ($dap DAP)';
      color = Colors.brown.shade700;
      icon = Icons.agriculture_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                "No Data Found",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      itemCount: filteredData.length,
      itemBuilder: (context, index) {
        final row = filteredData[index];
        if (row.isEmpty) return const SizedBox.shrink();

        // Data extraction
        final dap = _calculateDAP(row);
        final dapGradient = _getDapGradient(dap);
        final fieldNumber = getValue(row, 2, "-");
        final farmerName = getValue(row, 4, "-");
        final effectiveArea = getValue(row, 10, "0");
        final plantingDateDisplay = _formatPlantingDate(getValue(row, 12, ""));
        final desa = getValue(row, 14, "-");
        final fieldSpv = getValue(row, 18, "-");

        // --- HITUNG ESTIMASI GDU ---
        // Kita hitung GDU berdasarkan DAP menggunakan rumus interpolasi
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
                  color: Colors.purple.shade900.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                splashColor: Colors.purple.withOpacity(0.1),
                highlightColor: Colors.purple.withOpacity(0.05),
                onTap: () => onItemTap(fieldNumber),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // --- TOP ROW ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DAP Badge
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
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'DAP',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Main Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fieldNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: Colors.black87,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_rounded, size: 14, color: Colors.purple.shade400),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        farmerName,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade300),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // --- WARNING BANNER (Jika GDU Estimasi sudah masuk Generative) ---
                      _buildPhaseWarningBanner(estimatedGdu, dap),

                      // --- GDU METRICS (Estimasi) ---
                      _buildHeatUnitMetrics(estimatedGdu, dap),

                      const SizedBox(height: 12),

                      // --- DIVIDER ---
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final boxWidth = constraints.constrainWidth();
                          const dashWidth = 6.0;
                          final dashCount = (boxWidth / (2 * dashWidth)).floor();
                          return Flex(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            direction: Axis.horizontal,
                            children: List.generate(dashCount, (_) {
                              return SizedBox(
                                width: dashWidth,
                                height: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: Colors.grey.shade200),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      // --- METRICS GRID ---
                      Row(
                        children: [
                          _buildPremiumInfoPill(
                            icon: Icons.calendar_today_rounded,
                            label: 'Planted',
                            value: plantingDateDisplay,
                            color: Colors.blue.shade600,
                            bgColor: Colors.blue.shade50,
                          ),
                          const SizedBox(width: 10),
                          _buildPremiumInfoPill(
                            icon: Icons.aspect_ratio_rounded,
                            label: 'Area',
                            value: '$effectiveArea Ha',
                            color: const Color(0xFF00BFA5),
                            bgColor: const Color(0xFFE0F2F1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildPremiumInfoPill(
                            icon: Icons.location_on_rounded,
                            label: 'Loc',
                            value: desa,
                            color: Colors.indigo.shade600,
                            bgColor: Colors.indigo.shade50,
                          ),
                          const SizedBox(width: 10),
                          _buildPremiumInfoPill(
                            icon: Icons.badge_rounded,
                            label: 'SPV',
                            value: fieldSpv,
                            color: Colors.purple.shade600,
                            bgColor: Colors.purple.shade50,
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
    );
  }

  // Helper Widget for Info Pills
  Widget _buildPremiumInfoPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.7),
                        letterSpacing: 0.5
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}