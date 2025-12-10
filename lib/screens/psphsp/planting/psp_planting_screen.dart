// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart'; // Wajib untuk ambil list FA
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/google_sheets_api.dart';

class PspPlantingScreen extends StatefulWidget {
  final String spreadsheetId;
  final String region;

  const PspPlantingScreen({
    super.key,
    required this.spreadsheetId,
    required this.region,
  });

  @override
  State<PspPlantingScreen> createState() => _PspPlantingScreenState();
}

class _PspPlantingScreenState extends State<PspPlantingScreen> {
  final _formKey = GlobalKey<FormState>();
  late GoogleSheetsApi _googleSheetsApi;

  bool _isLoading = true;
  bool _isSubmitting = false;

  // --- Data untuk Dropdown ---
  List<Map<String, dynamic>> _availableFields = [];
  Map<String, dynamic>? _selectedFieldData;
  List<String> _fieldAssistantList = []; // List FA dari Firestore

  // --- Controllers ---
  final TextEditingController _hamletController = TextEditingController();
  final TextEditingController _villageController = TextEditingController();
  final TextEditingController _subDistrictController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _zoneController = TextEditingController();
  // _faController dihapus, diganti _selectedFA
  final TextEditingController _coordinateController = TextEditingController();
  final TextEditingController _plantingDateController = TextEditingController();

  // Teknis
  final TextEditingController _space1Controller = TextEditingController();
  final TextEditingController _plantingSpaceController = TextEditingController();
  final TextEditingController _space2Controller = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _seedLotController = TextEditingController();
  final TextEditingController _seedQtyController = TextEditingController();
  final TextEditingController _usageController = TextEditingController();

  // --- Dropdown Values ---
  final String _selectedStage = "Planting";

  String? _selectedFA; // Variable untuk Dropdown FA
  String? _selectedIsoYesNo;
  String? _selectedIsoType;
  String? _selectedIsoDist;
  String? _selectedPlantingMethod;

