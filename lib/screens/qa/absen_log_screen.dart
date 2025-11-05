import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enhanced_absen_service.dart';
import '../services/config_manager.dart';
import 'success_screen.dart';
import '../services/region_mapper_service.dart';
import '../services/google_sheets_api.dart';

class AbsenLogScreen extends StatefulWidget {
  const AbsenLogScreen({super.key});

  @override
  AbsenLogScreenState createState() => AbsenLogScreenState();
}

class AbsenLogScreenState extends State<AbsenLogScreen> with TickerProviderStateMixin {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _inTimeController = TextEditingController();
  Position? _currentPosition;
  File? _image;
  bool isSubmitEnabled = false;
  String _userEmail = 'Memuat...';
  String _userName = 'Memuat...';
  String? _userPhotoUrl;
  String? _spreadsheetId;
  String? _selectedRegion;
  String _userRole = 'qa';
  bool _isLoading = false;
  bool _hasTakenAttendance = false;

  GoogleSheetsApi? _googleSheetsApi;
  final String _worksheetTitle = 'Absen Log';

  bool _isSubmitting = false; // ✅ TAMBAHAN untuk prevent double submit

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  List<String> _availableRegions = [];
  Map<String, String> _regionDocumentIds = {};

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();

    _loadUserData();
    _loadUserRole();
    _loadSpreadsheetId();
    _loadAvailableRegions();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Pengguna';
      _userEmail = prefs.getString('userEmail') ?? 'unknown@email.com'; // Ambil email
      _userPhotoUrl = prefs.getString('userPhotoUrl');
    });
  }

  Future<void> _submitData() async {
    if (_isSubmitting) return;

    // Validasi tetap sama
    if (_selectedRegion == null || _googleSheetsApi == null) {
      _showErrorSnackBar('Harap pilih Region terlebih dahulu!');
      return;
    }
    if (_currentPosition == null) {
      _showErrorSnackBar('Lokasi tidak tersedia. Silakan coba lagi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });

    final now = DateTime.now();

    try {
      // =======================================================
      // LANGKAH 1: SIMPAN KE FIREBASE (PRIORITAS UTAMA)
      // =======================================================
      final dateString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final safeUserName = _userName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
      final safeRegion = _selectedRegion!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
      final customDocumentId = '${safeUserName}_${dateString}_$safeRegion';

      final Map<String, dynamic> absenDataFirebase = {
        'userName': _userName,
        'userEmail': _userEmail,
        'region': _selectedRegion,
        'timestamp': Timestamp.fromDate(now),
        'coordinates': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
      };

      debugPrint('[AbsenLog] 📤 Submitting to Firestore...');
      await FirebaseFirestore.instance
          .collection('absen_logs')
          .doc(customDocumentId)
          .set(absenDataFirebase);
      debugPrint('[AbsenLog] ✅ Firestore submission successful');

      // =======================================================
      // LANGKAH 2: SIMPAN KE GOOGLE SHEETS (SEBAGAI BACKUP)
      // =======================================================
      // Proses ini berjalan setelah Firebase berhasil.
      // Jika gagal, tidak akan menghentikan alur sukses absensi.
      try {
        final dateForSheet = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
        final timeForSheet = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        final coordinatesForSheet = '${_currentPosition!.latitude}, ${_currentPosition!.longitude}';

        final List<String> dataForSheet = [
          _userName,
          dateForSheet,
          timeForSheet,
          coordinatesForSheet
        ];

        debugPrint('[AbsenLog] 📤 Submitting to Google Sheets as backup...');
        await _googleSheetsApi!.init();
        await _googleSheetsApi!.addRow(_worksheetTitle, dataForSheet);
        debugPrint('[AbsenLog] ✅ Google Sheets backup successful');

      } catch (sheetError) {
        // Jika Sheets gagal, cukup catat error-nya. Aplikasi tetap lanjut.
        debugPrint('[AbsenLog] ⚠️ Google Sheets backup failed: $sheetError');
      }

      // =======================================================
      // LANJUTKAN ALUR SUKSES
      // =======================================================
      await AbsenCacheManager.markAbsenAction();
      await AbsenCacheManager.invalidateCache();

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SuccessScreen()),
      ).then((_) {
        if (mounted) Navigator.of(context).pop(true);
      });

    } catch (e) {
      debugPrint('[AbsenLog] ❌ Main submission error (Firestore): $e');
      if (mounted) {
        _showErrorSnackBar('Gagal menyimpan data utama. Silakan coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _loadAvailableRegions() async {
    try {
      // ✅ Load config dan region mapper
      await ConfigManager.loadConfig();
      await RegionMapperService.loadMappings();

      // ✅ Get regions berdasarkan role
      _regionDocumentIds = RegionMapperService.getRegionDocumentIdsForRole(_userRole);

      setState(() {
        _availableRegions = _regionDocumentIds.keys.toList();
        // ✅ SORTING ALFABETIS
        _availableRegions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });

      debugPrint('[AbsenLog] Loaded ${_availableRegions.length} regions for role: $_userRole');
      debugPrint('[AbsenLog] Regions (sorted): $_availableRegions');
    } catch (e) {
      debugPrint('[AbsenLog] Error loading regions: $e');
    }
  }

  void _showRegionPicker() {
    HapticFeedback.lightImpact();

    // ✅ Check jika belum ada regions
    if (_availableRegions.isEmpty) {
      _showErrorSnackBar('Tidak ada region tersedia untuk role Anda');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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

              // Header with Role Info
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade400, Colors.green.shade600],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_city_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pilih Region',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // ✅ Show role info
                              Text(
                                'Role: ${_userRole.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),

                    // ✅ Region count info
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_availableRegions.length} region tersedia',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // List Items
              Expanded(
                child: _availableRegions.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada region tersedia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hubungi admin untuk konfigurasi',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _availableRegions.length,
                  itemBuilder: (context, index) {
                    final region = _availableRegions[index];
                    final isSelected = _selectedRegion == region;

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

                          if (spreadsheetId == null) {
                            Navigator.pop(context);
                            _showErrorSnackBar('Spreadsheet ID tidak ditemukan untuk region ini');
                            return;
                          }

                          // Save ke preferences
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('selectedRegion', region);

                          setState(() {
                            _selectedRegion = region;
                            _spreadsheetId = spreadsheetId;
                          });

                          // ignore: use_build_context_synchronously
                          Navigator.pop(context);

                          HapticFeedback.mediumImpact();
                          _showSuccessSnackBar('Region $region berhasil dipilih!');

                          debugPrint('[AbsenLog] Region selected: $region');
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
    );
  }

  Future<void> _loadUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'qa';
    });
    debugPrint('[AbsenLog] User role: $_userRole');
  }

  // Pastikan fungsi ini menginisialisasi _googleSheetsApi
  Future<void> _loadSpreadsheetId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? selectedRegion = prefs.getString('selectedRegion');

    if (selectedRegion != null) {
      setState(() {
        _selectedRegion = selectedRegion;
        _spreadsheetId = ConfigManager.getSpreadsheetId(selectedRegion);
        // INISIALISASI API
        if (_spreadsheetId != null) {
          _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    // ✅ TAMBAHKAN validasi region di awal
    if (_spreadsheetId == null) {
      _showErrorSnackBar('Harap pilih Region terlebih dahulu!');
      return;
    }

    setState(() => _isLoading = true);

    var status = await Permission.location.request();

    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100,
          ),
        );

        if (!mounted) return;
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _hasTakenAttendance = true;
        });

        HapticFeedback.mediumImpact();
        _showSuccessSnackBar('Lokasi berhasil diambil!');
      } catch (e) {
        debugPrint('Error while accessing location: $e');
        setState(() => _isLoading = false);
        _showErrorSnackBar('Gagal mendapatkan lokasi');
      }
    } else {
      debugPrint('Location permission denied');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Izin lokasi ditolak');
    }
  }

  Future<void> _pickImage() async {
    if (!_hasTakenAttendance) {
      _showWarningSnackBar('Silakan ambil absensi terlebih dahulu!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      var status = await Permission.camera.request();

      if (status.isGranted) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );

        if (image != null) {
          if (!mounted) return;
          setState(() {
            _image = File(image.path);
            isSubmitEnabled = true;
            _isLoading = false;
          });
          HapticFeedback.mediumImpact();
          _showSuccessSnackBar('Foto berhasil diambil!');
        } else {
          debugPrint("No image selected");
          setState(() => _isLoading = false);
        }
      } else {
        debugPrint('Camera permission denied');
        setState(() => _isLoading = false);
        _showErrorSnackBar('Izin kamera ditolak');
      }
    } catch (e) {
      debugPrint("Error while accessing camera: $e");
      setState(() => _isLoading = false);
      _showErrorSnackBar('Gagal mengambil foto');
    }
  }

  void _autoFillDateTime() {
    final now = DateTime.now();
    _dateController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _inTimeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return; // ✅ TAMBAHKAN safety check

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2), // ✅ TAMBAHKAN duration
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_isSubmitting, // ✅ Prevent back saat submitting
        // ignore: deprecated_member_use
        onPopInvoked: (didPop) {
          if (!didPop && _isSubmitting) {
            _showWarningSnackBar('Mohon tunggu, sedang menyimpan data...');
          }
        },
        child: Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            height: 280,
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
            ),
          ),

          // Decorative Circles
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

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                _buildCustomAppBar(),

                // Scrollable Content
                Expanded(
                  child: _isLoading
                      ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
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
                          Lottie.asset(
                            'assets/loading.json',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Memproses...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildUserCard(),
                            const SizedBox(height: 16),
                            _buildDateTimeCard(),
                            const SizedBox(height: 16),
                            _buildLocationCard(),
                            const SizedBox(height: 16),
                            _buildPhotoCard(),
                            const SizedBox(height: 24),
                            _buildActionButton(),
                            const SizedBox(height: 16),
                            _buildInstructionCard(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: _isSubmitting
                  ? null // ✅ Disable back button saat submitting
                  : () {
                HapticFeedback.lightImpact();
                Navigator.pop(context, false); // Return false = cancel
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Absen Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Catat kehadiran Anda',
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
            color: Colors.green.withAlpha(30),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // User Info Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(80),
                      blurRadius: 12,
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
                    radius: 28,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                        ? NetworkImage(_userPhotoUrl!)
                        : const AssetImage('assets/logo.png') as ImageProvider,
                    child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                        ? Icon(
                      Icons.person_rounded,
                      color: Colors.green.shade700,
                      size: 32,
                    )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ✅ Show role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade100, Colors.blue.shade50],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge_rounded,
                            size: 12,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Region Selector Card
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showRegionPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: _selectedRegion != null
                      ? LinearGradient(
                    colors: [Colors.green.shade100, Colors.green.shade50],
                  )
                      : LinearGradient(
                    colors: [Colors.orange.shade100, Colors.orange.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedRegion != null
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedRegion != null
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.orange.shade400, Colors.orange.shade600],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedRegion != null
                            ? Icons.location_city_rounded
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Region',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedRegion ?? 'Pilih Region Dulu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _selectedRegion != null
                                  ? Colors.green.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: _selectedRegion != null
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Waktu Absen',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateTimeField('Tanggal', _dateController.text, Icons.calendar_today_rounded),
          const SizedBox(height: 12),
          _buildDateTimeField('Jam Masuk', _inTimeController.text, Icons.schedule_rounded),
        ],
      ),
    );
  }

  Widget _buildDateTimeField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100.withAlpha(127),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
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
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '--:--' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Lokasi Saat Ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade50,
                  Colors.orange.shade100.withAlpha(127),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.shade200,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      size: 18,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Koordinat GPS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currentPosition == null
                      ? 'Belum mengambil lokasi'
                      : '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _currentPosition == null
                        ? Colors.grey.shade500
                        : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Foto Absensi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _pickImage();
            },
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: _image == null
                    ? LinearGradient(
                  colors: [
                    Colors.grey.shade50,
                    Colors.grey.shade100.withAlpha(127),
                  ],
                )
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _image == null
                      ? Colors.grey.shade300
                      : Colors.purple.shade300,
                  width: 2,
                ),
                boxShadow: _image != null
                    ? [
                  BoxShadow(
                    color: Colors.purple.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : [],
              ),
              child: _image == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _hasTakenAttendance
                          ? Colors.purple.shade50
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 48,
                      color: _hasTakenAttendance
                          ? Colors.purple.shade400
                          : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hasTakenAttendance
                        ? 'Tap untuk mengambil foto'
                        : 'Ambil absensi terlebih dahulu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _hasTakenAttendance
                          ? Colors.purple.shade700
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasTakenAttendance
                        ? 'Kamera akan terbuka otomatis'
                        : 'Tekan tombol di bawah',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      _image!,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Foto Tersimpan',
                              style: TextStyle(
                                fontSize: 12,
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
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    String buttonText = isSubmitEnabled
        ? 'SUBMIT ABSENSI'
        : _hasTakenAttendance
        ? 'AMBIL FOTO'
        : 'AMBIL ABSENSI';

    IconData buttonIcon = isSubmitEnabled
        ? Icons.check_circle_rounded
        : _hasTakenAttendance
        ? Icons.camera_alt_rounded
        : Icons.fingerprint_rounded;

    List<Color> gradientColors = isSubmitEnabled
        ? [Colors.green.shade500, Colors.green.shade700]
        : _hasTakenAttendance
        ? [Colors.purple.shade400, Colors.purple.shade600]
        : [Colors.blue.shade500, Colors.blue.shade700];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: gradientColors),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withAlpha(100),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (isSubmitEnabled) {
              _submitData();
            } else if (_hasTakenAttendance) {
              _pickImage();
            } else {
              if (_spreadsheetId == null) {
                _showErrorSnackBar('Harap pilih Region terlebih dahulu!');
                return;
              }
              _autoFillDateTime();
              _getCurrentLocation();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  buttonIcon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withAlpha(127),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withAlpha(60),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Panduan Absensi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionStep(
            1,
            'Tekan "AMBIL ABSENSI"',
            'Sistem akan mengisi tanggal, jam, dan lokasi otomatis',
            Icons.fingerprint_rounded,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            2,
            'Tekan "AMBIL FOTO"',
            'Kamera akan terbuka untuk mengambil foto selfie',
            Icons.camera_alt_rounded,
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            3,
            'Tekan "SUBMIT ABSENSI"',
            'Data absensi akan tersimpan ke sistem',
            Icons.check_circle_rounded,
            Colors.green,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pastikan Region sudah dipilih di halaman utama',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(
      int step,
      String title,
      String description,
      IconData icon,
      MaterialColor color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.shade400, color.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(60),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: color.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}