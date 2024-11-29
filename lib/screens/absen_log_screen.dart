import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'google_sheets_api.dart'; // Import GoogleSheetsApi
import 'success_screen.dart';    // Import SuccessScreen
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

class AbsenLogScreen extends StatefulWidget {
  const AbsenLogScreen({super.key});

  @override
  AbsenLogScreenState createState() => AbsenLogScreenState(); // Mengubah ke public
}

class AbsenLogScreenState extends State<AbsenLogScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _inTimeController = TextEditingController();
  Position? _currentPosition;
  File? _image;
  bool isSubmitEnabled = false;
  String _userName = 'Memuat...'; // Inisialisasi userName dengan teks default

  // Inisialisasi GoogleSheetsApi
  final GoogleSheetsApi _googleSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
  final String _worksheetTitle = 'Absen Log';

  @override
  void initState() {
    super.initState();
    _initGoogleSheets();
    _loadUserName(); // Panggil fungsi untuk memuat userName dari SharedPreferences
  }

  // Fungsi untuk memuat userName dari SharedPreferences
  Future<void> _loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  // Inisialisasi API Google Sheets
  Future<void> _initGoogleSheets() async {
    try {
      await _googleSheetsApi.init();
      debugPrint('Google Sheets API berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('Error inisialisasi Google Sheets API: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
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
        });
      } catch (e) {
        debugPrint('Error while accessing location: $e');
      }
    } else {
      debugPrint('Location permission denied');
    }
  }

  Future<void> _pickImage() async {
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
          });
        } else {
          debugPrint("No image selected");
        }
      } else {
        debugPrint('Camera permission denied');
      }
    } catch (e) {
      debugPrint("Error while accessing camera: $e");
    }
  }

  // Function to auto-fill date and time when the user presses the absen button
  void _autoFillDateTime() {
    final now = DateTime.now();
    _dateController.text = "${now.day}/${now.month}/${now.year}";
    _inTimeController.text = "${now.hour}:${now.minute}";
  }

  Future<void> _submitData() async {
    if (_currentPosition != null) {
      final List<String> data = [
        _userName,
        _dateController.text,
        _inTimeController.text,
        '${_currentPosition!.latitude}, ${_currentPosition!.longitude}'
      ];

      try {
        await _googleSheetsApi.addRow(_worksheetTitle, data);

        if (!mounted) return;

        // Tampilkan notifikasi sukses saat absen berhasil
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Absen berhasil dilakukan")),
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const SuccessScreen(),
          ),
        );
      } catch (e) {
        debugPrint('Error submitting data: $e');
      }
    } else {
      debugPrint('No location available');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Absen Log',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildReadOnlyField('Nama', _userName),
            _buildReadOnlyField('Tanggal', _dateController.text),
            _buildReadOnlyField('Jam', _inTimeController.text),
            const SizedBox(height: 20),
            _buildLocationField(),
            const SizedBox(height: 20),
            _buildImagePicker(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSubmitEnabled
                  ? _submitData
                  : () async {
                _autoFillDateTime();
                await _getCurrentLocation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(isSubmitEnabled ? 'Submit' : 'Absen'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tekan tombol Absen untuk mengisi tanggal, jam dan lokasi secara otomatis.\nKemudian ambil foto untuk memunculkan tombol Submit.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value.isEmpty ? 'Belum diisi' : value),
      ),
    );
  }

  Widget _buildLocationField() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Lokasi (Otomatis diambil)',
        border: OutlineInputBorder(),
      ),
      child: Text(
        _currentPosition == null
            ? 'Belum mengambil lokasi'
            : 'Lat: ${_currentPosition?.latitude}, Long: ${_currentPosition?.longitude}',
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Foto (Wajib)'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          child: _image == null
              ? Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Icon(
              Icons.camera_alt,
              color: Colors.grey,
              size: 100,
            ),
          )
              : Image.file(
            _image!,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}
