import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import untuk fitur kalender
import 'training_sheet_api.dart'; // Import TrainingSheetApi
import 'package:http/http.dart' as http;  // Import http package for POST request
import 'dart:convert';  // Tambahkan ini untuk mendukung jsonEncode
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName

class TrainingScreen extends StatefulWidget {
  final Function(List<String>) onSave;

  const TrainingScreen({super.key, required this.onSave});

  @override
  TrainingScreenState createState() => TrainingScreenState();
}

class TrainingScreenState extends State<TrainingScreen> {
  late final TrainingSheetApi _trainingSheetApi;
  final _spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA'; // Spreadsheet ID yang benar

  bool _isLoading = true;

  // Controllers untuk field input
  final TextEditingController _fieldInspectorController = TextEditingController();
  final TextEditingController _growerController = TextEditingController();
  final TextEditingController _subGrowerController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _tkdExistedController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _manController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _manHoursController = TextEditingController(); // Man * Hours (dihitung otomatis)

  String? _selectedRegion; // Untuk dropdown Region

  final List<String> _regionOptions = [
    'Region 1',
    'Region 2',
    'Region 3',
    'Region 4',
    'Region 5',
    'Region 6',
    'NTB',
  ]; // Pilihan untuk dropdown Region

  @override
  void initState() {
    super.initState();
    _trainingSheetApi = TrainingSheetApi(_spreadsheetId);
    _loadSheetData(); // Memuat data dari Google Sheets
  }

  Future<void> _loadSheetData() async {
    try {
      await _trainingSheetApi.init();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk menghitung Man * Hours
  void _calculateManHours() {
    if (_manController.text.isNotEmpty && _hoursController.text.isNotEmpty) {
      double man = double.tryParse(_manController.text) ?? 0;
      double hours = double.tryParse(_hoursController.text) ?? 0;
      double manHours = man * hours;
      setState(() {
        _manHoursController.text = manHours.toString(); // Hasil Man * Hours otomatis
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_selectedRegion == null ||
        _fieldInspectorController.text.isEmpty ||
        _growerController.text.isEmpty ||
        _subGrowerController.text.isEmpty ||
        _lokasiController.text.isEmpty ||
        _tkdExistedController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _manController.text.isEmpty ||
        _hoursController.text.isEmpty ||
        _manHoursController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    try {
      // Buat rumus Week of Training untuk spreadsheet
      String weekOfTrainingFormula = '=WEEKNUM(${_dateController.text})';

      // Buat list data yang akan ditambahkan (tanpa nomor, nomor diisi otomatis)
      List<String> rowData = [
        _selectedRegion!,
        _fieldInspectorController.text,
        _growerController.text,
        _subGrowerController.text,
        _lokasiController.text,
        _tkdExistedController.text,
        _dateController.text,
        weekOfTrainingFormula, // Week of Training otomatis dari rumus
        _manController.text, // Man pada row 9
        _hoursController.text, // Hours pada row 10
        _manHoursController.text, // Hasil Man * Hours otomatis
      ];

      // Tambahkan data ke worksheet Training
      await _trainingSheetApi.addTrainingRow(rowData);

      // Panggil fungsi untuk mengirim POST request ke Apps Script setelah berhasil menyimpan
      await _sendPostToHistory(rowData);

      if (!mounted) return;  // Pastikan widget masih ter-mount

      // Tampilkan notifikasi sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data added successfully')),
      );

      // Reset form setelah submit
      _selectedRegion = null;
      _fieldInspectorController.clear();
      _growerController.clear();
      _subGrowerController.clear();
      _lokasiController.clear();
      _tkdExistedController.clear();
      _dateController.clear();
      _manController.clear();
      _hoursController.clear();
      _manHoursController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add data: $e')),
      );
    }
  }

  Future<void> _sendPostToHistory(List<String> rowData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userName = prefs.getString('userName') ?? 'Unknown User';

    final String url = 'https://script.google.com/macros/s/AKfycbwg3XKvFj9tsCCI9eJjHkcF508nqi-kFPXBfPeeJoOssdNTXgT10jV_VAlAebd7QzmZiw/exec';  // URL doPost di Apps Script

    // Susun data yang akan dikirim dalam format JSON
    final Map<String, dynamic> historyData = {
      'pageType': 'training',  // Tipe halaman
      'action': 'add',  // Aksi yang dilakukan
      'rowData': rowData,  // Data yang disimpan
      'user': userName,  // Nama pengguna yang melakukan perubahan
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(historyData),  // Encode data ke format JSON
      );

      if (response.statusCode == 200) {
        debugPrint('Data berhasil dicatat di History');
      } else {
        debugPrint('Gagal mencatat data di History: ${response.body}');
      }
    } catch (error) {
      debugPrint('Error saat mengirim data ke History: $error');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Training',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Dropdown untuk Region
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedRegion,
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value;
                  });
                },
                items: _regionOptions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region,
                    child: Text(region),
                  );
                }).toList(),
                decoration: const InputDecoration(
                  labelText: 'Region',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            _buildTextField('Nama Field Inspector', _fieldInspectorController),
            _buildTextField('Grower', _growerController),
            _buildTextField('Sub Grower', _subGrowerController),
            _buildTextField('Lokasi', _lokasiController),

            // Field angka untuk TKD Existed
            _buildNumericField('TKD Existed', _tkdExistedController),

            // Fitur kalender untuk Date of Training
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Training',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () {
                      _selectDate(context);
                    },
                  ),
                ),
              ),
            ),

            // Field angka untuk Man (row 9)
            _buildNumericField('Man', _manController, _calculateManHours),

            // Field angka untuk Hours (row 10)
            _buildNumericField('Hours', _hoursController, _calculateManHours),

            // Hasil Man * Hours (dihitung otomatis)
            _buildDisabledTextField('Man x Hours', _manHoursController),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk input angka dengan callback
  Widget _buildNumericField(String label, TextEditingController controller, [VoidCallback? onChanged]) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
    controller: controller,
    keyboardType: TextInputType.number,
      onChanged: (value) {
        if (onChanged != null) {
          onChanged();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
    );
  }

  // Widget untuk field yang tidak bisa diubah (Man x Hours)
  Widget _buildDisabledTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // Widget untuk input teks biasa
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

