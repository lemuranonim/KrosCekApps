import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/config_manager.dart';
import 'dashboard_analytics_tab.dart';
import 'dashboard_absensi_tab.dart';
import 'dashboard_aktivitas_tab.dart';
import 'data_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final _key = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  final ZoomDrawerController _drawerController = ZoomDrawerController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  String? userPhotoUrl;
  String _selectedRegion = '';
  List<String> _availableRegions = [];

  late TabController _tabController;
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // Load configurations from Firestore first
      await ConfigManager.loadConfig();

      // Fetch user data and app version
      await _fetchAppVersion();
      await _fetchUserData();
      await _fetchGoogleUserData();
      await _loadUserEmail();

      // Initialize data service with configurations
      await _dataService.initialize();

      // Load available regions from ConfigManager
      _availableRegions = ConfigManager.getAllRegionNames();

      // Set selected region
      final prefs = await SharedPreferences.getInstance();
      _selectedRegion = prefs.getString('selectedRegion') ?? '';

      if (_selectedRegion.isEmpty && _availableRegions.isNotEmpty) {
        _selectedRegion = _availableRegions.first;
        await prefs.setString('selectedRegion', _selectedRegion);
      }

      // Update data service with selected region
      if (_selectedRegion.isNotEmpty) {
        await _dataService.setSelectedRegion(_selectedRegion);
      }
    } catch (e) {
      debugPrint("Error loading initial data: $e");
      _showErrorMessage("Gagal memuat data: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Email tidak ditemukan';
    });
  }

  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  Future<void> _fetchGoogleUserData() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        setState(() {
          userName = googleUser.displayName ?? 'Pengguna';
          userEmail = googleUser.email;
          userPhotoUrl = googleUser.photoUrl;
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', googleUser.displayName ?? 'Pengguna');
        await prefs.setString('userEmail', googleUser.email);
        await prefs.setString('userPhotoUrl', googleUser.photoUrl ?? '');
      }
    } catch (error) {
      debugPrint("Error mengambil data Google: $error");
    }
  }

  Future<void> _logoutGoogle() async {
    await _googleSignIn.signOut();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reload configurations from Firestore
      await ConfigManager.loadConfig();

      // Update data service with current region
      if (_selectedRegion.isNotEmpty) {
        await _dataService.setSelectedRegion(_selectedRegion);
      }

      // Refresh all data
      await _dataService.refreshAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data berhasil diperbarui'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error refreshing data: $e");
      _showErrorMessage("Gagal memperbarui data: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onRegionChanged(String? region) async {
    if (region != null && region != _selectedRegion) {
      setState(() {
        _isLoading = true;
        _selectedRegion = region;
      });

      try {
        // Update data service with new region
        await _dataService.setSelectedRegion(region);

        // Save selected region to preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('selectedRegion', region);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Region diubah ke $region'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error changing region: $e");
        _showErrorMessage("Gagal mengubah region: ${e.toString()}");
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  void _handleBackInHomeScreen() {
    if (_drawerController.isOpen?.call() ?? false) {
      _drawerController.close?.call();
      return;
    }

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
                Text(
                  "Konfirmasi Medal",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Menopo panjenengan badhe medal saking aplikasi puniko?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      child: Text(
                        "Batal",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        context.pop(true);
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        elevation: 2,
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackInHomeScreen();
        }
        return;
      },
      child: ZoomDrawer(
        controller: _drawerController,
        style: DrawerStyle.defaultStyle,
        menuScreen: MenuScreen(
          userName: userName,
          userEmail: userEmail,
          userPhotoUrl: userPhotoUrl,
          appVersion: _appVersion,
          onAccountManagement: () => context.go('/accounts'),
          onRegions: () => context.go('/regions'),
          onAbsensi: () => context.go('/absensi'),
          // onAktivitas: () => context.go('/aktivitas'),
          onAuditDashboard: () => context.go('/audit_dashboard'),
          onWorkloadMap: () => context.go('/workload_map'),
          onCrud: () => context.go('/config'),
          onFilter: () => context.go('/filter'),
          onAuditGraph: () => context.go('/audit_graph'),
          onLogout: () => _logout(context),
        ),
        mainScreen: _buildMainScreen(context),
        borderRadius: 24.0,
        showShadow: true,
        angle: -1.0,
        slideWidth: MediaQuery.of(context).size.width * 0.95,
        openCurve: Curves.fastOutSlowIn,
        closeCurve: Curves.fastOutSlowIn,
        menuBackgroundColor: Colors.green[100]!,
      ),
    );
  }

  void _showRegionSelector() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Pilih Region",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: _availableRegions.map((region) {
                      return ListTile(
                        title: Text(region),
                        leading: Icon(
                          Icons.location_on,
                          color: _selectedRegion == region ? Colors.green : Colors.grey,
                        ),
                        selected: _selectedRegion == region,
                        selectedTileColor: Colors.green.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        onTap: () {
                          _onRegionChanged(region);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 10),
                ),
                child: const Text(
                  "Tutup",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);

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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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
      await _logoutGoogle();
      _navigateToLoginScreen(navigator);
    }
  }

  void _navigateToLoginScreen(NavigatorState navigator) {
    context.go('/login');
  }

  Widget _buildMainScreen(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (_selectedRegion.isNotEmpty)
              Text(
                'Region: $_selectedRegion',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade800, Colors.green.shade600],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _drawerController.toggle?.call(),
        ),
        actions: [

          // Region selector dropdown
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showRegionSelector,
            tooltip: 'Pilih Region',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          // IconButton(
          //   icon: const Icon(Icons.notifications_outlined),
          //   onPressed: () {
          //     // Add notification logic here
          //   },
          //   tooltip: 'Notifikasi',
          // ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined), // Ikon diubah agar lebih sesuai
            onPressed: () {
              // GANTI LOGIC LAMA DENGAN INI
              context.go('/notifications_management'); // Menggunakan GoRouter untuk navigasi
            },
            tooltip: 'Kirim Notifikasi',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_rounded),
              text: "Analytics",
            ),
            Tab(
              icon: Icon(Icons.assignment_turned_in_rounded),
              text: "Absensi",
            ),
            Tab(
              icon: Icon(Icons.trending_up_rounded),
              text: "Aktivitas",
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.green.shade50, Colors.white],
              ),
            ),
            child: TabBarView(
              controller: _tabController,
              children: [
                DashboardAnalyticsTab(
                  key: ValueKey<String>(_selectedRegion),
                  dataService: _dataService, // _dataService sudah di-update dengan region baru
                  isLoading: _isLoading,
                ),
                DashboardAbsensiTab(
                  key: ValueKey<String>(_selectedRegion),
                  dataService: _dataService, // _dataService sudah di-update dengan region baru
                ),
                DashboardAktivitasTab(
                  key: ValueKey<String>(_selectedRegion),
                  dataService: _dataService, // _dataService sudah di-update dengan region baru
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withAlpha(76),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Memuat data...',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'KC Dashboard v$_appVersion',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.green.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_dataService.getSpreadsheetId() != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Connected to Sheets',
                style: GoogleFonts.manrope(
                  color: Colors.green.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MenuScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userPhotoUrl;
  final String appVersion;
  final VoidCallback onLogout;
  final VoidCallback onAccountManagement;
  final VoidCallback onRegions;
  final VoidCallback onAbsensi;
  // final VoidCallback onAktivitas;
  final VoidCallback onWorkloadMap;
  final VoidCallback onCrud;
  final VoidCallback onFilter;
  final VoidCallback onAuditGraph;
  final VoidCallback onAuditDashboard;

  const MenuScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userPhotoUrl,
    required this.appVersion,
    required this.onLogout,
    required this.onAccountManagement,
    required this.onRegions,
    required this.onAbsensi,
    // required this.onAktivitas,
    required this.onWorkloadMap,
    required this.onCrud,
    required this.onFilter,
    required this.onAuditGraph,
    required this.onAuditDashboard,

  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.green,
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      minimumSize: const Size(double.infinity, 48), // Consistent button height
    );

    return Container(
      width: MediaQuery.of(context).size.width,
      height: screenHeight,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30.0),
          bottomRight: Radius.circular(30.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(2, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header dan user info
          Padding(
            padding: EdgeInsets.only(
              top: screenHeight * 0.1,
              left: 16,
              right: 16,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: screenHeight * 0.07,
                  backgroundColor: Colors.white,
                  backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                      ? NetworkImage(userPhotoUrl!)
                      : const AssetImage('assets/logo.png') as ImageProvider,
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  userEmail,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: Colors.white60,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Pemisah
          Container(
            width: 200,
            height: 1,
            color: Colors.white.withAlpha(76),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  // akun manajemen
                  ElevatedButton.icon(
                    onPressed: onAccountManagement,
                    icon: const Icon(
                      Icons.account_circle_outlined,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Akun Manajemen',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  // daftar region
                  ElevatedButton.icon(
                    onPressed: onRegions,
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Daftar Region',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  // absensi dashboard
                  ElevatedButton.icon(
                    onPressed: onAbsensi,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Absensi Dashboard',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  // // aktivitas dashboard
                  // ElevatedButton.icon(
                  //   onPressed: onAktivitas,
                  //   icon: const Icon(
                  //     Icons.list_alt_outlined,
                  //     size: 20,
                  //     color: Colors.green,
                  //   ),
                  //   label: const Text(
                  //     'Aktivitas Dashboard',
                  //     style: TextStyle(
                  //       color: Colors.green,
                  //       fontWeight: FontWeight.bold,
                  //     ),
                  //   ),
                  //   style: buttonStyle,
                  // ),
                  // const SizedBox(height: 10),
                  // Audit Dashboard
                  ElevatedButton.icon(
                    onPressed: onAuditDashboard,
                    icon: const Icon(
                      Icons.dashboard_outlined,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Audit Dashboard',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),

                  // audit graph
                  ElevatedButton.icon(
                    onPressed: onAuditGraph, // <-- PANGGIL CALLBACK
                    icon: const Icon(
                      Icons.pivot_table_chart_outlined, // Icon yang cocok
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Audit Graph',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  // workload map
                  ElevatedButton.icon(
                    onPressed: onWorkloadMap,
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Workload Map',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  // filter region
                  ElevatedButton.icon(
                    onPressed: onFilter,
                    icon: const Icon(
                      Icons.filter_list,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Filter Region',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  // Pengaturan
                  ElevatedButton.icon(
                    onPressed: onCrud,
                    icon: const Icon(
                      Icons.settings,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Pengaturan',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: buttonStyle,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 30,
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Updated Version $appVersion',
                          textStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                          speed: Duration(milliseconds: 200),
                        ),
                      ],
                      repeatForever: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(30.0),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 5),
                Text(
                  '© ${DateTime.now().year} Tim Cengoh, Ahli Huru-Hara',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'All Rights Reserved',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontFamily: 'Poppins',
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}