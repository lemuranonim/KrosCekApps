// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:ui'; // Penting untuk efek Glassmorphism

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'inspection_form_screen.dart';

class PiScreen extends StatefulWidget {
  const PiScreen({super.key});

  @override
  PiScreenState createState() => PiScreenState();
}

class PiScreenState extends State<PiScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _appVersion = 'Fetching...';
  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  String? userPhotoUrl;

  final ZoomDrawerController _drawerController = ZoomDrawerController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  String _greeting = '';
  String _currentTime = '';
  Timer? _timer;

  // --- Theme Colors (Emerald Green) ---
  final Color _primaryGreen = Colors.green.shade700;
  final Color _accentTeal = Colors.teal.shade400;
  // final Color _accentEmerald = const Color(0xFF10B981); // Emerald Green

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
    super.dispose();
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
      _currentTime = DateFormat('EEEE, d MMMM yyyy', 'en_US').format(now);
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      await _fetchAppVersion();
      await _fetchUserData();
      await _fetchGoogleUserData();
    } catch (e) {
      debugPrint("Error loading initial data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      }
    } catch (error) {
      debugPrint("Error fetching Google data: $error");
    }
  }

  Future<void> _fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'User';
    });
  }

  Future<void> _fetchAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() => _appVersion = packageInfo.version);
    } catch (e) {
      setState(() => _appVersion = 'Unknown');
    }
  }

  // --- HANDLE BACK PRESS (EXIT APP) ---
  void _handleBackPress() {
    // 1. Jika Drawer terbuka, tutup dulu
    if (_drawerController.isOpen!()) {
      _drawerController.close!();
      return;
    }

    // 2. Jika Drawer tertutup, tampilkan Dialog Konfirmasi Keluar
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(Icons.exit_to_app_rounded, color: Colors.red.shade600),
              const SizedBox(width: 12),
              const Text(
                  "Konfirmasi Medal",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
              ),
            ],
          ),
          content: const Text(
            "Menopo panjenengan badhe medal saking aplikasi puniko?",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Batal", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                // Keluar dari Aplikasi (Minimize/Close)
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text("Medal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.white.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.logout_rounded, color: _primaryGreen),
                const SizedBox(width: 12),
                const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text("Are you sure you want to logout?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Logout", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmLogout == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userRole');
      await _googleSignIn.signOut();

      if (mounted) {
        // ignore: use_build_context_synchronously
        context.go('/login');
      }
    }
  }

  void _navigateToInspection() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PlantInspectionForm(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubicEmphasized;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Panggil fungsi handle back yang baru
          _handleBackPress();
        }
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
        slideWidth: MediaQuery.of(context).size.width * 0.85,
        openCurve: Curves.easeInOutCubicEmphasized,
        closeCurve: Curves.easeInOutCubicEmphasized,
        menuBackgroundColor: Colors.purple.shade100,
      ),
    );
  }

  Widget _buildMainScreen(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(85),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.green.shade700.withOpacity(0.85),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade300, Colors.teal.shade400],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade700.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Plant Inspector',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Smart Monitoring System',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  leading: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                      onPressed: () => _drawerController.toggle!(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: _buildHomeContent(context),
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

  Widget _buildHomeContent(BuildContext context) {
    // 1. CEK JIKA EMAIL BELUM SIAP (Mencegah Query Prematur)
    if (userEmail == 'Fetching...' || userEmail == 'Unknown Email') {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryGreen),
            const SizedBox(height: 16),
            const Text("Memuat profil pengguna..."),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- GLASS HEADER ---
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.0),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade900, Colors.teal.shade800],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade900.withOpacity(0.3),
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
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 60, spreadRadius: 10)],
                    ),
                  ),
                ),

                ClipRRect(
                  borderRadius: BorderRadius.circular(32.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _accentTeal.withOpacity(0.5), width: 2),
                                boxShadow: [BoxShadow(color: _accentTeal.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)],
                              ),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.purple.shade100,
                                backgroundImage: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                                    ? NetworkImage(userPhotoUrl!)
                                    : const AssetImage('assets/logo.png') as ImageProvider,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting,
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userName,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.white.withOpacity(0.15), height: 1),
                        const SizedBox(height: 20),
                        Row(
                          children: [
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
                                  Icon(Icons.calendar_today_rounded, size: 14, color: _accentTeal),
                                  const SizedBox(width: 8),
                                  Text(_currentTime, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- HERO ACTION BUTTON (Premium Glassmorphism) ---
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _navigateToInspection();
            },
            child: Container(
              width: double.infinity,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade600.withOpacity(0.9),
                    Colors.teal.shade700.withOpacity(0.85),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade700.withOpacity(0.35),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.teal.shade600.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(-5, -5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Stack(
                    children: [
                      // Animated background circles
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -40,
                        bottom: -40,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      // Main content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        child: Row(
                          children: [
                            // Icon container with gradient
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade200, Colors.teal.shade300],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.shade400.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 20),
                            // Text content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Mulai Inspeksi Baru',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lakukan pemeriksaan plant',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Arrow icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 22,
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

          const SizedBox(height: 30),

          // --- HISTORY SECTION (UPDATED) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.history_edu_rounded, color: _primaryGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text('Inspeksi Terkini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- LIST INSPEKSI (STREAM BUILDER STABIL) ---
          StreamBuilder<QuerySnapshot>(
            // ✅ Gunakan Unique Key untuk mencegah rebuild yang tidak perlu
            key: ValueKey(userEmail),
            stream: FirebaseFirestore.instance
                .collection('plant_inspections')
                .where('inspector_email', isEqualTo: userEmail)
                .orderBy('created_at', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {

              // 1. Loading State (Hanya jika benar-benar waiting)
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(color: _primaryGreen),
                    )
                );
              }

              // 2. Error State (Untuk Debugging)
              if (snapshot.hasError) {
                debugPrint("❌ Error Stream: ${snapshot.error}");
                return Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade50,
                  child: Text("Error memuat data: ${snapshot.error}\nEmail: $userEmail", style: TextStyle(color: Colors.red)),
                );
              }

              // 3. Empty State (Data Kosong)
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                debugPrint("⚠️ Stream Active tapi data KOSONG untuk email: $userEmail");
                return _buildEmptyState();
              }

              // 4. Data Ada -> Tampilkan List
              debugPrint("✅ Stream Active: ${snapshot.data!.docs.length} data ditemukan");

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final String location = data['nama_lokasi'] ?? 'Lokasi Tidak Diketahui';
                  final String finding = data['temuan'] ?? '-';
                  final String category = data['kategori'] ?? 'Others';
                  final Timestamp? timestamp = data['created_at'];
                  final String dateStr = timestamp != null
                      ? DateFormat('dd MMM, HH:mm').format(timestamp.toDate())
                      : '-';

                  final List<dynamic> photos = data['photo_urls'] ?? [];
                  final String? thumbnail = photos.isNotEmpty
                      ? _getDirectDriveLink(photos.first)
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showInspectionDetail(context, data),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  image: thumbnail != null
                                      ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: thumbnail == null
                                    ? Icon(Icons.image_not_supported_rounded, color: Colors.grey.shade400)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                        Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(finding, style: TextStyle(fontSize: 13, color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 8),
                                    _buildCategoryBadge(category),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ✅ WIDGET KOSONG
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.eco_outlined, size: 40, color: Colors.green.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Inspeksi',
            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Mulai inspeksi pertama Anda hari ini!',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- HELPER: KONVERSI LINK DRIVE KE DIRECT IMAGE ---
  String _getDirectDriveLink(String viewLink) {
    // Cek apakah ini link Google Drive
    if (viewLink.contains('drive.google.com') && viewLink.contains('/d/')) {
      try {
        // Ambil ID File dari URL
        // Format: https://drive.google.com/file/d/ID_FILE/view...
        final id = viewLink.split('/d/')[1].split('/')[0];

        // Gunakan URL "lh3.googleusercontent.com" untuk loading gambar super cepat & cache friendly
        return 'https://lh3.googleusercontent.com/d/$id';
      } catch (e) {
        return viewLink; // Jika gagal parsing, kembalikan aslinya
      }
    }
    return viewLink;
  }

  // ✅ BADGE WARNA KATEGORI
  Widget _buildCategoryBadge(String category) {
    Color bgColor;
    Color textColor;

    switch (category) {
      case 'NC':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'Observasi':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bgColor.withOpacity(0.5)), // darken border slightly
      ),
      child: Text(
        category,
        style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ✅ FITUR: POPUP DETAIL INSPEKSI
  void _showInspectionDetail(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment_turned_in_rounded, color: _primaryGreen),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Inspeksi',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                        Text(
                          data['nama_lokasi'] ?? '-',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _buildCategoryBadge(data['kategori'] ?? 'Others'),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Details
              _buildDetailRow(Icons.person_outline, 'Inspector', data['inspector_name']),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.calendar_today_outlined, 'Waktu',
                  data['created_at'] != null
                      ? DateFormat('EEEE, dd MMMM yyyy • HH:mm').format((data['created_at'] as Timestamp).toDate())
                      : '-'),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.search_rounded, 'Temuan', data['temuan']),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.description_outlined, 'Deskripsi', data['deskripsi']),
              const SizedBox(height: 24),

              // Photos
              if (data['photo_urls'] != null && (data['photo_urls'] as List).isNotEmpty) ...[
                const Text('Foto Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (data['photo_urls'] as List).length,
                    itemBuilder: (context, index) {
                      // UBAH BARIS INI JUGA
                      final rawUrl = data['photo_urls'][index];
                      final url = _getDirectDriveLink(rawUrl); // Konversi dulu

                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(url), // URL sudah direct
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value ?? '-', style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
            ],
          ),
        ),
      ],
    );
  }
}
// ==================== MENU SCREEN (PREMIUM) ====================
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
          colors: [Colors.green.shade600, Colors.green.shade700, Colors.green.shade900],
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
                                            Icon(Icons.logout_rounded, size: 24, color: Colors.green.shade700),
                                            const SizedBox(width: 14),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.green.shade700,
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