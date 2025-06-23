import 'package:flutter/material.dart';
import 'generative_detail_screen.dart';

class AnalysisHeatmapTab extends StatelessWidget {
  final List<List<String>> filteredData;
  final Map<String, int> activityCounts;
  final String? selectedRegion;
  final Function(List<String>) getAuditStatus;
  final Function(String) getAuditStatusColor;

  const AnalysisHeatmapTab({
    super.key,
    required this.filteredData,
    required this.activityCounts,
    required this.selectedRegion,
    required this.getAuditStatus,
    required this.getAuditStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.grid_on, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        const Text(
                          'Heatmap',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Sampling ${filteredData.length.clamp(0, 100)} lahan',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Legend
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activity Count:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: [
                          _buildLegendItem(Colors.grey.shade200, '0 visited'),
                          _buildLegendItem(Colors.blue.shade200, '1 visited'),
                          _buildLegendItem(Colors.green.shade300, '2 visited'),
                          _buildLegendItem(Colors.amber.shade300, '3 visited'),
                          _buildLegendItem(Colors.orange.shade400, '4-5 visited'),
                          _buildLegendItem(Colors.red.shade500, '6+ visited'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Audit Status (Border Color):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: [
                          _buildLegendItem(AppTheme.success, 'Sampun'),
                          _buildLegendItem(AppTheme.warning, 'Dereng Jangkep'),
                          _buildLegendItem(AppTheme.error, 'Dereng Blas'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Heatmap grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    childAspectRatio: 1,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: filteredData.length.clamp(0, 100), // Limit to 100 fields
                  itemBuilder: (context, index) {
                    final fieldNumber = _getValue(filteredData[index], 2, "");
                    final activityCount = activityCounts[fieldNumber] ?? 0;
                    final auditStatus = getAuditStatus(filteredData[index]);

                    return Tooltip(
                      message: '$fieldNumber: $activityCount visits ($auditStatus)',
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GenerativeDetailScreen(
                                fieldNumber: fieldNumber,
                                region: selectedRegion ?? 'Unknown Region',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getHeatmapColor(activityCount),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: getAuditStatusColor(auditStatus),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$activityCount',
                              style: TextStyle(
                                color: activityCount > 2 ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (filteredData.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Text(
                        'Menampilkan 100 dari ${filteredData.length} lahan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.textMedium,
                        ),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Color _getHeatmapColor(int count) {
    if (count == 0) return Colors.grey.shade200;
    if (count == 1) return Colors.blue.shade200;
    if (count == 2) return Colors.green.shade300;
    if (count == 3) return Colors.amber.shade300;
    if (count <= 5) return Colors.orange.shade400;
    return Colors.red.shade500;
  }

  String _getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }
}

// AppTheme class for the heatmap tab
class AppTheme {
  // Primary colors
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);

  // Accent colors
  static const Color accent = Color(0xFF1976D2);
  static const Color accentLight = Color(0xFF42A5F5);

  // Status colors
  static const Color success = Color(0xFF388E3C);
  static const Color warning = Color(0xFFFFA000);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);

  // Neutral colors
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);
  static const Color textLight = Color(0xFFBDBDBD);
  static const Color background = Color(0xFFF5F5F5);
}