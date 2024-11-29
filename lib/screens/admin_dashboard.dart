import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'google_sheets_api.dart';
import 'admin_storage_service.dart';
import 'login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  final AdminStorageService storageService = AdminStorageService();
  final GoogleSheetsApi _googleSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
  final String _worksheetAbsenTitle = 'Absen Log';
  final String _worksheetAktivitasTitle = 'Aktivitas';

  late Future<ListResult> futureFiles;
  Future<List<List<String>>> futureAbsensiData = Future.value([]);
  Future<List<List<String>>> futureAktivitasData = Future.value([]);

  @override
  void initState() {
    super.initState();
    futureFiles = storageService.listFiles();
    _loadSheetData();  // Load data pertama kali saat inisialisasi

    _initGoogleSheets().then((_) {
      setState(() {
        futureAbsensiData = _fetchAbsensiData();
        futureAktivitasData = _fetchAktivitasData();
      });
    });
  }

  Future<void> _loadSheetData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        futureAbsensiData = _fetchAbsensiData();
        futureAktivitasData = _fetchAktivitasData();
        futureFiles = storageService.listFiles();
      });
    } else {
      // Jika tidak refresh, inisialisasi data tanpa setState untuk pertama kali
      futureAbsensiData = _fetchAbsensiData();
      futureAktivitasData = _fetchAktivitasData();
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

  String formatTimestamp(String serialTimestamp) {
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
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: LiquidPullToRefresh(
        onRefresh: () => _loadSheetData(refresh: true),
        color: Colors.green,
        backgroundColor: Colors.white,
        child: _buildDashboardView(),
      ),
    );
  }

  Future<void> _initGoogleSheets() async {
    try {
      await _googleSheetsApi.init();
      debugPrint('Google Sheets API berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('Error inisialisasi Google Sheets API: $e');
      await _showNotificationDialog('Error', 'Gagal menginisialisasi Google Sheets API. Coba lagi nanti.');
    }
  }

  Future<List<List<String>>> _fetchAbsensiData() async {
    try {
      final data = await _googleSheetsApi.getSpreadsheetData(_worksheetAbsenTitle);
      debugPrint('Data Absensi: $data');
      return data;
    } catch (e) {
      debugPrint('Error mengambil data Absensi: ${e.toString()}');
      return [];
    }
  }

  Future<List<List<String>>> _fetchAktivitasData() async {
    try {
      final data = await _googleSheetsApi.getSpreadsheetData(_worksheetAktivitasTitle);
      debugPrint('Data Aktivitas: $data');
      return data;
    } catch (e) {
      debugPrint('Error mengambil data Aktivitas: ${e.toString()}');
      return [];
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userRole');
    if (mounted) {
      await _showNotificationDialog('Logout Berhasil', 'Anda telah berhasil logout.');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _showNotificationDialog(String title, String content) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDashboardView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildAbsensiCard('Absensi Log', [
            _buildAttendanceChart(),
            const SizedBox(height: 20),
            _buildAbsensiTableWidget(),
          ]),
          const SizedBox(height: 20),
          _buildAktivitasCard('Aktivitas', [
            _buildAktivitasTableWidget(),
          ]),
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return FutureBuilder<List<List<String>>>(
      future: futureAbsensiData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada data absensi.'));
        } else {
          // Mengumpulkan data kehadiran berdasarkan tanggal
          Map<String, int> attendanceCount = {};
          for (var row in snapshot.data!.skip(1)) { // Lewati header
            String tanggal = formatTanggal(row[1]); // Menggunakan tanggal yang sudah diformat
            if (attendanceCount.containsKey(tanggal)) {
              attendanceCount[tanggal] = attendanceCount[tanggal]! + 1;
            } else {
              attendanceCount[tanggal] = 1;
            }
          }

          // Mengonversi data ke dalam format yang sesuai untuk BarChart
          List<BarChartGroupData> barGroups = [];
          int index = 0;
          attendanceCount.forEach((tanggal, count) {
            barGroups.add(
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: count.toDouble(),
                    width: 15, // Lebar batang
                  ),
                ],
                showingTooltipIndicators: [0],
              ),
            );
            index++;
          });

          return SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: attendanceCount.values.isNotEmpty ? attendanceCount.values.reduce((a, b) => a > b ? a : b).toDouble() + 1 : 10,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(attendanceCount.keys.elementAt(value.toInt()));
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildAbsensiTableWidget() {
    return FutureBuilder<List<List<String>>>(
      future: futureAbsensiData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada data absen.'));
        } else {
          return _buildAbsensiTable(snapshot.data!);
        }
      },
    );
  }

  Widget _buildAktivitasTableWidget() {
    return FutureBuilder<List<List<String>>>(
      future: futureAktivitasData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada data aktivitas.'));
        } else {
          return _buildAktivitasTable(snapshot.data!);
        }
      },
    );
  }

  Widget _buildAbsensiTable(List<List<String>> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Nama')),
          DataColumn(label: Text('Tanggal')),
          DataColumn(label: Text('Waktu Masuk')),
          DataColumn(label: Text('Lokasi')),
        ],
        rows: data.map((row) {
          return DataRow(cells: [
            DataCell(Text(row[0])),
            DataCell(Text(formatTanggal(row[1]))),
            DataCell(Text(formatWaktu(row[2]))),
            DataCell(Text(row[3])),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildAktivitasTable(List<List<String>> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
          DataColumn(label: Text('')),
        ],
        rows: data.map((row) {
          return DataRow(cells: [
            DataCell(Text(row[0])),
            DataCell(Text(row[1])),
            DataCell(Text(row[2])),
            DataCell(Text(row[3])),
            DataCell(Text(row[4])),
            DataCell(Text(row[5])),
            DataCell(Text(formatTimestamp(row[6]))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildAbsensiCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Column(children: children),
          ],
        ),
      ),
    );
  }

  Widget _buildAktivitasCard(String title, List<Widget> children) {
    return Card(
      color: Colors.green[50],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Column(children: children),
          ],
        ),
      ),
    );
  }
}
