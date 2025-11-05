import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'generative_detail_screen.dart';

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
  final bool showAuditedOnly;
  final bool showNotAuditedOnly;
  final TabController tabController;
  final String? selectedRegion;
  final Function(List<String>) getAuditStatus;
  final Function(String) getAuditStatusColor;
  final Function(String) getAuditStatusIcon;

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
    required this.showAuditedOnly,
    required this.showNotAuditedOnly,
    required this.tabController,
    required this.selectedRegion,
    required this.getAuditStatus,
    required this.getAuditStatusColor,
    required this.getAuditStatusIcon,
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
          if (searchQuery.isNotEmpty || showAuditedOnly || showNotAuditedOnly)
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

          // Recent Activities
          Text(
            'Update Terbaru',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          _buildRecentActivitiesCard(filteredData, context),

          const SizedBox(height: 24),

          // Fields with Most Activities
          Text(
            'Lahan Visited Terbanyak',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          _buildTopFieldsTable(filteredData, context),
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
          if (showAuditedOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Show Audited Only',
                      style: AppTheme.body,
                    ),
                  ),
                ],
              ),
            ),
          if (showNotAuditedOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.cancel, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Show Not Audited Only',
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

  Widget _buildRecentActivitiesCard(List<List<String>> filteredData, BuildContext context) {
    // Get all timestamps for filtered data
    final List<MapEntry<String, DateTime>> allActivities = [];

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final timestamps = activityTimestamps[fieldNumber];

      if (timestamps != null && timestamps.isNotEmpty) {
        for (var timestamp in timestamps) {
          allActivities.add(MapEntry(fieldNumber, timestamp));
        }
      }
    }

    // Sort by timestamp (newest first)
    allActivities.sort((a, b) => b.value.compareTo(a.value));

    // Take the 5 most recent activities
    final recentActivities = allActivities.take(5).toList();

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
              const Icon(Icons.history, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text(
                'Update Terbaru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No recent activities found.',
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
              children: recentActivities.map((activity) {
                final fieldNumber = activity.key;
                final timestamp = activity.value;
                final dateFormat = DateFormat('dd MMM yyyy HH:mm');

                // Find the field data
                final fieldData = filteredData.firstWhere(
                      (row) => _getValue(row, 2, "") == fieldNumber,
                  orElse: () => [],
                );

                final farmerName = fieldData.isNotEmpty ? _getValue(fieldData, 3, "Unknown") : "Unknown";
                final auditStatus = fieldData.isNotEmpty ? getAuditStatus(fieldData) : "Dereng Blas";

                return InkWell(
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
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: getAuditStatusColor(auditStatus).withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              getAuditStatusIcon(auditStatus),
                              color: getAuditStatusColor(auditStatus),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lahan $fieldNumber ($auditStatus)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Farmer: $farmerName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dateFormat.format(timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getTimeAgo(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.accent.withAlpha(204),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopFieldsTable(List<List<String>> filteredData, BuildContext context) {
    // Sort fields by activity count
    final List<MapEntry<String, int>> sortedFields = [];

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final count = activityCounts[fieldNumber] ?? 0;

      if (count > 0) {
        sortedFields.add(MapEntry(fieldNumber, count));
      }
    }

    sortedFields.sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 or fewer
    final topFields = sortedFields.take(5).toList();

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
                  const Icon(Icons.star, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  const Text(
                    'Visited Teratas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'Top ${topFields.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (topFields.isEmpty)
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 0,
                headingRowHeight: 40,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  fontSize: 13,
                ),
                columns: const [
                  DataColumn(label: Text('Lahan')),
                  DataColumn(label: Text('Visited')),
                  DataColumn(label: Text('Visit Terakhir')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('DAP')),
                  DataColumn(label: Text('Area (Ha)')),
                ],
                rows: topFields.map((entry) {
                  // Find corresponding field data
                  final fieldData = filteredData.firstWhere(
                        (row) => _getValue(row, 2, "") == entry.key,
                    orElse: () => [],
                  );

                  final auditStatus = fieldData.isNotEmpty ? getAuditStatus(fieldData) : "Dereng Blas";
                  final dap = fieldData.isNotEmpty ? _calculateDAP(fieldData) : 0;
                  final effectiveAreaStr = fieldData.isNotEmpty ? _getValue(fieldData, 8, "0").replaceAll(',', '.') : "0";
                  final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GenerativeDetailScreen(
                                fieldNumber: entry.key,
                                region: selectedRegion ?? 'Unknown Region',
                              ),
                            ),
                          );
                        },
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getActivityCountColor(entry.value),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              color: entry.value > 2 ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(_getLastVisitText(entry.key), style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getAuditStatusColor(auditStatus).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            auditStatus,
                            style: TextStyle(
                              color: getAuditStatusColor(auditStatus),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text('$dap', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(effectiveArea.toStringAsFixed(2), style: const TextStyle(fontSize: 13))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods
  String _getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }

  int _calculateDAP(List<String> row) {
    try {
      final plantingDate = _getValue(row, 9, ''); // Get planting date from column 9
      if (plantingDate.isEmpty) return 0;

      // Try to parse as Excel date number
      final parsedNumber = double.tryParse(plantingDate);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        final today = DateTime.now();
        return today.difference(date).inDays;
      } else {
        // Try to parse as formatted date
        try {
          final parts = plantingDate.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? DateTime.now().year;

            final date = DateTime(year, month, day);
            final today = DateTime.now();
            return today.difference(date).inDays;
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  String _getLastVisitText(String fieldNumber) {
    // Get the list of timestamps for this field
    final timestamps = activityTimestamps[fieldNumber];

    // If no timestamps, return "No data"
    if (timestamps == null || timestamps.isEmpty) {
      return "Mboten wonten data";
    }

    // Get the most recent timestamp (already sorted in _loadActivityData)
    final lastVisit = timestamps.first;

    return _getTimeAgo(lastVisit);
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // Format based on how long ago the visit was
    if (difference.inDays == 0) {
      // Today
      if (difference.inHours == 0) {
        if (difference.inMinutes < 5) {
          return "Baru saja";
        } else {
          // Minutes ago
          return "${difference.inMinutes} menit yang lalu";
        }
      } else {
        // Hours ago
        return "${difference.inHours} jam yang lalu";
      }
    } else if (difference.inDays == 1) {
      // Yesterday
      return "Kemarin";
    } else if (difference.inDays < 7) {
      // Within a week
      return "${difference.inDays} hari yang lalu";
    } else if (difference.inDays < 30) {
      // Within a month
      final weeks = (difference.inDays / 7).floor();
      return "$weeks minggu yang lalu";
    } else if (difference.inDays < 365) {
      // Within a year
      final months = (difference.inDays / 30).floor();
      return "$months bulan yang lalu";
    } else {
      // More than a year
      final years = (difference.inDays / 365).floor();
      return "$years tahun yang lalu";
    }
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
}