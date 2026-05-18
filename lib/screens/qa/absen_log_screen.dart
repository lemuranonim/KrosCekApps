import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kroscek/widgets/advanta_loading_state.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// 🌟 IMPORT SERVICE V2
import '../services/v2_enhanced_absen_service.dart';
import 'success_screen.dart';

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
  bool _isLoading = false;
  bool isSubmitEnabled = false;

  String _userEmail = 'Memuat...';
  String _userName = 'Memuat...';
  String? _selectedRegion;
  String _userRole = 'Memuat...';

  bool _hasAbsenToday = false;
  String? _jamAbsenTerdeteksi;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // 1. Ambil data profil dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('userEmail') ?? 'no-email@kroscek.id';
      _userName = prefs.getString('userName') ?? 'User Kroscek';
      _userRole = prefs.getString('userRole') ?? 'QA';
      _selectedRegion = prefs.getString('userRegion');

      _dateController.text = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());
    });

    // 2. Cek status absen hari ini ke Supabase V2
    await _checkAbsenStatus();

    // 3. Ambil lokasi otomatis
    await _getCurrentLocation();

    setState(() => _isLoading = false);
  }

  Future<void> _checkAbsenStatus() async {
    final status = await V2EnhancedAbsenService.checkAbsenStatus(userEmail: _userEmail);

    if (mounted) {
      setState(() {
        _hasAbsenToday = status['hasAbsen'] ?? false;
        if (_hasAbsenToday) {
          _jamAbsenTerdeteksi = status['jamAbsen'];
          _inTimeController.text = _jamAbsenTerdeteksi ?? '--:--';
        } else {
          _inTimeController.text = DateFormat('HH:mm').format(DateTime.now());
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // 🌟 FORMAT BARU GEOLOCATOR
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        setState(() {
          _currentPosition = position;
          _checkSubmitStatus();
        });
      }
    } catch (e) {
      debugPrint("Error lokasi: $e");
    }
  }

  Future<void> _pickImage() async {
    if (_hasAbsenToday) return;

    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      preferredCameraDevice: CameraDevice.front,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _checkSubmitStatus();
      });
    }
  }

  void _checkSubmitStatus() {
    setState(() {
      isSubmitEnabled = _image != null && _currentPosition != null && !_hasAbsenToday;
    });
  }

  Future<void> _submitAbsensi() async {
    if (!isSubmitEnabled || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final result = await V2EnhancedAbsenService.submitAbsen(
        userEmail: _userEmail,
        userName: _userName,
        role: _userRole,
        region: _selectedRegion ?? 'Unknown',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        image: _image!,
      );

      if (result['success']) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            // 🌟 MENGHILANGKAN PARAMETER 'title' YANG ERROR
            MaterialPageRoute(builder: (context) => const SuccessScreen()),
          );
        }
      } else {
        throw result['message'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Log Absensi QA', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const AdvantaLoadingState(
              title: 'Menyiapkan absensi',
              subtitle: 'Memeriksa status dan lokasi',
              accentColor: Colors.green,
              icon: Icons.location_searching_rounded,
            )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 25),

            _buildInfoField('Tanggal Hari Ini', _dateController, Icons.calendar_today),
            const SizedBox(height: 15),
            _buildInfoField('Jam Masuk', _inTimeController, Icons.access_time),
            const SizedBox(height: 25),

            const Text('Langkah Absensi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildStepItem(
              step: 1,
              title: 'Verifikasi Lokasi',
              description: _currentPosition != null
                  ? 'Lokasi terdeteksi (${_currentPosition!.latitude.toStringAsFixed(4)})'
                  : 'Mencari sinyal GPS...',
              icon: Icons.location_on,
              color: _currentPosition != null ? Colors.green : Colors.orange,
            ),

            const SizedBox(height: 12),

            GestureDetector(
              onTap: _pickImage,
              child: _buildStepItem(
                step: 2,
                title: 'Ambil Foto Selfie',
                description: _image != null ? 'Foto sudah diambil' : 'Klik untuk buka kamera',
                icon: Icons.camera_alt,
                color: _image != null ? Colors.green : Colors.blue,
                trailing: _image != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_image!, width: 50, height: 50, fit: BoxFit.cover),
                )
                    : null,
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSubmitEnabled ? _submitAbsensi : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text('KIRIM ABSENSI SEKARANG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _hasAbsenToday ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _hasAbsenToday ? Colors.green.shade200 : Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Lottie.asset(
            _hasAbsenToday ? 'assets/success_check.json' : 'assets/waiting.json',
            width: 60,
            repeat: _hasAbsenToday ? false : true,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasAbsenToday ? 'Anda Sudah Absen' : 'Siap Kerja Hari Ini?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _hasAbsenToday ? Colors.green.shade900 : Colors.blue.shade900),
                ),
                Text(
                  _hasAbsenToday
                      ? 'Terdeteksi pada jam $_jamAbsenTerdeteksi'
                      : 'Pastikan GPS aktif dan ambil foto selfie terbaikmu.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: Colors.green),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required int step,
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.shade700, radius: 15, child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          if (trailing != null) trailing else Icon(icon, color: color.shade300),
        ],
      ),
    );
  }
}
