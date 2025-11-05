import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_icons/weather_icons.dart';

import '../services/config_manager.dart';
import 'psp_absen_log_screen.dart';
import 'psp_activity_screen.dart';
import 'generative/psp_generative_screen.dart';
import 'psp_detailed_map_screen.dart';
import 'psp_detaselling_screen.dart';
import 'psp_issue_screen.dart';
import 'psp_training_screen.dart';
import 'psp_weather_widget.dart';
import 'vegetative/psp_vegetative_screen.dart';

class PspScreen extends StatefulWidget {
  const PspScreen({super.key});

  @override
  PspScreenState createState() => PspScreenState();
}

class PspScreenState extends State<PspScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  List<String> fieldSPVList = ['PSP'];
  List<String> faList = [];
  List<String> qaSPVList = [];
  List<String> seasonList = [];
  String? selectedFieldSPV;
  String? selectedFA;
  String? selectedQA;
  String? selectedSeason;
  String? selectedRegion;
  String? selectedSpreadsheetId;
  final ZoomDrawerController _drawerController =
      ZoomDrawerController(); // Tambahkan Controller
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  String? userPhotoUrl;
  StreamSubscription? _seasonsSubscription;

  String _greeting = '';
  String _currentTime = '';
  Timer? _timer;

  final Map<String, String> regionDocumentIds = {
    'PSP': 'psp',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _updateTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTime();
    });

    _loadInitialData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _seasonsSubscription?.cancel();
    super.dispose();
  }

  void _handleBackInHomeScreen() {
    // If the drawer is open, close it
    if (_drawerController.isOpen!()) {
      _drawerController.close!();
      return;
    }

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
                    color: Colors.redAccent,
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
                          color: Colors.redAccent,
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
                        backgroundColor: Colors.redAccent,
                        // Use backgroundColor instead of primary
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

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 4) {
        _greeting = 'Sugêng Ndalu!';
      } else if (hour < 10) {
        _greeting = 'Sugêng Enjing!';
      } else if (hour < 15) {
        _greeting = 'Sugêng Siang!';
      } else if (hour < 18) {
        _greeting = 'Sugêng Sontên!';
      } else {
        _greeting = 'Sugêng Ndalu!';
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime =
          '${_getDayName(now.weekday)}, ${now.day} ${_getMonthName(now.month)} ${now.year}';
    });
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'Januari';
      case 2:
        return 'Februari';
      case 3:
        return 'Maret';
      case 4:
        return 'April';
      case 5:
        return 'Mei';
      case 6:
        return 'Juni';
      case 7:
        return 'Juli';
      case 8:
        return 'Agustus';
      case 9:
        return 'September';
      case 10:
        return 'Oktober';
      case 11:
        return 'November';
      case 12:
        return 'Desember';
      default:
        return '';
    }
  }

  void _setupRealTimeListeners() {
    // Listener untuk seasons
    _seasonsSubscription = FirebaseFirestore.instance
        .collection('seasons')
        .doc('season')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          seasonList = List<String>.from(snapshot.data()!['sesi']);
        });
        _saveSeasonListToPreferences();
      }
    });
    getPSPFilterStream().listen((regions) {
      if (mounted) {
        setState(() {
          fieldSPVList = regions;
        });
      }
    });
  }

  // Stream untuk mendapatkan data QA SPV secara real-time
  Stream<List<String>> getQASPVStream(String selectedRegion) {
    if (selectedRegion.isEmpty) return Stream.value([]);

    String? documentId = regionDocumentIds[selectedRegion];
    if (documentId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('regions')
        .doc(documentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      return (data['qa_spv'] as Map<String, dynamic>).keys.toList();
    });
  }

  // Stream untuk mendapatkan data Districts secara real-time
  Stream<List<String>> getDistrictsStream(
      String? selectedRegion, String? selectedQASPV) {
    if (selectedRegion == null || selectedQASPV == null) {
      return Stream.value([]);
    }

    String? documentId = regionDocumentIds[selectedRegion];

    if (documentId == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('regions')
        .doc(documentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey('qa_spv') &&
          data['qa_spv'] is Map &&
          data['qa_spv'][selectedQASPV] != null &&
          data['qa_spv'][selectedQASPV]['districts'] != null) {
        return List<String>.from(data['qa_spv'][selectedQASPV]['districts']);
      }
      return [];
    });
  }

  // Stream untuk mendapatkan data PSP filter secara real-time
  Stream<List<String>> getPSPFilterStream() {
    return FirebaseFirestore.instance
        .collection('config')
        .doc('filter')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey('psp') && data['psp'] is List) {
        return List<String>.from(data['psp']);
      }
      return [];
    });
  }

  // Fetch season dari SharedPreferences
  Future<void> _loadSeasonPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSeason = prefs.getString('selectedSeason');
    });
  }

  Future<void> _fetchGoogleUserData() async {
    try {
      // FIX: Gunakan signInSilently() yang baru dengan null safety
      final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;

      GoogleSignInAccount? signedInUser = googleUser;
      if (signedInUser == null) {
        try {
          signedInUser = await _googleSignIn.signInSilently();
        } catch (e) {
          debugPrint("Silent sign in failed: $e");
          return;
        }
      }

      if (signedInUser != null) {
        setState(() {
          userName = signedInUser!.displayName ?? 'Pengguna';
          userEmail = signedInUser.email;
          userPhotoUrl = signedInUser.photoUrl;
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', signedInUser.displayName ?? 'Pengguna');
        await prefs.setString('userEmail', signedInUser.email);
        await prefs.setString('userPhotoUrl', signedInUser.photoUrl ?? '');
      }
    } catch (error) {
      debugPrint("Error mengambil data Google: $error");
    }
  }

  Future<void> _logoutGoogle() async {
    await _googleSignIn.signOut(); // Logout Google
  }

  // Fungsi untuk mengambil email dan nama dari SharedPreferences
  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  Future<void> _loadUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Email tidak ditemukan';
    });
  }

  Future<void> _saveFilterPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedQA', selectedQA ?? '');
    await prefs.setString('selectedFA', selectedFA ?? '');
    await prefs.setString('selectedSeason', selectedSeason ?? '');
  }

  Future<void> _saveSeasonListToPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('seasonList', seasonList);
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

    // Simulasikan loading dengan delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // Load regions from Firestore
      final configSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .get();
      if (configSnapshot.exists) {
        final data = configSnapshot.data();
        if (data != null && data.containsKey('psp')) {
          setState(() {
            fieldSPVList = List<String>.from(data['psp']);
          });
        }
      }

      // Load config from ConfigManager
      await ConfigManager.loadConfig();

      // Setup other data
      _setupRealTimeListeners();
      await _fetchAppVersion();
      await _fetchUserData();
      await _fetchGoogleUserData();
      await _loadUserEmail();
      await _loadSeasonPreference();
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      // Setelah selesai, matikan loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    // Simpan reference ke ScaffoldMessenger sebelum operasi async
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
    });

    // Reset all selections to initial state
    setState(() {
      selectedFieldSPV = null;
      selectedQA = null;
      selectedFA = null;
      selectedSeason = null;
      selectedSpreadsheetId = null;
      qaSPVList = [];
      faList = [];
    });

    // Clear the saved selections from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('selectedRegion');
    await prefs.remove('selectedQA');
    await prefs.remove('selectedFA');
    await prefs.remove('selectedSeason');

    // Simulasikan loading dengan delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Setelah selesai, matikan loading
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Show a snackbar to inform the user
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content:
              Text('Mulai dari Nol ya Kak...', textAlign: TextAlign.center),
          duration: Duration(seconds: 4),
        ),
      );
    }
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
              color: Colors.redAccent,
            ),
          ),
          content:
              const Text("Menopo panjenengan yakin badhe medal gantos akun?"),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    "Batal",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    // Use backgroundColor instead of primary
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

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        maintainState: true,
      ),
    );
  }

  void _showBottomSheetMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Garis drag handle di atas
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildPremiumMenuItem(
                context,
                icon: Icons.map, // Contoh ikon
                title: 'Workload Map',
                subtitle: 'Peta workload area dengan filter lanjutan',
                onTap: () {
                  Navigator.pop(context); // Tutup bottom sheet
                  if (selectedSpreadsheetId == null ||
                      selectedFieldSPV == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pilih Region dulu boloo!')),
                    );
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => PspDetailedMapScreen(
                        spreadsheetId: selectedSpreadsheetId!,
                        initialWorksheetTitle: 'Generative',
                        // Worksheet default
                        initialRegion: selectedFieldSPV,
                        initialDistrict: selectedFA,
                        initialSeason: selectedSeason,
                      )));
                },
              ),
              // Menu Items
              _buildPremiumMenuItem(
                context,
                icon: Icons.engineering_rounded,
                title: 'Training',
                subtitle: 'Materi & sumber daya pelatihan',
                onTap: () {
                  Navigator.pop(context);
                  _navigateTo(
                    context,
                    PspTrainingScreen(
                      onSave: (updatedData) {
                        setState(() {});
                      },
                    ),
                  );
                },
              ),

              _buildPremiumMenuItem(
                context,
                icon: Icons.list_alt_rounded,
                title: 'Absen Log',
                subtitle: 'Catatan kehadiran',
                onTap: () {
                  if (selectedFieldSPV == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pilih Region dulu boloo!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  _navigateTo(context, const PspAbsenLogScreen());
                },
              ),

              _buildPremiumMenuItem(
                context,
                icon: Icons.warning_amber_rounded,
                title: 'Issue',
                subtitle: 'Laporkan dan lacak masalah',
                onTap: () {
                  Navigator.pop(context);
                  if (selectedFA != null) {
                    _navigateTo(
                      context,
                      PspIssueScreen(
                        selectedFA: selectedFA!,
                        onSave: (updatedIssue) {
                          setState(() {});
                        },
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pilih Region, QA SPV & District dulu boloo!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 8),

              // Close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.redAccent),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
      child: ZoomDrawer(
        controller: _drawerController,
        style: DrawerStyle.defaultStyle,
        menuScreen: MenuScreen(
          userName: userName,
          userEmail: userEmail,
          userPhotoUrl: userPhotoUrl,
          appVersion: _appVersion,
          onLogout: () => _logout(context),
        ),
        mainScreen: _buildMainScreen(context),
        borderRadius: 24.0,
        showShadow: true,
        angle: -1.0,
        slideWidth: MediaQuery.of(context).size.width * 0.95,
        openCurve: Curves.fastOutSlowIn,
        closeCurve: Curves.fastOutSlowIn,
        menuBackgroundColor: Colors.redAccent[100]!,
      ),
    );
  }

  Widget _buildMainScreen(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: _selectedIndex == 0
                ? const Text('PSP Dashboard',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))
                : const Text('Aktivitas',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade800, Colors.red.shade600],
                ),
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => _drawerController.toggle!(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () {
                  // Action for info button
                  _showInfoDialog(context);
                },
              ),
              // Add refresh button to AppBar
              IconButton(
                icon: const Icon(Icons.autorenew_rounded, color: Colors.white),
                onPressed: _refreshData,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              // Removed LiquidPullToRefresh and using direct ListView instead
              _buildHomeContent(context),
              const PspActivityScreen(),
            ],
          ),
          floatingActionButton: Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withAlpha(60),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _showBottomSheetMenu,
              backgroundColor: Colors.redAccent,
              elevation: 0,
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.red.shade800, Colors.red.shade600],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withAlpha(50),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BottomAppBar(
                elevation: 0,
                color: Colors.transparent,
                notchMargin: 10.0,
                shape: const CircularNotchedRectangle(),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.home_rounded,
                          color: _selectedIndex == 0
                              ? Colors.white
                              : Colors.white70,
                          size: 35.0,
                        ),
                        onPressed: () => setState(() => _selectedIndex = 0),
                        splashColor: Colors.white.withAlpha(30),
                        highlightColor: Colors.white.withAlpha(20),
                      ),
                      const SizedBox(width: 30), // Space for FAB
                      IconButton(
                        icon: Icon(
                          Icons.restore_rounded,
                          color: _selectedIndex == 1
                              ? Colors.white
                              : Colors.white70,
                          size: 35.0,
                        ),
                        onPressed: () => setState(() => _selectedIndex = 1),
                        splashColor: Colors.white.withAlpha(30),
                        highlightColor: Colors.white.withAlpha(20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Gunakan Lottie animation untuk loading yang lebih menarik
                  Lottie.asset(
                    'assets/loading.json', // Pastikan file ini ada di assets
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ngrantos sekedap...',
                    style: TextStyle(
                      color: Colors.redAccent.shade700,
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Info Mase!',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
              'Yen diperluake, pencet tombol refresh kanggo nganyari data region dadi kosong koyo awal.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.10 * 255).toInt()),
                spreadRadius: 3,
                blurRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ganti bagian welcome message dengan:
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade50,
                          Colors.red.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withAlpha(25),
                          blurRadius: 10,
                          spreadRadius: 1,
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedTextKit(
                                    animatedTexts: [
                                      TyperAnimatedText(
                                        _greeting,
                                        textStyle: TextStyle(
                                          fontSize: 24.0,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.redAccent[700],
                                        ),
                                        textAlign: TextAlign.left,
                                        speed:
                                            const Duration(milliseconds: 500),
                                      ),
                                    ],
                                    totalRepeatCount: 1,
                                    displayFullTextOnTap: true,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withAlpha(25),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: BoxedIcon(
                                _greeting == 'Sugêng Enjing!'
                                    ? WeatherIcons.sunrise
                                    : _greeting == 'Sugêng Siang!'
                                    ? WeatherIcons.day_sunny
                                    : _greeting == 'Sugêng Sontên!'
                                    ? WeatherIcons.sunset
                                    : WeatherIcons.night_clear,
                                color: _greeting == 'Sugêng Enjing!'
                                    ? Colors.yellow.shade600
                                    : _greeting == 'Sugêng Siang!'
                                    ? Colors.amber.shade600
                                    : _greeting == 'Sugêng Sontên!'
                                    ? Colors.amber.shade900
                                    : Colors.blue.shade300,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withAlpha(15),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: Colors.redAccent.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _currentTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PspWeatherWidget(greeting: _greeting),
                  const SizedBox(height: 16),
                  // Dropdown untuk memilih Region
                  StreamBuilder<List<String>>(
                    stream: getPSPFilterStream(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      final regions = snapshot.data ?? [];

                      return DropdownButtonFormField<String>(
                        initialValue: selectedFieldSPV,
                        hint: const Text("Pilih Regionmu!",
                            style: TextStyle(color: Colors.grey)),
                        items: regions.map((region) {
                          return DropdownMenuItem<String>(
                            value: region,
                            child: Text(region,
                                style: const TextStyle(color: Colors.black87)),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          final scaffoldMessenger =
                          ScaffoldMessenger.of(context);
                          SharedPreferences prefs =
                          await SharedPreferences.getInstance();

                          if (value != null) {
                            final spreadsheetId =
                            ConfigManager.getSpreadsheetId(value);
                            await prefs.setString('selectedRegion', value);

                            setState(() {
                              selectedFieldSPV = value;
                              selectedSpreadsheetId = spreadsheetId;
                              selectedQA = null;
                              selectedFA = null;
                              selectedSeason = null;
                              faList.clear();
                            });

                            if (spreadsheetId == null) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Spreadsheet ID tidak ditemukan untuk region yang dipilih'),
                                ),
                              );
                            }
                          }
                        },
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                        dropdownColor: Colors.white,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.red),
                        iconSize: 28,
                        decoration: InputDecoration(
                          labelText: 'Field Region',
                          labelStyle: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.red, width: 2.0),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Colors.red, width: 2.5),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: const BorderSide(
                                color: Colors.red, width: 2.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        elevation: 2,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // StreamBuilder untuk QA SPV
                  if (selectedFieldSPV != null) ...[
                    StreamBuilder<List<String>>(
                      stream: getQASPVStream(selectedFieldSPV!),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }

                        final qaSPVList = snapshot.data ?? [];

                        return DropdownButtonFormField<String>(
                          initialValue: selectedQA,
                          hint: const Text("Pilih QA SPV!",
                              style: TextStyle(color: Colors.grey)),
                          items: qaSPVList.map((qa) {
                            return DropdownMenuItem<String>(
                              value: qa,
                              child: Text(qa,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            if (value != null) {
                              setState(() => selectedQA = value);
                              await _saveFilterPreferences();
                            }
                          },
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.redAccent),
                          iconSize: 28,
                          decoration: InputDecoration(
                            labelText: 'QA SPV',
                            labelStyle: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2.0),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2.5),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 8),

                  // StreamBuilder untuk Districts
                  if (selectedQA != null) ...[
                    StreamBuilder<List<String>>(
                      stream: getDistrictsStream(selectedFieldSPV, selectedQA),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }

                        final districts = snapshot.data ?? [];

                        return DropdownButtonFormField<String>(
                          initialValue: selectedFA,
                          hint: const Text("Pilih District!",
                              style: TextStyle(color: Colors.grey)),
                          items: districts.map((district) {
                            return DropdownMenuItem<String>(
                              value: district,
                              child: Text(district,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() => selectedFA = value);
                              _saveFilterPreferences();
                            }
                          },
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                          dropdownColor: Colors.white,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.redAccent),
                          iconSize: 28,
                          decoration: InputDecoration(
                            labelText: 'District',
                            labelStyle: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2.0),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2.5),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 8),

                  if (selectedQA != null || selectedFA != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      margin: const EdgeInsets.only(top: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withAlpha(25),
                            spreadRadius: 3,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.redAccent.withAlpha(76),
                          // ~30% opacity (255 * 0.3 ≈ 76)
                          width: 1.5,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Color.alphaBlend(
                                Colors.redAccent.withAlpha(12), Colors.white),
                            // ~5% opacity
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedQA != null) ...[
                            _buildResultItem(
                              icon: Icons.supervisor_account_rounded,
                              label: 'QA SPV',
                              value: selectedQA!,
                            ),
                            const Divider(
                              height: 20,
                              thickness: 1,
                              color: Colors.grey,
                              indent: 10,
                              endIndent: 10,
                            ),
                          ],
                          if (selectedFA != null) ...[
                            _buildResultItem(
                              icon: Icons.location_on_rounded,
                              label: 'District',
                              value: selectedFA!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Ganti ElevatedButton.icon dengan card yang lebih menarik
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade600,
                Colors.red.shade800,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withAlpha(76),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (selectedFieldSPV == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Pilih Region dulu sebelum cek Estimasi TKD!',
                            textAlign: TextAlign.center)),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PspKalkulatorTKDPage(
                      selectedRegion: selectedFieldSPV!,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withAlpha(30),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calculate_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimasi TKD',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hitung estimasi TKD berdasarkan data terkini',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
// Premium FASE INSPEKSI Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    // You can change this to any icon you prefer
                    color: Colors.redAccent[700],
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FASE INSPEKSI',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Grid Layout for Inspection Phases
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  buildPremiumCategoryItem(
                    context,
                    'assets/vegetative.png',
                    'Vegetative',
                    'Plant growth stage',
                    selectedSpreadsheetId,
                    selectedFA,
                    selectedQA,
                    selectedSeason,
                    selectedFieldSPV,
                    seasonList,
                  ),
                  buildPremiumCategoryItem(
                    context,
                    'assets/generative.png',
                    'Generative',
                    'Flowering stage',
                    selectedSpreadsheetId,
                    selectedFA,
                    selectedQA,
                    selectedSeason,
                    selectedFieldSPV,
                    seasonList,
                  ),
                ],
              ), // cek
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultItem(
      {required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(25), // ~10% opacity
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.redAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCategoryItem(
    BuildContext context,
    String imagePath,
    String label,
    String? spreadsheetId,
    String? selectedDistrict,
    String? selectedQA,
    String? selectedSeason,
    String? region,
    List<String> seasonList,
  ) {
    return GestureDetector(
      onTap: () {
        if (spreadsheetId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Harap pilih Region terlebih dahulu',
                    textAlign: TextAlign.center)),
          );
          return;
        }
        if (selectedQA == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('QA SPV belum dipilih gaes!',
                    textAlign: TextAlign.center)),
          );
          return;
        }
        if (selectedDistrict == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Hayo, Districtnya belum dipilih!',
                    textAlign: TextAlign.center)),
          );
          return;
        }

        Widget targetScreen;
        switch (label) {
          case 'Vegetative':
            targetScreen = PspVegetativeScreen(
              spreadsheetId: spreadsheetId,
              selectedDistrict: selectedDistrict,
              selectedQA: selectedQA,
              selectedSeason: selectedSeason,
              region: region ?? 'Unknown Region',
              seasonList: seasonList,
            );
            break;
          case 'Generative':
            targetScreen = PspGenerativeScreen(
              spreadsheetId: spreadsheetId,
              selectedDistrict: selectedDistrict,
              selectedQA: selectedQA,
              selectedSeason: selectedSeason,
              region: region ?? 'Unknown Region',
              seasonList: seasonList,
            );
            break;
          default:
            return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(55.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.10 * 255).toInt()),
              spreadRadius: 3,
              blurRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(55.0),
          ),
          elevation: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(imagePath,
                    height: 60, width: 60, fit: BoxFit.contain),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget buildPremiumCategoryItem(
  BuildContext context,
  String imagePath,
  String label,
  String description,
  String? spreadsheetId,
  String? selectedDistrict,
  String? selectedQA,
  String? selectedSeason,
  String? region,
  List<String> seasonList,
) {
  return GestureDetector(
    onTap: () {
      if (spreadsheetId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Harap pilih Region terlebih dahulu',
                  textAlign: TextAlign.center)),
        );
        return;
      }
      if (selectedQA == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('QA SPV belum dipilih gaes!',
                  textAlign: TextAlign.center)),
        );
        return;
      }
      if (selectedDistrict == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Hayo, Districtnya belum dipilih!',
                  textAlign: TextAlign.center)),
        );
        return;
      }

      Widget targetScreen;
      switch (label) {
        case 'Vegetative':
          targetScreen = PspVegetativeScreen(
            spreadsheetId: spreadsheetId,
            selectedDistrict: selectedDistrict,
            selectedQA: selectedQA,
            selectedSeason: selectedSeason,
            region: region ?? 'Unknown Region',
            seasonList: seasonList,
          );
          break;
        case 'Generative':
          targetScreen = PspGenerativeScreen(
            spreadsheetId: spreadsheetId,
            selectedDistrict: selectedDistrict,
            selectedQA: selectedQA,
            selectedSeason: selectedSeason,
            region: region ?? 'Unknown Region',
            seasonList: seasonList,
          );
          break;
        default:
          return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => targetScreen),
      );
    },
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.redAccent.withAlpha(5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withAlpha(25),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.redAccent.withAlpha(51),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular image container with gradient background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.redAccent.withAlpha(25),
                  Colors.redAccent.withAlpha(51),
                ],
              ),
            ),
            child: Image.asset(
              imagePath,
              height: 40,
              width: 40,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            label,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class MenuScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userPhotoUrl;
  final String appVersion;
  final VoidCallback onLogout;

  const MenuScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userPhotoUrl,
    required this.appVersion,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: MediaQuery.of(context).size.width,
      height: screenHeight,
      decoration: BoxDecoration(
        color: Colors.redAccent,
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
          // Main content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  top: screenHeight * 0.1,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Foto Profil
                    CircleAvatar(
                      radius: screenHeight * 0.07,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                              ? NetworkImage(userPhotoUrl!)
                              : const AssetImage('assets/logo.png')
                                  as ImageProvider,
                    ),
                    const SizedBox(height: 16),

                    // Nama dan Email
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
                    const SizedBox(height: 24),

                    // Garis Pemisah
                    Container(
                      width: 200,
                      height: 1,
                      color: Colors.white.withAlpha(76),
                    ),
                    const SizedBox(height: 24),

                    // Tombol Logout
                    ElevatedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 30,
                      child: AnimatedTextKit(
                        animatedTexts: [
                          TypewriterAnimatedText(
                            'Version $appVersion',
                            textStyle: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            ),
                            speed: const Duration(milliseconds: 200),
                          ),
                        ],
                        repeatForever: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.redAccent[800],
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(30.0),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 5),
                Text(
                  '© 2024 Tim Cengoh, Ahli Huru-Hara',
                  style: TextStyle(
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
