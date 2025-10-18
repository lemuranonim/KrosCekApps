import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class TrainingScreenState extends State<TrainingScreen>
    with TickerProviderStateMixin {
  late final TrainingSheetApi _trainingSheetApi;
  final _spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';

  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

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

    _trainingSheetApi = TrainingSheetApi(_spreadsheetId);
    _loadConfig();
    _loadSheetData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();

      setState(() {
        _isLoading = true;
      });

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
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Gagal menyimpan: $e')),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                // Form Content
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
                            'Ngrantos sekedap...',
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionCard(
                                'Informasi Dasar',
                                Icons.info_rounded,
                                Colors.blue,
                                [
                                  _buildDropdownField(
                                    'Region',
                                    _selectedRegion,
                                    _regionOptions,
                                        (value) => _onRegionSelected(value),
                                    validator: (value) => value == null
                                        ? 'Pilih region terlebih dahulu'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Nama Field Inspector',
                                    _fieldInspectorController,
                                    Icons.person_rounded,
                                    validator: (value) => value!.isEmpty
                                        ? 'Field ini wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Grower',
                                    _growerController,
                                    Icons.people_rounded,
                                    validator: (value) => value!.isEmpty
                                        ? 'Field ini wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Sub Grower',
                                    _subGrowerController,
                                    Icons.people_outline_rounded,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              _buildSectionCard(
                                'Detail Lokasi & Tanggal',
                                Icons.location_on_rounded,
                                Colors.orange,
                                [
                                  _buildTextField(
                                    'Lokasi',
                                    _lokasiController,
                                    Icons.place_rounded,
                                    validator: (value) => value!.isEmpty
                                        ? 'Field ini wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildNumericField(
                                    'TKD Existed',
                                    _tkdExistedController,
                                    Icons.numbers_rounded,
                                    validator: (value) => value!.isEmpty
                                        ? 'Field ini wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDateField(context),
                                ],
                              ),

                              const SizedBox(height: 20),

                              _buildSectionCard(
                                'Perhitungan Man Hours',
                                Icons.calculate_rounded,
                                Colors.purple,
                                [
                                  _buildNumericField(
                                    'Man',
                                    _manController,
                                    Icons.man_rounded,
                                    onChanged: _calculateManHours,
                                    validator: (value) => value!.isEmpty
                                        ? 'Field ini wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildNumericField(
                                    'Hours',
                                    _hoursController,
                                    Icons.access_time_rounded,
                                    onChanged: _calculateManHours,
                                    validator: (value) => value!.isEmpty
                                        ? 'Field ini wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDisabledTextField(
                                    'Man × Hours (Hasil)',
                                    _manHoursController,
                                    Icons.functions_rounded,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 30),

                              _buildSubmitButton(),

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
              onPressed: () {
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
                  'Training Form',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Isi form training TKD',
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      String title,
      IconData icon,
      MaterialColor color,
      List<Widget> children,
      ) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.shade50, color.shade100.withAlpha(127)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.shade400, color.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100.withAlpha(127)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(Icons.map_rounded, color: Colors.green.shade600),
        ),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        validator: validator,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(Icons.arrow_drop_down_rounded, size: 28),
        isExpanded: true,
        hint: Text(
          'Pilih $label',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        String? Function(String?)? validator,
      }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100.withAlpha(127)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.green.shade600),
        ),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildNumericField(
      String label,
      TextEditingController controller,
      IconData icon, {
        VoidCallback? onChanged,
        String? Function(String?)? validator,
      }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100.withAlpha(127)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (value) {
          if (onChanged != null) {
            onChanged();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.teal.shade600),
        ),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade50, Colors.grey.shade100.withAlpha(127)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: _dateController,
        readOnly: true,
        onTap: () {
          HapticFeedback.lightImpact();
          _selectDate(context);
        },
        decoration: InputDecoration(
          labelText: 'Tanggal Training',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(Icons.calendar_today_rounded, color: Colors.green.shade600),
          suffixIcon: IconButton(
            icon: Icon(Icons.event_rounded, color: Colors.green.shade600),
            onPressed: () {
              HapticFeedback.lightImpact();
              _selectDate(context);
            },
          ),
        ),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        validator: (value) => value!.isEmpty ? 'Pilih tanggal training' : null,
      ),
    );
  }

  Widget _buildDisabledTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100.withAlpha(76)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.green.shade700),
        ),
        style: TextStyle(
          color: Colors.green.shade900,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade700],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(80),
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
            if (_formKey.currentState!.validate()) {
              _submitForm();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'SUBMIT TRAINING',
                  style: TextStyle(
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
}