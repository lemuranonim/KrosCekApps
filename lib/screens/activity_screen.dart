import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_sheets_api.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  ActivityScreenState createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> {
  List<List<String>> _activityLogs = [];
  bool _isLoading = true;

  final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';
  final String worksheetTitle = 'Aktivitas';
  late final GoogleSheetsApi _googleSheetsApi;

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
    _loadUserDataAndFetchLogs();
  }

  // Ambil userEmail dan userName dari SharedPreferences lalu ambil log aktivitas
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
    try {
      // Ambil semua data dari Google Sheets
      final rows = await _googleSheetsApi.getSpreadsheetData(worksheetTitle);

      // Filter data untuk mencocokkan userEmail atau userName
      setState(() {
        _activityLogs = rows
            .skip(1) // Lewati header
            .where((row) => row[0] == userEmail || row[1] == userName)
            .toList();
      });
    } catch (e) {
      // print('Error fetching data: $e');
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final originalFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
      final dateTime = originalFormat.parse(timestamp);
      final newFormat = DateFormat('EEEE, dd MMM yyyy, HH:mm');
      return newFormat.format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  String formatTanggal(String serialTanggal) {
    try {
      final int daysSince1900 = int.parse(serialTanggal);
      final DateTime date = DateTime(1900, 1, 1).add(Duration(days: daysSince1900 - 2));
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return serialTanggal; // Mengembalikan nilai asli jika bukan angka
    }
  }

  String formatWaktu(String serialWaktu) {
    try {
      final double fractionalDay = double.parse(serialWaktu);
      final int totalSeconds = (fractionalDay * 86400).round();
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int seconds = totalSeconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return serialWaktu; // Mengembalikan nilai asli jika bukan angka
    }
  }

  String _formatTimestamp(String serialTimestamp) {
    try {
      // Pisahkan bagian integer (hari) dan desimal (waktu)
      final double serial = double.parse(serialTimestamp);
      final int daysSince1900 = serial.floor();
      final double fractionalDay = serial - daysSince1900;

      // Konversi ke tanggal berdasarkan hari sejak 1 Jan 1900
      final DateTime date = DateTime(1900, 1, 1).add(Duration(days: daysSince1900 - 2));

      // Hitung waktu berdasarkan bagian desimal dari hari
      final int totalSeconds = (fractionalDay * 86400).round();
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int seconds = totalSeconds % 60;

      // Format gabungan tanggal dan waktu
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(
        DateTime(date.year, date.month, date.day, hours, minutes, seconds),
      );
    } catch (e) {
      return serialTimestamp; // Mengembalikan nilai asli jika terjadi error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LiquidPullToRefresh(
        onRefresh: _loadUserDataAndFetchLogs, // Tambahkan fungsi refresh
        color: Colors.green,
        child: _buildLogActivityList(),
      ),
    );
  }

  // Fungsi untuk membangun daftar log aktivitas berdasarkan filter userEmail atau userName
  Widget _buildLogActivityList() {
    if (_activityLogs.isEmpty) {
      return const Center(child: Text('Tidak ada aktivitas yang tercatat'));
    }

    return ListView.builder(
      itemCount: _activityLogs.length,
      itemBuilder: (context, index) {
        final log = _activityLogs[index];
        return ListTile(
          title: Text(
            log[3],
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: log[2]),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Sheet: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: log[4]),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Field Number: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: log[5]),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Waktu: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: _formatTimestamp(log[6])),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
