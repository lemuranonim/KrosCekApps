import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_sheets_api.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'config_manager.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  ActivityScreenState createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> {
  List<List<String>> _activityLogs = [];
  bool _isLoading = true;

  final String worksheetTitle = 'Aktivitas';
  late GoogleSheetsApi _googleSheetsApi;

  @override
  void initState() {
    super.initState();
    _initializeConfigAndLoadData(); // Panggil fungsi untuk muat konfigurasi dan data
  }

  Future<void> _initializeConfigAndLoadData() async {
    // Muat konfigurasi dari config.json
    await ConfigManager.loadConfig();

    // Ambil semua spreadsheet ID dari config.json
    final List<String> spreadsheetIds = ConfigManager.getAllSpreadsheetIds();

    // Inisialisasi API untuk spreadsheet pertama (contoh)
    _googleSheetsApi = GoogleSheetsApi(spreadsheetIds.first);

    // Ambil data log aktivitas dari semua spreadsheet
    await _loadUserDataAndFetchLogs();

    setState(() {});
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
    List<List<String>> allLogs = [];

    try {
      // Ambil semua Spreadsheet ID dari ConfigManager
      final List<String> spreadsheetIds = ConfigManager.getAllSpreadsheetIds();

      for (String id in spreadsheetIds) {
        // Inisialisasi API untuk setiap Spreadsheet ID
        final api = GoogleSheetsApi(id);
        await api.init();

        // Ambil data dari worksheet 'Aktivitas'
        final rows = await api.getSpreadsheetData('Aktivitas');

        // Filter data berdasarkan userEmail atau userName
        final filteredLogs = rows
            .skip(1) // Lewati header
            .where((row) => row[0] == userEmail || row[1] == userName)
            .toList();

        allLogs.addAll(filteredLogs); // Gabungkan semua data yang cocok
      }

      // Perbarui state dengan semua log yang ditemukan
      setState(() {
        _activityLogs = allLogs;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
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
            log[4],
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
                      text: 'Region: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: log[3]),
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
                    TextSpan(text: log[5]),
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
                    TextSpan(text: log[6]),
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
                    TextSpan(text: _formatTimestamp(log[7])),
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
