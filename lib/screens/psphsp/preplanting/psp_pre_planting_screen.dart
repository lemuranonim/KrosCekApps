// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/google_sheets_api.dart'; // Sesuaikan path ini jika perlu

class PspPrePlantingScreen extends StatefulWidget {
  final String spreadsheetId;
  final String region;
  final String? initialSeason;

  const PspPrePlantingScreen({
    super.key,
    required this.spreadsheetId,
    required this.region,
    this.initialSeason,
  });

  @override
  State<PspPrePlantingScreen> createState() => _PspPrePlantingScreenState();
}

class _PspPrePlantingScreenState extends State<PspPrePlantingScreen> {
  final _formKey = GlobalKey<FormState>();
  late GoogleSheetsApi _googleSheetsApi;
  bool _isSubmitting = false;
  bool _isLoadingConfig = true;

  // --- Controllers ---
  final TextEditingController _fieldNumberController = TextEditingController();
  final TextEditingController _farmerNameController = TextEditingController();
  final TextEditingController _growerController = TextEditingController();
  final TextEditingController _totalAreaController = TextEditingController();
  final TextEditingController _discardAreaController = TextEditingController();
  final TextEditingController _effectiveAreaController = TextEditingController();

  // --- Dropdown Values ---
  String? _selectedSeason;
  String? _selectedCornType;
  String? _selectedSeedType;
  String? _selectedParentCode;
  String? _selectedPrevCrop;

  // --- Data Lists from Firestore ---
  List<String> _seasonList = [];
  List<String> _cornTypeList = [];
  List<String> _seedTypeList = [];
  List<String> _parentCodeList = [];

  // Hardcoded list sesuai permintaan
  final List<String> _prevCropList = [
    'A = Previous Crop not Corn',
    'B = Corn after corn with different trait',
    'C = Corn after Corn same trait'
  ];

  // --- Colors (Premium Theme) ---
  final Color _primaryPurple = Colors.purple.shade800;
  final Color _accentAmber = const Color(0xFFFFC400);

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _selectedSeason = widget.initialSeason;
    _fetchConfigs();

