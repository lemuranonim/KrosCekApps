import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class Generative3EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave;

  const Generative3EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave,
  });

  @override
  Generative3EditScreenState createState() => Generative3EditScreenState();
}

class Generative3EditScreenState extends State<Generative3EditScreen> {
  late List<String> row;
  late GoogleSheetsApi gSheetsApi;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAudit3Controller;
  late TextEditingController _dateClosedController;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;

  String? selectedFemaleShed2;
  String? selectedSheddingMale2;
  String? selectedSheddingFemale2;
  String? selectedStandingCropMale;
  String? selectedStandingCropFemale;
  String? selectedLSV;
  String? selectedDetasselingObservation;
  String? selectedAffectedFields;
  String? selectedNickCover;
  String? selectedIsolation;
  String? selectedIsolationType;
  String? selectedIsolationDistance;
  String? selectedQPIR;
  String? selectedFlagging;
  String? selectedCropUniformityTiga;
  String? selectedRecommendation;
  String? selectedReasonPLD;
  String? selectedReasonTidakTeraudit;
  late TextEditingController _remarksController;
  late TextEditingController _recommendationPLDController;

  final List<String> femaleShed2Items = ['A', 'B', 'C', 'D'];
  final List<String> sheddingMale2Items = ['A', 'B'];
  final List<String> sheddingFemale2Items = ['A', 'B'];
  final List<String> standingCropMaleItems = ['A', 'B'];
  final List<String> standingCropFemaleItems = ['A', 'B'];
  final List<String> lsvItems = ['A', 'B'];
  final List<String> detasselingObservationItems = ['A', 'B', 'C', 'D'];
  final List<String> affectedFieldsItems = ['A', 'B'];
  final List<String> nickCoverItems = ['A', 'B', 'C'];
  final List<String> isolationItems = ['Y', 'N'];
  final List<String> isolationTypeItems = ['A', 'B'];
  final List<String> isolationDistanceItems = ['A', 'B', 'C', 'D'];
  final List<String> qPIRItems = ['Y', 'N'];
  final List<String> flaggingItems = ['GF', 'RFI', 'RFD', 'BF', 'Discard'];
  final List<String> cropUniformityTigaItems = ['1', '2', '3', '4', '5'];
  final List<String> recommendationItems = ['Continue', 'Discard'];
  final List<String> reasonPLDItems = ['A', 'B'];
  final List<String> reasonTidakTerauditItems = ['A', 'B', 'C'];

  bool isLoading = false;

