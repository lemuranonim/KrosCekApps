import 'dart:async';
import 'dart:ui';

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
import 'psp_detailed_map_screen.dart';
import 'psp_issue_screen.dart';
import 'psp_training_screen.dart';
import 'psp_weather_widget.dart';
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

  final Map<String, String> regionDocumentIds = {
    'PSP HSP': 'psp hsp',
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
  if (_drawerController.isOpen!()) {
    _drawerController.close!();
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
              const Text(
                "Exit Confirmation",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Are you sure you want to exit the application?",
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
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      SystemNavigator.pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      "Exit",
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
    _currentTime =
    '${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}, ${now.year}';
  });
}

String _getDayName(int day) {
  switch (day) {
    case 1:
      return 'Monday';
    case 2:
      return 'Tuesday';
    case 3:
      return 'Wednesday';
    case 4:
      return 'Thursday';
    case 5:
      return 'Friday';
    case 6:
      return 'Saturday';
    case 7:
      return 'Sunday';
    default:
      return '';
  }
}

String _getMonthName(int month) {
  switch (month) {
    case 1:
      return 'January';
    case 2:
      return 'February';
    case 3:
      return 'March';
    case 4:
      return 'April';
    case 5:
      return 'May';
    case 6:
      return 'June';
    case 7:
      return 'July';
    case 8:
      return 'August';
    case 9:
      return 'September';
    case 10:
      return 'October';
    case 11:
      return 'November';
    case 12:
      return 'December';
    default:
      return '';
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

    if (data.containsKey('zones') &&
        data['zones'] is Map &&
        data['zones'][selectedQASPV] != null &&
        data['zones'][selectedQASPV]['field_assistant'] != null) {
      return List<String>.from(
          data['zones'][selectedQASPV]['field_assistant']);
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
        userName = signedInUser!.displayName ?? 'Pengguna';
        userEmail = signedInUser.email;
        userPhotoUrl = signedInUser.photoUrl;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'userName', signedInUser.displayName ?? 'Pengguna');
      await prefs.setString('userEmail', signedInUser.email);
      await prefs.setString('userPhotoUrl', signedInUser.photoUrl ?? '');
    }
  } catch (error) {
    debugPrint("Error mengambil data Google: $error");
  }
}

