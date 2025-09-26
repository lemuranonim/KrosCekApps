import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisDashboardTab extends StatelessWidget {
  final List<List<String>> filteredData;
  final Map<String, int> activityCounts;
  final Map<String, List<DateTime>> activityTimestamps;
  final int sampunCount;
  final int derengJangkepCount;
  final int derengBlasCount;
  final int sampunWithActivity;
  final int derengJangkepWithActivity;
  final int derengBlasWithActivity;
  final double sampunArea;
  final double derengJangkepArea;
  final double derengBlasArea;
  final int fieldsWithActivity;
  final String searchQuery;
  final TabController tabController;
  final String? selectedRegion;
  final Function(List<String>) getAuditStatus;
  final Function(String) getAuditStatusColor;
  final Function(String) getAuditStatusIcon;
  final double ketersediaanAreaA;
  final double ketersediaanAreaB;
  final double ketersediaanAreaC;
  final double ketersediaanAreaD;
  final double ketersediaanAreaE;
  final double efektivitasAreaEfektif;
  final double efektivitasAreaTidakEfektif;
  final List<String> availableGrowers;
  final List<String> availableCoordinators;
  final Function getKetersediaanStatus;
  final Function getEffectivenessStatus;

  const AnalysisDashboardTab({
    super.key,
    required this.filteredData,
    required this.activityCounts,
    required this.activityTimestamps,
    required this.sampunCount,
    required this.derengJangkepCount,
    required this.derengBlasCount,
    required this.sampunWithActivity,
    required this.derengJangkepWithActivity,
    required this.derengBlasWithActivity,
    required this.sampunArea,
    required this.derengJangkepArea,
    required this.derengBlasArea,
    required this.fieldsWithActivity,
    required this.searchQuery,
    required this.tabController,
    required this.selectedRegion,
    required this.getAuditStatus,
    required this.getAuditStatusColor,
    required this.getAuditStatusIcon,
    required this.ketersediaanAreaA,
    required this.ketersediaanAreaB,
    required this.ketersediaanAreaC,
    required this.ketersediaanAreaD,
    required this.ketersediaanAreaE,
    required this.efektivitasAreaEfektif,
    required this.efektivitasAreaTidakEfektif,
    required this.availableGrowers,
    required this.availableCoordinators,
    required this.getKetersediaanStatus,
    required this.getEffectivenessStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Recalculate statistics for filtered data
    int filteredTotal = filteredData.length;
    int filteredWithActivity = 0;

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final hasActivity = activityCounts.containsKey(fieldNumber);

      if (hasActivity) filteredWithActivity++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter info
          if (searchQuery.isNotEmpty)
            _buildActiveFiltersCard(),

          // Dashboard Grid
          const SizedBox(height: 8),
          Text(
            'Dashboard',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),

          // In the dashboard tab, include these cards:
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildDashboardCard(
                title: 'Visited',
                value: '$filteredWithActivity',
                total: filteredTotal,
                subtitle: 'Lahan',
                icon: Icons.analytics,
                color: AppTheme.info,
                percentage: _formatPercentage(filteredWithActivity, filteredTotal),
                trend: filteredWithActivity > fieldsWithActivity / 2 ? 'up' : 'down',
              ),

              _buildDashboardCard(
                title: 'Sampun',
                value: '$sampunCount',
                total: filteredTotal,
                subtitle: 'Lahan',
                icon: Icons.check_circle,
                color: AppTheme.success,
                percentage: _formatPercentage(sampunCount, filteredTotal),
                trend: sampunCount > filteredTotal / 3 ? 'up' : 'down',
              ),

              _buildDashboardCard(
                title: 'Dereng Jangkep',
                value: '$derengJangkepCount',
                total: filteredTotal,
                subtitle: 'Lahan',
                icon: Icons.warning,
                color: AppTheme.warning,
                percentage: _formatPercentage(derengJangkepCount, filteredTotal),
                trend: 'neutral',
              ),

              _buildDashboardCard(
                title: 'Dereng Blas',
                value: '$derengBlasCount',
                total: filteredTotal,
                subtitle: 'Lahan',
                icon: Icons.cancel,
                color: AppTheme.error,
                percentage: _formatPercentage(derengBlasCount, filteredTotal),
                trend: derengBlasCount < filteredTotal / 3 ? 'up' : 'down',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Activity Distribution
          Text(
            'Visited',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          _buildActivityDistributionCard(filteredData),

          const SizedBox(height: 24),

          // Audit Status Details
          Text(
            'Detail Audited Status',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          _buildAuditStatusCard(filteredData),

          const SizedBox(height: 24),

          Text(
            'Analisis Ketersediaan',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          // Panggil Widget baru di sini
          KetersediaanCard(
            allFilteredData: filteredData,
            availableCoordinators: availableCoordinators,
            getKetersediaanStatus: getKetersediaanStatus,
          ),

          const SizedBox(height: 24),

          Text(
            'Analisis Efektivitas',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          EffectivenessCard( // <-- Panggil widget stateful yang sudah kita buat
            allFilteredData: filteredData,
            availableCoordinators: availableCoordinators,
            getEffectivenessStatus: getEffectivenessStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentLight.withAlpha(127)),
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
            children: [
              Icon(Icons.filter_list, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Active Filters',
                style: AppTheme.heading3,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                onPressed: () {
                  // This would need to be handled by the parent widget
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const Divider(),
          if (searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: AppTheme.textMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search: "$searchQuery"',
                      style: AppTheme.body,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    int? total,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String percentage,
    required String trend,
  }) {
    return Container(
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
      child: Stack(
        children: [
          // Background indicator
          Positioned(
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(12),
              ),
              child: Container(
                width: 60,
                height: 60,
                color: color.withAlpha(25),
                child: Icon(
                  icon,
                  size: 40,
                  color: color.withAlpha(51),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (total != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ $total',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (trend == 'up')
                            const Icon(Icons.arrow_upward, size: 12, color: AppTheme.success)
                          else if (trend == 'down')
                            const Icon(Icons.arrow_downward, size: 12, color: AppTheme.error)
                          else
                            const Icon(Icons.remove, size: 12, color: AppTheme.textMedium),
                          const SizedBox(width: 4),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
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
        ],
      ),
    );
  }

  Widget _buildActivityDistributionCard(List<List<String>> filteredData) {
    // Count activities for filtered data
    final Map<int, int> distribution = {};
    int totalWithActivity = 0;

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final count = activityCounts[fieldNumber] ?? 0;

      if (count > 0) {
        distribution[count] = (distribution[count] ?? 0) + 1;
        totalWithActivity++;
      }
    }

    // Sort by activity count
    final sortedCounts = distribution.keys.toList()..sort();

    return Container(
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
                  const Icon(Icons.bar_chart, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Visited',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '$totalWithActivity/${filteredData.length} lahan',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (totalWithActivity == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No fields with activities found.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textMedium,
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                // Distribution bars
                ...sortedCounts.map((count) {
                  final fieldsWithThisCount = distribution[count]!;
                  final percentage = _formatPercentage(fieldsWithThisCount, totalWithActivity);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '$count ${count == 1 ? 'Visited' : 'Visited'}:',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$fieldsWithThisCount lahan ($percentage%)',
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            // Background bar
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // Foreground bar
                            FractionallySizedBox(
                              widthFactor: fieldsWithThisCount / totalWithActivity,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getActivityCountColor(count),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAuditStatusCard(List<List<String>> filteredData) {
    // Count fields by audit status
    int sampunCount = 0;
    int derengJangkepCount = 0;
    int derengBlasCount = 0;

    int sampunWithActivity = 0;
    int derengJangkepWithActivity = 0;
    int derengBlasWithActivity = 0;

    double sampunArea = 0.0;
    double derengJangkepArea = 0.0;
    double derengBlasArea = 0.0;

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final auditStatus = getAuditStatus(row);
      final hasActivity = activityCounts[fieldNumber] != null && activityCounts[fieldNumber]! > 0;

      // Calculate effective area
      final effectiveAreaStr = _getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;

      if (auditStatus == "Sampun") {
        sampunCount++;
        sampunArea += effectiveArea;
        if (hasActivity) sampunWithActivity++;
      } else if (auditStatus == "Dereng Jangkep") {
        derengJangkepCount++;
        derengJangkepArea += effectiveArea;
        if (hasActivity) derengJangkepWithActivity++;
      } else {
        derengBlasCount++;
        derengBlasArea += effectiveArea;
        if (hasActivity) derengBlasWithActivity++;
      }
    }

    return Container(
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
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success),
              const SizedBox(width: 8),
              const Text(
                'Detail Audited Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Audit status sections
          Row(
            children: [
              Expanded(
                child: _buildAuditStatusSection(
                  title: 'Sampun',
                  count: sampunCount,
                  total: filteredData.length,
                  withActivity: sampunWithActivity,
                  color: AppTheme.success,
                  icon: Icons.check_circle,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildAuditStatusSection(
                  title: 'Dereng Jangkep',
                  count: derengJangkepCount,
                  total: filteredData.length,
                  withActivity: derengJangkepWithActivity,
                  color: AppTheme.warning,
                  icon: Icons.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildAuditStatusSection(
                  title: 'Dereng Blas',
                  count: derengBlasCount,
                  total: filteredData.length,
                  withActivity: derengBlasWithActivity,
                  color: AppTheme.error,
                  icon: Icons.cancel,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Area analysis
          const Text(
            'Area Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Total Area',
                  value: '${(sampunArea + derengJangkepArea + derengBlasArea).toStringAsFixed(2)} Ha',
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Sampun Area',
                  value: '${sampunArea.toStringAsFixed(2)} Ha',
                  percentage: _formatPercentage(sampunArea.round(), (sampunArea + derengJangkepArea + derengBlasArea).round()),
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Dereng Jangkep Area',
                  value: '${derengJangkepArea.toStringAsFixed(2)} Ha',
                  percentage: _formatPercentage(derengJangkepArea.round(), (sampunArea + derengJangkepArea + derengBlasArea).round()),
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Dereng Blas Area',
                  value: '${derengBlasArea.toStringAsFixed(2)} Ha',
                  percentage: _formatPercentage(derengBlasArea.round(), (sampunArea + derengJangkepArea + derengBlasArea).round()),
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditStatusSection({
    required String title,
    required int count,
    required int total,
    required int withActivity,
    required Color color,
    required IconData icon,
  }) {
    final withoutActivity = count - withActivity;
    final withActivityPercentage = count > 0 ? _formatPercentage(withActivity, count) : '0.0';
    final withoutActivityPercentage = count > 0 ? _formatPercentage(withoutActivity, count) : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$count lahan (${_formatPercentage(count, total)}%)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 12),

        // With activity
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Visited: $withActivity ($withActivityPercentage%)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Without activity
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Belum Visited: $withoutActivity ($withoutActivityPercentage%)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaAnalysisItem({
    required String title,
    required String value,
    String? percentage,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (percentage != null) ...[
            const SizedBox(height: 2),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 12,
                color: color.withAlpha(204),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper methods
  String _getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }

  String _formatPercentage(int part, int total) {
    if (total == 0) return '0.0';
    return ((part / total) * 100).toStringAsFixed(1);
  }

  Color _getActivityCountColor(int count) {
    if (count == 0) return Colors.grey.shade300;
    if (count == 1) return Colors.blue.shade300;
    if (count == 2) return Colors.green.shade400;
    if (count == 3) return Colors.amber.shade400;
    if (count <= 5) return Colors.orange.shade500;
    return Colors.red.shade500;
  }
}

// ===================================================================
// CLASS WIDGET BARU UNTUK DONUT CHART (DARI OPSI 2)
// LETAKKAN INI DI LUAR CLASS AnalysisDashboardTab, TAPI MASIH DALAM FILE YANG SAMA
// ===================================================================
class DonutChartCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final double totalValue;
  final List<Map<String, dynamic>> chartData;

  const DonutChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.totalValue,
    required this.chartData,
  });

  @override
  State<DonutChartCard> createState() => _DonutChartCardState();
}

class _DonutChartCardState extends State<DonutChartCard> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Header Kartu (tetap sama)
          Row(
            children: [
              Icon(widget.icon, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // LayoutBuilder untuk Tampilan Responsif
          LayoutBuilder(
            builder: (context, constraints) {
              // Tentukan breakpoint. Jika lebar kurang dari 350, ganti ke Column.
              // Anda bisa menyesuaikan nilai 350 ini jika perlu.
              const double breakpoint = 350.0;

              // --- Definisikan Widget Chart ---
              final pieChart = PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: List.generate(widget.chartData.length, (i) {
                    final isTouched = i == touchedIndex;
                    final radius = isTouched ? 60.0 : 50.0;
                    final data = widget.chartData[i];
                    return PieChartSectionData(
                      color: data['color'],
                      value: data['value'],
                      title: '${data['percentage']}%',
                      radius: radius,
                      titleStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                    );
                  }),
                ),
              );

              // --- Definisikan Widget Legenda ---
              final legend = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.chartData.map((data) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: data['color'], borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('${data['title']} (${data['value'].toStringAsFixed(2)} Ha)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              // Tampilkan layout berdasarkan lebar yang tersedia
              if (constraints.maxWidth < breakpoint) {
                // TAMPILAN SEMPIT (Ponsel Potret)
                return Column(
                  children: [
                    SizedBox(height: 180, child: pieChart), // Chart di atas
                    const SizedBox(height: 24),
                    legend, // Legenda di bawah
                  ],
                );
              } else {
                // TAMPILAN LEBAR (Tablet / Ponsel Lanskap)
                return Row(
                  children: [
                    Expanded(flex: 2, child: AspectRatio(aspectRatio: 1, child: pieChart)), // Chart di kiri
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: legend), // Legenda di kanan
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// analysis_dashboard_tab.dart

// ===================================================================
// KARTU BARU UNTUK ANALISIS KETERSEDIAAN (STATEFUL)
// ===================================================================
class KetersediaanCard extends StatefulWidget {
  final List<List<String>> allFilteredData;
  final List<String> availableCoordinators;
  final Function getKetersediaanStatus;

  const KetersediaanCard({
    super.key,
    required this.allFilteredData,
    required this.availableCoordinators,
    required this.getKetersediaanStatus,
  });

  @override
  State<KetersediaanCard> createState() => _KetersediaanCardState();
}

class _KetersediaanCardState extends State<KetersediaanCard> {
  String? _selectedCoordinator;

  // Helper untuk mengambil nilai dari baris data
  String _getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }

  @override
  Widget build(BuildContext context) {
    // Saring data secara lokal berdasarkan dropdown koordinator
    final localFilteredData = widget.allFilteredData.where((row) {
      if (_selectedCoordinator == null) return true; // Tampilkan semua jika tidak ada yang dipilih
      // Filter berdasarkan Koordinator dari kolom DJ (indeks 113)
      return _getValue(row, 113, "").trim().toLowerCase() == _selectedCoordinator;
    }).toList();

    // Lakukan kalkulasi berdasarkan data yang sudah difilter secara lokal
    double ketersediaanAreaA = 0.0;
    double ketersediaanAreaB = 0.0;
    double ketersediaanAreaC = 0.0;
    double ketersediaanAreaD = 0.0;
    double ketersediaanAreaE = 0.0;

    for (var row in localFilteredData) {
      final effectiveAreaStr = _getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
      final ketersediaanStatus = widget.getKetersediaanStatus(row);

      switch (ketersediaanStatus) {
        case 'A': ketersediaanAreaA += effectiveArea; break;
        case 'B': ketersediaanAreaB += effectiveArea; break;
        case 'C': ketersediaanAreaC += effectiveArea; break;
        case 'D': ketersediaanAreaD += effectiveArea; break;
        case 'E': ketersediaanAreaE += effectiveArea; break;
      }
    }
    final totalArea = ketersediaanAreaA + ketersediaanAreaB + ketersediaanAreaC + ketersediaanAreaD + ketersediaanAreaE;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text('Ketersediaan Tenaga Kerja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildCoordinatorDropdown(),
            ],
          ),
          const Divider(height: 24),
          _buildProgressRow(title: 'A (100%)', valueHa: ketersediaanAreaA.toStringAsFixed(2), percentage: _formatPercentageDouble(ketersediaanAreaA, totalArea), color: Colors.green.shade700, progress: totalArea > 0 ? ketersediaanAreaA / totalArea : 0.0),
          _buildProgressRow(title: 'B (80%)', valueHa: ketersediaanAreaB.toStringAsFixed(2), percentage: _formatPercentageDouble(ketersediaanAreaB, totalArea), color: Colors.lightGreen.shade600, progress: totalArea > 0 ? ketersediaanAreaB / totalArea : 0.0),
          _buildProgressRow(title: 'C (60%)', valueHa: ketersediaanAreaC.toStringAsFixed(2), percentage: _formatPercentageDouble(ketersediaanAreaC, totalArea), color: AppTheme.warning, progress: totalArea > 0 ? ketersediaanAreaC / totalArea : 0.0),
          _buildProgressRow(title: 'D (40%)', valueHa: ketersediaanAreaD.toStringAsFixed(2), percentage: _formatPercentageDouble(ketersediaanAreaD, totalArea), color: Colors.orange.shade700, progress: totalArea > 0 ? ketersediaanAreaD / totalArea : 0.0),
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: _buildProgressRow(title: 'E (20%)', valueHa: ketersediaanAreaE.toStringAsFixed(2), percentage: _formatPercentageDouble(ketersediaanAreaE, totalArea), color: AppTheme.error, progress: totalArea > 0 ? ketersediaanAreaE / totalArea : 0.0),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCoordinator,
          hint: const Text('All Co-Det', style: TextStyle(fontSize: 12)),
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(color: AppTheme.textDark, fontSize: 12),
          onChanged: (String? newValue) {
            setState(() {
              _selectedCoordinator = newValue;
            });
          },
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Co-Det'),
            ),
            ...widget.availableCoordinators.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toTitleCase(), overflow: TextOverflow.ellipsis),
              );
            })
          ],
        ),
      ),
    );
  }



  Widget _buildProgressRow({
    required String title,
    required String valueHa,
    required String percentage,
    required Color color,
    required double progress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textMedium)),
              Text('$valueHa Ha', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(color: color.withAlpha(51), borderRadius: BorderRadius.circular(5)),
              ),
              LayoutBuilder(
                builder: (context, constraints) => Container(
                  width: constraints.maxWidth * progress,
                  height: 10,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$percentage%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  String _formatPercentageDouble(double part, double total) {
    if (total == 0) return '0.0';
    return ((part / total) * 100).toStringAsFixed(1);
  }
}

// analysis_dashboard_tab.dart

// ===================================================================
// KARTU BARU UNTUK ANALISIS EFEKTIVITAS (STATEFUL)
// ===================================================================
class EffectivenessCard extends StatefulWidget {
  final List<List<String>> allFilteredData;
  final List<String> availableCoordinators;
  final Function getEffectivenessStatus;

  const EffectivenessCard({
    super.key,
    required this.allFilteredData,
    required this.availableCoordinators,
    required this.getEffectivenessStatus,
  });

  @override
  State<EffectivenessCard> createState() => _EffectivenessCardState();
}

class _EffectivenessCardState extends State<EffectivenessCard> {
  String? _selectedCoordinator;
  int touchedIndex = -1;

  String _getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }

  @override
  Widget build(BuildContext context) {
    // 1. Saring data secara lokal berdasarkan dropdown
    final localFilteredData = widget.allFilteredData.where((row) {
      if (_selectedCoordinator == null) return true;
      // Filter berdasarkan Koordinator dari kolom DJ (indeks 113)
      return _getValue(row, 113, "").trim().toLowerCase() == _selectedCoordinator;
    }).toList();

    // 2. Lakukan kalkulasi berdasarkan data yang sudah difilter
    double efektivitasAreaEfektif = 0.0;
    double efektivitasAreaTidakEfektif = 0.0;

    for (var row in localFilteredData) {
      final effectiveAreaStr = _getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
      final effectivenessStatus = widget.getEffectivenessStatus(row);

      if (effectivenessStatus == 'Efektif') {
        efektivitasAreaEfektif += effectiveArea;
      } else if (effectivenessStatus == 'Tidak Efektif') {
        efektivitasAreaTidakEfektif += effectiveArea;
      }
    }

    final totalArea = efektivitasAreaEfektif + efektivitasAreaTidakEfektif;
    final List<Map<String, dynamic>> chartData = [
      {'title': 'Efektif', 'value': efektivitasAreaEfektif, 'percentage': _formatPercentageDouble(efektivitasAreaEfektif, totalArea), 'color': AppTheme.success},
      {'title': 'Tidak Efektif', 'value': efektivitasAreaTidakEfektif, 'percentage': _formatPercentageDouble(efektivitasAreaTidakEfektif, totalArea), 'color': AppTheme.error},
    ];

    // 3. Bangun UI lengkap dengan Donut Chart dan Legenda
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Kartu dengan Dropdown
          Row(
            children: [
              const Icon(Icons.task_alt, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Efektivitas Tenaga Kerja', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildCoordinatorDropdown(),
            ],
          ),
          const SizedBox(height: 16),

          // LayoutBuilder untuk Tampilan Responsif (Chart & Legenda)
          LayoutBuilder(
            builder: (context, constraints) {
              const double breakpoint = 350.0;

              final pieChart = PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: List.generate(chartData.length, (i) {
                    final isTouched = i == touchedIndex;
                    final radius = isTouched ? 60.0 : 50.0;
                    final data = chartData[i];
                    return PieChartSectionData(
                      color: data['color'],
                      value: data['value'] as double,
                      title: '${data['percentage']}%',
                      radius: radius,
                      titleStyle: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                    );
                  }),
                ),
              );

              final legend = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: chartData.map((data) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: data['color'] as Color, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text('${data['title']} (${(data['value'] as double).toStringAsFixed(2)} Ha)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );

              if (constraints.maxWidth < breakpoint) {
                return Column(
                  children: [
                    SizedBox(height: 180, child: pieChart),
                    const SizedBox(height: 24),
                    legend,
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(flex: 2, child: AspectRatio(aspectRatio: 1, child: pieChart)),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: legend),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCoordinator,
          hint: const Text('All Co-Det', style: TextStyle(fontSize: 12)),
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: const TextStyle(color: AppTheme.textDark, fontSize: 12),
          onChanged: (String? newValue) {
            setState(() {
              _selectedCoordinator = newValue;
            });
          },
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All Co-Det'),
            ),
            ...widget.availableCoordinators.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toTitleCase(), overflow: TextOverflow.ellipsis),
              );
            })
          ],
        ),
      ),
    );
  }

  String _formatPercentageDouble(double part, double total) {
    if (total == 0) return '0.0';
    return ((part / total) * 100).toStringAsFixed(1);
  }
}

// AppTheme class for the dashboard tab
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

  // Text styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textDark,
    letterSpacing: 0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textDark,
    letterSpacing: 0.25,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textMedium,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: textDark,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: textMedium,
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(12),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

extension StringCasingExtension on String {
  String toCapitalized() => length > 0 ?'${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str.toCapitalized()).join(' ');
}