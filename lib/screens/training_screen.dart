import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import untuk fitur kalender
import 'training_sheet_api.dart'; // Import TrainingSheetApi
import 'success_screen.dart';
import 'package:lottie/lottie.dart';
import 'config_manager.dart';

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
    _trainingSheetApi = TrainingSheetApi(_spreadsheetId); // Inisialisasi hanya sekali
    _loadConfig(); // Muat konfigurasi region
    _loadSheetData(); // Muat data dari Google Sheets
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

  Future<void> _loadConfig() async {
    await ConfigManager.loadConfig(); // Muat konfigurasi dari config.json
  }

  Future<void> _onRegionSelected(String? region) async {
    setState(() {
      _selectedRegion = region;
      _isLoading = true; // Tampilkan loading saat perubahan region
    });

    // Ambil Spreadsheet ID berdasarkan region yang dipilih
    final String? spreadsheetId = ConfigManager.getSpreadsheetId(region!);
    if (spreadsheetId != null) {
      // Perbarui Spreadsheet ID tanpa inisialisasi ulang
      await _trainingSheetApi.updateSpreadsheet(spreadsheetId);
    }

    setState(() {
      _isLoading = false; // Selesai memuat
    });
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

      if (!mounted) return;  // Pastikan widget masih ter-mount

      // Tampilkan notifikasi sukses
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SuccessScreen(),
        ),
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
          ? Center(child: Lottie.asset('assets/loading.json'))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Dropdown untuk Region
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedRegion,
                onChanged: (value) async {
                  await _onRegionSelected(value); // Fungsi baru untuk menangani pemilihan region
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