Future<void> _logoutGoogle() async {
  await _googleSignIn.signOut();
}

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
  final navigator = Navigator.of(context);

  bool? confirmLogout = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text(
          "Logout Confirmation",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        content:
        const Text("Are you sure you want to logout and switch account?"),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  "Logout",
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
    barrierColor: Colors.black.withAlpha(153),
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    Colors.orange.shade50.withAlpha(76),
                  ],
                ),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(76),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(top: 12, bottom: 32),
                children: <Widget>[
                  // Drag Handle
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: value,
                          child: Container(
                            width: 50,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withAlpha(100),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Header
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade50,
                          Colors.orange.shade100.withAlpha(127),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withAlpha(30),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.orange.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withAlpha(100),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.dashboard_customize_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Select the menu you need',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Menu Items
                  _buildEnhancedMenuItem(
                    context,
                    index: 0,
                    icon: Icons.list_alt_rounded,
                    iconColor: Colors.indigo.shade600,
                    title: 'Attendance Log',
                    subtitle: 'Attendance records',
                    gradientColors: [
                      Colors.indigo.shade50,
                      Colors.indigo.shade100
                    ],
                    onTap: () {
                      if (selectedFieldSPV == null) {
                        Navigator.pop(context);
                        _showSnackBar(context, 'Please select Region first!');
                        return;
                      }
                      Navigator.pop(context);
                      _navigateTo(context, const PspAbsenLogScreen());
                    },
                  ),

                  _buildEnhancedMenuItem(
                    context,
                    index: 1,
                    icon: Icons.map_rounded,
                    iconColor: Colors.blue.shade600,
                    title: 'Workload Map',
                    subtitle: 'Area workload map with advanced filters',
                    gradientColors: [
                      Colors.blue.shade50,
                      Colors.blue.shade100
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      if (selectedSpreadsheetId == null ||
                          selectedFieldSPV == null) {
                        _showSnackBar(context, 'Please select Region first!');
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
                    },
                  ),

                  _buildEnhancedMenuItem(
                    context,
                    index: 2,
                    icon: Icons.model_training_rounded,
                    iconColor: Colors.teal.shade600,
                    title: 'Training',
                    subtitle: 'Training materials & resources',
                    gradientColors: [
                      Colors.teal.shade50,
                      Colors.teal.shade100
                    ],
                    onTap: () {
                      Navigator.pop(context);
                      _navigateTo(
                        context,
                        PspTrainingScreen(onSave: (updatedData) {
                          setState(() {});
                        }),
                      );
                    },
                  ),

                  _buildEnhancedMenuItem(
                    context,
                    index: 3,
                    icon: Icons.report_problem_rounded,
                    iconColor: Colors.red.shade600,
                    title: 'Issue',
                    subtitle: 'Report and track problems',
                    gradientColors: [Colors.red.shade50, Colors.red.shade100],
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
                        _showSnackBar(context,
                            'Please select Region, Zone PIC & Field Assistant first!');
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // Close Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.grey.shade50,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tutup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.grey.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

Widget _buildEnhancedMenuItem(
    BuildContext context, {
      required int index,
      required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle,
      required List<Color> gradientColors,
      required VoidCallback onTap,
    }) {
  return TweenAnimationBuilder(
    tween: Tween<double>(begin: 0, end: 1),
    duration: Duration(milliseconds: 400 + (index * 100)),
    curve: Curves.easeOutCubic,
    builder: (context, double value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: iconColor.withAlpha(76),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withAlpha(30),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              iconColor.withAlpha(204),
                              iconColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withAlpha(100),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(204),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withAlpha(30),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: iconColor,
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
  );
}

@override
Widget build(BuildContext context) {
  super.build(context);
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
        onLogout: () => _logout(context),
      ),
      mainScreen: _buildMainScreen(context),
      borderRadius: 24.0,
      showShadow: true,
      angle: -1.0,
      slideWidth: MediaQuery.of(context).size.width * 0.95,
      openCurve: Curves.fastOutSlowIn,
      closeCurve: Curves.fastOutSlowIn,
      menuBackgroundColor: Colors.orange[100]!,
    ),
  );
}

Widget _buildMainScreen(BuildContext context) {
  return Stack(
    children: [
      Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            title: _selectedIndex == 0
                ? Row(
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: 0.7 + (value * 0.3),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.dashboard_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            )
                : Row(
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: 0.7 + (value * 0.3),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Text(
                  'Aktivitas',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.shade800,
                    Colors.orange.shade600,
                    Colors.orange.shade700,
                  ],
                ),
              ),
            ),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
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
        floatingActionButton: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: 0.5 + (value * 0.5),
              child: Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.orange.shade50,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha(80),
                      blurRadius: 20,
                      spreadRadius: 3,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.shade600,
                        Colors.orange.shade700,
                        Colors.orange.shade800,
                      ],
                    ),
                  ),
                  child: FloatingActionButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showBottomSheetMenu();
                    },
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        floatingActionButtonLocation:
        FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade800,
                Colors.orange.shade600,
                Colors.orange.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withAlpha(60),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, -3),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: BottomAppBar(
              elevation: 0,
              color: Colors.transparent,
              notchMargin: 12.0,
              shape: const CircularNotchedRectangle(),
              child: Container(
                height: 65,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavBarItem(
                      icon: Icons.home_rounded,
                      label: '',
                      isSelected: _selectedIndex == 0,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedIndex = 0);
                      },
                    ),
                    const SizedBox(width: 40),
                    _buildNavBarItem(
                      icon: Icons.history_rounded,
                      label: '',
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
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.white.withAlpha(204),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/loading.json',
                      width: 180,
                      height: 180,
                    ),
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.orange.shade600,
                          Colors.orange.shade800,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Ngrantos sekedap...',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeInOut,
                          builder: (context, double value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange.shade600,
                              ),
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
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:
        isSelected ? Colors.white.withAlpha(51) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(63)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: isSelected ? 28 : 26,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: isSelected ? 12 : 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.3,
            ),
            child: Text(label),
          ),
        ],
      ),
    ),
  );
}

