import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../services/config_manager.dart';
import 'training_sheet_api.dart';
import 'success_screen.dart';

class TrainingScreen extends StatefulWidget {
  final Function(List<String>) onSave;

  const TrainingScreen({super.key, required this.onSave});

  @override
  TrainingScreenState createState() => TrainingScreenState();
}

class TrainingScreenState extends State<TrainingScreen> {
  late final TrainingSheetApi _trainingSheetApi;
  final _spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';

  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _fieldInspectorController = TextEditingController();
  final TextEditingController _growerController = TextEditingController();
  final TextEditingController _subGrowerController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _tkdExistedController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _manController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _manHoursController = TextEditingController();

  String? _selectedRegion;
  final List<String> _regionOptions = [
    'Region 1',
    'Region 2',
    'Region 3',
    'Region 4',
    'Region 5',
    'Region 6',
    'NTB',
  ];

  @override
  void initState() {
    super.initState();
    _trainingSheetApi = TrainingSheetApi(_spreadsheetId);
    _loadConfig();
    _loadSheetData();
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
    await ConfigManager.loadConfig();
  }

  Future<void> _onRegionSelected(String? region) async {
    setState(() {
      _selectedRegion = region;
      _isLoading = true;
    });

    final String? spreadsheetId = ConfigManager.getSpreadsheetId(region!);
    if (spreadsheetId != null) {
      await _trainingSheetApi.updateSpreadsheet(spreadsheetId);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _calculateManHours() {
    if (_manController.text.isNotEmpty && _hoursController.text.isNotEmpty) {
      double man = double.tryParse(_manController.text) ?? 0;
      double hours = double.tryParse(_hoursController.text) ?? 0;
      double manHours = man * hours;
      setState(() {
        _manHoursController.text = manHours.toString();
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
    if (_formKey.currentState!.validate()) {
      try {
        String weekOfTrainingFormula = '=WEEKNUM(${_dateController.text})';

        List<String> rowData = [
          _selectedRegion!,
          _fieldInspectorController.text,
          _growerController.text,
          _subGrowerController.text,
          _lokasiController.text,
          _tkdExistedController.text,
          _dateController.text,
          weekOfTrainingFormula,
          _manController.text,
          _hoursController.text,
          _manHoursController.text,
        ];

        await _trainingSheetApi.addTrainingRow(rowData);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SuccessScreen(),
          ),
        );

        // Reset form
        _formKey.currentState?.reset();
        _selectedRegion = null;
        _manHoursController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Training Form',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700], // Changed to green
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(15),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/loading.json',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            Text(
              'Ngrantos sekedap...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDropdownField(
                        'Region',
                        _selectedRegion,
                        _regionOptions,
                            (value) => _onRegionSelected(value),
                        validator: (value) => value == null
                            ? 'Please select a region'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Nama Field Inspector',
                        _fieldInspectorController,
                        Icons.person,
                        validator: (value) => value!.isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Grower',
                        _growerController,
                        Icons.people,
                        validator: (value) => value!.isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        'Sub Grower',
                        _subGrowerController,
                        Icons.people_outline,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTextField(
                        'Lokasi',
                        _lokasiController,
                        Icons.location_on,
                        validator: (value) => value!.isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildNumericField(
                        'TKD Existed',
                        _tkdExistedController,
                        Icons.numbers,
                        validator: (value) => value!.isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(context),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildNumericField(
                        'Man',
                        _manController,
                        Icons.man,
                        onChanged: _calculateManHours,
                        validator: (value) => value!.isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildNumericField(
                        'Hours',
                        _hoursController,
                        Icons.access_time,
                        onChanged: _calculateManHours,
                        validator: (value) => value!.isEmpty
                            ? 'This field is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildDisabledTextField(
                        'Man × Hours',
                        _manHoursController,
                        Icons.calculate,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submitForm();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700], // Changed to green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'SUBMIT FORM',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
      String label,
      String? value,
      List<String> items,
      Function(String?) onChanged, {
        String? Function(String?)? validator,
      }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: const Icon(Icons.map, color: Colors.green), // Changed to green
      ),
      style: TextStyle(
        color: Colors.grey[800],
        fontSize: 15,
      ),
      validator: validator,
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(Icons.arrow_drop_down, size: 28),
      isExpanded: true,
      hint: Text(
        'Select $label',
        style: TextStyle(color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.green), // Changed to green
      ),
      style: TextStyle(
        color: Colors.grey[800],
        fontSize: 15,
      ),
      validator: validator,
    );
  }

  Widget _buildNumericField(
      String label,
      TextEditingController controller,
      IconData icon, {
        VoidCallback? onChanged,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (value) {
        if (onChanged != null) {
          onChanged();
        }
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.teal),
      ),
      style: TextStyle(
        color: Colors.grey[800],
        fontSize: 15,
      ),
      validator: validator,
    );
  }

  Widget _buildDateField(BuildContext context) {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: () => _selectDate(context),
      decoration: InputDecoration(
        labelText: 'Date of Training',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: const Icon(Icons.calendar_today, color: Colors.green), // Changed to green
        suffixIcon: IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () => _selectDate(context),
        ),
      ),
      style: TextStyle(
        color: Colors.grey[800],
        fontSize: 15,
      ),
      validator: (value) =>
      value!.isEmpty ? 'Please select a date' : null,
    );
  }

  Widget _buildDisabledTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      ) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.green), // Changed to green
        filled: true,
        fillColor: Colors.grey[100],
      ),
      style: TextStyle(
        color: Colors.grey[800],
        fontSize: 15,
      ),
    );
  }
}