import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:sidebarx/sidebarx.dart';
// import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  final _controller = SidebarXController(selectedIndex: 6, extended: true);
  final _key = GlobalKey<ScaffoldState>();
  String _appVersion = 'Production Final Version';

  @override
  void initState() {
    super.initState();
    _loadSheetData();
    _getAppVersion();
  }

  Future<void> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'Updated Version ${packageInfo.version}';
      });
    } catch (e) {
      // If there's an error, keep the default version
    }
  }

  Future<void> _loadSheetData({bool refresh = false}) async {
    if (refresh) {
      setState(() {});
    }
  }

  String formatTanggal(String serialTanggal) {
    try {
      final int daysSince1900 = int.parse(serialTanggal);
      final DateTime date = DateTime(1900, 1, 1).add(Duration(days: daysSince1900 - 2));
      return DateFormat('dd-MM-yyyy').format(date);
    } catch (e) {
      return serialTanggal;
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
      return serialWaktu;
    }
  }

  String formatTimestamp(String serialTimestamp) {
    try {
      final double serial = double.parse(serialTimestamp);
      final int daysSince1900 = serial.floor();
      final double fractionalDay = serial - daysSince1900;
      final DateTime date = DateTime(1900, 1, 1).add(Duration(days: daysSince1900 - 2));
      final int totalSeconds = (fractionalDay * 86400).round();
      final int hours = totalSeconds ~/ 3600;
      final int minutes = (totalSeconds % 3600) ~/ 60;
      final int seconds = totalSeconds % 60;
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(
        DateTime(date.year, date.month, date.day, hours, minutes, seconds),
      );
    } catch (e) {
      return serialTimestamp;
    }
  }

  void _handleBackInHomeScreen() {
    // If not, show a confirmation dialog for logout
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  "Konfirmasi Medal",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                // Content
                Text(
                  "Menopo panjenengan badhe medal saking aplikasi puniko?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        "Batal",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        // Exit the app
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Use backgroundColor instead of primary
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        "Medal",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ), // Ensure child is the last parameter
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Callback saat pengguna menekan tombol back
      canPop: false, // Mencegah pop langsung
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        // didPop akan false karena canPop: false
        if (!didPop) {
          _handleBackInHomeScreen();
        }
        return;
      },
      child: Scaffold(
        key: _key,
        appBar: AppBar(
          title: const Text('Admin Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _key.currentState?.openDrawer();
            },
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade800, Colors.green.shade600],
              ),
            ),
          ),
          actions: [],
        ),
        drawer: SidebarX(
          controller: _controller,
          theme: SidebarXTheme(
            // Improved background
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(0),
            ),
            // Better text styling
            textStyle: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            selectedTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            // Improved padding and spacing
            itemTextPadding: const EdgeInsets.only(left: 16),
            selectedItemTextPadding: const EdgeInsets.only(left: 16),
            // Better item decoration
            itemDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.transparent),
            ),
            selectedItemDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.green.shade600,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(51),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            // Improved icon styling
            iconTheme: const IconThemeData(
              color: Colors.black54,
              size: 22,
            ),
            selectedIconTheme: const IconThemeData(
              color: Colors.white,
              size: 22,
            ),
          ),
          headerBuilder: (context, extended) {
            return Container(
              height: 120,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade100,
                    radius: 30,
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Colors.green.shade700,
                      size: 30,
                    ),
                  ),
                  if (extended) ...[  // Only show text when extended
                    const SizedBox(height: 8),
                    Text(
                      'Admin Panel',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          footerBuilder: (context, extended) {
            return Container(
              height: 50,
              color: Colors.green.shade50,
              child: Center(
                child: Text(
                  _appVersion,
                  style: GoogleFonts.manrope(
                    color: Colors.green.shade800,
                    fontSize: 11,
                  ),
                ),
              ),
            );
          },
          extendedTheme: const SidebarXTheme(
            width: 240,
            margin: EdgeInsets.only(right: 10),
          ),
          items: [
            SidebarXItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () {
                context.go('/admin');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(
              icon: Icons.account_circle_outlined,
              label: 'Accounts Management',
              onTap: () {
                context.go('/accounts');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(
              icon: Icons.map_outlined,
              label: 'Regions Management',
              onTap: () {
                context.go('/regions');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(
              icon: Icons.checklist_outlined,
              label: 'Absensi Dashboard',
              onTap: () {
                context.go('/absensi');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(
              icon: Icons.history_outlined,
              label: 'Aktivitas Dashboard',
              onTap: () {
                context.go('/aktivitas');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(
              icon: Icons.settings_outlined,
              label: 'Config Management',
              onTap: () {
                context.go('/config');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(
              icon: Icons.filter_list_outlined,
              label: 'Filter Regions',
              onTap: () {
                context.go('/filter');
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            SidebarXItem(),
            SidebarXItem(
              icon: Icons.logout,
              label: 'Logout',
              onTap: () {
                if (_key.currentState?.isDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
                _logout();
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Sugêng Rawuh Poro SPV',
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Under Maintenance Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade100, Colors.orange.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.construction,
                          size: 80,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Under Maintenance',
                          style: GoogleFonts.poppins(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dashboard sedang dalam proses pengembangan. Fitur-fitur baru akan segera tersedia.',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Estimasi selesai: 19 Mei 2025',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w500,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                // _buildRegionChart(),
                const SizedBox(height: 20),
                // _buildActivityChart(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildRegionChart() {
  //   return SizedBox(
  //     height: 300,
  //     child: BarChart(
  //       BarChartData(
  //         titlesData: FlTitlesData(
  //           leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
  //           bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
  //         ),
  //         borderData: FlBorderData(show: true),
  //         barGroups: regionData.entries.map((entry) {
  //           return BarChartGroupData(
  //             x: entry.key.hashCode,
  //             barRods: [
  //               BarChartRodData(
  //                 toY: entry.value.toDouble(),
  //                 color: Colors.green,
  //               ),
  //             ],
  //           );
  //         }).toList(),
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildActivityChart() {
  //   return SizedBox(
  //     height: 300,
  //     child: PieChart(
  //       PieChartData(
  //         sections: activityData.entries.map((entry) {
  //           return PieChartSectionData(
  //             value: entry.value.toDouble(),
  //             title: entry.key,
  //             color: Colors.primaries[activityData.keys.toList().indexOf(entry.key) % Colors.primaries.length],
  //           );
  //         }).toList(),
  //       ),
  //     ),
  //   );
  // }

  Future<void> _logout() async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            "Konfirmasi Medal",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          content: const Text("Menopo panjenengan yakin badhe medal gantos akun?"),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    "Batal",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    "Medal",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userRole');
      if (mounted) {
        _showNotificationDialog('Logout Successful', 'You have successfully logged out.');
        context.go('/login');
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
}