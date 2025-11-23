// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SERVICES
import '../services/google_drive_service.dart';
import '../services/google_sheets_api.dart';
import '../services/config_manager.dart';

class PlantInspectionForm extends StatefulWidget {
  const PlantInspectionForm({super.key});

  @override
  State<PlantInspectionForm> createState() => _PlantInspectionFormState();
}

class _PlantInspectionFormState extends State<PlantInspectionForm> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ID FOLDER GOOGLE DRIVE KHUSUS PI
  final String _piDriveFolderId = '1RlL2iUzyVixAHtp_WdFEPLAUkvQifwxB';

  final TextEditingController _temuanController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

  Position? _currentPosition;
  final List<XFile> _selectedImages = [];
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  bool _hasLocationData = false;
  late DateTime _inspectionDateTime;

  String? _selectedKategori;
  final List<String> _kategoriOptions = ['Improvement', 'NC', 'Others']; // Typo fixed: Obsevasi -> Observasi

  // Dropdown options untuk Site Toller
  String? _selectedSiteToller;
  final List<String> _siteToollerOptions = [
    'Prasad 1 Pasuruan',
    'Prasad 2 Pasuruan',
    'Prasad Malang',
    'Prasad Lombok',
    'Prasad NTB',
    'Restu Kediri',
    'Restu Klaten',
    'Winmar Kediri',
  ];

  // Dropdown options untuk Function Area
  String? _selectedFunctionArea;
  final List<String> _functionAreaOptions = ['Drier', 'Warehouse', 'CTP', 'Intake'];

  // Dropdown options untuk Reported Shift
  String? _selectedReportedShift;
  final List<String> _reportedShiftOptions = ['Shift 1', 'Shift 2', 'Shift 3'];

  List<String> _officerList = [];
  String? _selectedOfficer;
  bool _isLoadingOfficers = false;

  GoogleSheetsApi? _googleSheetsApi;
  final String _worksheetTitle = 'Plant Inspection'; // Pastikan sheet ini ada di Excel
  final String _officerSheetTitle = 'Officer';
  String? _selectedRegion;
  String? _spreadsheetId;
  List<String> _availableRegions = [];
  String _userRole = 'pi'; // Default Role

  // Colors
  final Color _primaryColor = Colors.green.shade700;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _inspectionDateTime = DateTime.now();

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

    _initData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _temuanController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadUserRoleAndRegions();
  }

  Future<void> _fetchOfficers() async {
    if (_googleSheetsApi == null) return;

    setState(() {
      _isLoadingOfficers = true;
      _officerList = [];
      _selectedOfficer = null;
    });

    try {
      debugPrint("🔍 [Officer] Fetching list from sheet: $_officerSheetTitle");

      // Inisialisasi API jika belum
      await _googleSheetsApi!.init();

      // Ambil semua data dari tab Officer
      final rows = await _googleSheetsApi!.getSpreadsheetData(_officerSheetTitle);

      List<String> loadedOfficers = [];

      // Loop mulai index 1 (Lewati Header Baris 1)
      if (rows.length > 1) {
        for (int i = 1; i < rows.length; i++) {
          // Pastikan baris tidak kosong dan kolom A (index 0) ada isinya
          if (rows[i].isNotEmpty && rows[i][0].trim().isNotEmpty) {
            loadedOfficers.add(rows[i][0].trim());
          }
        }
      }

      // Sort alfabetis agar rapi
      loadedOfficers.sort();

      // Cek SharedPreferences untuk Auto-Select jika nama user cocok dengan list
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('userName');

      String? initialSelection;
      if (savedName != null && loadedOfficers.contains(savedName)) {
        initialSelection = savedName;
      }

      if (mounted) {
        setState(() {
          _officerList = loadedOfficers;
          _selectedOfficer = initialSelection;
          _isLoadingOfficers = false;
        });
      }

      debugPrint("✅ [Officer] Loaded ${loadedOfficers.length} names");

    } catch (e) {
      debugPrint("❌ [Officer] Gagal load data: $e");
      if (mounted) {
        setState(() {
          _isLoadingOfficers = false;
          _officerList = [];
        });
        _showErrorSnackBar("Gagal memuat daftar Officer dari Spreadsheet");
      }
    }
  }

  // GANTI METHOD INI
  Future<void> _loadUserRoleAndRegions() async {
    setState(() => _isLoadingLocation = true); // Pakai loading indicator yang ada

    try {
      // 1. Load Spreadsheet IDs (Config)
      await ConfigManager.loadConfig();

      // 2. Tentukan Role (Hardcode 'pi' sementara untuk memastikan)
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String role = prefs.getString('userRole') ?? 'pi';

      // Jika user login sebagai 'qa' tapi ingin tes menu 'pi', paksa disini:
      // role = 'pi';

      debugPrint("🔍 [PI Form] Fetching mappings for role: $role...");

      // 3. FETCH LANGSUNG DARI SERVER (BYPASS CACHE)
      // Ini solusi kuncinya: Source.server
      final docSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('region_mappings')
          .get(const GetOptions(source: Source.server));

      if (!docSnapshot.exists) {
        debugPrint("❌ [PI Form] Dokumen region_mappings tidak ditemukan!");
        return;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      debugPrint("🔍 [PI Form] Raw Data Loaded: ${data.keys.toList()}");

      if (data.containsKey(role)) {
        // Ambil Map milik role 'pi'
        final roleMap = data[role] as Map<String, dynamic>;

        // Convert ke List String untuk dropdown
        final List<String> regions = roleMap.keys.toList();
        regions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        debugPrint("✅ [PI Form] Regions Found: $regions");

        if (mounted) {
          setState(() {
            _userRole = role;
            _availableRegions = regions;
          });
        }

        // Auto-select jika ada history
        final savedRegion = prefs.getString('selectedRegion');
        if (savedRegion != null && _availableRegions.contains(savedRegion)) {
          _selectRegion(savedRegion);
        }
      } else {
        debugPrint("⚠️ [PI Form] Key '$role' tidak ditemukan di region_mappings");
        if(mounted) _showErrorSnackBar("Role '$role' belum dikonfigurasi di Database.");
      }

    } catch (e) {
      debugPrint('❌ Error loading regions: $e');
      if(mounted) _showErrorSnackBar('Gagal memuat data: $e');
    } finally {
      if(mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _selectRegion(String regionLabel) async {
    try {
      debugPrint("🔍 [PI Form] Selecting region: $regionLabel");

      // 1. Ambil Mapping Langsung dari Server (Bypass Cache)
      // Kita ambil ulang mapping untuk memastikan kita punya Key yang benar untuk ConfigManager
      final docSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('region_mappings')
          .get(const GetOptions(source: Source.server));

      String? configKey;

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        // Pastikan _userRole valid, jika tidak ada ambil map kosong
        final roleMap = (data[_userRole] ?? {}) as Map<String, dynamic>;
        configKey = roleMap[regionLabel];
      }

      debugPrint("🔍 [PI Form] Config Key from mapping: $configKey");

      // 2. Ambil Spreadsheet ID dari ConfigManager
      // Coba cari pakai Config Key (hasil mapping) dulu
      String? spreadsheetId;

      if (configKey != null) {
        spreadsheetId = ConfigManager.getSpreadsheetId(configKey);
      }

      // ✅ PERBAIKAN: Null-aware assignment
      // Jika spreadsheetId masih null, coba cari pakai Label-nya langsung (Fallback)
      spreadsheetId ??= ConfigManager.getSpreadsheetId(regionLabel);

      debugPrint("🔍 [PI Form] Final Spreadsheet ID: $spreadsheetId");

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        _showErrorSnackBar('Spreadsheet ID belum disetting untuk wilayah ini.');
        return;
      }

      // 3. Update State
      setState(() {
        _selectedRegion = regionLabel;
        _spreadsheetId = spreadsheetId;
        // Inisialisasi API dengan ID yang baru ditemukan
        _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
      });

      // 4. Simpan ke Memory HP (Preferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedRegion', regionLabel);

      _fetchOfficers();

    } catch (e) {
      debugPrint("❌ Error selecting region: $e");
      _showErrorSnackBar("Gagal memilih region: $e");
    }
  }

  void _showRegionPicker() {
    // Debugging jika list kosong
    if (_availableRegions.isEmpty) {
      _showErrorSnackBar('Tidak ada department untuk role: $_userRole. Cek Firestore (config/region_mappings/$_userRole)');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pilih Department Inspeksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _availableRegions.length,
                itemBuilder: (context, index) {
                  final region = _availableRegions[index];
                  return ListTile(
                    leading: const Icon(Icons.business_rounded, color: Colors.green),
                    title: Text(region, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: _selectedRegion == region ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      _selectRegion(region);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... [Function _getCurrentLocation, _pickImages, _removeImage SAMA SEPERTI SEBELUMNYA] ...
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _hasLocationData = true;
        });
        _showSuccessSnackBar('Lokasi berhasil diambil!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal mendapatkan lokasi: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        // 👇 TURUNKAN KUALITAS BIAR LEBIH RINGAN
        // 80 masih cukup bagus. Kalau masih gagal, coba 50 or 60.
        imageQuality: 60,
        maxWidth: 1024, // Batasi lebar gambar (resize otomatis)
      );
      if (image != null) {
        if (mounted) {
          setState(() => _selectedImages.add(image));
          _showSuccessSnackBar('Foto berhasil diambil!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal mengambil foto: $e');
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ✅ LOGIKA UTAMA SUBMIT (FIRESTORE + DRIVE + SHEETS)
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOfficer == null) {
      _showErrorSnackBar('❌ Nama Officer WAJIB dipilih!');
      return;
    }
    if (_selectedRegion == null || _googleSheetsApi == null) {
      _showErrorSnackBar('❌ Department WAJIB dipilih!');
      _showRegionPicker();
      return;
    }
    if (_selectedKategori == null) {
      _showErrorSnackBar('❌ Kategori WAJIB dipilih!');
      return;
    }
    if (_selectedSiteToller == null) {
      _showErrorSnackBar('❌ Site Toller WAJIB dipilih!');
      return;
    }
    if (_selectedFunctionArea == null) {
      _showErrorSnackBar('❌ Function Area WAJIB dipilih!');
      return;
    }
    if (_selectedReportedShift == null) {
      _showErrorSnackBar('❌ Reported Shift WAJIB dipilih!');
      return;
    }
    if (_currentPosition == null) {
      _showErrorSnackBar('❌ Lokasi WAJIB diambil terlebih dahulu!');
      return;
    }
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('❌ Minimal 1 foto bukti diperlukan!');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail') ?? 'unknown';
      final userName = _selectedOfficer!;

      // 1️⃣ UPLOAD FOTO KE GOOGLE DRIVE (FOLDER KHUSUS PI)
      List<String> uploadedPhotoLinks = [];
      final driveService = GoogleDriveService();

      debugPrint('[Inspection] Uploading ${_selectedImages.length} images to Drive PI Folder...');

      for (var xFile in _selectedImages) {
        try {
          File file = File(xFile.path);

          // ✅ MENGGUNAKAN FOLDER ID KHUSUS PI
          String? link = await driveService.uploadImage(
              file,
              userName,
              _selectedRegion!,
              targetFolderId: _piDriveFolderId // Gunakan parameter baru
          );

          if (link != null) {
            uploadedPhotoLinks.add(link);
          }
        } catch (e) {
          debugPrint("❌ Gagal upload foto: $e");
        }
      }

      String photoLinksString = uploadedPhotoLinks.isNotEmpty
          ? uploadedPhotoLinks.join(',\n')
          : '-';

      // 2️⃣ SIMPAN KE FIRESTORE
      debugPrint('[Inspection] Saving to Firestore...');

      final inspectionData = {
        'inspector_email': userEmail,
        'inspector_name': userName,
        'department': _selectedRegion, // Label Department
        'nama_lokasi': userName,
        'kategori': _selectedKategori,
        'temuan': _temuanController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'map_link': 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}',
        'photo_count': _selectedImages.length,
        'photo_urls': uploadedPhotoLinks,
        'inspection_date': _inspectionDateTime,
        'created_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('plant_inspections').add(inspectionData);

      // ============================================================
      // 3️⃣ LANGKAH 3: SIMPAN KE GOOGLE SHEETS (SESUAI GAMBAR)
      // ============================================================
      debugPrint('[Inspection] Saving to Google Sheets...');

      try {
        final dateFormat = DateFormat('dd/MM/yyyy').format(_inspectionDateTime);
        final timeFormat = DateFormat('HH:mm').format(_inspectionDateTime);
        final fullDate = "$dateFormat $timeFormat";

        // Format Koordinat & Link Map
        final lat = _currentPosition!.latitude;
        final lng = _currentPosition!.longitude;
        final coordText = '$lat, $lng';
        // Link standar Google Maps
        final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

        // ---------------------------------------------------------
        // MENYUSUN DATA ROW SESUAI KOLOM (A - M)
        // Urutan: No, Department, Timestamp, Coordinate, Site Toller, Function Area,
        //         Reported Date, Reported Shift, Officer Name, Finding, Categories,
        //         Description, Documentation
        // ---------------------------------------------------------
        final List<String> rowData = [
          // Col A: No
          '=ROW()-1',

          // Col B: Department
          _selectedRegion ?? '-',

          // Col C: Timestamp
          fullDate,

          // Col D: Coordinate
          '=HYPERLINK("$mapUrl"; "$coordText")',

          // Col E: Site Toller
          _selectedSiteToller ?? '-',

          // Col F: Function Area
          _selectedFunctionArea ?? '-',

          // Col G: Reported Date
          dateFormat,

          // Col H: Reported Shift
          _selectedReportedShift ?? '-',

          // Col I: Officer Name
          userName,

          // Col J: Finding (Subject)
          _temuanController.text.trim(),

          // Col K: Categories
          _selectedKategori ?? '-',

          // Col L: Description
          _deskripsiController.text.trim(),

          // Col M: Documentation (Photo Links)
          photoLinksString.contains('http')
              ? '=HYPERLINK("$photoLinksString"; "Lihat Foto")'
              : photoLinksString
        ];

        await _googleSheetsApi!.init();
        // Pastikan nama Worksheet sesuai dengan yang ada di Spreadsheet Anda
        await _googleSheetsApi!.addRow(_worksheetTitle, rowData);
        debugPrint('[Inspection] ✅ Google Sheets success');

      } catch (sheetError) {
        debugPrint("⚠️ Gagal simpan ke Sheets: $sheetError");
        // Error sheets tidak menghentikan flow sukses
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
                SizedBox(height: 10),
                Text('Berhasil Dikirim!', textAlign: TextAlign.center),
              ],
            ),
            content: const Text(
              'Laporan inspeksi berhasil disimpan.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Gagal mengirim laporan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ... [Helper methods seperti _showSuccessSnackBar, _showErrorSnackBar TETAP SAMA] ...
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      onPopInvoked: (didPop) {
        if (!didPop && _isSubmitting) {
          _showErrorSnackBar('Mohon tunggu, sedang menyimpan data...');
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
                    _primaryColor,
                    Colors.teal.shade800,
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
                    child: _isLoadingLocation
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
                              'Mengambil Lokasi...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
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
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ✅ WIDGET REGION PICKER BARU
                                _buildRegionSelector(),
                                const SizedBox(height: 16),

                                _buildDateTimeCard(),
                                const SizedBox(height: 16),
                                _buildLocationCard(),
                                const SizedBox(height: 16),
                                _buildFormFieldsCard(),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 1. WIDGET KARTU SELECTOR (Gaya seperti Department)
  // =======================================================
  Widget _buildSelectionCard({
    required String title,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isError = false,
    String errorText = '',
    bool isLocked = false,
  }) {
    Color borderColor;
    Color iconColor;
    Color iconBgColor;

    if (isLocked) {
      borderColor = Colors.grey.shade300;
      iconColor = Colors.grey.shade500;
      iconBgColor = Colors.grey.shade100;
    } else if (isError) {
      borderColor = Colors.red.shade300;
      iconColor = Colors.red.shade600;
      iconBgColor = Colors.red.shade50;
    } else if (value == null) {
      borderColor = Colors.orange.shade300;
      iconColor = Colors.orange.shade700;
      iconBgColor = Colors.orange.shade100;
    } else {
      borderColor = Colors.green.shade300;
      iconColor = Colors.green.shade700;
      iconBgColor = Colors.green.shade100;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked || isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade50.withOpacity(0.5) : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: value == null ? 1.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: iconColor))
                    : Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLocked
                          ? 'Pilih Department dulu'
                          : isError
                          ? errorText
                          : value ?? 'Pilih $title...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isLocked || isError
                            ? Colors.grey.shade500
                            : value == null
                            ? Colors.orange.shade800
                            : Colors.green.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down_circle_outlined,
                color: isLocked ? Colors.grey.shade300 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================================================
  // 2. POP-UP PICKER UNTUK OFFICER
  // =======================================================
  void _showOfficerPicker() {
    if (_selectedRegion == null) {
      _showErrorSnackBar('Pilih Department terlebih dahulu!');
      return;
    }
    if (_isLoadingOfficers) return;
    if (_officerList.isEmpty) {
      _showErrorSnackBar('Daftar Officer kosong atau gagal dimuat.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pilih Nama Inspector',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _officerList.length,
                itemBuilder: (context, index) {
                  final name = _officerList[index];
                  final isSelected = _selectedOfficer == name;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                      child: Icon(Icons.person, color: isSelected ? Colors.green : Colors.grey),
                    ),
                    title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      setState(() {
                        _selectedOfficer = name;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 3. POP-UP PICKER UNTUK KATEGORI
  // =======================================================
  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4, // Lebih pendek
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pilih Kategori',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _kategoriOptions.length,
                itemBuilder: (context, index) {
                  final category = _kategoriOptions[index];
                  final isSelected = _selectedKategori == category;

                  // Tentukan Icon & Warna
                  IconData catIcon;
                  Color catColor;
                  switch(category) {
                    case 'NC': catIcon = Icons.warning_rounded; catColor = Colors.red; break;
                    case 'Observasi': catIcon = Icons.visibility_rounded; catColor = Colors.blue; break;
                    default: catIcon = Icons.more_horiz_rounded; catColor = Colors.purple; break;
                  }

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: catColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(catIcon, color: catColor, size: 20),
                    ),
                    title: Text(category, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      setState(() => _selectedKategori = category);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 4. POP-UP PICKER UNTUK SITE TOLLER
  // =======================================================
  void _showSiteToollerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pilih Site Toller',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _siteToollerOptions.length,
                itemBuilder: (context, index) {
                  final site = _siteToollerOptions[index];
                  final isSelected = _selectedSiteToller == site;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.factory_rounded, color: Colors.purple, size: 20),
                    ),
                    title: Text(site, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      setState(() => _selectedSiteToller = site);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 5. POP-UP PICKER UNTUK FUNCTION AREA
  // =======================================================
  void _showFunctionAreaPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pilih Function Area',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _functionAreaOptions.length,
                itemBuilder: (context, index) {
                  final area = _functionAreaOptions[index];
                  final isSelected = _selectedFunctionArea == area;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.domain_rounded, color: Colors.indigo, size: 20),
                    ),
                    title: Text(area, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      setState(() => _selectedFunctionArea = area);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // 6. POP-UP PICKER UNTUK REPORTED SHIFT
  // =======================================================
  void _showReportedShiftPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Pilih Reported Shift',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _reportedShiftOptions.length,
                itemBuilder: (context, index) {
                  final shift = _reportedShiftOptions[index];
                  final isSelected = _selectedReportedShift == shift;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.schedule_rounded, color: Colors.amber.shade700, size: 20),
                    ),
                    title: Text(shift, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    onTap: () {
                      setState(() => _selectedReportedShift = shift);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UI REGION SELECTOR
  Widget _buildRegionSelector() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showRegionPicker,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedRegion == null ? Colors.orange.shade300 : Colors.green.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedRegion == null ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.map_rounded,
                  color: _selectedRegion == null ? Colors.orange.shade700 : Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Department',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _selectedRegion ?? 'Pilih Department...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedRegion == null ? Colors.orange.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.grey),
            ],
          ),
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
                  ? null
                  : () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inspection Form',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Laporan Inspeksi Plant Processing',
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

  Widget _buildDateTimeCard() {
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_inspectionDateTime);
    final formattedTime = DateFormat('HH:mm:ss').format(_inspectionDateTime);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.amber.shade300.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.amber.shade400, Colors.orange.shade500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu Inspeksi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Timestamp otomatis',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // DateTime display with glass effect
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.amber.shade50.withOpacity(0.8),
                  Colors.orange.shade50.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.amber.shade300.withOpacity(0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tanggal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 42),
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  color: Colors.amber.shade200.withOpacity(0.5),
                  height: 1,
                  thickness: 1.2,
                ),
                const SizedBox(height: 16),

                // Time section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Waktu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 42),
                  child: Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.orange.shade700,
                      letterSpacing: 0.3,
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

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.blue.shade300.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 15,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan subtitle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade400, Colors.cyan.shade500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Lokasi GPS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    _currentPosition != null ? '✓ Lokasi sudah diambil' : 'Wajib diisi',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentPosition != null ? Colors.green.shade600 : Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Koordinat display dengan animation
          if (_hasLocationData && _currentPosition != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.shade50.withOpacity(0.8),
                    Colors.cyan.shade50.withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.green.shade400.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.teal.shade500],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Lokasi Tersimpan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // LAT
                  _buildCoordinateDisplay(
                    label: 'Latitude',
                    value: _currentPosition!.latitude.toStringAsFixed(6),
                    icon: Icons.north_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: Colors.blue.shade200.withOpacity(0.5),
                    height: 1,
                  ),
                  const SizedBox(height: 16),

                  // LNG
                  _buildCoordinateDisplay(
                    label: 'Longitude',
                    value: _currentPosition!.longitude.toStringAsFixed(6),
                    icon: Icons.east_rounded,
                    color: Colors.cyan,
                  ),
                  const SizedBox(height: 14),

                  // Accuracy info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              size: 16,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Akurasi: ${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Akurat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.shade50.withOpacity(0.7),
                    Colors.orange.shade50.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.red.shade300.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.location_off_rounded,
                      size: 24,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi belum diambil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'Tap tombol di bawah untuk mengambil',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 18),

          // Button dengan glassmorphism
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.cyan.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoadingLocation ? null : _getCurrentLocation,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isLoadingLocation
                            ? Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.only(right: 12),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.location_searching_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        const SizedBox(width: 10),
                        Text(
                          _isLoadingLocation ? 'Mengambil Lokasi...' : '🎯 Update Koordinat',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinateDisplay({
    required String label,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color.shade700),
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
                  fontWeight: FontWeight.w600,
                  color: color.shade700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormFieldsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.green.shade300.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 12)),
          BoxShadow(color: Colors.white.withOpacity(0.6), blurRadius: 15, offset: const Offset(-5, -5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.teal.shade500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8)],
                ),
                child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detail Inspeksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
                  Text('Lengkapi data di bawah', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1. NAMA INSPECTOR (UI BARU)
          _buildSelectionCard(
            title: 'Nama Inspector',
            value: _selectedOfficer,
            icon: Icons.person_rounded,
            onTap: _showOfficerPicker,
            isLoading: _isLoadingOfficers,
            isLocked: _selectedRegion == null,
            isError: _selectedRegion != null && !_isLoadingOfficers && _officerList.isEmpty,
            errorText: 'Gagal load data / Kosong',
          ),

          const SizedBox(height: 16),

          // 2. KATEGORI (UI BARU)
          _buildSelectionCard(
            title: 'Kategori',
            value: _selectedKategori,
            icon: Icons.category_rounded,
            onTap: _showCategoryPicker,
          ),

          const SizedBox(height: 16),

          // 3. SITE TOLLER (UI BARU)
          _buildSelectionCard(
            title: 'Site Toller',
            value: _selectedSiteToller,
            icon: Icons.factory_rounded,
            onTap: _showSiteToollerPicker,
          ),

          const SizedBox(height: 16),

          // 4. FUNCTION AREA (UI BARU)
          _buildSelectionCard(
            title: 'Function Area',
            value: _selectedFunctionArea,
            icon: Icons.domain_rounded,
            onTap: _showFunctionAreaPicker,
          ),

          const SizedBox(height: 16),

          // 5. REPORTED SHIFT (UI BARU)
          _buildSelectionCard(
            title: 'Reported Shift',
            value: _selectedReportedShift,
            icon: Icons.schedule_rounded,
            onTap: _showReportedShiftPicker,
          ),

          const SizedBox(height: 16),

          // 6. TEMUAN (TEXT FIELD TETAP SAMA)
          _buildModernTextField(
            controller: _temuanController,
            label: 'Temuan (Finding)',
            hint: 'Apa yang ditemukan?',
            icon: Icons.search_rounded,
            validator: (value) => value == null || value.isEmpty ? 'Temuan wajib diisi' : null,
          ),

          const SizedBox(height: 16),

          // 4. DESKRIPSI (TEXT FIELD TETAP SAMA)
          _buildModernTextField(
            controller: _deskripsiController,
            label: 'Deskripsi Detail',
            hint: 'Jelaskan secara detail...',
            icon: Icons.description_rounded,
            maxLines: 3,
            validator: (value) => value == null || value.isEmpty ? 'Deskripsi wajib diisi' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.green.shade50.withOpacity(0.6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.green.shade200.withOpacity(0.5),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.green.shade500,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.green.shade200.withOpacity(0.4),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.red.shade400,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.orange.shade200.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(-3, -3),
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
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto Bukti Inspeksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedImages.length} foto tersimpan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImages.isEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _pickImages();
              },
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade50,
                      Colors.orange.shade100.withAlpha(127),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 48,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap untuk Ambil Foto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kamera akan terbuka otomatis',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_selectedImages[index].path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _removeImage(index);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Ambil Foto Lagi'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.orange.shade600),
                      foregroundColor: Colors.orange.shade600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    bool isFormComplete = _currentPosition != null && _selectedImages.isNotEmpty;

    String buttonText = _currentPosition == null
        ? '📍 AMBIL LOKASI DULU'
        : _selectedImages.isEmpty
        ? '📸 AMBIL FOTO DULU'
        : 'SUBMIT LAPORAN';

    IconData buttonIcon = _currentPosition == null
        ? Icons.location_on_rounded
        : _selectedImages.isEmpty
        ? Icons.camera_alt_rounded
        : Icons.send_rounded;

    List<Color> gradientColors = isFormComplete
        ? [_primaryColor, Colors.teal.shade700]
        : [Colors.grey.shade400, Colors.grey.shade600];

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
          onTap: isFormComplete && !_isSubmitting
              ? () {
                  HapticFeedback.mediumImpact();
                  _submitForm();
                }
              : _currentPosition == null
              ? () {
                  HapticFeedback.lightImpact();
                  _showErrorSnackBar('⚠️ Harap ambil lokasi terlebih dahulu!');
                }
              : _selectedImages.isEmpty
              ? () {
                  HapticFeedback.lightImpact();
                  _showErrorSnackBar('⚠️ Harap ambil minimal 1 foto!');
                }
              : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: _isSubmitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      const SizedBox(width: 12),
                      const Text(
                        'Menyimpan...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(buttonIcon, color: Colors.white, size: 24),
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
            Colors.green.shade50.withOpacity(0.9),
            Colors.teal.shade50.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.green.shade300.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.12),
            blurRadius: 25,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 12,
            offset: const Offset(-4, -4),
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
                    colors: [Colors.green.shade400, Colors.teal.shade600],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(60),
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
                'Panduan Inspeksi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionStep(1, 'Update Lokasi', 'Tekan tombol update untuk mendapatkan koordinat GPS', Icons.my_location_rounded, Colors.blue),
          const SizedBox(height: 12),
          _buildInstructionStep(2, 'Isi Detail', 'Lengkapi semua field dengan informasi inspeksi', Icons.description_rounded, Colors.green),
          const SizedBox(height: 12),
          _buildInstructionStep(3, 'Ambil Foto', 'Sertakan minimal 1 foto sebagai bukti inspeksi', Icons.camera_alt_rounded, Colors.orange),
          const SizedBox(height: 12),
          _buildInstructionStep(4, 'Submit', 'Tekan tombol submit untuk menyimpan laporan', Icons.check_circle_rounded, Colors.teal),
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

