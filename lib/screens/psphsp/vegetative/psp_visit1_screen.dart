// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/google_sheets_api.dart';

class PspVisit1Screen extends StatefulWidget {
  final String spreadsheetId;
  final String fieldNumber; // Menerima Field No dari halaman detail
  final String region;

  const PspVisit1Screen({
    super.key,
    required this.spreadsheetId,
    required this.fieldNumber,
    required this.region,
  });

  @override
  State<PspVisit1Screen> createState() => _PspVisit1ScreenState();
}

class _PspVisit1ScreenState extends State<PspVisit1Screen> {
  final _formKey = GlobalKey<FormState>();
  late GoogleSheetsApi _googleSheetsApi;

  bool _isLoading = true;
  bool _isSubmitting = false;

  // Menyimpan Index Baris Target di Google Sheets
  int? _targetRowIndex;

  // --- Controllers ---
  final TextEditingController _visitDateController = TextEditingController();
  final TextEditingController _germinationController = TextEditingController();
  final TextEditingController _germinationRemarksController = TextEditingController();
  final TextEditingController _envRemarksController = TextEditingController();
  final TextEditingController _recPldAreaController = TextEditingController();

  // --- Dropdown Values ---
  String? _selectedSeedTreatment; // Yes / No
  String? _selectedRecommendation; // Continue / Discard

  // --- Colors ---
  final Color _primaryColor = Colors.purple.shade800;

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _loadFieldData();
  }

  @override
  void dispose() {
    _visitDateController.dispose();
    _germinationController.dispose();
    _germinationRemarksController.dispose();
    _envRemarksController.dispose();
    _recPldAreaController.dispose();
    super.dispose();
  }

  // --- 1. Cari Baris Target Berdasarkan Field Number ---
  Future<void> _loadFieldData() async {
    try {
      await _googleSheetsApi.init();

      // Ambil data dari sheet 'Vegetative'
      final rows = await _googleSheetsApi.getSpreadsheetData('Vegetative');

      // Cari index baris (Looping)
      int foundIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        // Cek Kolom C (Index 2) = Field Number
        if (rows[i].length > 2 && rows[i][2].toString().trim() == widget.fieldNumber) {
          foundIndex = i + 1; // Konversi ke 1-based index untuk GSheets
          break;
        }
      }

      if (foundIndex != -1) {
        setState(() {
          _targetRowIndex = foundIndex;
          _isLoading = false;
          // Default Tanggal Hari Ini
          _visitDateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
        });
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("Error: Field Number ${widget.fieldNumber} not found!", isError: true);
        Navigator.pop(context);
      }

    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Connection Error: $e", isError: true);
    }
  }

  // --- 2. Submit Data Visit 1 ---
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetRowIndex == null) return;

    setState(() => _isSubmitting = true);

    try {
      // MAPPING KOLOM (AN, AP - AU)
      // AN = 40, AP = 42, ..., AU = 47
      Map<int, String> updates = {
        40: _visitDateController.text,          // Date Of Visit 1
        42: "${_germinationController.text}%",  // Germination (%)
        43: _germinationRemarksController.text, // Germination Remarks
        44: _envRemarksController.text,         // Environment Remarks
        45: _selectedSeedTreatment ?? "-",      // Additional seed treatment
        46: _selectedRecommendation ?? "-",     // Recommendation
        47: _recPldAreaController.text,         // Recommendation PLD (Ha)
      };

      // Update ke Sheet 'Vegetative'
      await _googleSheetsApi.updateSpecificCells('Vegetative', _targetRowIndex!, updates);

      if (mounted) {
        _showSnackBar("Visit 1 Data successfully saved!", isError: false);
        Navigator.pop(context, true); // Kembali & Refresh
      }
    } catch (e) {
      _showSnackBar("Failed to save: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Visit 1 Check", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            child: Container(color: _primaryColor.withOpacity(0.7)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background
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
                    // Header Info
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _primaryColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          "Target Field: ${widget.fieldNumber}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- SECTION 1: DATE & GERMINATION ---
                    _buildSectionHeader("Germination Check", Icons.timer_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _visitDateController.text = DateFormat('dd/MM/yyyy').format(picked);
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: _buildTextField(_visitDateController, "Date of Visit 1", Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                  _germinationController,
                                  "Germination",
                                  Icons.percent,
                                  keyboardType: TextInputType.number,
                                  suffixText: "%"
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(_germinationRemarksController, "Germination Remarks", Icons.note_alt_outlined, maxLines: 2),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 2: ENVIRONMENT & TREATMENT ---
                    _buildSectionHeader("Environment & Treatment", Icons.eco_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        _buildTextField(
                            _envRemarksController,
                            "Env. Remarks (Weather, Pest, etc.)",
                            Icons.wb_sunny_outlined,
                            maxLines: 3
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownSimple(
                            "Additional Seed Treatment?",
                            ["Yes", "No"],
                                (val) => setState(() => _selectedSeedTreatment = val),
                            value: _selectedSeedTreatment,
                            icon: Icons.science_outlined
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 3: RECOMMENDATION ---
                    _buildSectionHeader("Recommendation", Icons.recommend_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        _buildDropdownSimple(
                            "Action Recommendation",
                            ["Continue to Next Process", "Discard"],
                                (val) => setState(() => _selectedRecommendation = val),
                            value: _selectedRecommendation,
                            icon: Icons.thumbs_up_down_outlined
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                            _recPldAreaController,
                            "Recommendation PLD (Ha)",
                            Icons.aspect_ratio_rounded,
                            keyboardType: TextInputType.number
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Submit Button
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
                            : const Text("SAVE VISIT 1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Reusable Widgets ---

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

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? suffixText}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
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

  Widget _buildDropdownSimple(String label, List<String> items, Function(String?) onChanged, {String? value, IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: (val) => val == null ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }
}