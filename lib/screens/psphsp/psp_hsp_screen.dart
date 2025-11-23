// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui';

// import 'package:animated_text_kit/animated_text_kit.dart';
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
import 'psp_detailed_map_screen.dart';
import 'psp_issue_screen.dart';
import 'psp_training_screen.dart';
import 'psp_weather_widget.dart'; // Pastikan ini mengarah ke widget cuaca baru kamu
import 'vegetative/psp_vegetative_screen.dart';

enum SnackBarType { success, error, info }

class PspHspScreen extends StatefulWidget {
  const PspHspScreen({super.key});

  @override
  PspHspScreenState createState() => PspHspScreenState();
}

class PspHspScreenState extends State<PspHspScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  List<String> fieldSPVList = ['PSP HSP'];
  List<String> faList = [];
  List<String> qaSPVList = [];
  List<String> seasonList = [];
  String? selectedFieldSPV;
  String? selectedFA;
  String? selectedQA;
  String? selectedSeason;
  String? selectedRegion;
  String? selectedSpreadsheetId;
  final ZoomDrawerController _drawerController = ZoomDrawerController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  String? userPhotoUrl;
  StreamSubscription? _seasonsSubscription;

  String _greeting = '';
  String _currentTime = '';
  Timer? _timer;
  late AnimationController _fabController;

  final Map<String, String> regionDocumentIds = {
    'PSP HSP': 'psp hsp',
  };

  // Colors for Premium UI
  final Color _accentCyan = const Color(0xFF00E5FF);
  final Color _accentAmber = const Color(0xFFFFC400);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
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
    _fabController.dispose();
    super.dispose();
  }

  void _handleBackInHomeScreen() {
    if (_drawerController.isOpen!()) {
      _drawerController.close!();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildExitDialog(),
    );
  }

  Widget _buildExitDialog() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(32.0),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                "Exit Application",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to close the app?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white,
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          SystemNavigator.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Exit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 4) {
        _greeting = 'Good Night!';
      } else if (hour < 10) {
        _greeting = 'Good Morning!';
      } else if (hour < 15) {
        _greeting = 'Good Afternoon!';
      } else if (hour < 18) {
        _greeting = 'Good Evening!';
      } else {
        _greeting = 'Good Night!';
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}, ${now.year}';
    });
  }

  String _getDayName(int day) {
    switch (day) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }

  void _setupRealTimeListeners() {
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
      return (data['zones'] as Map<String, dynamic>).keys.toList();
    });
  }

  Stream<List<String>> getDistrictsStream(String? selectedRegion, String? selectedQASPV) {
    if (selectedRegion == null || selectedQASPV == null) return Stream.value([]);
    String? documentId = regionDocumentIds[selectedRegion];
    if (documentId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('regions')
        .doc(documentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey('zones') &&
          data['zones'] is Map &&
          data['zones'][selectedQASPV] != null &&
          data['zones'][selectedQASPV]['field_assistant'] != null) {
        return List<String>.from(data['zones'][selectedQASPV]['field_assistant']);
      }
      return [];
    });
  }

  Stream<List<String>> getPSPFilterStream() {
    return FirebaseFirestore.instance
        .collection('config')
        .doc('filter')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey('psphsp') && data['psphsp'] is List) {
        return List<String>.from(data['psphsp']);
      }
      return [];
    });
  }

  Future<void> _loadSeasonPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSeason = prefs.getString('selectedSeason');
    });
  }

  Future<void> _fetchGoogleUserData() async {
    try {
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
          userName = signedInUser!.displayName ?? 'User';
          userEmail = signedInUser.email;
          userPhotoUrl = signedInUser.photoUrl;
        });

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', signedInUser.displayName ?? 'User');
        await prefs.setString('userEmail', signedInUser.email);
        await prefs.setString('userPhotoUrl', signedInUser.photoUrl ?? '');
      }
    } catch (error) {
      debugPrint("Error fetching Google data: $error");
    }
  }

  Future<void> _logoutGoogle() async {
    await _googleSignIn.signOut();
  }

  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'User';
    });
  }

  Future<void> _loadUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Email not found';
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

    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final configSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .get();
      if (configSnapshot.exists) {
        final data = configSnapshot.data();
        if (data != null && data.containsKey('psphsp')) {
          setState(() {
            fieldSPVList = List<String>.from(data['psphsp']);
          });
        }
      }

      await ConfigManager.loadConfig();

      _setupRealTimeListeners();
      await _fetchAppVersion();
      await _fetchUserData();
      await _fetchGoogleUserData();
      await _loadUserEmail();
      await _loadSeasonPreference();
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _buildLogoutDialog(dialogContext);
      },
    );

    if (confirmLogout == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userRole');
      await _logoutGoogle();
      // ignore: use_build_context_synchronously
      if (mounted) context.go('/login');
    }
  }

  // ... (Keep _buildLogoutDialog as is or simplify if needed) ...
  Widget _buildLogoutDialog(BuildContext dialogContext) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(32.0),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                "Logout Confirmation",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text(
                "Are you sure you want to logout?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: Colors.white,
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubicEmphasized;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
          var fadeAnimation = animation.drive(fadeTween);

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        maintainState: true,
      ),
    );
  }

  void _showBottomSheetMenu() {
    // ... (Keep implementation same as provided) ...
    HapticFeedback.mediumImpact();
    _fabController.forward().then((_) => _fabController.reverse());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.purple.shade50.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 16, bottom: 40),
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 60,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purple.shade300, Colors.purple.shade600],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Header and Menu Items logic...
                    // (Use previous implementation for menu items)
                    _buildMenuItem(context, 0, Icons.list_alt_rounded, Colors.indigo.shade600, 'Attendance Log', 'Track attendance records', [Colors.indigo.shade50, Colors.indigo.shade100], () {
                      if (selectedFieldSPV == null) {
                        Navigator.pop(context);
                        _showSnackBar(context, 'Please select Division first!');
                        return;
                      }
                      Navigator.pop(context);
                      _navigateTo(context, const PspAbsenLogScreen());
                    }),
                    _buildMenuItem(context, 1, Icons.map_rounded, Colors.blue.shade600, 'Workload Map', 'Area workload with advanced filters', [Colors.blue.shade50, Colors.blue.shade100], () {
                      Navigator.pop(context);
                      if (selectedSpreadsheetId == null || selectedFieldSPV == null) {
                        _showSnackBar(context, 'Please select Division first!');
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => PspDetailedMapScreen(
                          spreadsheetId: selectedSpreadsheetId!,
                          initialWorksheetTitle: 'Generative',
                          initialRegion: selectedFieldSPV,
                          initialDistrict: selectedFA,
                          initialSeason: selectedSeason,
                        ),
                      ));
                    }),
                    _buildMenuItem(context, 2, Icons.model_training_rounded, Colors.teal.shade600, 'Training', 'Training materials & resources', [Colors.teal.shade50, Colors.teal.shade100], () {
                      Navigator.pop(context);
                      _navigateTo(context, PspTrainingScreen(onSave: (updatedData) {
                        setState(() {});
                      }));
                    }),
                    _buildMenuItem(context, 3, Icons.report_problem_rounded, Colors.red.shade600, 'Issue', 'Report and track problems', [Colors.red.shade50, Colors.red.shade100], () {
                      Navigator.pop(context);
                      if (selectedFA != null) {
                        _navigateTo(context, PspIssueScreen(
                          selectedFA: selectedFA!,
                          onSave: (updatedIssue) {
                            setState(() {});
                          },
                        ));
                      } else {
                        _showSnackBar(context, 'Please select Division, Zone PIC & Field Assistant first!');
                      }
                    }),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: BorderSide(color: Colors.grey.shade300, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            backgroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded, color: Colors.grey.shade700, size: 26),
                              const SizedBox(width: 10),
                              Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.grey.shade700, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, int index, IconData icon, Color iconColor, String title, String subtitle, List<Color> gradientColors, VoidCallback onTap) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (index * 120)),
      curve: Curves.easeInOutCubicEmphasized,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - value)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onTap();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: iconColor.withOpacity(0.3), width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [iconColor.withOpacity(0.8), iconColor],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 34),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87, letterSpacing: 0.3)),
                                const SizedBox(height: 6),
                                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: iconColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ... (Build method remains same, drawer integration etc) ...
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: false,
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
          onLogout: () => _logout(context),
        ),
        mainScreen: _buildMainScreen(context),
        borderRadius: 32.0,
        showShadow: true,
        angle: -2.0,
        slideWidth: MediaQuery.of(context).size.width * 0.88,
        openCurve: Curves.easeInOutCubicEmphasized,
        closeCurve: Curves.easeInOutCubicEmphasized,
        menuBackgroundColor: Colors.purple[100]!,
      ),
    );
  }

  Widget _buildMainScreen(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(75),
            child: AppBar(
              title: _selectedIndex == 0
                  ? Row(
                children: [
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: 0.6 + (value * 0.4),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.grain_rounded, color: Colors.white, size: 26),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  const Text('PSP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.8)),
                ],
              )
                  : Row(
                children: [
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: 0.6 + (value * 0.4),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.history_rounded, color: Colors.white, size: 26),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  const Text('Activity', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.8)),
                ],
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.purple.shade800, Colors.purple.shade600, Colors.purple.shade700],
                  ),
                ),
              ),
              elevation: 8,
              shadowColor: Colors.purple.withOpacity(0.4),
              iconTheme: const IconThemeData(color: Colors.white),
              leading: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _drawerController.toggle!();
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeContent(context),
              const PspActivityScreen(),
            ],
          ),
          floatingActionButton: ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.15).animate(
              CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
            ),
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.4 + (value * 0.6),
                  child: Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.purple.shade50],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.purple.shade400, Colors.purple.shade700, Colors.purple.shade900],
                        ),
                      ),
                      child: FloatingActionButton(
                        onPressed: _showBottomSheetMenu,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade800, Colors.purple.shade600, Colors.purple.shade700],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, -8),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              child: BottomAppBar(
                elevation: 0,
                color: Colors.transparent,
                notchMargin: 14.0,
                shape: const CircularNotchedRectangle(),
                child: Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavBarItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: _selectedIndex == 0,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedIndex = 0);
                        },
                      ),
                      const SizedBox(width: 50),
                      _buildNavBarItem(
                        icon: Icons.history_rounded,
                        label: 'Activity',
                        isSelected: _selectedIndex == 1,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedIndex = 1);
                        },
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.purple.shade50.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset('assets/loading.json', width: 200, height: 200),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade800],
                        ).createShader(bounds),
                        child: const Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 240,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 1800),
                            curve: Curves.easeInOutCubicEmphasized,
                            builder: (context, double value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                              );
                            },
                            onEnd: () {
                              if (_isLoading) {
                                setState(() {});
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavBarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              size: isSelected ? 30 : 26,
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: isSelected ? 13 : 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.5,
                height: 1.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // --- UNIFIED GLASS HEADER (Profile, Greeting, Date) ---
                // This aligns with the new weather widget style
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOutCubicEmphasized,
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32.0),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.purple.shade900,
                                Colors.blue.shade900,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.shade900.withOpacity(0.4),
                                blurRadius: 25,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Decorative Glows
                              Positioned(
                                top: -40,
                                right: -40,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.1),
                                        blurRadius: 50,
                                        spreadRadius: 10,
                                      )
                                    ],
                                  ),
                                ),
                              ),

                              // Glass Container Content
                              ClipRRect(
                                borderRadius: BorderRadius.circular(32.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.1),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Avatar & Greeting
                                        Row(
                                          children: [
                                            // Avatar with Glow
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: _accentCyan.withOpacity(0.5), width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _accentCyan.withOpacity(0.3),
                                                    blurRadius: 15,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: CircleAvatar(
                                                radius: 28,
                                                backgroundColor: Colors.purple.shade100,
                                                backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                                                    ? NetworkImage(userPhotoUrl!)
                                                    : const AssetImage('assets/logo.png') as ImageProvider,
                                              ),
                                            ),
                                            const SizedBox(width: 16),

                                            // Greeting Text
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        _greeting,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.white.withOpacity(0.8),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Dynamic Icon based on time
                                                      Icon(
                                                        _greeting.contains('Morning') ? WeatherIcons.sunrise
                                                            : _greeting.contains('Afternoon') ? WeatherIcons.day_sunny
                                                            : _greeting.contains('Evening') ? WeatherIcons.sunset
                                                            : WeatherIcons.night_clear,
                                                        color: _accentAmber,
                                                        size: 14,
                                                      )
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    userName,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Menu Button (Quick trigger)
                                            GestureDetector(
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                _drawerController.toggle!();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 20),
                                        Divider(color: Colors.white.withOpacity(0.15), height: 1),
                                        const SizedBox(height: 20),

                                        // Bottom Row: Date & Status
                                        Row(
                                          children: [
                                            // Glass Date Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.calendar_today_rounded, size: 14, color: _accentCyan),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _currentTime,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),

                                            // Active Role Badge
                                            Row(
                                              children: [
                                                Text(
                                                  "Ready to work",
                                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.greenAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Weather Widget (Updated Style)
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOut,
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: PspWeatherWidget(greeting: _greeting),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Filter Section (Updated to match Glassmorphism)
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOut,
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: _buildFilterSection(context),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Section Header Premium
        SliverToBoxAdapter(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1700),
            curve: Curves.easeOutCubic,
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    decoration: BoxDecoration(
                      // Background Kaca Putih Bersih
                      color: Colors.white.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.shade900.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16), // Padding lebih compact
                          child: Row(
                            children: [
                              // Animated Icon Container
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.elasticOut,
                                builder: (context, double iconValue, child) {
                                  return Transform.scale(
                                    scale: 0.8 + (iconValue * 0.2),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.purple.shade500, Colors.purple.shade800],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purple.withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.grain_rounded, color: Colors.white, size: 28),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(width: 16),

                              // Title & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PHASE',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple.shade400,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Parent Seeds Production',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.purple.shade900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Counter Badge (Pill Shape)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.purple.shade100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.layers_rounded, size: 14, color: Colors.purple.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      '1 Active', // Bisa diganti dinamis jika ada variabel count
                                      style: TextStyle(
                                        color: Colors.purple.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Grid Premium
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 20,
              childAspectRatio: 2.3,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return _PostHarvestCard(
                  imagePath: 'assets/vegetative.png',
                  label: 'Vegetative',
                  description: 'Parent Seeds Production',
                  phase: 'Phase',
                  primaryColor: Colors.purple.shade600,
                  secondaryColor: Colors.purple.shade800,
                  delay: 0,
                  spreadsheetId: selectedSpreadsheetId,
                  selectedDistrict: selectedFA,
                  selectedQA: selectedQA,
                  selectedSeason: selectedSeason,
                  region: selectedFieldSPV,
                  seasonList: seasonList,
                  onTap: () {
                    HapticFeedback.mediumImpact();

                    if (selectedSpreadsheetId == null) {
                      _showSnackBar(context, 'Please select Division first');
                      return;
                    }
                    if (selectedQA == null) {
                      _showSnackBar(context, 'Zone PIC not selected yet!');
                      return;
                    }
                    if (selectedFA == null) {
                      _showSnackBar(context, 'Hey, FA not selected yet!');
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PspVegetativeScreen(
                          spreadsheetId: selectedSpreadsheetId!,
                          selectedDistrict: selectedFA!,
                          selectedQA: selectedQA!,
                          selectedSeason: selectedSeason,
                          region: selectedFieldSPV ?? 'Unknown Region',
                          seasonList: seasonList,
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: 1,
            ),
          ),
        ),
      ],
    );
  }

  // --- REPLACEMENT CODE FOR FILTER SECTION ---

  Widget _buildFilterSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4), // Sedikit margin agar shadow tidak terpotong
      decoration: BoxDecoration(
        // Efek Kaca: Putih transparan
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade900.withOpacity(0.08),
            blurRadius: 25,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Blur latar belakang
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Filter ---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'FILTER BY ZONE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900, // Lebih tebal & modern
                        color: Colors.purple.shade900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- Filter Dropdowns ---
                StreamBuilder<List<String>>(
                  stream: getPSPFilterStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                    final regions = snapshot.data ?? [];
                    return _buildFilterChip(
                      label: 'Division',
                      value: selectedFieldSPV,
                      icon: Icons.location_city_rounded,
                      onTap: () => _showRegionBottomSheet(context, regions),
                      delay: 0,
                    );
                  },
                ),

                if (selectedFieldSPV != null) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<List<String>>(
                    stream: getQASPVStream(selectedFieldSPV!),
                    builder: (context, snapshot) {
                      final qaSPVList = snapshot.data ?? [];
                      return _buildFilterChip(
                        label: 'Zone PIC',
                        value: selectedQA,
                        icon: Icons.supervisor_account_rounded,
                        onTap: () => _showQASPVBottomSheet(context, qaSPVList),
                        delay: 100,
                      );
                    },
                  ),
                ],

                if (selectedQA != null) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<List<String>>(
                    stream: getDistrictsStream(selectedFieldSPV, selectedQA),
                    builder: (context, snapshot) {
                      final districts = snapshot.data ?? [];
                      return _buildFilterChip(
                        label: 'Field Assistant',
                        value: selectedFA,
                        icon: Icons.location_on_rounded,
                        onTap: () => _showDistrictBottomSheet(context, districts),
                        delay: 200,
                      );
                    },
                  ),
                ],

                // --- Active Filter Summary & Reset ---
                if (selectedFieldSPV != null || selectedQA != null || selectedFA != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Row(
                      children: [
                        // Status Indicator
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getActiveFiltersCount(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade900,
                                        ),
                                      ),
                                      Text(
                                        "Filters applied",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.purple.shade700.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Reset Button (Styled)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _clearAllFilters();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.refresh_rounded, size: 16, color: Colors.red.shade400),
                                const SizedBox(width: 6),
                                Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    int delay = 0,
  }) {
    final bool hasValue = value != null;

    // Animasi masuk sederhana
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOut,
      builder: (context, double val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - val)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            // Jika aktif: Gradient Ungu. Jika tidak: Putih Kaca.
            gradient: hasValue
                ? LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasValue ? Colors.purple.shade300 : Colors.white,
              width: hasValue ? 0 : 1.5,
            ),
            boxShadow: hasValue
                ? [
              BoxShadow(
                color: Colors.purple.shade700.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ]
                : [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasValue ? Colors.white.withOpacity(0.2) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: hasValue ? Colors.white : Colors.purple.shade300,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasValue ? Colors.white.withOpacity(0.7) : Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'Select $label',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: hasValue ? Colors.white : Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow / Status Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasValue ? Colors.white : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasValue ? Icons.edit_rounded : Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: hasValue ? Colors.purple.shade800 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Method lain seperti _showRegionBottomSheet, dll. tetap sama persis dengan kode sebelumnya) ...

  void _showRegionBottomSheet(BuildContext context, List<String> regions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.3)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 14),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.location_city_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Select Division',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 28),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isSelected = selectedFieldSPV == region;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade700])
                            : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.purple.shade800 : Colors.grey.shade200,
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_city_rounded,
                            color: isSelected ? Colors.white : Colors.purple.shade600,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          region,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28)
                            : null,
                        onTap: () async {
                          final spreadsheetId = ConfigManager.getSpreadsheetId(region);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('selectedRegion', region);

                          setState(() {
                            selectedFieldSPV = region;
                            selectedSpreadsheetId = spreadsheetId;
                            selectedQA = null;
                            selectedFA = null;
                            faList.clear();
                          });

                          if (context.mounted) Navigator.pop(context);

                          if (spreadsheetId == null) {
                            if (context.mounted) _showSnackBar(context, 'Spreadsheet ID not found');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQASPVBottomSheet(BuildContext context, List<String> qaSPVList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.3)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 14),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.supervisor_account_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Text('Select Zone PIC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 28),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: qaSPVList.length,
                  itemBuilder: (context, index) {
                    final qa = qaSPVList[index];
                    final isSelected = selectedQA == qa;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade700])
                            : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.purple.shade800 : Colors.grey.shade200,
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: isSelected ? Colors.white : Colors.purple.shade600,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          qa,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28)
                            : null,
                        onTap: () async {
                          setState(() => selectedQA = qa);
                          await _saveFilterPreferences();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistrictBottomSheet(BuildContext context, List<String> districts) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.purple.shade50.withOpacity(0.3)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 14),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade300, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade400, Colors.purple.shade700],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Text('Select Field Assistant', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 28),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: districts.length,
                  itemBuilder: (context, index) {
                    final district = districts[index];
                    final isSelected = selectedFA == district;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade700])
                            : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.purple.shade800 : Colors.grey.shade200,
                          width: isSelected ? 2 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: isSelected ? Colors.white : Colors.purple.shade600,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          district,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28)
                            : null,
                        onTap: () async {
                          setState(() => selectedFA = district);
                          await _saveFilterPreferences();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAllFilters() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      selectedFieldSPV = null;
      selectedQA = null;
      selectedFA = null;
      selectedSpreadsheetId = null;
      faList.clear();
    });

    await prefs.remove('selectedRegion');
    await prefs.remove('selectedQA');
    await prefs.remove('selectedFA');

    if (mounted) {
      _showSnackBar(context, 'All filters have been reset', type: SnackBarType.success);
    }
  }

  String _getActiveFiltersCount() {
    int count = 0;
    if (selectedFieldSPV != null) count++;
    if (selectedQA != null) count++;
    if (selectedFA != null) count++;
    return '$count Active Filter${count > 1 ? 's' : ''}';
  }
}

