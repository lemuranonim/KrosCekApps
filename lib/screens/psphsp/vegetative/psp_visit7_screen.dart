// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/google_sheets_api.dart';

class PspVisit7Screen extends StatefulWidget {
  final String spreadsheetId;
  final String fieldNumber;
  final String region;

  const PspVisit7Screen({
    super.key,
    required this.spreadsheetId,
    required this.fieldNumber,
    required this.region,
  });

  @override
  State<PspVisit7Screen> createState() => _PspVisit7ScreenState();
}

class _PspVisit7ScreenState extends State<PspVisit7Screen> {
  final _formKey = GlobalKey<FormState>();
  late GoogleSheetsApi _googleSheetsApi;

  bool _isLoading = true;
  bool _isSubmitting = false;

  int? _targetRowIndex;

  // --- Controllers ---
  final TextEditingController _visitDateController = TextEditingController();

  // Roguing 4 Details
  final TextEditingController _roguingDateController = TextEditingController();
  final TextEditingController _rogOfftypeController = TextEditingController();
  final TextEditingController _rogVolunteerController = TextEditingController();
  final TextEditingController _rogLsvController = TextEditingController();
  final TextEditingController _rogQtyController = TextEditingController();

  // Remarks
  final TextEditingController _plantPerfRemarksController = TextEditingController();
  final TextEditingController _envRemarksController = TextEditingController();

  // Final Stats
  final TextEditingController _recPldAreaController = TextEditingController();
  final TextEditingController _vegPopController = TextEditingController(); // Vegetative Population
  final TextEditingController _coordinateController = TextEditingController();

  // --- Dropdown Values ---
  final List<String> _ratingOptions = ["A = Good", "B = Fair", "C = Need Improvement"];
  String? _selectedCropRate;
  String? _selectedUniformity;
  String? _selectedHealth;

  final List<String> _statusOptions = ["Done", "Not Yet"];
  String? _selectedInsecticide;
  String? _selectedFungicide;
  String? _selectedFoliar;

  String? _selectedRecommendation;

  // --- Colors ---
  final Color _primaryColor = Colors.purple.shade800;

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _loadFieldData();

