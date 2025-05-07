import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'google_sheets_api.dart';
import 'success_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_manager.dart';
import 'package:lottie/lottie.dart';

class AbsenLogScreen extends StatefulWidget {
  const AbsenLogScreen({super.key});

  @override
  AbsenLogScreenState createState() => AbsenLogScreenState();
}

class AbsenLogScreenState extends State<AbsenLogScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _inTimeController = TextEditingController();
  Position? _currentPosition;
  File? _image;
  bool isSubmitEnabled = false;
  String _userName = 'Memuat...';
  String? _spreadsheetId;
  bool _isLoading = false;
  bool _hasTakenAttendance = false; // New flag to track if attendance was taken

  GoogleSheetsApi? _googleSheetsApi;
  final String _worksheetTitle = 'Absen Log';

  // Green color palette
  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _primaryLightColor = const Color(0xFF81C784);
  final Color _primaryDarkColor = const Color(0xFF1B5E20);
  final Color _backgroundColor = const Color(0xFFF5F5F6);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF263238);

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadSpreadsheetId();
  }

  Future<void> _loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  Future<void> _loadSpreadsheetId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? selectedRegion = prefs.getString('selectedRegion');

    if (selectedRegion != null) {
      String? spreadsheetId = ConfigManager.getSpreadsheetId(selectedRegion);
      setState(() {
        _spreadsheetId = spreadsheetId;
        if (spreadsheetId != null) {
          _googleSheetsApi = GoogleSheetsApi(spreadsheetId);
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
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
          _hasTakenAttendance = true; // Set flag to true after successful attendance
        });
      } catch (e) {
        debugPrint('Error while accessing location: $e');
        setState(() => _isLoading = false);
      }
    } else {
      debugPrint('Location permission denied');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    // Check if attendance has been taken first
    if (!_hasTakenAttendance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan tekan "AMBIL ABSENSI" terlebih dahulu'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var status = await Permission.camera.request();

      if (status.isGranted) {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.camera);

        if (image != null) {
          if (!mounted) return;
          setState(() {
            _image = File(image.path);
            isSubmitEnabled = true;
            _isLoading = false;
          });
        } else {
          debugPrint("No image selected");
          setState(() => _isLoading = false);
        }
      } else {
        debugPrint('Camera permission denied');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error while accessing camera: $e");
      setState(() => _isLoading = false);
    }
  }

  void _autoFillDateTime() {
    final now = DateTime.now();
    _dateController.text = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _inTimeController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _submitData() async {
    if (_spreadsheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih Region terlebih dahulu sebelum Absen!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi tidak tersedia. Silakan coba lagi.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_googleSheetsApi == null || _spreadsheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spreadsheet ID tidak ditemukan untuk region yang dipilih.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final List<String> data = [
      _userName,
      _dateController.text,
      _inTimeController.text,
      '${_currentPosition!.latitude}, ${_currentPosition!.longitude}'
    ];

    try {
      await _googleSheetsApi!.init();
      await _googleSheetsApi!.addRow(_worksheetTitle, data);

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SuccessScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Error saat mengirim data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal menyimpan data. Silakan coba lagi.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Absen Log',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: _primaryDarkColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
          child: Lottie.asset('assets/loading.json')
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildUserCard(),
            const SizedBox(height: 20),
            _buildDateTimeCard(),
            const SizedBox(height: 20),
            _buildLocationCard(),
            const SizedBox(height: 20),
            _buildPhotoCard(),
            const SizedBox(height: 30),
            _buildActionButton(),
            const SizedBox(height: 15),
            _buildInstructionText(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _primaryLightColor,
              child: Icon(Icons.person, color: Colors.white),
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
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${_spreadsheetId != null ? 'Region Terpilih' : 'Region Belum Dipilih'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _spreadsheetId != null ? _primaryColor : Colors.orange,
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

  Widget _buildDateTimeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Waktu Absen',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryDarkColor,
              ),
            ),
            const SizedBox(height: 12),
            _buildDateTimeField('Tanggal', _dateController.text),
            const SizedBox(height: 12),
            _buildDateTimeField('Jam Masuk', _inTimeController.text),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '--:--' : value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Lokasi Saat Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryDarkColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Koordinat GPS',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentPosition == null
                        ? 'Belum mengambil lokasi'
                        : '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _textColor,
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

  Widget _buildPhotoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Foto Absensi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryDarkColor,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: _image == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 50,
                      color: _hasTakenAttendance
                          ? Colors.grey[400]
                          : Colors.grey[200],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasTakenAttendance
                          ? 'Klik untuk mengambil foto'
                          : 'Silakan ambil absensi terlebih dahulu',
                      style: TextStyle(
                        color: _hasTakenAttendance
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _image!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return ElevatedButton(
      onPressed: isSubmitEnabled
          ? _submitData
          : () async {
        if (_spreadsheetId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Harap pilih Region terlebih dahulu sebelum Absen!'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _autoFillDateTime();
        await _getCurrentLocation();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSubmitEnabled
            ? _primaryColor
            : _hasTakenAttendance
            ? _primaryLightColor
            : _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: _primaryColor.withAlpha(763),
      ),
      child: Text(
        isSubmitEnabled
            ? 'SUBMIT ABSENSI'
            : _hasTakenAttendance
            ? 'AMBIL FOTO'
            : 'AMBIL ABSENSI',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInstructionText() {
    return Text(
          '1. Tekan tombol "Ambil Absensi" untuk mengisi tanggal, jam dan lokasi\n'
          '2. Setelah berhasil, tombol akan berubah menjadi "Ambil Foto"\n'
          '3. Ambil foto untuk memunculkan tombol Submit\n'
          '4. Pastikan Region sudah dipilih sebelum melakukan absensi',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}