    // Listeners untuk kalkulasi otomatis Area
    _totalAreaController.addListener(_calculateEffectiveArea);
    _discardAreaController.addListener(_calculateEffectiveArea);
  }

  @override
  void dispose() {
    _fieldNumberController.dispose();
    _farmerNameController.dispose();
    _growerController.dispose();
    _totalAreaController.dispose();
    _discardAreaController.dispose();
    _effectiveAreaController.dispose();
    super.dispose();
  }

  void _calculateEffectiveArea() {
    double total = double.tryParse(_totalAreaController.text.replaceAll(',', '.')) ?? 0.0;
    double discard = double.tryParse(_discardAreaController.text.replaceAll(',', '.')) ?? 0.0;
    double effective = total - discard;

    if (effective < 0) effective = 0;

    // Update text hanya jika berbeda agar kursor tidak lompat
    String newValue = effective.toStringAsFixed(2).replaceAll('.', ',');
    if (_effectiveAreaController.text != newValue) {
      _effectiveAreaController.text = newValue;
    }
  }

  Future<void> _fetchConfigs() async {
    try {
      // 1. Fetch Seasons dari 'seasons/season'
      final seasonDoc = await FirebaseFirestore.instance.collection('seasons').doc('season').get();
      if (seasonDoc.exists) {
        setState(() {
          _seasonList = List<String>.from(seasonDoc.data()?['sesi'] ?? []);
        });
      }

      // 2. Fetch Configs dari 'plant_types/corn'
      final plantTypesDoc = await FirebaseFirestore.instance.collection('plant_types').doc('corn').get();

      if (plantTypesDoc.exists) {
        final data = plantTypesDoc.data() ?? {};
        setState(() {
          // Ambil Corn Type
          if (data['corn_type'] != null) {
            _cornTypeList = List<String>.from(data['corn_type']);
          }

          // Ambil Seed Type
          if (data['seed_type'] != null) {
            _seedTypeList = List<String>.from(data['seed_type']);
          }

          // Ambil Parent Code
          if (data['parent_code'] != null) {
            _parentCodeList = List<String>.from(data['parent_code']);
          }
        });
      } else {
        debugPrint("Warning: plant_types/corn not found in Firestore");
      }

    } catch (e) {
      debugPrint("Error fetching configs: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading configs: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _googleSheetsApi.init();

      // Urutan Kolom Sesuai Permintaan:
      // 0. No (Formula)
      // 1. Season
      // 2. Field Number
      // 3. Corn Type
      // 4. Seed Type
      // 5. Farmer Name
      // 6. Grower/Agent
      // 7. Parent Code
      // 8. Total Area Planted
      // 9. Discard Area
      // 10. Effective Area
      // 11. Previous Crop Actual

      final rowData = [
        "=ROW()-1", // Kolom 0: Auto Number via Formula Excel/Sheets
        _selectedSeason ?? "-",
        _fieldNumberController.text.toUpperCase(),
        _selectedCornType ?? "-",
        _selectedSeedType ?? "-",
        _farmerNameController.text.toUpperCase(),
        _growerController.text.toUpperCase(),
        _selectedParentCode ?? "-",
        _totalAreaController.text,
        _discardAreaController.text,
        _effectiveAreaController.text,
        _selectedPrevCrop ?? "-",
      ];

      // Append ke worksheet 'Vegetative'
      await _googleSheetsApi.addRow('Vegetative', rowData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("Pre-Planting data saved successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Kembali dan trigger refresh jika perlu
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back_rounded, color: _primaryPurple),
          ),
        ),
        title: Text(
          "New Pre-Planting",
          style: TextStyle(color: _primaryPurple, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple.shade50, Colors.white],
              ),
            ),
          ),

          if (_isLoadingConfig)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 100), // Top padding for AppBar
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("General Info", Icons.info_outline_rounded),
                    const SizedBox(height: 16),
                    _buildGlassContainer(
                      children: [
                        _buildDropdownField(
                          label: "Season",
                          value: _selectedSeason,
                          items: _seasonList,
                          icon: Icons.calendar_month_rounded,
                          onChanged: (val) => setState(() => _selectedSeason = val),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _fieldNumberController,
                          label: "Field Number",
                          icon: Icons.tag_rounded,
                          validator: (v) => v == null || v.isEmpty ? "Required" : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader("Crop Details", Icons.grass_rounded),
                    const SizedBox(height: 16),
                    _buildGlassContainer(
                      children: [
                        _buildDropdownField(
                          label: "Corn Type",
                          value: _selectedCornType,
                          items: _cornTypeList,
                          icon: Icons.grain_rounded,
                          onChanged: (val) => setState(() => _selectedCornType = val),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: "Seed Type",
                          value: _selectedSeedType,
                          items: _seedTypeList,
                          icon: Icons.spa_rounded,
                          onChanged: (val) => setState(() => _selectedSeedType = val),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: "Parent Code",
                          value: _selectedParentCode,
                          items: _parentCodeList,
                          icon: Icons.qr_code_rounded,
                          onChanged: (val) => setState(() => _selectedParentCode = val),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: "Previous Crop Actual",
                          value: _selectedPrevCrop,
                          items: _prevCropList,
                          icon: Icons.history_edu_rounded,
                          isDense: true, // Karena teksnya panjang
                          onChanged: (val) => setState(() => _selectedPrevCrop = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader("Farmer & Location", Icons.person_pin_circle_rounded),
                    const SizedBox(height: 16),
                    _buildGlassContainer(
                      children: [
                        _buildTextField(
                          controller: _farmerNameController,
                          label: "Farmer Name",
                          icon: Icons.person_rounded,
                          validator: (v) => v == null || v.isEmpty ? "Required" : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _growerController,
                          label: "Grower / Agent",
                          icon: Icons.badge_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader("Area Measurement (Ha)", Icons.area_chart_rounded),
                    const SizedBox(height: 16),
                    _buildGlassContainer(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _totalAreaController,
                                label: "Total Area",
                                icon: Icons.square_foot_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => v == null || v.isEmpty ? "Required" : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _discardAreaController,
                                label: "Discard Area",
                                icon: Icons.delete_outline_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _accentAmber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _accentAmber.withOpacity(0.3)),
                          ),
                          child: _buildTextField(
                            controller: _effectiveAreaController,
                            label: "Effective Area (Auto)",
                            icon: Icons.verified_rounded,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            // readOnly: true, // Bisa di-uncomment kalau mau murni auto
                            labelColor: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Submit Button (Floating)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryPurple.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : const Text(
                  "SUBMIT DATA",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.0
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primaryPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: _primaryPurple,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade900.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    Color? labelColor,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor ?? Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: labelColor ?? Colors.purple.shade300, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryPurple),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
    bool isDense = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: TextStyle(fontSize: isDense ? 12 : 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true, // Agar teks panjang tidak overflow
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.purple.shade300, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _primaryPurple),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
      validator: (v) => v == null ? "Required" : null,
    );
  }
}