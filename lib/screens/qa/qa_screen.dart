import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
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

import '../services/region_mapper_service.dart';
import '../services/config_manager.dart';
import 'absen_log_screen.dart';
import 'activity_screen.dart';
import 'dashboard_visit_screen.dart';
import 'detailed_map_screen.dart';
import 'detaselling_screen.dart';
import 'generative/generative_screen.dart';
import 'harvest/harvest_screen.dart';
import 'issue_screen.dart';
import 'pre_harvest/pre_harvest_screen.dart';
import 'training_screen.dart';
import 'vegetative/vegetative_screen.dart';
import 'weather_widget.dart';
import '../../services/notification_service.dart';
import 'notification_list_screen.dart';

enum SnackBarType { success, error, info }
class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  QaScreenState createState() => QaScreenState();
}

class QaScreenState extends State<QaScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  List<String> fieldSPVList = [];
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
  Stream<int>? _unreadNotificationsStream;
  StreamSubscription? _notificationListener;
  String _greeting = '';
  String _currentTime = '';
  Timer? _timer;
  Map<String, String> _regionDocumentIds = {};

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
    _setupLocalNotificationListener();
    _initializeUnreadStream();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _seasonsSubscription?.cancel();
    _notificationListener?.cancel();
    super.dispose();
  }

  void _setupLocalNotificationListener() {
    _notificationListener = FirebaseFirestore.instance
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(1) // Kita hanya peduli pada notifikasi terbaru
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return; // Tidak ada notifikasi

      final notificationDoc = snapshot.docs.first;
      final notificationId = notificationDoc.id;
      final notificationData = notificationDoc.data();
      final prefs = await SharedPreferences.getInstance();
      final lastShownId = prefs.getString('lastLocalNotificationId');

      // Tampilkan notifikasi hanya jika ini adalah notifikasi baru
      if (notificationId != lastShownId) {
        final title = notificationData['title'] ?? 'Notifikasi Baru';
        String body = notificationData['body'] ?? 'Anda memiliki pesan baru.';
        final bool isRichText = notificationData['isRichText'] ?? false;

        // --- PENYESUAIAN UTAMA DIMULAI DI SINI ---
        // Jika notifikasi adalah rich text, kita ubah dari format JSON ke teks biasa.
        if (isRichText) {
          try {
            // 1. Ubah string JSON menjadi objek List
            var json = jsonDecode(body);
            // 2. Buat objek Document dari data JSON tersebut
            final doc = Document.fromJson(json);
            // 3. Gunakan fungsi toPlainText() untuk mendapatkan teks biasa
            //    Kita juga mengganti karakter baris baru (\n) dengan spasi agar rapi.
            body = doc.toPlainText().replaceAll('\n', ' ').trim();

            // Jika body kosong setelah konversi, beri pesan default
            if (body.isEmpty) {
              body = 'Anda menerima pesan terformat. Buka aplikasi untuk melihat.';
            }

          } catch (e) {
            // Jika terjadi error saat konversi, tampilkan pesan fallback
            body = 'Anda menerima pesan terformat. Buka aplikasi untuk melihat.';
            debugPrint("Error converting Quill JSON to plain text: $e");
          }
        }

        // Panggil service untuk menampilkan notifikasi di HP dengan body yang sudah bersih
        NotificationService().showNotification(title, body);

        // Simpan ID notifikasi terakhir yang ditampilkan untuk menghindari duplikat
        await prefs.setString('lastLocalNotificationId', notificationId);
      }
    });
  }

  void _initializeUnreadStream() {
    setState(() {
      _unreadNotificationsStream = Stream.fromFuture(SharedPreferences.getInstance()).asyncExpand((prefs) {
        final lastReadTimestamp = prefs.getString('lastNotificationViewTimestamp');

        Query query = FirebaseFirestore.instance.collection('notifications');

        if (lastReadTimestamp != null) {
          query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.parse(lastReadTimestamp)));
        }

        return query.snapshots().map((snapshot) => snapshot.size);
      });
    });
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
                const Text(
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
                        Navigator.of(context).pop(true);
                        // Exit the app
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        // Use backgroundColor instead of primary
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
    getQAFilterStream().listen((regions) {
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

    String? documentId = _regionDocumentIds[selectedRegion];
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

    String? documentId = _regionDocumentIds[selectedRegion];

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

  // Stream untuk mendapatkan data QA filter secara real-time
  Stream<List<String>> getQAFilterStream() {
    return FirebaseFirestore.instance
        .collection('config')
        .doc('filter')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return [];
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      if (data.containsKey('qa') && data['qa'] is List) {
        return List<String>.from(data['qa']);
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

    // Simulasikan loading dengan delay
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      // BARU: Memuat semua konfigurasi secara paralel untuk efisiensi
      await Future.wait([
        ConfigManager.loadConfig(),         // Memuat config spreadsheet
        RegionMapperService.loadMappings(), // Memuat config pemetaan region
      ]);

      // Ambil pemetaan region KHUSUS untuk peran 'qa' dari service yang baru
      if (mounted) {
        setState(() {
          _regionDocumentIds = RegionMapperService.getRegionDocumentIdsForRole('qa');
        });
      }

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
          content:
          const Text("Menopo panjenengan yakin badhe medal gantos akun?"),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
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
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    // Use backgroundColor instead of primary
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
      isScrollControlled: true, // ✅ Sudah ada, bagus!
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(153),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7, // Mulai dari 70% tinggi layar
            minChildSize: 0.5, // Minimal 50% tinggi layar
            maxChildSize: 0.95, // Maksimal 95% tinggi layar
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.green.shade50.withAlpha(76),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(76),
                      blurRadius: 30,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController, // ✅ PENTING: Gunakan scrollController
                  padding: const EdgeInsets.only(top: 12, bottom: 32),
                  children: <Widget>[
                    // Animated Drag Handle
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
                                    Colors.green.shade400,
                                    Colors.green.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withAlpha(100),
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

                    // Enhanced Header with Gradient Background
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.shade50,
                            Colors.green.shade100.withAlpha(127),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withAlpha(30),
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
                                  Colors.green.shade400,
                                  Colors.green.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withAlpha(100),
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
                                  'Pilih menu yang kamu butuhkan',
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

                    // Menu Items dengan Enhanced Animation
                    _buildEnhancedMenuItem(
                      context,
                      index: 0,
                      icon: Icons.list_alt_rounded,
                      iconColor: Colors.indigo.shade600,
                      title: 'Absen Log',
                      subtitle: 'Catatan kehadiran',
                      gradientColors: [Colors.indigo.shade50, Colors.indigo.shade100],
                      onTap: () {
                        if (selectedFieldSPV == null) {
                          Navigator.pop(context);
                          _showSnackBar(context, 'Pilih Region dulu boloo!');
                          return;
                        }
                        Navigator.pop(context);
                        _navigateTo(context, const AbsenLogScreen());
                      },
                    ),

                    _buildEnhancedMenuItem(
                      context,
                      index: 1,
                      icon: Icons.map_rounded,
                      iconColor: Colors.blue.shade600,
                      title: 'Workload Map',
                      subtitle: 'Peta workload area dengan filter lanjutan',
                      gradientColors: [Colors.blue.shade50, Colors.blue.shade100],
                      onTap: () {
                        Navigator.pop(context);
                        if (selectedSpreadsheetId == null || selectedFieldSPV == null) {
                          _showSnackBar(context, 'Pilih Region dulu boloo!');
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => DetailedMapScreen(
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
                      subtitle: 'Materi & sumber daya pelatihan',
                      gradientColors: [Colors.teal.shade50, Colors.teal.shade100],
                      onTap: () {
                        Navigator.pop(context);
                        _navigateTo(
                          context,
                          TrainingScreen(onSave: (updatedData) {
                            setState(() {});
                          }),
                        );
                      },
                    ),

                    _buildEnhancedMenuItem(
                      context,
                      index: 3,
                      icon: Icons.analytics_rounded,
                      iconColor: Colors.purple.shade600,
                      title: 'Dashboard Visit',
                      subtitle: 'Ringkasan visit dan crop uniformity',
                      gradientColors: [Colors.purple.shade50, Colors.purple.shade100],
                      onTap: () {
                        Navigator.pop(context);
                        if (selectedSpreadsheetId == null || selectedFieldSPV == null) {
                          _showSnackBar(context, 'Pilih Region dulu boloo!');
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => DashboardVisitScreen(
                            selectedRegion: selectedFieldSPV!,
                            spreadsheetId: selectedSpreadsheetId!,
                          ),
                        ));
                      },
                    ),

                    _buildEnhancedMenuItem(
                      context,
                      index: 4,
                      icon: Icons.report_problem_rounded,
                      iconColor: Colors.red.shade600,
                      title: 'Issue',
                      subtitle: 'Laporkan dan lacak masalah',
                      gradientColors: [Colors.red.shade50, Colors.red.shade100],
                      onTap: () {
                        Navigator.pop(context);
                        if (selectedFA != null) {
                          _navigateTo(
                            context,
                            IssueScreen(
                              selectedFA: selectedFA!,
                              onSave: (updatedIssue) {
                                setState(() {});
                              },
                            ),
                          );
                        } else {
                          _showSnackBar(context, 'Pilih Region, QA SPV & District dulu boloo!');
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Enhanced Close Button
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

                    // ✅ TAMBAHAN: Padding bawah untuk layar kecil
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

// Enhanced Menu Item Widget - ADD THIS METHOD TO QaScreenState class
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
                        // Icon Container with Gradient
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

                        // Text Content
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

                        // Arrow Icon with Background
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
        menuBackgroundColor: Colors.green[100]!,
      ),
    );
  }

  // Replace the _buildMainScreen method in qa_screen.dart

  Widget _buildMainScreen(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          // ENHANCED APP BAR
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: AppBar(
              title: _selectedIndex == 0
                  ? Row(
                children: [
                  // Animated Icon
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
                      Colors.green.shade800,
                      Colors.green.shade600,
                      Colors.green.shade700,
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
              actions: [
                // Notification Button with Badge
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: StreamBuilder<int>(
                    stream: _unreadNotificationsStream,
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_rounded),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const NotificationListScreen(),
                                ),
                              );
                              _initializeUnreadStream();
                            },
                            tooltip: 'Riwayat Notifikasi',
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade400,
                                      Colors.red.shade600,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withAlpha(100),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeContent(context),
              const ActivityScreen(),
            ],
          ),

          // ENHANCED FLOATING ACTION BUTTON
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
                        Colors.green.shade50,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(80),
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
                          Colors.green.shade600,
                          Colors.green.shade700,
                          Colors.green.shade800,
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
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

          // ENHANCED BOTTOM NAVIGATION BAR
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade800,
                  Colors.green.shade600,
                  Colors.green.shade700,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(60),
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
                      // Home Button
                      _buildNavBarItem(
                        icon: Icons.home_rounded,
                        label: '',
                        isSelected: _selectedIndex == 0,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedIndex = 0);
                        },
                      ),

                      const SizedBox(width: 40), // Space for FAB

                      // Activity Button
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

        // ENHANCED LOADING OVERLAY
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
                      // Lottie Animation
                      Lottie.asset(
                        'assets/loading.json',
                        width: 180,
                        height: 180,
                      ),
                      const SizedBox(height: 24),

                      // Loading Text with Gradient
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade800,
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

                      // Loading Progress Indicator
                      Container(
                        width: 200,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
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
                                  Colors.green.shade600,
                                ),
                              );
                            },
                            onEnd: () {
                              // Loop animation if still loading
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

// Helper Widget for Enhanced Bottom Nav Bar Item
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
          color: isSelected
              ? Colors.white.withAlpha(51)
              : Colors.transparent,
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

  // Replace the entire _buildHomeContent method in qa_screen.dart with this:

  Widget _buildHomeContent(BuildContext context) {
    // Data untuk kartu fase inspeksi
    final List<Map<String, dynamic>> inspectionPhases = [
      {
        'imagePath': 'assets/vegetative.png',
        'label': 'Vegetative',
        'description': 'Plant growth',
        'phase': 'Fase 1',
        'primaryColor': Colors.green.shade600,
        'secondaryColor': Colors.green.shade700,
        'delay': 0,
      },
      {
        'imagePath': 'assets/generative.png',
        'label': 'Generative',
        'description': 'Flowering',
        'phase': 'Fase 2',
        'primaryColor': Colors.amber.shade600,
        'secondaryColor': Colors.amber.shade700,
        'delay': 100,
      },
      {
        'imagePath': 'assets/preharvest.png',
        'label': 'Pre-Harvest',
        'description': 'Maturation',
        'phase': 'Fase 3',
        'primaryColor': Colors.orange.shade600,
        'secondaryColor': Colors.orange.shade700,
        'delay': 200,
      },
      {
        'imagePath': 'assets/harvest.png',
        'label': 'Harvest',
        'description': 'Harvesting',
        'phase': 'Fase 4',
        'primaryColor': Colors.red.shade600,
        'secondaryColor': Colors.red.shade700,
        'delay': 300,
      },
    ];

    // DIUBAH: Menggunakan CustomScrollView untuk scrolling yang lebih mulus
    return CustomScrollView(
      slivers: [
        // SliverToBoxAdapter digunakan untuk membungkus semua widget non-sliver
        // seperti Container, Column, dll.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16), // Padding atas untuk semua konten

                // ENHANCED WELCOME CARD WITH GREETING (Kode tidak berubah)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(40),
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
                        // ... (Seluruh isi dari Welcome Card tetap sama)
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Enhanced User Avatar with Gradient Border & Micro-interaction
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _drawerController.toggle!();
                                    },
                                    child: TweenAnimationBuilder(
                                      tween: Tween<double>(begin: 0, end: 1),
                                      duration: const Duration(milliseconds: 800),
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
                                                  Colors.green.shade400,
                                                  Colors.green.shade600,
                                                  Colors.green.shade800,
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withAlpha(100),
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
                                                backgroundColor: Colors.green.shade100,
                                                backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                                                    ? NetworkImage(userPhotoUrl!)
                                                    : const AssetImage('assets/logo.png') as ImageProvider,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Greeting Text with Animation
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Animated Greeting
                                        TweenAnimationBuilder(
                                          tween: Tween<double>(begin: 0, end: 1),
                                          duration: const Duration(milliseconds: 600),
                                          curve: Curves.easeOut,
                                          builder: (context, double value, child) {
                                            return Opacity(
                                              opacity: value,
                                              child: Transform.translate(
                                                offset: Offset(0, 10 * (1 - value)),
                                                child: AnimatedTextKit(
                                                  animatedTexts: [
                                                    TyperAnimatedText(
                                                      _greeting,
                                                      textStyle: TextStyle(
                                                        fontSize: 22.0,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.green.shade800,
                                                        letterSpacing: 0.5,
                                                      ),
                                                      speed: const Duration(milliseconds: 100),
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

                                        // User Name with fade-in
                                        TweenAnimationBuilder(
                                          tween: Tween<double>(begin: 0, end: 1),
                                          duration: const Duration(milliseconds: 800),
                                          curve: Curves.easeOut,
                                          builder: (context, double value, child) {
                                            return Opacity(
                                              opacity: value,
                                              child: Text(
                                                userName,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green.shade700,
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

                                  // Weather Icon with Pulse Animation
                                  TweenAnimationBuilder(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 1000),
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
                                                Colors.green.shade50,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withAlpha(40),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 4),
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
                                                ? Colors.orange.shade600
                                                : _greeting == 'Sugêng Siang!'
                                                ? Colors.amber.shade600
                                                : _greeting == 'Sugêng Sontên!'
                                                ? Colors.deepOrange.shade600
                                                : Colors.indigo.shade300,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.green.shade50,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withAlpha(20),
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
                                                color: Colors.green.shade700,
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
                                                color: Colors.green.shade800,
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
                                      child: WeatherWidget(greeting: _greeting),
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
                                      child: _buildPremiumFilterSection(context),
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

                // Estimasi TKD Button
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOut,
                  builder: (context, double value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withAlpha(60),
                                blurRadius: 15,
                                spreadRadius: 1,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                if (selectedFieldSPV == null) {
                                  _showSnackBar(context, 'Pilih Region dulu sebelum cek Estimasi TKD!');
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => KalkulatorTKDPage(
                                      selectedRegion: selectedFieldSPV!,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              splashColor: Colors.white.withAlpha(76),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.orange.shade400,
                                      Colors.orange.shade600,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.orange.shade700.withAlpha(100),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icon Container with Pulsing Animation
                                    TweenAnimationBuilder(
                                      tween: Tween<double>(begin: 0.9, end: 1.0),
                                      duration: const Duration(milliseconds: 1000),
                                      curve: Curves.easeInOut,
                                      builder: (context, double scale, child) {
                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withAlpha(76),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(25),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.calculate_rounded,
                                              size: 24,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                      onEnd: () {
                                        // Loop animation
                                        if (mounted) {
                                          setState(() {});
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 16),

                                    // Text Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Estimasi TKD',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Hitung kebutuhan tenaga detaseling',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withAlpha(229),
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Arrow Icon with Shimmer Effect
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(51),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(20),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20,
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

                // Premium FASE INSPEKSI Section Header (Kode tidak berubah)
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
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100.withAlpha(127),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withAlpha(30),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Animated Icon Container
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
                                            Colors.green.shade600,
                                            Colors.green.shade800,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.withAlpha(100),
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

                              // Header Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FASE INSPEKSI',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pilih fase untuk inspeksi',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Info Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withAlpha(60),
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
                                      '4',
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


        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), // Padding sekeliling grid
          sliver: SliverGrid(
            // Delegate untuk mendefinisikan tampilan grid
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,          // 2 kolom
              crossAxisSpacing: 16,       // Jarak horizontal antar kartu
              mainAxisSpacing: 16,        // Jarak vertikal antar kartu
              childAspectRatio: 1 / 1.4,  // Rasio lebar:tinggi kartu
            ),
            // Delegate untuk membangun item-item di dalam grid
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
                    // Logika navigasi saat kartu di-tap (tidak berubah)
                    HapticFeedback.mediumImpact();

                    if (selectedSpreadsheetId == null) {
                      _showSnackBar(context, 'Harap pilih Region terlebih dahulu');
                      return;
                    }
                    if (selectedQA == null) {
                      _showSnackBar(context, 'QA SPV belum dipilih gaes!');
                      return;
                    }
                    if (selectedFA == null) {
                      _showSnackBar(context, 'Hayo, Districtnya belum dipilih!');
                      return;
                    }

                    Widget targetScreen;
                    switch (phase['label']) {
                      case 'Vegetative':
                        targetScreen = VegetativeScreen(
                          spreadsheetId: selectedSpreadsheetId!,
                          selectedDistrict: selectedFA!,
                          selectedQA: selectedQA!,
                          selectedSeason: selectedSeason,
                          region: selectedFieldSPV ?? 'Unknown Region',
                          seasonList: seasonList,
                        );
                        break;
                      case 'Generative':
                        targetScreen = GenerativeScreen(
                          spreadsheetId: selectedSpreadsheetId!,
                          selectedDistrict: selectedFA!,
                          selectedQA: selectedQA!,
                          selectedSeason: selectedSeason,
                          region: selectedFieldSPV ?? 'Unknown Region',
                          seasonList: seasonList,
                        );
                        break;
                      case 'Pre-Harvest':
                        targetScreen = PreHarvestScreen(
                          spreadsheetId: selectedSpreadsheetId!,
                          selectedDistrict: selectedFA!,
                          selectedQA: selectedQA!,
                          selectedSeason: selectedSeason,
                          region: selectedFieldSPV ?? 'Unknown Region',
                          seasonList: seasonList,
                        );
                        break;
                      case 'Harvest':
                        targetScreen = HarvestScreen(
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
              childCount: inspectionPhases.length, // Jumlah total item dalam grid
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
          colors: [Colors.white, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(25),
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
                // Header (WITHOUT separate Reset button)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withAlpha(76),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'FILTER BY REGION!',
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

                // Region Chip
                _buildFilterChip(
                  label: 'Region',
                  value: selectedFieldSPV,
                  icon: Icons.location_city_rounded,
                  onTap: () => _showRegionBottomSheet(context),
                ),

                // QA SPV Chip
                if (selectedFieldSPV != null) ...[
                  const SizedBox(height: 12),
                  _buildFilterChip(
                    label: 'QA SPV',
                    value: selectedQA,
                    icon: Icons.supervisor_account_rounded,
                    onTap: () => _showQASPVBottomSheet(context),
                  ),
                ],

                // District Chip
                if (selectedQA != null) ...[
                  const SizedBox(height: 12),
                  _buildFilterChip(
                    label: 'District',
                    value: selectedFA,
                    icon: Icons.location_on_rounded,
                    onTap: () => _showDistrictBottomSheet(context),
                  ),
                ],

                // MERGED Active Filters Summary with Reset Button
                if (selectedFieldSPV != null || selectedQA != null || selectedFA != null) ...[
                  const SizedBox(height: 16),

                  // Enhanced Active Filter Summary Card with Integrated Reset
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade50,
                          Colors.green.shade100.withAlpha(127),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.shade300,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha(30),
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
                              // Check Icon
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade600,
                                      Colors.green.shade700,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withAlpha(60),
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

                              // Active Filters Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getActiveFiltersCount(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getActiveFiltersList(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Reset Button (Integrated)
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
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
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

// Helper method to get active filters count
  String _getActiveFiltersCount() {
    int count = 0;
    if (selectedFieldSPV != null) count++;
    if (selectedQA != null) count++;
    if (selectedFA != null) count++;

    return '$count Filter Aktif';
  }

// Helper method to get active filters list
  String _getActiveFiltersList() {
    List<String> active = [];
    if (selectedFieldSPV != null) active.add('Region');
    if (selectedQA != null) active.add('QA SPV');
    if (selectedFA != null) active.add('District');

    return active.join(' • ');
  }

// Dialog to show active filters details (optional - triggered on tap)
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
                  Colors.green.shade50,
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
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
                      'Filter Aktif',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Active Filters List
                if (selectedFieldSPV != null)
                  _buildFilterDetailRow(
                    icon: Icons.location_city_rounded,
                    label: 'Region',
                    value: selectedFieldSPV!,
                    color: Colors.blue.shade600,
                  ),
                if (selectedQA != null) ...[
                  const SizedBox(height: 12),
                  _buildFilterDetailRow(
                    icon: Icons.supervisor_account_rounded,
                    label: 'QA SPV',
                    value: selectedQA!,
                    color: Colors.purple.shade600,
                  ),
                ],
                if (selectedFA != null) ...[
                  const SizedBox(height: 12),
                  _buildFilterDetailRow(
                    icon: Icons.location_on_rounded,
                    label: 'District',
                    value: selectedFA!,
                    color: Colors.orange.shade600,
                  ),
                ],

                const SizedBox(height: 20),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
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

// Helper widget for filter detail row in dialog
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

// Confirmation dialog for reset
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
                // Icon
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

                // Title
                const Text(
                  'Reset Semua Filter?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'Semua filter yang aktif akan dihapus dan dikembalikan ke kondisi awal.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Action Buttons
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
                          'Batal',
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

// ============================================
// FILTER CHIP WIDGET
// ============================================

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
            colors: [Colors.green.shade400, Colors.green.shade600],
          )
              : null,
          color: hasValue ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValue ? Colors.green.shade700 : Colors.grey.shade300,
            width: hasValue ? 2 : 1,
          ),
          boxShadow: hasValue
              ? [
            BoxShadow(
              color: Colors.green.withAlpha(76),
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
                    value ?? 'Pilih $label',
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

  // BOTTOM SHEET - REGION (FIXED)
  void _showRegionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreamBuilder<List<String>>(
        stream: getQAFilterStream(),
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
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_city_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pilih Region',
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

                // List Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          )
                              : null,
                          color: isSelected ? null : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
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
                              color: isSelected ? Colors.white : Colors.green.shade600,
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
                              ? const Icon(Icons.check_circle_rounded, color: Colors.white)
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

                            // ignore: use_build_context_synchronously
                            Navigator.pop(context);

                            if (spreadsheetId == null) {
                              // LANGKAH 3: Ganti SnackBar dengan fungsi terpusat
                              // ignore: use_build_context_synchronously
                              _showSnackBar(context, 'Spreadsheet ID tidak ditemukan');
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

  // BOTTOM SHEET - QA SPV (FIXED)
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
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.supervisor_account_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pilih QA SPV',
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

                // List Items
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
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          )
                              : null,
                          color: isSelected ? null : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
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
                              color: isSelected ? Colors.white : Colors.green.shade600,
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
                              ? const Icon(Icons.check_circle_rounded, color: Colors.white)
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

// BOTTOM SHEET - DISTRICT (FIXED)
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
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pilih District',
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

                // List Items
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
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          )
                              : null,
                          color: isSelected ? null : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
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
                              color: isSelected ? Colors.white : Colors.green.shade600,
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
                              ? const Icon(Icons.check_circle_rounded, color: Colors.white)
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

// ============================================
// HELPER METHODS
// ============================================

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

    // LANGKAH 3: Ganti SnackBar dengan fungsi terpusat
    // ignore: use_build_context_synchronously
    _showSnackBar(context, 'Semua filter telah direset', type: SnackBarType.success);
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
          // LANGKAH 3: Ganti SnackBar dengan fungsi terpusat
          _showSnackBar(context, 'Harap pilih Region terlebih dahulu');
          return;
        }
        if (selectedQA == null) {
          // LANGKAH 3: Ganti SnackBar dengan fungsi terpusat
          _showSnackBar(context, 'QA SPV belum dipilih gaes!');
          return;
        }
        if (selectedDistrict == null) {
          // LANGKAH 3: Ganti SnackBar dengan fungsi terpusat
          _showSnackBar(context, 'Hayo, Districtnya belum dipilih!');
          return;
        }

        Widget targetScreen;
        switch (label) {
          case 'Vegetative':
            targetScreen = VegetativeScreen(
              spreadsheetId: spreadsheetId,
              selectedDistrict: selectedDistrict,
              selectedQA: selectedQA,
              selectedSeason: selectedSeason,
              region: region ?? 'Unknown Region',
              seasonList: seasonList,
            );
            break;
          case 'Generative':
            targetScreen = GenerativeScreen(
              spreadsheetId: spreadsheetId,
              selectedDistrict: selectedDistrict,
              selectedQA: selectedQA,
              selectedSeason: selectedSeason,
              region: region ?? 'Unknown Region',
              seasonList: seasonList,
            );
            break;
          case 'Pre-Harvest':
            targetScreen = PreHarvestScreen(
              spreadsheetId: spreadsheetId,
              selectedDistrict: selectedDistrict,
              selectedQA: selectedQA,
              selectedSeason: selectedSeason,
              region: region ?? 'Unknown Region',
              seasonList: seasonList,
            );
            break;
          case 'Harvest':
            targetScreen = HarvestScreen(
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
                    color: Colors.green,
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
      // Haptic feedback
      HapticFeedback.mediumImpact();

      if (spreadsheetId == null) {
        _showSnackBar(context, 'Harap pilih Region terlebih dahulu');
        return;
      }
      if (selectedQA == null) {
        _showSnackBar(context, 'QA SPV belum dipilih gaes!');
        return;
      }
      if (selectedDistrict == null) {
        _showSnackBar(context, 'Hayo, Districtnya belum dipilih!');
        return;
      }

      Widget targetScreen;
      switch (label) {
        case 'Vegetative':
          targetScreen = VegetativeScreen(
            spreadsheetId: spreadsheetId,
            selectedDistrict: selectedDistrict,
            selectedQA: selectedQA,
            selectedSeason: selectedSeason,
            region: region ?? 'Unknown Region',
            seasonList: seasonList,
          );
          break;
        case 'Generative':
          targetScreen = GenerativeScreen(
            spreadsheetId: spreadsheetId,
            selectedDistrict: selectedDistrict,
            selectedQA: selectedQA,
            selectedSeason: selectedSeason,
            region: region ?? 'Unknown Region',
            seasonList: seasonList,
          );
          break;
        case 'Pre-Harvest':
          targetScreen = PreHarvestScreen(
            spreadsheetId: spreadsheetId,
            selectedDistrict: selectedDistrict,
            selectedQA: selectedQA,
            selectedSeason: selectedSeason,
            region: region ?? 'Unknown Region',
            seasonList: seasonList,
          );
          break;
        case 'Harvest':
          targetScreen = HarvestScreen(
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
            Colors.green.withAlpha(50),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(25),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.green.withAlpha(51),
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
                  Colors.green.withAlpha(25),
                  Colors.green.withAlpha(51),
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
              color: Colors.green,
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

// LANGKAH 2: Modifikasi fungsi _showSnackBar untuk menerima tipe
void _showSnackBar(BuildContext context, String message, {SnackBarType type = SnackBarType.error}) {
  Color backgroundColor;
  switch (type) {
    case SnackBarType.success:
      backgroundColor = Colors.green.shade600;
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

// Replace the MenuScreen class in qa_screen.dart

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
            Colors.green.shade700,
            Colors.green.shade800,
            Colors.green.shade900,
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
          // Decorative Background Circles
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

          // Main Content
          Column(
            children: [
              // Profile Section
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
                        // Enhanced Profile Avatar
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
                                    backgroundColor: Colors.green.shade100,
                                    backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                                        ? NetworkImage(userPhotoUrl!)
                                        : const AssetImage('assets/logo.png') as ImageProvider,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // User Name with Animation
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

                        // User Email with Animation
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

                        // Divider with Gradient
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

                        // Enhanced Logout Button
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
                                          borderRadius: BorderRadius.circular(16),
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
                                              color: Colors.green.shade700,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
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

                        // Version Info with Animation
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

              // Enhanced Footer
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
                    // Divider
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

                    // Copyright Text
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
                      'Ahli Huru-Hara',
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

// HAPUS metode _buildEnhancedCategoryCard yang lama dan GANTI dengan KELAS BARU di bawah ini.
// Letakkan di luar kelas QaScreenState, misalnya di paling bawah file.

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
    // BARU: Animasi entri untuk fade in dan slide up
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
                  // Latar Belakang Gradient
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

                  // Konten Kartu
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phase Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: widget.primaryColor.withAlpha((255 * 0.15).toInt()),
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

                        // Judul & Deskripsi
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

                        // Tombol Aksi
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [widget.primaryColor, widget.secondaryColor],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.primaryColor.withAlpha((255 * 0.4).toInt()),
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

                  // Gambar yang "mengambang"
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