  // --- Colors ---
  final Color _primaryColor = Colors.teal.shade800;

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _loadInitialData();
  }

  @override
  void dispose() {
    _hamletController.dispose();
    _villageController.dispose();
    _subDistrictController.dispose();
    _districtController.dispose();
    _zoneController.dispose();
    _coordinateController.dispose();
    _plantingDateController.dispose();
    _space1Controller.dispose();
    _plantingSpaceController.dispose();
    _space2Controller.dispose();
    _remarksController.dispose();
    _seedLotController.dispose();
    _seedQtyController.dispose();
    _usageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      await _googleSheetsApi.init();

      // 1. Ambil Field Data dari Sheets
      final fields = await _googleSheetsApi.getAvailableFields('Vegetative');

      // 2. Ambil Data Field Assistant dari Firestore
      // Path: regions -> psp -> (field) zones
      final docSnapshot = await FirebaseFirestore.instance
          .collection('regions')
          .doc('psp') // Sesuai path regions/psp
          .get();

      List<String> faList = [];
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['zones'] != null) {
          final zonesMap = data['zones'] as Map<String, dynamic>;

          // Loop setiap Zone untuk ambil field_assistant
          zonesMap.forEach((key, value) {
            if (value['field_assistant'] != null) {
              final faArray = List<String>.from(value['field_assistant']);
              faList.addAll(faArray);
            }
          });
        }
      }

      // Hapus duplikat dan urutkan
      faList = faList.toSet().toList()..sort();

      if (mounted) {
        setState(() {
          _availableFields = fields;
          _fieldAssistantList = faList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _plantingDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitData() async {
    if (_selectedFieldData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Field Number first!")),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Ambil Target Baris
      final int targetRowIndex = _selectedFieldData!['rowIndex'];

      // 2. Siapkan Formula String
      // Rumus Sheet: =WEEKNUM(V{row}) dan =TEXT(M{row}; "MMMM")
      final String formulaWeekPlanting = "=WEEKNUM(V$targetRowIndex)";
      final String formulaMonthPlanting = "=TEXT(M$targetRowIndex; \"MMMM\")";

      // 3. Mapping Kolom (UPDATED 13-37)
      Map<int, String> updates = {
        13: _plantingDateController.text,  // Planting Date
        14: _hamletController.text,        // Hamlet
        15: _villageController.text,       // Village
        16: _subDistrictController.text,   // Sub District
        17: _districtController.text,      // District
        18: _zoneController.text,          // Zone
        19: _selectedFA ?? "-",            // Field Assistant (Dropdown)
        20: _coordinateController.text,    // Coordinate
        21: _selectedStage,                // Stage ("Planting")
        22: _plantingDateController.text,  // Reporting Date
        23: formulaWeekPlanting,           // Week Report (Pakai Rumus)
        24: "0",                           // DAS
        25: formulaWeekPlanting,           // Week Planting (Pakai Rumus dari Kolom V)
        26: formulaMonthPlanting,          // Month Planting (Pakai Rumus dari Kolom M)
        27: _selectedIsoYesNo ?? "-",      // Isolation A/B
        28: _selectedIsoType ?? "-",       // Isolation Type
        29: _selectedIsoDist ?? "-",       // Isolation Distance
        30: _space1Controller.text,        // Space 1
        31: _plantingSpaceController.text, // Planting Space
        32: _space2Controller.text,        // Space 2
        33: _remarksController.text,       // Planting Remarks
        34: _selectedPlantingMethod ?? "-",// Planting Method
        35: _seedLotController.text,       // Seed Lot
        36: _seedQtyController.text,       // Seed Qty
        37: "${_usageController.text}%",   // PS Usage (Tambah %)
      };

      // 4. Eksekusi Update
      await _googleSheetsApi.updateSpecificCells('Vegetative', targetRowIndex, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.check, color: Colors.white), SizedBox(width: 10), Text("Planting data updated!")]),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Planting Phase", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: _primaryColor.withOpacity(0.6)),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_primaryColor.withOpacity(0.1), Colors.white],
              ),
            ),
          ),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: FIELD SELECTION ---
                    _buildSectionHeader("Select Field", Icons.search_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: InputDecoration(
                            labelText: "Search Field Number / Farmer",
                            prefixIcon: Icon(Icons.qr_code_scanner, color: _primaryColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          isExpanded: true,
                          items: _availableFields.map((field) {
                            return DropdownMenuItem(
                              value: field,
                              child: Text(
                                "${field['fieldNumber']} - ${field['farmer']}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedFieldData = val;
                              // Optional: Reset controllers or fill existing data here
                            });
                          },
                        ),
                      ],
                    ),

                    if (_selectedFieldData != null) ...[
                      const SizedBox(height: 24),

                      // --- SECTION 2: LOCATION & STAFF ---
                      _buildSectionHeader("Location & Staff", Icons.location_on_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_hamletController, "Hamlet (Dusun)", Icons.home_work_outlined)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_villageController, "Village (Desa)", Icons.holiday_village_outlined)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_subDistrictController, "Sub-District", Icons.map_outlined)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_districtController, "District", Icons.map_rounded)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(_zoneController, "Zone / Area", Icons.share_location_rounded),
                          const SizedBox(height: 10),

                          // FA Dropdown Otomatis dari Firestore
                          _buildDropdownSimple(
                              "Field Assistant",
                              _fieldAssistantList,
                                  (v) => setState(() => _selectedFA = v),
                              value: _selectedFA,
                              icon: Icons.person_outline
                          ),

                          const SizedBox(height: 10),
                          _buildTextField(_coordinateController, "Coordinate (Lat, Long)", Icons.my_location, keyboardType: TextInputType.text),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 3: PLANTING DETAILS ---
                      _buildSectionHeader("Planting Info", Icons.calendar_today_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: AbsorbPointer(
                              child: _buildTextField(
                                  _plantingDateController,
                                  "Planting Date",
                                  Icons.date_range,
                                  validator: (v) => v!.isEmpty ? "Required" : null
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Auto Calculated Fields (Display Only - Rumus akan dikirim ke Sheets)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    "Week & Month Planting will be calculated automatically in Spreadsheet.",
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 4: ISOLATION ---
                      _buildSectionHeader("Isolation", Icons.security_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          _buildDropdownSimple("Isolation Compliance", ["A= Yes", "B= No"], (v) => _selectedIsoYesNo = v),
                          const SizedBox(height: 10),
                          _buildDropdownSimple("Isolation Type", ["A= Other seed production", "B= Commercial"], (v) => _selectedIsoType = v),
                          const SizedBox(height: 10),
                          _buildDropdownSimple("Isolation Distance", ["A= >400", "B= <400"], (v) => _selectedIsoDist = v),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- SECTION 5: TECHNICAL & SEED ---
                      _buildSectionHeader("Seed & Technical", Icons.science_rounded),
                      const SizedBox(height: 10),
                      _buildGlassContainer(
                        children: [
                          _buildDropdownSimple(
                              "Planting Method",
                              [
                                "A = Normal - One seed per hole",
                                "B = Normal - Two seed per hole",
                                "C = Pair to Pair - One Seed per hole",
                                "D = Pair to Pair - Two Seed per hole"
                              ],
                                  (v) => _selectedPlantingMethod = v,
                              isDense: true
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_space1Controller, "Space 1", Icons.space_bar, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_plantingSpaceController, "P. Space", Icons.linear_scale, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTextField(_space2Controller, "Space 2", Icons.space_bar, keyboardType: TextInputType.number)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(_seedLotController, "Seed Lot #", Icons.qr_code),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(_seedQtyController, "Seed Qty (kg)", Icons.scale, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              // Usage % Input
                              Expanded(child: _buildTextField(
                                  _usageController,
                                  "PS Usage",
                                  Icons.percent,
                                  keyboardType: TextInputType.number,
                                  suffixText: "%" // Visual cue
                              )),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(_remarksController, "Planting Remarks", Icons.comment, maxLines: 2),
                        ],
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 5,
                            shadowColor: _primaryColor.withOpacity(0.5),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("UPDATE PLANTING DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildGlassContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? Function(String?)? validator, String? suffixText}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildDropdownSimple(String label, List<String> items, Function(String?) onChanged, {bool isDense = false, String? value, IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: isDense ? 12 : 14)))).toList(),
      onChanged: onChanged,
    );
  }
}