Widget _buildHomeContent(BuildContext context) {
  final List<Map<String, dynamic>> inspectionPhases = [
    {
      'imagePath': 'assets/vegetative.png',
      'label': 'All Zone',
      'description': 'PSP stage',
      'phase': 'Fase 1',
      'primaryColor': Colors.orange.shade600,
      'secondaryColor': Colors.orange.shade700,
      'delay': 0,
    },
  ];

  return CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Welcome Card
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha(40),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.0),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _drawerController.toggle!();
                                  },
                                  child: TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration:
                                    const Duration(milliseconds: 800),
                                    curve: Curves.elasticOut,
                                    builder: (context, double value, child) {
                                      return Transform.scale(
                                        scale: 0.7 + (value * 0.3),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.orange.shade400,
                                                Colors.orange.shade600,
                                                Colors.orange.shade800,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.orange
                                                    .withAlpha(100),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                            child: CircleAvatar(
                                              radius: 32,
                                              backgroundColor:
                                              Colors.orange.shade100,
                                              backgroundImage: userPhotoUrl !=
                                                  null &&
                                                  userPhotoUrl!.isNotEmpty
                                                  ? NetworkImage(userPhotoUrl!)
                                                  : const AssetImage(
                                                  'assets/logo.png')
                                              as ImageProvider,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      TweenAnimationBuilder(
                                        tween: Tween<double>(begin: 0, end: 1),
                                        duration:
                                        const Duration(milliseconds: 600),
                                        curve: Curves.easeOut,
                                        builder: (context, double value,
                                            child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Transform.translate(
                                              offset:
                                              Offset(0, 10 * (1 - value)),
                                              child: AnimatedTextKit(
                                                animatedTexts: [
                                                  TyperAnimatedText(
                                                    _greeting,
                                                    textStyle: TextStyle(
                                                      fontSize: 22.0,
                                                      fontWeight:
                                                      FontWeight.w800,
                                                      color: Colors
                                                          .orange.shade800,
                                                      letterSpacing: 0.5,
                                                    ),
                                                    speed: const Duration(
                                                        milliseconds: 100),
                                                  ),
                                                ],
                                                totalRepeatCount: 1,
                                                displayFullTextOnTap: true,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      TweenAnimationBuilder(
                                        tween: Tween<double>(begin: 0, end: 1),
                                        duration:
                                        const Duration(milliseconds: 800),
                                        curve: Curves.easeOut,
                                        builder: (context, double value,
                                            child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Text(
                                              userName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                Colors.orange.shade700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                TweenAnimationBuilder(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration:
                                  const Duration(milliseconds: 1000),
                                  curve: Curves.elasticOut,
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: 0.5 + (value * 0.5),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withAlpha(229),
                                              Colors.orange.shade50,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.orange
                                                  .withAlpha(40),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: BoxedIcon(
                                          _greeting == 'Good Morning!'
                                              ? WeatherIcons.sunrise
                                              : _greeting == 'Good Afternoon!'
                                              ? WeatherIcons.day_sunny
                                              : _greeting ==
                                              'Good Evening!'
                                              ? WeatherIcons.sunset
                                              : WeatherIcons
                                              .night_clear,
                                          color:
                                          _greeting == 'Good Morning!'
                                              ? Colors.orange.shade600
                                              : _greeting ==
                                              'Good Afternoon!'
                                              ? Colors.amber.shade600
                                              : _greeting ==
                                              'Good Evening!'
                                              ? Colors.deepOrange
                                              .shade600
                                              : Colors
                                              .indigo.shade300,
                                          size: 32,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeOut,
                              builder: (context, double value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 10 * (1 - value)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Colors.orange.shade50,
                                          ],
                                        ),
                                        borderRadius:
                                        BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                            Colors.orange.withAlpha(20),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade700,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _currentTime,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOut,
                              builder: (context, double value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child:
                                    PspWeatherWidget(greeting: _greeting),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1400),
                              curve: Curves.easeOut,
                              builder: (context, double value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child:
                                    _buildPremiumFilterSection(context),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section Header
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1600),
                curve: Curves.easeOut,
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.shade50,
                              Colors.orange.shade100.withAlpha(127),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withAlpha(30),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, double iconValue, child) {
                                return Transform.scale(
                                  scale: 0.5 + (iconValue * 0.5),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange.shade600,
                                          Colors.orange.shade800,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.orange.withAlpha(100),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.auto_graph_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'FIELD DATABASE',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select zone for inspection',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withAlpha(60),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.eco_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '1',
                                    style: TextStyle(
                                      color: Colors.white,
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
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // Grid Section
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1 / 1.4,
          ),
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final phase = inspectionPhases[index];
              return _EnhancedCategoryCard(
                imagePath: phase['imagePath'],
                label: phase['label'],
                description: phase['description'],
                phase: phase['phase'],
                primaryColor: phase['primaryColor'],
                secondaryColor: phase['secondaryColor'],
                delay: phase['delay'],
                spreadsheetId: selectedSpreadsheetId,
                selectedDistrict: selectedFA,
                selectedQA: selectedQA,
                selectedSeason: selectedSeason,
                region: selectedFieldSPV,
                seasonList: seasonList,
                onTap: () {
                  HapticFeedback.mediumImpact();

                  if (selectedSpreadsheetId == null) {
                    _showSnackBar(
                        context, 'Please select Division first');
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

                  Widget targetScreen;
                  switch (phase['label']) {
                    case 'All Zone':
                      targetScreen = PspVegetativeScreen(
                        spreadsheetId: selectedSpreadsheetId!,
                        selectedDistrict: selectedFA!,
                        selectedQA: selectedQA!,
                        selectedSeason: selectedSeason,
                        region: selectedFieldSPV ?? 'Unknown Region',
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
              );
            },
            childCount: inspectionPhases.length,
          ),
        ),
      ),
    ],
  );
}

Widget _buildPremiumFilterSection(BuildContext context) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.orange.shade50],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.orange.withAlpha(25),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withAlpha(76),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'FILTER BY ZONE!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildFilterChip(
                label: 'Division',
                value: selectedFieldSPV,
                icon: Icons.location_city_rounded,
                onTap: () => _showRegionBottomSheet(context),
              ),

              if (selectedFieldSPV != null) ...[
                const SizedBox(height: 12),
                _buildFilterChip(
                  label: 'Zone PIC',
                  value: selectedQA,
                  icon: Icons.supervisor_account_rounded,
                  onTap: () => _showQASPVBottomSheet(context),
                ),
              ],

              if (selectedQA != null) ...[
                const SizedBox(height: 12),
                _buildFilterChip(
                  label: 'Field Assistant',
                  value: selectedFA,
                  icon: Icons.location_on_rounded,
                  onTap: () => _showDistrictBottomSheet(context),
                ),
              ],

              if (selectedFieldSPV != null ||
                  selectedQA != null ||
                  selectedFA != null) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.shade50,
                        Colors.orange.shade100.withAlpha(127),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withAlpha(30),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showActiveFiltersDialog(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.orange.shade600,
                                    Colors.orange.shade700,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withAlpha(60),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getActiveFiltersCount(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getActiveFiltersList(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _showResetConfirmationDialog(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade400,
                                      Colors.red.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withAlpha(40),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
            ],
          ),
        ),
      ),
    ),
  );
}

String _getActiveFiltersCount() {
  int count = 0;
  if (selectedFieldSPV != null) count++;
  if (selectedQA != null) count++;
  if (selectedFA != null) count++;
  return '$count Active Filter${count > 1 ? 's' : ''}';
}

String _getActiveFiltersList() {
  List<String> active = [];
  if (selectedFieldSPV != null) active.add('Division');
  if (selectedQA != null) active.add('Zone PIC');
  if (selectedFA != null) active.add('Field Assistant');
  return active.join(' • ');
}

void _showActiveFiltersDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.orange.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Active Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (selectedFieldSPV != null)
                _buildFilterDetailRow(
                  icon: Icons.location_city_rounded,
                  label: 'Division',
                  value: selectedFieldSPV!,
                  color: Colors.blue.shade600,
                ),
              if (selectedQA != null) ...[
                const SizedBox(height: 12),
                _buildFilterDetailRow(
                  icon: Icons.supervisor_account_rounded,
                  label: 'Zone PIC',
                  value: selectedQA!,
                  color: Colors.purple.shade600,
                ),
              ],
              if (selectedFA != null) ...[
                const SizedBox(height: 12),
                _buildFilterDetailRow(
                  icon: Icons.location_on_rounded,
                  label: 'Field Assistant',
                  value: selectedFA!,
                  color: Colors.orange.shade600,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildFilterDetailRow({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withAlpha(76),
        width: 1.5,
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _showResetConfirmationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.red.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reset All Filters?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'All active filters will be removed and returned to initial state.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _clearAllFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildFilterChip({
  required String label,
  required String? value,
  required IconData icon,
  required VoidCallback onTap,
}) {
  final bool hasValue = value != null;

  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hasValue
            ? LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        )
            : null,
        color: hasValue ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? Colors.orange.shade700 : Colors.grey.shade300,
          width: hasValue ? 2 : 1,
        ),
        boxShadow: hasValue
            ? [
          BoxShadow(
            color: Colors.orange.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasValue ? Colors.white.withAlpha(51) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: hasValue ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasValue ? Colors.white70 : Colors.grey.shade600,
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
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: hasValue ? Colors.white : Colors.grey.shade400,
          ),
        ],
      ),
    ),
  );
}

void _showRegionBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StreamBuilder<List<String>>(
      stream: getPSPFilterStream(),
      builder: (context, snapshot) {
        final regions = snapshot.data ?? [];

        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_city_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Division',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isSelected = selectedFieldSPV == region;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        )
                            : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange.shade700
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withAlpha(51)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_city_rounded,
                            color: isSelected
                                ? Colors.white
                                : Colors.orange.shade600,
                          ),
                        ),
                        title: Text(
                          region,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                            color: Colors.white)
                            : null,
                        onTap: () async {
                          final spreadsheetId =
                          ConfigManager.getSpreadsheetId(region);
                          final prefs =
                          await SharedPreferences.getInstance();
                          await prefs.setString('selectedRegion', region);

                          setState(() {
                            selectedFieldSPV = region;
                            selectedSpreadsheetId = spreadsheetId;
                            selectedQA = null;
                            selectedFA = null;
                            faList.clear();
                          });

                          // ignore: use_build_context_synchronously
                          Navigator.pop(context);

                          if (spreadsheetId == null) {
                            // ignore: use_build_context_synchronously
                            _showSnackBar(context,
                                'Spreadsheet ID not found');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showQASPVBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StreamBuilder<List<String>>(
      stream: getQASPVStream(selectedFieldSPV!),
      builder: (context, snapshot) {
        final qaSPVList = snapshot.data ?? [];

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.supervisor_account_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Zone PIC',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: qaSPVList.length,
                  itemBuilder: (context, index) {
                    final qa = qaSPVList[index];
                    final isSelected = selectedQA == qa;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        )
                            : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange.shade700
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withAlpha(51)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: isSelected
                                ? Colors.white
                                : Colors.orange.shade600,
                          ),
                        ),
                        title: Text(
                          qa,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                            color: Colors.white)
                            : null,
                        onTap: () async {
                          setState(() => selectedQA = qa);
                          await _saveFilterPreferences();
                          // ignore: use_build_context_synchronously
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showDistrictBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StreamBuilder<List<String>>(
      stream: getDistrictsStream(selectedFieldSPV, selectedQA),
      builder: (context, snapshot) {
        final districts = snapshot.data ?? [];

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pilih Field Assistant',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: districts.length,
                  itemBuilder: (context, index) {
                    final district = districts[index];
                    final isSelected = selectedFA == district;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.orange.shade600
                          ],
                        )
                            : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange.shade700
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withAlpha(51)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: isSelected
                                ? Colors.white
                                : Colors.orange.shade600,
                          ),
                        ),
                        title: Text(
                          district,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                            color: Colors.white)
                            : null,
                        onTap: () async {
                          setState(() => selectedFA = district);
                          await _saveFilterPreferences();
                          // ignore: use_build_context_synchronously
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

  // ignore: use_build_context_synchronously
  _showSnackBar(context, 'All filters have been reset',
      type: SnackBarType.success);
}
}

void _showSnackBar(BuildContext context, String message,
    {SnackBarType type = SnackBarType.error}) {
  Color backgroundColor;
  switch (type) {
    case SnackBarType.success:
      backgroundColor = Colors.orange.shade600;
      break;
    case SnackBarType.error:
      backgroundColor = Colors.red.shade400;
      break;
    case SnackBarType.info:
      backgroundColor = Colors.black87;
      break;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      backgroundColor: backgroundColor,
      duration: const Duration(seconds: 3),
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
          colors: [
            Colors.orange.shade700,
            Colors.orange.shade800,
            Colors.orange.shade900,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30.0),
          bottomRight: Radius.circular(30.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 20,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(7),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: screenHeight * 0.08,
                      left: 24,
                      right: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, double value, child) {
                            return Transform.scale(
                              scale: 0.7 + (value * 0.3),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withAlpha(76),
                                      Colors.white.withAlpha(25),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(51),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: CircleAvatar(
                                    radius: screenHeight * 0.08,
                                    backgroundColor: Colors.orange.shade100,
                                    backgroundImage: userPhotoUrl != null &&
                                        userPhotoUrl!.isNotEmpty
                                        ? NetworkImage(userPhotoUrl!)
                                        : const AssetImage('assets/logo.png')
                                    as ImageProvider,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(38),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withAlpha(76),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.email_rounded,
                                        size: 14,
                                        color: Colors.white.withAlpha(229),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          userEmail,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontFamily: 'Poppins',
                                            color: Colors.white.withAlpha(229),
                                            decoration: TextDecoration.none,
                                            fontWeight: FontWeight.w500,
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
                        const SizedBox(height: 32),
                        Container(
                          width: 220,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withAlpha(102),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 32),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(51),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
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
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                          horizontal: 32,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.white.withAlpha(242),
                                            ],
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white.withAlpha(127),
                                            width: 2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 22,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                letterSpacing: 0.5,
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
                        const SizedBox(height: 20),
                        TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOut,
                          builder: (context, double value, child) {
                            return Opacity(
                              opacity: value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(51),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: Colors.white.withAlpha(204),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Version $appVersion',
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(204),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.none,
                                        letterSpacing: 0.3,
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
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(51),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(30.0),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 180,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withAlpha(76),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '© ${DateTime.now().year} Tim Cengoh',
                      style: TextStyle(
                        color: Colors.white.withAlpha(204),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        decoration: TextDecoration.none,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chaos Experts',
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.w500,
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

class _EnhancedCategoryCard extends StatefulWidget {
  const _EnhancedCategoryCard({
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
  State<_EnhancedCategoryCard> createState() => _EnhancedCategoryCardState();
}

class _EnhancedCategoryCardState extends State<_EnhancedCategoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + widget.delay),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
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
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withAlpha((255 * 0.25).toInt()),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.primaryColor.withAlpha((255 * 0.1).toInt()),
                          Colors.white,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.primaryColor
                                .withAlpha((255 * 0.15).toInt()),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            widget.phase,
                            style: TextStyle(
                              color: widget.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  widget.primaryColor,
                                  widget.secondaryColor
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.primaryColor
                                      .withAlpha((255 * 0.4).toInt()),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: -20,
                    child: Image.asset(
                      widget.imagePath,
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}