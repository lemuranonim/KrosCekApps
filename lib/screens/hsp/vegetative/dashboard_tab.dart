import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'vegetative_detail_screen.dart';
import 'app_theme.dart';
import 'utils.dart';

class DashboardTab extends StatelessWidget {
  final List<List<String>> filteredData;
  final Map<String, int> activityCounts;
  final Map<String, List<DateTime>> activityTimestamps;
  final TabController tabController;
  final int totalFields;
  final int fieldsWithActivity;
  final Map<int, int> activityDistribution;
  final double totalEffectiveArea;
  final double auditedEffectiveArea;
  final double notAuditedEffectiveArea;
  final String? selectedRegion;
  final String searchQuery;
  final bool showAuditedOnly;
  final bool showNotAuditedOnly;

  const DashboardTab({
    super.key,
    required this.filteredData,
    required this.activityCounts,
    required this.activityTimestamps,
    required this.tabController,
    required this.totalFields,
    required this.fieldsWithActivity,
    required this.activityDistribution,
    required this.totalEffectiveArea,
    required this.auditedEffectiveArea,
    required this.notAuditedEffectiveArea,
    required this.selectedRegion,
    required this.searchQuery,
    required this.showAuditedOnly,
    required this.showNotAuditedOnly,
  });

  @override
  Widget build(BuildContext context) {
    // Recalculate statistics for filtered data
    int filteredTotal = filteredData.length;
    int filteredWithActivity = 0;
    int filteredAudited = 0;
    double filteredArea = 0;

    for (var row in filteredData) {
      final fieldNumber = getValue(row, 2, "Unknown");
      final isAudited = getValue(row, 55, "NOT Audited") == "Audited";
      final hasActivity = activityCounts.containsKey(fieldNumber);

      if (hasActivity) filteredWithActivity++;
      if (isAudited) {
        filteredAudited++;
      }

      final effectiveAreaStr = getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
      filteredArea += effectiveArea;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter info
          if (searchQuery.isNotEmpty || showAuditedOnly || showNotAuditedOnly)
            _buildActiveFiltersCard(context),

          // Dashboard Grid
          const SizedBox(height: 8),
          Text(
            'Dashboard',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),

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
                percentage: formatPercentage(filteredWithActivity, filteredTotal),
                trend: filteredWithActivity > fieldsWithActivity / 2 ? 'up' : 'down',
              ),
              _buildDashboardCard(
                title: 'Audited',
                value: '$filteredAudited',
                total: filteredTotal,
                subtitle: 'Lahan',
                icon: Icons.check_circle,
                color: AppTheme.success,
                percentage: formatPercentage(filteredAudited, filteredTotal),
                trend: filteredAudited > filteredTotal / 2 ? 'up' : 'down',
              ),
              _buildDashboardCard(
                title: 'Area',
                value: filteredArea.toStringAsFixed(1),
                total: null,
                subtitle: 'Hektar',
                icon: Icons.area_chart,
                color: AppTheme.accent,
                percentage: formatPercentage(filteredArea.round(), totalEffectiveArea.round()),
                trend: 'neutral',
              ),
              _buildDashboardCard(
                title: 'Lahan',
                value: '$filteredTotal',
                total: totalFields,
                subtitle: 'Data',
                icon: Icons.grid_view,
                color: AppTheme.warning,
                percentage: formatPercentage(filteredTotal, totalFields),
                trend: 'neutral',
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

  Widget _buildActiveFiltersCard(BuildContext context) {
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
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      // This would need to be handled by the parent widget
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
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
                      'Tampilkan Lahan Audited Saja',
                      style: AppTheme.body,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      // This would need to be handled by the parent widget
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
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
                      'Tampilkan Lahan Not Audited Saja',
                      style: AppTheme.body,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      // This would need to be handled by the parent widget
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
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
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
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
      final fieldNumber = getValue(row, 2, "Unknown");
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
                  final percentage = formatPercentage(fieldsWithThisCount, totalWithActivity);

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
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Container(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: getActivityCountColor(count),
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
    int auditedCount = 0;
    int notAuditedCount = 0;
    int auditedWithActivity = 0;
    int notAuditedWithActivity = 0;

    for (var row in filteredData) {
      final fieldNumber = getValue(row, 2, "Unknown");
      final isAudited = getValue(row, 55, "NOT Audited") == "Audited";
      final hasActivity = activityCounts[fieldNumber] != null && activityCounts[fieldNumber]! > 0;

      if (isAudited) {
        auditedCount++;
        if (hasActivity) auditedWithActivity++;
      } else {
        notAuditedCount++;
        if (hasActivity) notAuditedWithActivity++;
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

          // Audited section
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildAuditStatusSection(
                  title: 'Audited (Sampun)',
                  count: auditedCount,
                  total: filteredData.length,
                  withActivity: auditedWithActivity,
                  color: AppTheme.success,
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildAuditStatusSection(
                  title: 'Not Audited (Dereng)',
                  count: notAuditedCount,
                  total: filteredData.length,
                  withActivity: notAuditedWithActivity,
                  color: AppTheme.error,
                  icon: Icons.cancel,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

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
                  value: '${totalEffectiveArea.toStringAsFixed(2)} Ha',
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Audited Area',
                  value: '${auditedEffectiveArea.toStringAsFixed(2)} Ha',
                  percentage: formatPercentage(auditedEffectiveArea.round(), totalEffectiveArea.round()),
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Not Audited Area',
                  value: '${notAuditedEffectiveArea.toStringAsFixed(2)} Ha',
                  percentage: formatPercentage(notAuditedEffectiveArea.round(), totalEffectiveArea.round()),
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
    final withActivityPercentage = count > 0 ? formatPercentage(withActivity, count) : '0.0';
    final withoutActivityPercentage = count > 0 ? formatPercentage(withoutActivity, count) : '0.0';

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
          '$count lahan (${formatPercentage(count, total)}%)',
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
      final fieldNumber = getValue(row, 2, "Unknown");
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
                      (row) => getValue(row, 2, "") == fieldNumber,
                  orElse: () => [],
                );

                final farmerName = fieldData.isNotEmpty ? getValue(fieldData, 3, "Unknown") : "Unknown";
                final isAudited = fieldData.isNotEmpty && getValue(fieldData, 55, "NOT Audited") == "Audited";

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => VegetativeDetailScreen(
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
                            color: isAudited ? AppTheme.success.withAlpha(25) : AppTheme.error.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              isAudited ? Icons.check_circle : Icons.cancel,
                              color: isAudited ? AppTheme.success : AppTheme.error,
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
                                'Lahan $fieldNumber (${isAudited ? "Audited" : "Not Audited"})',
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
                              getTimeAgo(timestamp),
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

          if (recentActivities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Lihat Semua'),
                  onPressed: () {
                    tabController.animateTo(3); // Switch to Data Table tab
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopFieldsTable(List<List<String>> filteredData, BuildContext context) {
    // Sort fields by activity count
    final List<MapEntry<String, int>> sortedFields = [];

    for (var row in filteredData) {
      final fieldNumber = getValue(row, 2, "Unknown");
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
                        (row) => getValue(row, 2, "") == entry.key,
                    orElse: () => [],
                  );

                  final isAudited = fieldData.isNotEmpty && getValue(fieldData, 55, "NOT Audited") == "Audited";
                  final dap = fieldData.isNotEmpty ? calculateDAP(fieldData) : 0;
                  final effectiveAreaStr = fieldData.isNotEmpty ? getValue(fieldData, 8, "0").replaceAll(',', '.') : "0";
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
                              builder: (context) => VegetativeDetailScreen(
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
                            color: getActivityCountColor(entry.value),
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
                      DataCell(Text(getLastVisitText(entry.key, activityTimestamps), style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAudited ? AppTheme.success.withAlpha(25) : AppTheme.error.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAudited ? 'Sampun' : 'Dereng',
                            style: TextStyle(
                              color: isAudited ? AppTheme.success : AppTheme.error,
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

          if (topFields.isNotEmpty && sortedFields.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Lihat Semua'),
                  onPressed: () {
                    tabController.animateTo(3); // Switch to Data Table tab
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