    // Auto calculate Total Roguing Qty
    _rogOfftypeController.addListener(_calcTotalRoguing);
    _rogVolunteerController.addListener(_calcTotalRoguing);
    _rogLsvController.addListener(_calcTotalRoguing);
  }

  @override
  void dispose() {
    _visitDateController.dispose();
    _roguingDateController.dispose();
    _rogOfftypeController.dispose();
    _rogVolunteerController.dispose();
    _rogLsvController.dispose();
    _rogQtyController.dispose();
    _plantPerfRemarksController.dispose();
    _envRemarksController.dispose();
    _recPldAreaController.dispose();
    _vegPopController.dispose();
    _coordinateController.dispose();
    super.dispose();
  }

  void _calcTotalRoguing() {
    int offtype = int.tryParse(_rogOfftypeController.text) ?? 0;
    int volunteer = int.tryParse(_rogVolunteerController.text) ?? 0;
    int lsv = int.tryParse(_rogLsvController.text) ?? 0;
    int total = offtype + volunteer + lsv;
    _rogQtyController.text = total.toString();
  }

  Future<void> _loadFieldData() async {
    try {
      await _googleSheetsApi.init();
      final rows = await _googleSheetsApi.getSpreadsheetData('Vegetative');

      int foundIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        if (rows[i].length > 2 && rows[i][2].toString().trim() == widget.fieldNumber) {
          foundIndex = i + 1;
          break;
        }
      }

      if (foundIndex != -1) {
        setState(() {
          _targetRowIndex = foundIndex;
          _isLoading = false;
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetRowIndex == null) return;

    setState(() => _isSubmitting = true);

    try {
      // MAPPING KOLOM VISIT 7 (EF, EI - EX)
      // EF=136, EI=139 ... EX=154
      Map<int, String> updates = {
        136: _visitDateController.text,         // EF: Date Of Visit 7
        // EG(137), EH(138) Skipped
        139: _roguingDateController.text,       // EI: Actual Roguing 4 Date
        140: _rogOfftypeController.text,        // EJ: Roguing 4 Offtype
        141: _rogVolunteerController.text,      // EK: Roguing 4 Volunteer
        142: _rogLsvController.text,            // EL: Roguing 4 LSV
        143: _rogQtyController.text,            // EM: Qty Roguing 4 (Total)
        144: _selectedCropRate ?? "-",          // EN: Veg Crop Rate
        145: _selectedUniformity ?? "-",        // EO: Veg Crop Uniformity
        146: _selectedHealth ?? "-",            // EP: Veg Crop Health
        147: _plantPerfRemarksController.text,  // EQ: Plant Performance Remarks
        148: _envRemarksController.text,        // ER: Environment Remarks
        149: _selectedInsecticide ?? "-",       // ES: Spray Insecticide
        150: _selectedFungicide ?? "-",         // ET: Spray Fungicide
        151: _selectedFoliar ?? "-",            // EU: Spray Foliar/Micronutrients
        152: _selectedRecommendation ?? "-",    // EV: Recommendation
        153: _recPldAreaController.text,        // EW: Recommendation PLD (Ha)
        154: "${_vegPopController.text}%",      // EX: Vegetative Population (%)
      };

      await _googleSheetsApi.updateSpecificCells('Vegetative', _targetRowIndex!, updates);

      if (mounted) {
        _showSnackBar("Visit 7 (Final Veg) Saved Successfully!", isError: false);
        Navigator.pop(context, true);
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
        title: const Text("Visit 7 (Final Veg)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _primaryColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          "Updating Field: ${widget.fieldNumber}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- SECTION 1: ROGUING 4 ---
                    _buildSectionHeader("Roguing 4 & Schedule", Icons.group_remove_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        GestureDetector(
                          onTap: () => _selectDate(context, _visitDateController),
                          child: AbsorbPointer(
                            child: _buildTextField(_visitDateController, "Date of Visit 7", Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Roguing Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Roguing 4 Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _selectDate(context, _roguingDateController),
                                child: AbsorbPointer(
                                  child: _buildTextField(_roguingDateController, "Actual Roguing Date", Icons.event_available),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(_rogOfftypeController, "Offtype", Icons.cancel_outlined, keyboardType: TextInputType.number)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildTextField(_rogVolunteerController, "Volunteer", Icons.nature, keyboardType: TextInputType.number)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(_rogLsvController, "LSV", Icons.bug_report_outlined, keyboardType: TextInputType.number)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildTextField(_rogQtyController, "Total Qty", Icons.functions, keyboardType: TextInputType.number, isReadOnly: true)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 2: CROP CONDITION ---
                    _buildSectionHeader("Crop Condition", Icons.grass_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        _buildDropdownSimple("Veg. Crop Rate", _ratingOptions, (v) => _selectedCropRate = v, value: _selectedCropRate),
                        const SizedBox(height: 10),
                        _buildDropdownSimple("Veg. Uniformity", _ratingOptions, (v) => _selectedUniformity = v, value: _selectedUniformity),
                        const SizedBox(height: 10),
                        _buildDropdownSimple("Veg. Health", _ratingOptions, (v) => _selectedHealth = v, value: _selectedHealth),
                        const SizedBox(height: 10),
                        _buildTextField(_plantPerfRemarksController, "Plant Performance Remarks", Icons.notes_rounded, maxLines: 2),
                        const SizedBox(height: 10),
                        _buildTextField(_envRemarksController, "Environment Remarks", Icons.wb_sunny_outlined, maxLines: 2),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 3: MAINTENANCE CHECK ---
                    _buildSectionHeader("Final Maintenance", Icons.water_drop_outlined),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        _buildDropdownSimple("Spray Insecticide", _statusOptions, (v) => _selectedInsecticide = v, value: _selectedInsecticide, icon: Icons.bug_report),
                        const SizedBox(height: 10),
                        _buildDropdownSimple("Spray Fungicide", _statusOptions, (v) => _selectedFungicide = v, value: _selectedFungicide, icon: Icons.coronavirus),
                        const SizedBox(height: 10),
                        _buildDropdownSimple("Spray Foliar/Micro", _statusOptions, (v) => _selectedFoliar = v, value: _selectedFoliar, icon: Icons.science),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION 4: FINAL RECOMMENDATION ---
                    _buildSectionHeader("Final Assessment", Icons.verified_rounded),
                    const SizedBox(height: 10),
                    _buildGlassContainer(
                      children: [
                        _buildTextField(
                            _vegPopController,
                            "Vegetative Population",
                            Icons.groups_3_rounded,
                            keyboardType: TextInputType.number,
                            suffixText: "%"
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownSimple(
                            "Recommendation",
                            ["Continue to Next Process", "Discard"],
                                (v) => _selectedRecommendation = v,
                            value: _selectedRecommendation,
                            icon: Icons.thumbs_up_down
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                            _recPldAreaController,
                            "Recommendation PLD (Ha)",
                            Icons.area_chart_rounded,
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
                            : const Text("SAVE VISIT 7 (FINAL)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  // --- Helper Widgets ---
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

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? suffixText, bool isReadOnly = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: isReadOnly,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildDropdownSimple(String label, List<String> items, Function(String?) onChanged, {String? value, IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon ?? Icons.arrow_drop_down_circle, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }
}