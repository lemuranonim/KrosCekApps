import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'preharvest_detail_screen.dart';

class PreHarvestListviewBuilder extends StatelessWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Function(String) onItemTap;

  const PreHarvestListviewBuilder({
    super.key,
    required this.filteredData,
    this.selectedRegion,
    required this.onItemTap,
  });

  String getValue(List<String> row, int index, String defaultValue) {
    if (index < row.length) {
      return row[index];
    }
    return defaultValue;
  }

  int _calculateDAP(List<String> row) {
    try {
      final plantingDate = getValue(row, 9, ''); // Get planting date from column 9
      if (plantingDate.isEmpty) return 0;

      // Convert the planting date string to a DateTime object
      final parsedDate = DateFormat('dd/MM/yyyy').parse(_convertToDateIfNecessary(plantingDate));
      final today = DateTime.now();
      return today.difference(parsedDate).inDays; // Calculate the difference in days
    } catch (e) {
      return 0; // Return 0 if there's an error in parsing
    }
  }

  // Helper function to convert Excel date format if necessary
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
      // First check if it's an Excel date number
      final parsedNumber = double.tryParse(dateStr);
      if (parsedNumber != null) {
        // Convert Excel date number to DateTime
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd MMM yyyy').format(date); // Format as "01 Jan 2023"
      }

      // If not a number, try to parse as a date string (assuming format is dd/MM/yyyy)
      final parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsedDate); // Format as "01 Jan 2023"
    } catch (e) {
      // If parsing fails, return the original string
      return dateStr;
    }
  }

  Color _getDapColor(int dap) {
    if (dap <= 40) {
      return Colors.lightGreen;
    } else if (dap <= 46) {
      return Colors.lime;
    } else if (dap <= 70) {
      return Colors.amber;
    } else if (dap <= 100) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
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

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: filteredData.length,
      itemBuilder: (context, index) {
        final row = filteredData[index];
        final isAudited = getValue(row, 39, "NOT Audited") == "Audited";
        final dap = _calculateDAP(row);
        final fieldNumber = getValue(row, 2, "Unknown");
        final farmerName = getValue(row, 3, "Unknown");
        final growerName = getValue(row, 4, "Unknown");
        final hybrid = getValue(row, 5, "Unknown");
        final effectiveArea = getValue(row, 8, "0");
        final rawPlantingDate = getValue(row, 9, "Unknown");
        final plantingDate = _formatPlantingDate(rawPlantingDate);
        final desa = getValue(row, 11, "Unknown");
        final kecamatan = getValue(row, 12, "Unknown");
        final kabupaten = getValue(row, 13, "Unknown");
        final fieldSpv = getValue(row, 15, "Unknown");
        final fa = getValue(row, 16, "Unknown");
        final weekOfPreHarvest = getValue(row, 27, "Unknown");

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
                      builder: (context) => PreHarvestDetailScreen(
                        fieldNumber: fieldNumber,
                        region: selectedRegion ?? 'Unknown Region',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with Field Number and Status
                      Row(
                        children: [
                          // Left side with image and DAP
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
                                  tag: 'pre_harvest_$fieldNumber',
                                  child: Image.asset(
                                    'assets/preharvest.png',
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

                          // Middle section with field number and details
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

                                // Farmer and Grower info
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

                                // Hybrid and Area info
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

                      // Divider
                      Container(
                        height: 1,
                        color: isAudited
                            ? Colors.green.withAlpha(51)
                            : Colors.red.withAlpha(51),
                      ),

                      const SizedBox(height: 12),

                      // Location and Personnel info in a grid
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Location info
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

                          // Personnel info
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
                                  label: 'SPV',
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
                                  icon: Icons.calendar_month,
                                  label: 'Week',
                                  value: weekOfPreHarvest,
                                  iconColor: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // View Details Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isAudited
                                  ? [Colors.green.shade400, Colors.green.shade600]
                                  : [Colors.orange.shade400, Colors.orange.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isAudited
                                    ? Colors.green.withAlpha(60)
                                    : Colors.orange.withAlpha(60),
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
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PreHarvestDetailScreen(
                                      fieldNumber: fieldNumber,
                                      region: selectedRegion ?? 'Unknown Region',
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'View Details',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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
}