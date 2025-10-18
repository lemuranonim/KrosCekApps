import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class PspActivityScreen extends StatefulWidget {
  const PspActivityScreen({super.key});

  @override
  PspActivityScreenState createState() => PspActivityScreenState();
}

class PspActivityScreenState extends State<PspActivityScreen> {
  List<List<String>> _activityLogs = [];
  bool _isLoading = true;

  final String worksheetTitle = 'Aktivitas';
  late GoogleSheetsApi _googleSheetsApi;

  @override
  void initState() {
    super.initState();
    _initializeConfigAndLoadData();
  }

  Future<void> _initializeConfigAndLoadData() async {
    await ConfigManager.loadConfig();
    final List<String> spreadsheetIds = ConfigManager.getAllSpreadsheetIds();
    _googleSheetsApi = GoogleSheetsApi(spreadsheetIds.first);
    await _loadUserDataAndFetchLogs();
    setState(() {});
  }

  Future<void> _loadUserDataAndFetchLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    final userName = prefs.getString('userName');

    await _googleSheetsApi.init();

    if (userEmail != null || userName != null) {
      await _fetchActivityLogs(userEmail, userName);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchActivityLogs(String? userEmail, String? userName) async {
    List<List<String>> allLogs = [];

    try {
      final List<String> spreadsheetIds = ConfigManager.getAllSpreadsheetIds();

      for (String id in spreadsheetIds) {
        final api = GoogleSheetsApi(id);
        await api.init();
        final rows = await api.getSpreadsheetData('Aktivitas');
        final filteredLogs = rows
            .skip(1)
            .where((row) => row[0] == userEmail || row[1] == userName)
            .toList();
        allLogs.addAll(filteredLogs);
      }

      // Sort logs by timestamp (newest first)
      allLogs.sort((a, b) {
        try {
          final double timestampA = double.parse(a[7]);
          final double timestampB = double.parse(b[7]);
          return timestampB.compareTo(timestampA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _activityLogs = allLogs;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
    }
  }

  String _formatTimestamp(String serialTimestamp) {
    try {
      final double serial = double.parse(serialTimestamp);
      final int daysSince1900 = serial.floor();
      final double fractionalDay = serial - daysSince1900;

      final DateTime date = DateTime(1900, 1, 1).add(Duration(days: daysSince1900 - 2));

      final int totalSeconds = (fractionalDay * 86400).round();
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int seconds = totalSeconds % 60;

      return DateFormat('dd MMM yyyy • HH:mm').format(
        DateTime(date.year, date.month, date.day, hours, minutes, seconds),
      );
    } catch (e) {
      return serialTimestamp;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'berhasil':
        return Colors.green;
      case 'failed':
      case 'gagal':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getActionIcon(String action) {
    if (action.toLowerCase().contains('tambah')) return Icons.add_circle_outline;
    if (action.toLowerCase().contains('edit')) return Icons.edit_outlined;
    if (action.toLowerCase().contains('hapus')) return Icons.delete_outline;
    if (action.toLowerCase().contains('login')) return Icons.login;
    if (action.toLowerCase().contains('logout')) return Icons.logout;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/loading.json',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            const Text(
              'Loading activity logs...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : LiquidPullToRefresh(
        onRefresh: _loadUserDataAndFetchLogs,
        color: Colors.orange[700],
        height: 100,
        backgroundColor: Colors.white,
        animSpeedFactor: 2,
        showChildOpacityTransition: false,
        child: _buildLogActivityList(),
      ),
    );
  }

  Widget _buildLogActivityList() {
    if (_activityLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/empty.json', // Add an empty state animation
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            const Text(
              'No activity records found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pull down to refresh',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: _activityLogs.length,
        itemBuilder: (context, index) {
          final log = _activityLogs[index];
          final status = log[2];
          final region = log[3];
          final action = log[4];
          final sheet = log[5];
          final fieldNumber = log[6];
          final timestamp = _formatTimestamp(log[7]);

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getActionIcon(action),
                                color: _getStatusColor(status),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timestamp,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        _buildInfoRow('Region', region),
                        _buildInfoRow('Sheet', sheet), _buildInfoRow('Field Number', fieldNumber),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}