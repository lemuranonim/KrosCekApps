import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'psp_generative_detail_screen.dart';

// Define app theme constants
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

  // Card decoration
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

class PspGenerativeActivityAnalysisScreen extends StatefulWidget {
  final Map<String, int> activityCounts;
  final Map<String, List<DateTime>> activityTimestamps;
  final List<List<String>> pspGenerativeData;
  final String? selectedRegion;

  const PspGenerativeActivityAnalysisScreen({
    super.key,
    required this.activityCounts,
    required this.activityTimestamps,
    required this.pspGenerativeData,
    this.selectedRegion,
  });

  @override
  State<PspGenerativeActivityAnalysisScreen> createState() => _PspGenerativeActivityAnalysisScreenState();
}

class _PspGenerativeActivityAnalysisScreenState extends State<PspGenerativeActivityAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Filters
  String _searchQuery = '';
  bool _showAuditedOnly = false;
  bool _showNotAuditedOnly = false;

  // Calculated statistics
  late int _totalFields;
  late int _fieldsWithActivity;
  late Map<int, int> _activityDistribution;
  late double _totalEffectiveArea;
  late double _auditedEffectiveArea;
  late double _notAuditedEffectiveArea;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Simulate loading delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _calculateStatistics();
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _calculateStatistics() {
    // Basic counts
    _totalFields = widget.pspGenerativeData.length;
    _fieldsWithActivity = widget.activityCounts.keys.length;

    // Activity distribution
    _activityDistribution = {};
    for (var count in widget.activityCounts.values) {
      _activityDistribution[count] = (_activityDistribution[count] ?? 0) + 1;
    }

    // Audit status counts
    _totalEffectiveArea = 0;
    _auditedEffectiveArea = 0;
    _notAuditedEffectiveArea = 0;

    for (var row in widget.pspGenerativeData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final isAudited = _getValue(row, 55, "NOT Audited") == "Audited";
      final hasActivity = widget.activityCounts.containsKey(fieldNumber);

      // Calculate effective area
      final effectiveAreaStr = _getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
      _totalEffectiveArea += effectiveArea;

      if (isAudited) {
        _auditedEffectiveArea += effectiveArea;
        if (hasActivity) {}
      } else {
        _notAuditedEffectiveArea += effectiveArea;
        if (hasActivity) {}
      }
    }
  }

  List<List<String>> _getFilteredData() {
    return widget.pspGenerativeData.where((row) {
      final fieldNumber = _getValue(row, 2, "Unknown").toLowerCase();
      final farmerName = _getValue(row, 3, "Unknown").toLowerCase();
      final growerName = _getValue(row, 4, "Unknown").toLowerCase();
      final hybrid = _getValue(row, 5, "Unknown").toLowerCase();
      final isAudited = _getValue(row, 55, "NOT Audited") == "Audited";

      // Apply search filter
      bool matchesSearch = _searchQuery.isEmpty ||
          fieldNumber.contains(_searchQuery.toLowerCase()) ||
          farmerName.contains(_searchQuery.toLowerCase()) ||
          growerName.contains(_searchQuery.toLowerCase()) ||
          hybrid.contains(_searchQuery.toLowerCase());

      // Apply audit status filter
      bool matchesAuditStatus = true;
      if (_showAuditedOnly && !isAudited) matchesAuditStatus = false;
      if (_showNotAuditedOnly && isAudited) matchesAuditStatus = false;

      return matchesSearch && matchesAuditStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _getFilteredData();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Analysis',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryDark, AppTheme.primary],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withAlpha(178),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 13,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.grid_on), text: 'Heatmap'),
          ],
        ),
        actions: [
          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            color: Colors.white,
            tooltip: 'Cari Lahan',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cari Lahan'),
                  content: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Enter field number, farmer name...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('CLEAR'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('APPLY'),
                    ),
                  ],
                ),
              );
            },
          ),

          // Filter button
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter Data',
            onSelected: (value) {
              setState(() {
                if (value == 'audited') {
                  _showAuditedOnly = !_showAuditedOnly;
                  if (_showAuditedOnly) _showNotAuditedOnly = false;
                } else if (value == 'notAudited') {
                  _showNotAuditedOnly = !_showNotAuditedOnly;
                  if (_showNotAuditedOnly) _showAuditedOnly = false;
                } else if (value == 'reset') {
                  _showAuditedOnly = false;
                  _showNotAuditedOnly = false;
                  _searchQuery = '';
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'audited',
                child: Row(
                  children: [
                    Icon(
                      _showAuditedOnly ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppTheme.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Show Audited Only'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'notAudited',
                child: Row(
                  children: [
                    Icon(
                      _showNotAuditedOnly ? Icons.check_box : Icons.check_box_outline_blank,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text('Show Not Audited Only'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppTheme.info, size: 20),
                    SizedBox(width: 12),
                    Text('Reset Filters'),
                  ],
                ),
              ),
            ],
          ),

          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: Colors.white,
            tooltip: 'Help',
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : TabBarView(
        controller: _tabController,
        children: [
          // Dashboard Tab
          _buildSummaryTab(filteredData),

          // Heatmap Tab
          _buildHeatmapTab(filteredData),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading analysis data...',
            style: AppTheme.subtitle,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(List<List<String>> filteredData) {
    // Recalculate statistics for filtered data
    int filteredTotal = filteredData.length;
    int filteredWithActivity = 0;
    int filteredAudited = 0;
    double filteredArea = 0;

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final isAudited = _getValue(row, 55, "NOT Audited") == "Audited";
      final hasActivity = widget.activityCounts.containsKey(fieldNumber);

      if (hasActivity) filteredWithActivity++;
      if (isAudited) {
        filteredAudited++;
      }

      final effectiveAreaStr = _getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;
      filteredArea += effectiveArea;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter info
          if (_searchQuery.isNotEmpty || _showAuditedOnly || _showNotAuditedOnly)
            _buildActiveFiltersCard(),

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
                percentage: _formatPercentage(filteredWithActivity, filteredTotal),
                trend: filteredWithActivity > _fieldsWithActivity / 2 ? 'up' : 'down',
              ),
              _buildDashboardCard(
                title: 'Audited',
                value: '$filteredAudited',
                total: filteredTotal,
                subtitle: 'Lahan',
                icon: Icons.check_circle,
                color: AppTheme.success,
                percentage: _formatPercentage(filteredAudited, filteredTotal),
                trend: filteredAudited > filteredTotal / 2 ? 'up' : 'down',
              ),
              _buildDashboardCard(
                title: 'Area',
                value: filteredArea.toStringAsFixed(1),
                total: null,
                subtitle: 'Hektar',
                icon: Icons.area_chart,
                color: AppTheme.accent,
                percentage: _formatPercentage(filteredArea.round(), _totalEffectiveArea.round()),
                trend: 'neutral',
              ),
              _buildDashboardCard(
                title: 'Lahan',
                value: '$filteredTotal',
                total: _totalFields,
                subtitle: 'Data',
                icon: Icons.grid_view,
                color: AppTheme.warning,
                percentage: _formatPercentage(filteredTotal, _totalFields),
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
          _buildRecentActivitiesCard(filteredData),

          const SizedBox(height: 24),

          // Fields with Most Activities
          Text(
            'Lahan Visited Terbanyak',
            style: AppTheme.heading2,
          ),
          const SizedBox(height: 16),
          _buildTopFieldsTable(filteredData),
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
                  setState(() {
                    _searchQuery = '';
                    _showAuditedOnly = false;
                    _showNotAuditedOnly = false;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const Divider(),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: AppTheme.textMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search: "$_searchQuery"',
                      style: AppTheme.body,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          if (_showAuditedOnly)
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
                      setState(() {
                        _showAuditedOnly = false;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),
          if (_showNotAuditedOnly)
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
                      setState(() {
                        _showNotAuditedOnly = false;
                      });
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
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
      final count = widget.activityCounts[fieldNumber] ?? 0;

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
    int auditedCount = 0;
    int notAuditedCount = 0;
    int auditedWithActivity = 0;
    int notAuditedWithActivity = 0;

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final isAudited = _getValue(row, 55, "NOT Audited") == "Audited";
      final hasActivity = widget.activityCounts[fieldNumber] != null && widget.activityCounts[fieldNumber]! > 0;

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
                  value: '${_totalEffectiveArea.toStringAsFixed(2)} Ha',
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Audited Area',
                  value: '${_auditedEffectiveArea.toStringAsFixed(2)} Ha',
                  percentage: _formatPercentage(_auditedEffectiveArea.round(), _totalEffectiveArea.round()),
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAreaAnalysisItem(
                  title: 'Not Audited Area',
                  value: '${_notAuditedEffectiveArea.toStringAsFixed(2)} Ha',
                  percentage: _formatPercentage(_notAuditedEffectiveArea.round(), _totalEffectiveArea.round()),
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

  Widget _buildRecentActivitiesCard(List<List<String>> filteredData) {
    // Get all timestamps for filtered data
    final List<MapEntry<String, DateTime>> allActivities = [];

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final timestamps = widget.activityTimestamps[fieldNumber];

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
                final isAudited = fieldData.isNotEmpty && _getValue(fieldData, 55, "NOT Audited") == "Audited";

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PspGenerativeDetailScreen(
                          fieldNumber: fieldNumber,
                          region: widget.selectedRegion ?? 'Unknown Region',
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

  Widget _buildTopFieldsTable(List<List<String>> filteredData) {
    // Sort fields by activity count
    final List<MapEntry<String, int>> sortedFields = [];

    for (var row in filteredData) {
      final fieldNumber = _getValue(row, 2, "Unknown");
      final count = widget.activityCounts[fieldNumber] ?? 0;

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

                  final isAudited = fieldData.isNotEmpty && _getValue(fieldData, 55, "NOT Audited") == "Audited";
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
                              builder: (context) => PspGenerativeDetailScreen(
                                fieldNumber: entry.key,
                                region: widget.selectedRegion ?? 'Unknown Region',
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
        ],
      ),
    );
  }

  Widget _buildHeatmapTab(List<List<String>> filteredData) {
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
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLegendItem(Colors.grey.shade200, '0 visited'),
                      _buildLegendItem(Colors.blue.shade200, '1 visited'),
                      _buildLegendItem(Colors.green.shade300, '2 visited'),
                      _buildLegendItem(Colors.amber.shade300, '3 visited'),
                      _buildLegendItem(Colors.orange.shade400, '4-5 visited'),
                      _buildLegendItem(Colors.red.shade500, '6+ visited'),
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
                    final activityCount = widget.activityCounts[fieldNumber] ?? 0;
                    final isAudited = _getValue(filteredData[index], 55, "NOT Audited") == "Audited";

                    return Tooltip(
                      message: '$fieldNumber: $activityCount visits${isAudited ? " (Audited)" : " (Not Audited)"}',
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PspGenerativeDetailScreen(
                                fieldNumber: fieldNumber,
                                region: widget.selectedRegion ?? 'Unknown Region',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getHeatmapColor(activityCount),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isAudited ? AppTheme.success : AppTheme.error,
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

  Color _getActivityCountColor(int count) {
    if (count == 0) return Colors.grey.shade300;
    if (count == 1) return Colors.blue.shade300;
    if (count == 2) return Colors.green.shade400;
    if (count == 3) return Colors.amber.shade400;
    if (count <= 5) return Colors.orange.shade500;
    return Colors.red.shade500;
  }

  String _formatPercentage(int part, int total) {
    if (total == 0) return '0.0';
    return ((part / total) * 100).toStringAsFixed(1);
  }

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
    final timestamps = widget.activityTimestamps[fieldNumber];

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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.accent),
            const SizedBox(width: 8),
            const Text('Info Mase!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Dashboard Tab',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Shows summary statistics and key metrics about Psp Generative activity. The cards display information about activity status, audit status, and area analysis.',
              ),
              SizedBox(height: 12),

              Text(
                'Heatmap Tab',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Displays a grid view of fields with color coding based on activity count. Green border indicates audited fields, red border indicates not audited fields.',
              ),
              SizedBox(height: 12),
              Text(
                'Filtering & Searching',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Use the search box to find specific fields by field number, farmer name, etc. Use the filter options to show only audited or not audited fields.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}