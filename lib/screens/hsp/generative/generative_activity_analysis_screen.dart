import 'package:flutter/material.dart';
import 'analysis_dashboard_tab.dart';
import 'analysis_heatmap_tab.dart';

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

class GenerativeActivityAnalysisScreen extends StatefulWidget {
  final Map<String, int> activityCounts;
  final Map<String, List<DateTime>> activityTimestamps;
  final List<List<String>> generativeData;
  final String? selectedRegion;

  const GenerativeActivityAnalysisScreen({
    super.key,
    required this.activityCounts,
    required this.activityTimestamps,
    required this.generativeData,
    this.selectedRegion,
  });

  @override
  State<GenerativeActivityAnalysisScreen> createState() => _GenerativeActivityAnalysisScreenState();
}

class _GenerativeActivityAnalysisScreenState extends State<GenerativeActivityAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Audit status constants
  static const String _auditStatusSampun = "Sampun";
  static const String _auditStatusDerengJangkep = "Dereng Jangkep";
  static const String _auditStatusDerengBlas = "Dereng Blas";

  // Filters
  String _searchQuery = '';
  bool _showAuditedOnly = false;
  bool _showNotAuditedOnly = false;

  // Sorting
  final String _sortColumn = 'activityCount';
  final bool _sortAscending = false;

  // Filter state variables
  final bool _showSampunOnly = false;
  final bool _showDerengJangkepOnly = false;
  final bool _showDerengBlasOnly = false;

  // Count variables for audit status
  int sampunCount = 0;
  int derengJangkepCount = 0;
  int derengBlasCount = 0;

  // Activity count variables
  int sampunWithActivity = 0;
  int derengJangkepWithActivity = 0;
  int derengBlasWithActivity = 0;

  // Area variables
  double sampunArea = 0.0;
  double derengJangkepArea = 0.0;
  double derengBlasArea = 0.0;

  // Calculated statistics
  int _fieldsWithActivity = 0;
  Map<int, int> _activityDistribution = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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

  String getAuditStatus(List<String> row) {
    // Get values from columns BT and BU (assuming these are indices 71 and 72)
    // Note: Adjust these indices based on the actual position of columns BT and BU
    final btValue = getValue(row, 72, "").trim().toLowerCase();
    final buValue = getValue(row, 73, "").trim().toLowerCase();

    // Check for "Audited" status in both columns
    final isBtAudited = btValue == "audited";
    final isBuAudited = buValue == "audited";

    if (isBtAudited && isBuAudited) {
      // Both columns show "Audited"
      return _auditStatusSampun;
    } else if (isBtAudited || isBuAudited) {
      // Only one column shows "Audited"
      return _auditStatusDerengJangkep;
    } else {
      // Neither column shows "Audited"
      return _auditStatusDerengBlas;
    }
  }

  Color getAuditStatusColor(String status) {
    switch (status) {
      case _auditStatusSampun:
        return AppTheme.success;
      case _auditStatusDerengJangkep:
        return AppTheme.warning;
      case _auditStatusDerengBlas:
        return AppTheme.error;
      default:
        return AppTheme.error;
    }
  }

  IconData getAuditStatusIcon(String status) {
    switch (status) {
      case _auditStatusSampun:
        return Icons.check_circle;
      case _auditStatusDerengJangkep:
        return Icons.warning;
      case _auditStatusDerengBlas:
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  void _calculateStatistics() {
    // Basic counts
    _fieldsWithActivity = widget.activityCounts.keys.length;

    // Activity distribution
    _activityDistribution = {};
    for (var count in widget.activityCounts.values) {
      _activityDistribution[count] = (_activityDistribution[count] ?? 0) + 1;
    }

    sampunCount = 0;
    derengJangkepCount = 0;
    derengBlasCount = 0;

    sampunWithActivity = 0;
    derengJangkepWithActivity = 0;
    derengBlasWithActivity = 0;

    sampunArea = 0.0;
    derengJangkepArea = 0.0;
    derengBlasArea = 0.0;

    for (var row in widget.generativeData) {
      final fieldNumber = getValue(row, 2, "Unknown");
      final auditStatus = getAuditStatus(row);
      final hasActivity = widget.activityCounts.containsKey(fieldNumber);

      // Calculate effective area
      final effectiveAreaStr = getValue(row, 8, "0").replaceAll(',', '.');
      final effectiveArea = double.tryParse(effectiveAreaStr) ?? 0.0;

      if (auditStatus == _auditStatusSampun) {
        sampunCount++;
        sampunArea += effectiveArea;
        if (hasActivity) sampunWithActivity++;
      } else if (auditStatus == _auditStatusDerengJangkep) {
        derengJangkepCount++;
        derengJangkepArea += effectiveArea;
        if (hasActivity) derengJangkepWithActivity++;
      } else {
        derengBlasCount++;
        derengBlasArea += effectiveArea;
        if (hasActivity) derengBlasWithActivity++;
      }
    }
  }

  List<List<String>> getFilteredData() {
    return widget.generativeData.where((row) {
      final fieldNumber = getValue(row, 2, "Unknown").toLowerCase();
      final farmerName = getValue(row, 3, "Unknown").toLowerCase();
      final growerName = getValue(row, 4, "Unknown").toLowerCase();
      final hybrid = getValue(row, 5, "Unknown").toLowerCase();
      final auditStatus = getAuditStatus(row);

      // Apply search filter
      bool matchesSearch = _searchQuery.isEmpty ||
          fieldNumber.contains(_searchQuery.toLowerCase()) ||
          farmerName.contains(_searchQuery.toLowerCase()) ||
          growerName.contains(_searchQuery.toLowerCase()) ||
          hybrid.contains(_searchQuery.toLowerCase());

      // Apply audit status filter
      bool matchesAuditStatus = true;
      if (_showSampunOnly && auditStatus != _auditStatusSampun) matchesAuditStatus = false;
      if (_showDerengJangkepOnly && auditStatus != _auditStatusDerengJangkep) matchesAuditStatus = false;
      if (_showDerengBlasOnly && auditStatus != _auditStatusDerengBlas) matchesAuditStatus = false;

      return matchesSearch && matchesAuditStatus;
    }).toList();
  }

  List<List<String>> getSortedData(List<List<String>> filteredData) {
    final sortedData = List<List<String>>.from(filteredData);

    switch (_sortColumn) {
      case 'fieldNumber':
        sortedData.sort((a, b) {
          final fieldNumberA = getValue(a, 2, "");
          final fieldNumberB = getValue(b, 2, "");
          return _sortAscending
              ? fieldNumberA.compareTo(fieldNumberB)
              : fieldNumberB.compareTo(fieldNumberA);
        });
        break;
      case 'activityCount':
        sortedData.sort((a, b) {
          final fieldNumberA = getValue(a, 2, "");
          final fieldNumberB = getValue(b, 2, "");
          final countA = widget.activityCounts[fieldNumberA] ?? 0;
          final countB = widget.activityCounts[fieldNumberB] ?? 0;
          return _sortAscending
              ? countA.compareTo(countB)
              : countB.compareTo(countA);
        });
        break;
      case 'auditStatus':
        sortedData.sort((a, b) {
          final statusA = getAuditStatus(a);
          final statusB = getAuditStatus(b);
          return _sortAscending
              ? statusA.compareTo(statusB)
              : statusB.compareTo(statusA);
        });
        break;
      case 'dap':
        sortedData.sort((a, b) {
          final dapA = calculateDAP(a);
          final dapB = calculateDAP(b);
          return _sortAscending
              ? dapA.compareTo(dapB)
              : dapB.compareTo(dapA);
        });
        break;
      case 'area':
        sortedData.sort((a, b) {
          final areaStrA = getValue(a, 8, "0").replaceAll(',', '.');
          final areaStrB = getValue(b, 8, "0").replaceAll(',', '.');
          final areaA = double.tryParse(areaStrA) ?? 0.0;
          final areaB = double.tryParse(areaStrB) ?? 0.0;
          return _sortAscending
              ? areaA.compareTo(areaB)
              : areaB.compareTo(areaA);
        });
        break;
      case 'farmer':
        sortedData.sort((a, b) {
          final farmerA = getValue(a, 3, "Unknown");
          final farmerB = getValue(b, 3, "Unknown");
          return _sortAscending
              ? farmerA.compareTo(farmerB)
              : farmerB.compareTo(farmerA);
        });
        break;
    }

    return sortedData;
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = getFilteredData();

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
          AnalysisDashboardTab(
            filteredData: filteredData,
            activityCounts: widget.activityCounts,
            activityTimestamps: widget.activityTimestamps,
            sampunCount: sampunCount,
            derengJangkepCount: derengJangkepCount,
            derengBlasCount: derengBlasCount,
            sampunWithActivity: sampunWithActivity,
            derengJangkepWithActivity: derengJangkepWithActivity,
            derengBlasWithActivity: derengBlasWithActivity,
            sampunArea: sampunArea,
            derengJangkepArea: derengJangkepArea,
            derengBlasArea: derengBlasArea,
            fieldsWithActivity: _fieldsWithActivity,
            searchQuery: _searchQuery,
            showAuditedOnly: _showAuditedOnly,
            showNotAuditedOnly: _showNotAuditedOnly,
            tabController: _tabController,
            selectedRegion: widget.selectedRegion,
            getAuditStatus: getAuditStatus,
            getAuditStatusColor: getAuditStatusColor,
            getAuditStatusIcon: getAuditStatusIcon,
          ),

          // Heatmap Tab
          AnalysisHeatmapTab(
            filteredData: filteredData,
            activityCounts: widget.activityCounts,
            selectedRegion: widget.selectedRegion,
            getAuditStatus: getAuditStatus,
            getAuditStatusColor: getAuditStatusColor,
          ),
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
                'Audit Status Categories',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                  '• Sampun: Display all phases marked as "Audited"\n'
                      '• Dereng Jangkep: Display at least one phase marked as "Audited," but not all\n'
                      '• Dereng Blas: Display no phases marked as "Audited"'
              ),
              SizedBox(height: 12),

              Text(
                'Dashboard Tab',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Shows summary statistics and key metrics about generative activity. The cards display information about activity status, audit status, and area analysis.',
              ),
              SizedBox(height: 12),

              Text(
                'Heatmap Tab',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Displays a grid view of fields with color coding based on activity count. Border colors indicate audit status: green for Sampun, yellow for Dereng Jangkep, and red for Dereng Blas.',
              ),
              SizedBox(height: 12),

              Text(
                'Filtering & Searching',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(
                'Use the search box to find specific fields by field number, farmer name, etc. Use the filter options to show fields with specific audit statuses.',
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

  // Utility functions
  static String getValue(List<String> row, int index, String defaultValue) {
    if (row.isEmpty || index >= row.length) return defaultValue;
    return row[index];
  }

  static int calculateDAP(List<String> row) {
    try {
      final plantingDate = getValue(row, 9, ''); // Get planting date from column 9
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
}