void _showSnackBar(BuildContext context, String message, {SnackBarType type = SnackBarType.error}) {
  Color backgroundColor;
  IconData icon;

  switch (type) {
    case SnackBarType.success:
      backgroundColor = Colors.purple.shade600;
      icon = Icons.check_circle_rounded;
      break;
    case SnackBarType.error:
      backgroundColor = Colors.red.shade500;
      icon = Icons.error_rounded;
      break;
    case SnackBarType.info:
      backgroundColor = Colors.black87;
      icon = Icons.info_rounded;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade700, Colors.purple.shade800, Colors.purple.shade900],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(40.0),
          bottomRight: Radius.circular(40.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.08, left: 28, right: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.elasticOut,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: 0.6 + (value * 0.4),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 25,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: CircleAvatar(
                                    radius: screenHeight * 0.09,
                                    backgroundColor: Colors.purple.shade100,
                                    backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                                        ? NetworkImage(userPhotoUrl!)
                                        : const AssetImage('assets/logo.png') as ImageProvider,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 15 * (1 - value)),
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                    letterSpacing: 0.8,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 15 * (1 - value)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.email_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          userEmail,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Poppins',
                                            color: Colors.white.withOpacity(0.9),
                                            decoration: TextDecoration.none,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: 240,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.4),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 40),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 25 * (1 - value)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        onLogout();
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 36),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.white, Colors.white.withOpacity(0.95)],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.logout_rounded, size: 24, color: Colors.purple.shade700),
                                            const SizedBox(width: 14),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.purple.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1300),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.white.withOpacity(0.8)),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Version $appVersion',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.none,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                  ),
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(40.0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '© 2024 Tim Cengoh, Ahli Huru-Hara',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        decoration: TextDecoration.none,
                        letterSpacing: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All Rights Reserved',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostHarvestCard extends StatefulWidget {
  const _PostHarvestCard({
    required this.imagePath,
    required this.label,
    required this.description,
    required this.phase,
    required this.primaryColor,
    required this.secondaryColor,
    required this.delay,
    required this.spreadsheetId,
    required this.selectedDistrict,
    required this.selectedQA,
    required this.selectedSeason,
    required this.region,
    required this.seasonList,
    required this.onTap,
  });

  final String imagePath;
  final String label;
  final String description;
  final String phase;
  final Color primaryColor;
  final Color secondaryColor;
  final int delay;
  final String? spreadsheetId;
  final String? selectedDistrict;
  final String? selectedQA;
  final String? selectedSeason;
  final String? region;
  final List<String> seasonList;
  final VoidCallback onTap;

  @override
  State<_PostHarvestCard> createState() => _PostHarvestCardState();
}

class _PostHarvestCardState extends State<_PostHarvestCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + widget.delay),
      curve: Curves.easeInOutCubicEmphasized,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 60 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              // Background Kaca Semi-Transparan
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Efek Blur
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Padding sedikit lebih rapi
                  child: Row(
                    children: [
                      // --- Icon Container (Gradient Pop) ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.primaryColor,
                              widget.secondaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: widget.primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          widget.imagePath,
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                          color: Colors.white, // Memutihkan icon agar kontras
                        ),
                      ),

                      const SizedBox(width: 20),

                      // --- Text Content ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Phase Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: widget.primaryColor.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                widget.phase.toUpperCase(), // Uppercase biar tegas
                                style: TextStyle(
                                  color: widget.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Title
                            Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87, // Hitam pekat agar mudah dibaca
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Description
                            Text(
                              widget.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // --- Action Arrow ---
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: widget.primaryColor,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}