  bool get areRecommendationFieldsRequired {
    return selectedRecommendation != null && selectedRecommendation != 'Discard';
  }

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    // Initialize controllers for date fields
    _dateAudit3Controller = TextEditingController(text: _convertToDateIfNecessary(row[47]));

    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    gSheetsApi.init();
    // Initialize controllers for dropdown fields
    selectedFemaleShed2 = row[49];
    selectedSheddingMale2 = row[50];
    selectedSheddingFemale2 = row[51];
    selectedStandingCropMale = row[52];
    selectedStandingCropFemale = row[53];
    selectedLSV = row[54];
    selectedDetasselingObservation = row[55];
    selectedAffectedFields = row[56];
    selectedNickCover = row[57];
    selectedIsolation = row[58];
    selectedIsolationType = row[59];
    selectedIsolationDistance = row[60];
    selectedQPIR = row[61];
    // Initialize controllers for date fields
    _dateClosedController = TextEditingController(text: _convertToDateIfNecessary(row[62]));
    // Initialize controllers for dropdown fields
    selectedFlagging = row[63];
    selectedCropUniformityTiga = row[64];
    selectedRecommendation = row[65];
    // Initialize controllers for text fields
    _remarksController = TextEditingController(text: row[66]);
    _recommendationPLDController = TextEditingController(text: row[67]);
    // Initialize controllers for dropdown fields
    selectedReasonPLD = row[68];
  }

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('generativeData');
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('generativeData');
    final cacheKey = 'detailScreenData_${rowData[2]}';
    await box.put(cacheKey, rowData);
  }

  Future<void> _loadUserCredentials() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString('userEmail') ?? 'Unknown Email';
      userName = prefs.getString('userName') ?? 'Pengguna';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Field Audit 3 Edit',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            )
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade700, Colors.green.shade100],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLoading)
                          const LinearProgressIndicator(
                            backgroundColor: Colors.green,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),

                        const SizedBox(height: 10),

                        // Field Information Section
                        _buildSectionHeader('Field Information'),

                        _buildInfoCard(
                          title: 'Field Number',
                          value: row[2],
                          icon: Icons.numbers,
                        ),

                        _buildInfoCard(
                          title: 'Region',
                          value: widget.region,
                          icon: Icons.location_on,
                        ),
                        const SizedBox(height: 20),
                        _buildRequiredFieldsNotice(),

                        // Audit Information Section
                        _buildSectionHeader('Audit 3 Information'),
                        _buildDatePickerField('Date of Audit 3 (dd/MM)', 47, _dateAudit3Controller),
                        const SizedBox(height: 10),

                        // Female Shedding Section
                        _buildSectionHeader('Female Shedding Assessment'),
                        _buildDropdownFormField(
                          label: 'Female Shedding',
                          items: femaleShed2Items,
                          value: selectedFemaleShed2,
                          onChanged: (value) {
                            setState(() {
                              selectedFemaleShed2 = value;
                              row[49] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = 0-5 shedd / Ha\nB (RF) = 6-30 shedd / Ha\nC (BF) = >30 shedd / Ha',
                          icon: Icons.spa,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),

                        // Shedding Offtype Section
                        _buildSectionHeader('Shedding Offtype Assessment'),
                        _buildDropdownFormField(
                          label: 'Shedding Offtype & CVL Male',
                          items: sheddingMale2Items,
                          value: selectedSheddingMale2,
                          onChanged: (value) {
                            setState(() {
                              selectedSheddingMale2 = value;
                              row[50] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.male,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Shedding Offtype & CVL Female',
                          items: sheddingFemale2Items,
                          value: selectedSheddingFemale2,
                          onChanged: (value) {
                            setState(() {
                              selectedSheddingFemale2 = value;
                              row[51] = value ?? '';
                            });
                          },
                          helpText: 'A = 0-5 plants / Ha\nB = > 5 plants / Ha',
                          icon: Icons.female,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),

                        // Standing Crop Section
                        _buildSectionHeader('Standing Crop Assessment'),
                        _buildDropdownFormField(
                          label: 'Standing crop Offtype & CVL Male',
                          items: standingCropMaleItems,
                          value: selectedStandingCropMale,
                          onChanged: (value) {
                            setState(() {
                              selectedStandingCropMale = value;
                              row[52] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.agriculture,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Standing crop Offtype & CVL Female',
                          items: standingCropFemaleItems,
                          value: selectedStandingCropFemale,
                          onChanged: (value) {
                            setState(() {
                              selectedStandingCropFemale = value;
                              row[53] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = 0-5 plants / Ha\nB (RF) = >5-10 plants / Ha',
                          icon: Icons.agriculture,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),

                        // LSV Section
                        _buildSectionHeader('LSV Assessment'),
                        _buildDropdownFormField(
                          label: 'LSV Ditemukan',
                          items: lsvItems,
                          value: selectedLSV,
                          onChanged: (value) {
                            setState(() {
                              selectedLSV = value;
                              row[54] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.bug_report,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),

                        // Detasseling Section
                        _buildSectionHeader('Detasseling Assessment'),
                        _buildDropdownFormField(
                          label: 'Detasseling Process Observation',
                          items: detasselingObservationItems,
                          value: selectedDetasselingObservation,
                          onChanged: (value) {
                            setState(() {
                              selectedDetasselingObservation = value;
                              row[55] = value ?? '';
                            });
                          },
                          helpText: 'A=Best (0,5)\nB=Good (5,5)\nC=Poor (5,7)\nD=Very Poor (>7)',
                          icon: Icons.content_cut,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),

                        // Field Conditions Section
                        _buildSectionHeader('Field Conditions'),
                        _buildDropdownFormField(
                          label: 'Affected by other fields',
                          items: affectedFieldsItems,
                          value: selectedAffectedFields,
                          onChanged: (value) {
                            setState(() {
                              selectedAffectedFields = value;
                              row[56] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = Not Affected\nB (RF) = Severly Affected (if distance < 50 mtr)',
                          icon: Icons.landscape,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Nick Cover',
                          items: nickCoverItems,
                          value: selectedNickCover,
                          onChanged: (value) {
                            setState(() {
                              selectedNickCover = value;
                              row[57] = value ?? '';
                            });
                          },
                          helpText: 'A = Good Nick - Male early or 1% Male Shedd at 5% Silk or reverse\nB = >10-25 % receptive silks at either end & no male shedding\nC = >25% receptive silks at either end & no male shedding',
                          icon: Icons.eco,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),

                        // Isolation Section
                        _buildSectionHeader('Isolation Assessment'),
                        _buildDropdownFormField(
                          label: 'Isolation (Y/N)',
                          items: isolationItems,
                          value: selectedIsolation,
                          onChanged: (value) {
                            setState(() {
                              selectedIsolation = value;
                              row[58] = value ?? '';
                            });
                          },
                          helpText: 'Y = Yes\nN = No',
                          icon: Icons.fence,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),
                        if (selectedIsolation == 'Y')
                          Column(
                            children: [
                              _buildDropdownFormField(
                                label: 'If "YES" IsolationType',
                                items: isolationTypeItems,
                                value: selectedIsolationType,
                                onChanged: (value) {
                                  setState(() {
                                    selectedIsolationType = value;
                                    row[59] = value ?? '';
                                  });
                                },
                                helpText: 'A : Seed Production\nB : Jagung Komersial',
                                icon: Icons.category,
                              ),
                              const SizedBox(height: 10),
                              _buildDropdownFormField(
                                label: 'If "YES" IsolationDist. (m)',
                                items: isolationDistanceItems,
                                value: selectedIsolationDistance,
                                onChanged: (value) {
                                  setState(() {
                                    selectedIsolationDistance = value;
                                    row[60] = value ?? '';
                                  });
                                },
                                helpText: 'A (GF) = >300 m\nB (GF) = >200-<300 m\nC (RF) = >100 & <200 m\nD (RF) = <100 m',
                                icon: Icons.social_distance,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),

                        // QPIR Section
                        _buildSectionHeader('QPIR & Closing Information'),
                        _buildDropdownFormField(
                          label: 'QPIR Applied',
                          items: qPIRItems,
                          value: selectedQPIR,
                          onChanged: (value) {
                            setState(() {
                              selectedQPIR = value;
                              row[61] = value ?? '';
                            });
                          },
                          helpText: 'Y = Ada\nN = Tidak Ada',
                          icon: Icons.check_circle_outline,
                          required: areRecommendationFieldsRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDatePickerField('Closed out Date', 62, _dateClosedController),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'FLAGGING',
                          items: flaggingItems,
                          value: selectedFlagging,
                          onChanged: (value) {
                            setState(() {
                              selectedFlagging = value;
                              row[63] = value ?? '';
                            });
                          },
                          helpText: 'GF/RFI/RFD/BF/Discard',
                          icon: Icons.flag,
                        ),
                        const SizedBox(height: 20),
                        // Crop Uniformity Section
                        _buildSectionHeader('Crop Performance'),
                        _buildDropdownFormField(
                          label: 'Crop Uniformity (Gen.3)',
                          items: cropUniformityTigaItems,
                          value: selectedCropUniformityTiga,
                          onChanged: (value) {
                            setState(() {
                              selectedCropUniformityTiga = value;
                              row[64] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.check_box_outline_blank,
                          required: areRecommendationFieldsRequired,
                        ),

                        // Recommendation Section
                        _buildSectionHeader('Recommendation'),
                        _buildDropdownFormField(
                          label: 'Recommendation',
                          items: recommendationItems,
                          value: selectedRecommendation,
                          onChanged: (value) {
                            setState(() {
                              selectedRecommendation = value;
                              row[65] = value ?? '';
                            });
                          },
                          helpText: 'Continue to Next Process/Discard',
                          icon: Icons.recommend,
                        ),
                        const SizedBox(height: 10),
                        _buildTextFormField('Remarks', 66,
                            icon: Icons.comment,
                            maxLines: 2,
                            controller: _remarksController,
                        ),
                        const SizedBox(height: 10),
                        _buildTextFormField('Recommendation PLD (Ha)', 67,
                            icon: Icons.area_chart,
                            keyboardType: TextInputType.number,
                            prefix: "'",
                            controller: _recommendationPLDController,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormFieldPld(
                          label: 'Reason PLD',
                          items: reasonPLDItems,
                          value: selectedReasonPLD,
                          onChanged: (value) {
                            setState(() {
                              selectedReasonPLD = value;
                              row[68] = value ?? '';
                            });
                          },
                          helpText: 'A : No Plant\nB : Class D (Uniformity)',
                          icon: Icons.info_outline,
                        ),
                        const SizedBox(height: 30),

                        // Save Button
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                if (_isDataValid()) {
                                  _showConfirmationDialog();
                                } else {
                                  _showErrorSnackBar('Please complete all required fields');
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(220, 60),
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(Icons.save, size: 26, color: Colors.white),
                            label: const Text(
                              'Simpan',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const Divider(thickness: 2, color: Colors.green),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required String value, required IconData icon}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredFieldsNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Fields marked with * are required and must be filled',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField(
      String label,
      int index, {
        TextInputType keyboardType = TextInputType.text,
        IconData? icon,
        int maxLines = 1,
        String? prefix,
        required TextEditingController controller,
        bool required = true,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label, // Add asterisk only if required
          labelStyle: TextStyle(color: Colors.green.shade700),
          prefixIcon: icon != null ? Icon(icon, color: Colors.green.shade600) : null,
          prefixText: prefix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            row[index] = value;
          });
        },
      ),
    );
  }

// buildDatePickerField
  Widget _buildDatePickerField(String label, int index, TextEditingController controller, {bool defaultRequired = true}) {
    bool required = areRecommendationFieldsRequired || defaultRequired;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label, // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.green.shade700),
          prefixIcon: Icon(Icons.calendar_today, color: Colors.green.shade600),
          suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Please select a date for $label';
          }
          return null;
        },
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: Colors.green.shade700,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedDate != null) {
            String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
            setState(() {
              controller.text = formattedDate;
              row[index] = formattedDate;
            });
          }
        },
      ),
    );
  }

  Widget _buildDropdownFormField({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    String? hint,
    String? helpText,
    IconData? icon,
    bool required = true,
  }) {
    if (!items.contains(value)) {
      value = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(51),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: required ? "$label *" : label, // Add asterisk only if required
              labelStyle: TextStyle(color: Colors.green.shade700),
              prefixIcon: icon != null ? Icon(icon, color: Colors.green.shade600) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: value,
            hint: Text(hint ?? 'Select an option'),
            validator: (value) {
              if (required && (value == null || value.isEmpty)) {
                return 'Please select an option';
              }
              return null;
            },
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            dropdownColor: Colors.white,
            icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
          ),
        ),
        if (helpText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              helpText,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownFormFieldPld({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    String? hint,
    String? helpText,
    IconData? icon,
    bool required = false,
  }) {
    if (!items.contains(value)) {
      value = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(51),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: required ? "$label *" : label, // Add asterisk only if required
              labelStyle: TextStyle(color: Colors.green.shade700),
              prefixIcon: icon != null ? Icon(icon, color: Colors.green.shade600) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.green.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: value,
            hint: Text(hint ?? 'Select an option'),
            validator: (value) {
              if (required && (value == null || value.isEmpty)) {
                return 'Please select an option';
              }
              return null;
            },
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            dropdownColor: Colors.white,
            icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
          ),
        ),
        if (helpText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              helpText,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<bool> _saveToGoogleSheets(List<String> rowData) async {
    if (!mounted) return false;
    setState(() => isLoading = true);

    try {
      // 1. Cari tahu di baris mana data akan diperbarui
      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Generative');
      if (sheet == null) {
        throw Exception('Worksheet "Generative" tidak ditemukan.');
      }
      final rowIndex = await _findRowByFieldNumber(sheet, rowData[2]);
      if (rowIndex == -1) {
        throw Exception('Data dengan Field Number ${rowData[2]} tidak ditemukan.');
      }

      // 2. Siapkan Map berisi data yang akan diupdate [columnIndex: value]
      final Map<int, String> updates = {
        48: _dateAudit3Controller.text, // Kolom AV: Date of Audit 3
        50: selectedFemaleShed2 ?? '', // Kolom AX: Female Shedding
        51: selectedSheddingMale2 ?? '', // Kolom AY: Shedding Offtype & CVL Male
        52: selectedSheddingFemale2 ?? '', // Kolom AZ: Shedding Offtype & CVL Female
        53: selectedStandingCropMale ?? '', // Kolom BA: Standing crop Offtype & CVL Male
        54: selectedStandingCropFemale ?? '', // Kolom BB: Standing crop Offtype & CVL Female
        55: selectedLSV ?? '', // Kolom BC: LSV Ditemukan
        56: selectedDetasselingObservation ?? '', // Kolom BD: Detasseling Process Observation
        57: selectedAffectedFields ?? '', // Kolom BE: Affected by other fields
        58: selectedNickCover ?? '', // Kolom BF: Nick Cover
        59: selectedIsolation ?? '', // Kolom BG: Isolation (Y/N)
        60: selectedIsolationType ?? '', // Kolom BH: IsolationType
        61: selectedIsolationDistance ?? '', // Kolom BI: IsolationDist. (m)
        62: selectedQPIR ?? '', // Kolom BJ: QPIR Applied
        63: _dateClosedController.text, // Kolom BK: Closed out Date
        64: selectedFlagging ?? '', // Kolom BL: FLAGGING
        65: selectedCropUniformityTiga ?? '', // Kolom BM: Crop Uniformity (Gen.3)
        66: selectedRecommendation ?? '', // Kolom BN: Recommendation
        67: _remarksController.text, // Kolom BO: Remarks
        68: "'${_recommendationPLDController.text}", // Kolom BP: Recommendation PLD (Ha) -> Tambah '
        69: selectedReasonPLD ?? '', // Kolom BQ: Reason PLD
      };

      // 3. Panggil fungsi baru untuk memperbarui sel-sel spesifik
      await gSheetsApi.updateSpecificCells('Generative', rowIndex, updates);

      // 4. Simpan ke cache lokal (Hive) dengan data terbaru
      updates.forEach((colIndex, value) {
        if ((colIndex - 1) < row.length) {
          row[colIndex - 1] = value;
        }
      });
      await _saveToHive(row);
      await _logActivityAfterSave();
      // 5. Kembalikan rumus
      await _restoreGenerativeFormulas(gSheetsApi, sheet, rowIndex);

      return true;

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data Generative-3: ${e.toString()}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _logActivityAfterSave() async {
    try {
      final String spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final worksheetTitle = 'Aktivitas';

      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle(worksheetTitle);
      if (sheet == null) {
        debugPrint('Gagal: Worksheet "$worksheetTitle" tidak ditemukan.');
        return;
      }

      final String timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      final String fieldNumber = widget.row[2];
      final String regions = widget.row.length > 18 ? widget.row[18] : '';
      final String action = 'Update';
      final String status = 'Success';

      final List<String> rowData = [
        userEmail,
        userName,
        status,
        regions,
        action,
        'Generative - Audit 3', // Phase
        fieldNumber,
        timestamp,
      ];

      await sheet.values.appendRow(rowData, fromColumn: 1);
    } catch (e) {
      debugPrint("Gagal mencatat aktivitas: $e");
      _logErrorToActivity("Gagal mencatat aktivitas: $e");
    }
  }

  Future<void> _restoreGenerativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Check Result
        '=IF(OR(BL$rowIndex=0;BL$rowIndex="");"Not Audited";"Audited")',
        row: rowIndex, column: 73);
    await sheet.values.insertValue( // Check Progress
        '=IF(OR(AG$rowIndex=""; AG$rowIndex=0; NOT(ISNUMBER(AG$rowIndex)); IFERROR(YEAR(AG$rowIndex)<2024; FALSE); AP$rowIndex=""; AP$rowIndex=0; NOT(ISNUMBER(AP$rowIndex)); IFERROR(YEAR(AP$rowIndex)<2024; FALSE)); "Not Audited"; "Audited")',
        row: rowIndex, column: 74);
    debugPrint("Rumus berhasil diterapkan di Generative pada baris $rowIndex.");
  }

  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber)
  async {
    final List<List<String>> rows = await sheet.values.allRows();
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) {
        return i + 1;
      }
    }
    return -1;
  }

  Future<void> _showConfirmationDialog() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.save_outlined, color: Colors.green.shade700),
            const SizedBox(width: 10),
            const Text('Confirm Save'),
          ],
        ),
        content: const Text('Are you sure you want to save the changes? All required fields must be filled correctly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      await _executeSaveProcess();
    }
  }

  Future<void> _executeSaveProcess() async {
    // 1. Tampilkan dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/loading.json', width: 150, height: 150),
              const SizedBox(height: 20),
              const Text(
                "Ngrantos sekedap...",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );
      },
    );

    // 2. Coba simpan data
    final bool success = await _saveToGoogleSheets(row);

    // 3. Tutup dialog loading
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 4. Navigasi berdasarkan hasil
    if (mounted) {
      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              row: row,
              userName: userName,
              userEmail: userEmail,
              region: widget.region,
              phase: 'Generative - Audit 3',
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const FailedScreen(),
          ),
        );
      }
    }
  }

  bool _isDataValid() {
    // Kondisi utama: Apakah semua field di semua audit menjadi wajib?
    final bool allAuditsFullyRequired = selectedRecommendation != 'Discard' && selectedFlagging != 'Discard';

    // Validasi untuk field isolasi yang kondisional
    bool isolationFieldsValid = true;
    if (selectedIsolation == 'Y') {
      isolationFieldsValid = selectedIsolationType != null && selectedIsolationType!.isNotEmpty &&
          selectedIsolationDistance != null && selectedIsolationDistance!.isNotEmpty;
    }

    // Validasi untuk field yang selalu wajib di Audit 3 terlepas dari kondisi discard global
    // (misalnya tanggal audit, flagging, dan recommendation itu sendiri harus selalu dipilih)
    bool baseAudit3FieldsValid = _dateAudit3Controller.text.isNotEmpty &&
        selectedFlagging != null && selectedFlagging!.isNotEmpty &&
        selectedRecommendation != null && selectedRecommendation!.isNotEmpty;

    if (!baseAudit3FieldsValid) {
      _showErrorSnackBar('Please fill in Date of Audit 3, Flagging, and Recommendation.');
      return false;
    }

    // Jika semua audit menjadi wajib diisi penuh
    if (allAuditsFullyRequired) {
      return baseAudit3FieldsValid &&
          selectedFemaleShed2 != null && selectedFemaleShed2!.isNotEmpty &&
          selectedSheddingMale2 != null && selectedSheddingMale2!.isNotEmpty &&
          selectedSheddingFemale2 != null && selectedSheddingFemale2!.isNotEmpty &&
          selectedStandingCropMale != null && selectedStandingCropMale!.isNotEmpty &&
          selectedStandingCropFemale != null && selectedStandingCropFemale!.isNotEmpty &&
          selectedLSV != null && selectedLSV!.isNotEmpty &&
          selectedDetasselingObservation != null && selectedDetasselingObservation!.isNotEmpty &&
          selectedAffectedFields != null && selectedAffectedFields!.isNotEmpty &&
          selectedNickCover != null && selectedNickCover!.isNotEmpty &&
          selectedCropUniformityTiga != null && selectedCropUniformityTiga!.isNotEmpty &&
          selectedIsolation != null && selectedIsolation!.isNotEmpty &&
          isolationFieldsValid &&
          selectedQPIR != null && selectedQPIR!.isNotEmpty &&
          _dateClosedController.text.isNotEmpty &&
          _remarksController.text.isNotEmpty && // Wajib karena allAuditsFullyRequired
          _recommendationPLDController.text.isNotEmpty && // Wajib karena allAuditsFullyRequired
          selectedReasonPLD != null && selectedReasonPLD!.isNotEmpty; // Wajib karena allAuditsFullyRequired
    } else {
      // Jika salah satu (Recommendation atau Flagging di Audit 3) adalah 'Discard'
      // Maka field-field Audit 3 lain selain tanggal, flagging, dan recommendation itu sendiri menjadi tidak wajib,
      // KECUALI field yang terkait Recommendation (Remarks, PLD, Reason PLD) jika Recommendation BUKAN 'Discard'.

      if (areRecommendationFieldsRequired) {
        // Jika Recommendation BUKAN 'Discard', maka field terkaitnya wajib.
        // Field lain di Audit 3 bisa jadi opsional jika Flagging adalah 'Discard'.
        // Untuk kasus ini, kita tetap validasi field recommendation.
        // Field lain (FemaleShed2, SheddingMale2, dll.) menjadi opsional jika Flagging adalah 'Discard'.
        // bool recommendationRelatedFieldsValid = _remarksController.text.isNotEmpty &&
        //     _recommendationPLDController.text.isNotEmpty &&
        //     selectedReasonPLD != null && selectedReasonPLD!.isNotEmpty;
        // if (!recommendationRelatedFieldsValid) {
        //   _showErrorSnackBar('Remarks, Recommendation PLD, and Reason PLD are required when Recommendation is not Discard.');
        //   return false;
        // }
        // Jika Flagging adalah 'Discard' tapi Recommendation bukan 'Discard',
        // maka hanya field dasar Audit 3 dan field recommendation yang wajib.
        // Field lainnya di Audit 3 menjadi opsional.
        if (selectedFlagging == 'Discard') {
          return baseAudit3FieldsValid;
        } else {
          // Jika Flagging BUKAN 'Discard', tapi Recommendation adalah 'Discard' (sudah ditangani di `allAuditsFullyRequired = false`)
          // atau skenario lain yang tidak masuk `allAuditsFullyRequired`.
          // Dalam kasus ini, karena Recommendation bukan 'Discard' (dicek oleh `areRecommendationFieldsRequired`),
          // maka field-field standar Audit 3 (selain yang terkait PLD) juga harus valid.
          return baseAudit3FieldsValid &&
              // recommendationRelatedFieldsValid &&
              selectedFemaleShed2 != null && selectedFemaleShed2!.isNotEmpty &&
              selectedSheddingMale2 != null && selectedSheddingMale2!.isNotEmpty &&
              selectedSheddingFemale2 != null && selectedSheddingFemale2!.isNotEmpty &&
              selectedStandingCropMale != null && selectedStandingCropMale!.isNotEmpty &&
              selectedStandingCropFemale != null && selectedStandingCropFemale!.isNotEmpty &&
              selectedLSV != null && selectedLSV!.isNotEmpty &&
              selectedDetasselingObservation != null && selectedDetasselingObservation!.isNotEmpty &&
              selectedAffectedFields != null && selectedAffectedFields!.isNotEmpty &&
              selectedNickCover != null && selectedNickCover!.isNotEmpty &&
              selectedCropUniformityTiga != null && selectedCropUniformityTiga!.isNotEmpty &&
              selectedIsolation != null && selectedIsolation!.isNotEmpty &&
              isolationFieldsValid &&
              selectedQPIR != null && selectedQPIR!.isNotEmpty &&
              _dateClosedController.text.isNotEmpty;
        }
      } else {
        // Jika Recommendation adalah 'Discard'.
        // Maka field Remarks, PLD, Reason PLD tidak wajib.
        // Jika Flagging juga 'Discard', maka hanya field dasar (tanggal, flagging, recommendation) yang wajib.
        // Jika Flagging BUKAN 'Discard' tapi Recommendation 'Discard', field lain di Audit 3 tetap wajib.
        if (selectedFlagging == 'Discard') {
          // Keduanya (atau salah satunya, yaitu recommendation) adalah Discard.
          // Field dasar sudah divalidasi di awal.
          return baseAudit3FieldsValid;
        } else {
          // Flagging BUKAN 'Discard', TAPI Recommendation adalah 'Discard'.
          // Semua field Audit 3 (kecuali Remarks, PLD, Reason PLD) wajib.
          return baseAudit3FieldsValid &&
              selectedFemaleShed2 != null && selectedFemaleShed2!.isNotEmpty &&
              selectedSheddingMale2 != null && selectedSheddingMale2!.isNotEmpty &&
              selectedSheddingFemale2 != null && selectedSheddingFemale2!.isNotEmpty &&
              selectedStandingCropMale != null && selectedStandingCropMale!.isNotEmpty &&
              selectedStandingCropFemale != null && selectedStandingCropFemale!.isNotEmpty &&
              selectedLSV != null && selectedLSV!.isNotEmpty &&
              selectedDetasselingObservation != null && selectedDetasselingObservation!.isNotEmpty &&
              selectedAffectedFields != null && selectedAffectedFields!.isNotEmpty &&
              selectedNickCover != null && selectedNickCover!.isNotEmpty &&
              selectedCropUniformityTiga != null && selectedCropUniformityTiga!.isNotEmpty &&
              selectedIsolation != null && selectedIsolation!.isNotEmpty &&
              isolationFieldsValid &&
              selectedQPIR != null && selectedQPIR!.isNotEmpty &&
              _dateClosedController.text.isNotEmpty;
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _convertToDateIfNecessary(String value) {
    try {
      final parsedNumber = double.tryParse(value);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      // Handle parsing error
    }
    return value;
  }
}

class SuccessScreen extends StatelessWidget {
  final List<String> row;
  final String userName;
  final String userEmail;
  final String region;
  final String phase;

  const SuccessScreen({
    super.key,
    required this.row,
    required this.userName,
    required this.userEmail,
    required this.region,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Success',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Data berhasil disimpan!',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Langsung kembali ke layar sebelumnya.
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Selesai',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FailedScreen extends StatelessWidget {
  const FailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Failed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Failed to save data. Please try again.',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60),
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _logErrorToActivity(String message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> logs = prefs.getStringList('activityLogs') ?? [];
  logs.add('${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}: $message');
  await prefs.setStringList('activityLogs', logs);
}