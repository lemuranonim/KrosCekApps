import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'login_screen.dart';
import 'regions_dashboard.dart';
import 'absensi_dashboard.dart';
import 'aktivitas_dashboard.dart';
import 'account_management.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {

  @override
  void initState() {
    super.initState();
    _loadSheetData();  // Load data pertama kali saat inisialisasi
  }

  Future<void> _loadSheetData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
      });
    } else {
      // Jika tidak refresh, inisialisasi data tanpa setState untuk pertama kali

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
          // Card untuk Regions Dashboard
          _buildNavigationCard(
            icon: Icons.account_circle_rounded,
            title: 'Accounts Management',
            destination: const AccountManagement(),
          ),
          const SizedBox(height: 20),
          // Card untuk Regions Dashboard
          _buildNavigationCard(
            icon: Icons.map_rounded,
            title: 'Regions Management',
            destination: const RegionsDashboard(),
          ),
          const SizedBox(height: 20),
          // Card baru untuk Absensi Dashboard
          _buildNavigationCard(
            icon: Icons.checklist_rounded,
            title: 'Absensi Dashboard',
            destination: const AbsensiDashboard(), // Your Absensi Dashboard widget
          ),
          const SizedBox(height: 20),
          // Card baru untuk Aktivitas Dashboard
          _buildNavigationCard(
            icon: Icons.history_rounded,
            title: 'Aktivitas Dashboard',
            destination: const AktivitasDashboard(), // Your Absensi Dashboard widget
          ),
        ],
      ),
    );
  }

  // New reusable card widget for navigation
  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required Widget destination,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.green, size: 40),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }
}
