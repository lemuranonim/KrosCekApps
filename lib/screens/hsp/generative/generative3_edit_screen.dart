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
  String? selectedCropUniformity;
  String? selectedIsolation;
  String? selectedIsolationType;
  String? selectedIsolationDistance;
  String? selectedQPIR;
  String? selectedFlagging;
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
  final List<String> cropUniformityItems = ['A', 'B', 'C'];
  final List<String> isolationItems = ['Y', 'N'];
  final List<String> isolationTypeItems = ['A', 'B'];
  final List<String> isolationDistanceItems = ['A', 'B', 'C', 'D'];
  final List<String> qPIRItems = ['Y', 'N'];
  final List<String> flaggingItems = ['GF', 'RFI', 'RFD', 'BF', 'Discard'];
  final List<String> recommendationItems = ['Continue', 'Discard'];
  final List<String> reasonPLDItems = ['A', 'B'];
  final List<String> reasonTidakTerauditItems = ['A', 'B', 'C'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAudit3Controller = TextEditingController(text: _convertToDateIfNecessary(row[45]));
    _dateClosedController = TextEditingController(text: _convertToDateIfNecessary(row[61]));

    // Initialize controllers for text fields
    _remarksController = TextEditingController(text: row[64]);
    _recommendationPLDController = TextEditingController(text: row[65]);

    selectedFemaleShed2 = row[47];
    selectedSheddingMale2 = row[48];
    selectedSheddingFemale2 = row[49];
    selectedStandingCropMale = row[50];
    selectedStandingCropFemale = row[51];
    selectedLSV = row[52];
    selectedDetasselingObservation = row[53];
    selectedAffectedFields = row[54];
    selectedNickCover = row[55];
    selectedCropUniformity = row[56];
    selectedIsolation = row[57];
    selectedIsolationType = row[58];
    selectedIsolationDistance = row[59];
    selectedQPIR = row[60];
    selectedFlagging = row[62];
    selectedRecommendation = row[63];
    selectedReasonPLD = row[66];
    selectedReasonTidakTeraudit = row[67];
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
                        _buildDatePickerField('Date of Audit 3 (dd/MM)', 45, _dateAudit3Controller),
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
                              row[47] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = 0-5 shedd / Ha\nB (RF) = 6-30 shedd / Ha\nC (BF) = >30 shedd / Ha',
                          icon: Icons.spa,
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
                              row[48] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.male,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Shedding Offtype & CVL Female',
                          items: sheddingFemale2Items,
                          value: selectedSheddingFemale2,
                          onChanged: (value) {
                            setState(() {
                              selectedSheddingFemale2 = value;
                              row[49] = value ?? '';
                            });
                          },
                          helpText: 'A = 0-5 plants / Ha\nB = > 5 plants / Ha',
                          icon: Icons.female,
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
                              row[50] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.agriculture,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Standing crop Offtype & CVL Female',
                          items: standingCropFemaleItems,
                          value: selectedStandingCropFemale,
                          onChanged: (value) {
                            setState(() {
                              selectedStandingCropFemale = value;
                              row[51] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = 0-5 plants / Ha\nB (RF) = >5-10 plants / Ha',
                          icon: Icons.agriculture,
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
                              row[52] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.bug_report,
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
                              row[53] = value ?? '';
                            });
                          },
                          helpText: 'A=Best (0,5)\nB=Good (5,5)\nC=Poor (5,7)\nD=Very Poor (>7)',
                          icon: Icons.content_cut,
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
                              row[54] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = Not Affected\nB (RF) = Severly Affected (if distance < 50 mtr)',
                          icon: Icons.landscape,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Nick Cover',
                          items: nickCoverItems,
                          value: selectedNickCover,
                          onChanged: (value) {
                            setState(() {
                              selectedNickCover = value;
                              row[55] = value ?? '';
                            });
                          },
                          helpText: 'A = Good Nick - Male early or 1% Male Shedd at 5% Silk or reverse\nB = >10-25 % receptive silks at either end & no male shedding\nC = >25% receptive silks at either end & no male shedding',
                          icon: Icons.eco,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Crop Uniformity',
                          items: cropUniformityItems,
                          value: selectedCropUniformity,
                          onChanged: (value) {
                            setState(() {
                              selectedCropUniformity = value;
                              row[56] = value ?? '';
                            });
                          },
                          helpText: 'A=Good\nB= Fair\nC=Poor',
                          icon: Icons.grass,
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
                              row[57] = value ?? '';
                            });
                          },
                          helpText: 'Y = Yes\nN = No',
                          icon: Icons.fence,
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
                                    row[58] = value ?? '';
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
                                    row[59] = value ?? '';
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
                              row[60] = value ?? '';
                            });
                          },
                          helpText: 'Y = Ada\nN = Tidak Ada',
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(height: 10),
                        _buildDatePickerField('Closed out Date', 61, _dateClosedController),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'FLAGGING',
                          items: flaggingItems,
                          value: selectedFlagging,
                          onChanged: (value) {
                            setState(() {
                              selectedFlagging = value;
                              row[62] = value ?? '';
                            });
                          },
                          helpText: 'GF/RFI/RFD/BF/Discard',
                          icon: Icons.flag,
                        ),
                        const SizedBox(height: 20),

                        // Recommendation Section
                        _buildSectionHeader('Recommendation'),
                        _buildDropdownFormField(
                          label: 'Recommendation',
                          items: recommendationItems,
                          value: selectedRecommendation,
                          onChanged: (value) {
                            setState(() {
                              selectedRecommendation = value;
                              row[63] = value ?? '';
                            });
                          },
                          helpText: 'Continue to Next Process/Discard',
                          icon: Icons.recommend,
                        ),
                        const SizedBox(height: 10),
                        _buildTextFormField('Remarks', 64,
                            icon: Icons.comment,
                            maxLines: 2,
                            controller: _remarksController),
                        const SizedBox(height: 10),
                        _buildTextFormField('Recommendation PLD (Ha)', 65,
                            icon: Icons.area_chart,
                            keyboardType: TextInputType.number,
                            prefix: "'",
                            controller: _recommendationPLDController),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Reason PLD',
                          items: reasonPLDItems,
                          value: selectedReasonPLD,
                          onChanged: (value) {
                            setState(() {
                              selectedReasonPLD = value;
                              row[66] = value ?? '';
                            });
                          },
                          helpText: 'A : No Plant\nB : Class D (Uniformity)',
                          icon: Icons.info_outline,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Reason Tidak Teraudit',
                          items: reasonTidakTerauditItems,
                          value: selectedReasonTidakTeraudit,
                          onChanged: (value) {
                            setState(() {
                              selectedReasonTidakTeraudit = value;
                              row[67] = value ?? '';
                            });
                          },
                          helpText: 'A= Discard/PLD\nB= Lokasi tidak ditemukan\nC = Mised Out',
                          icon: Icons.not_interested,
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
          labelText: "$label *", // Add asterisk to indicate required field
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
          if (value == null || value.isEmpty) {
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
  Widget _buildDatePickerField(String label, int index, TextEditingController controller) {
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
          labelText: "$label *", // Add asterisk to indicate required field
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
          if (value == null || value.isEmpty) {
            return 'Please select a date';
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
              labelText: "$label *", // Add asterisk to indicate required field
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
            value: value,
            hint: Text(hint ?? 'Select an option'),
            validator: (value) {
              if (value == null || value.isEmpty) {
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

  void _showLoadingDialogAndClose() {
    bool dialogShown = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        dialogShown = true;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/loading.json', width: 150, height: 150),
              const SizedBox(height: 20),
              const Text(
                "Saving data...",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );

    Timer(const Duration(seconds: 5), () {
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SuccessScreen(
                  row: row,
                  userName: userName,
                  userEmail: userEmail,
                  region: widget.region,
                ),
              ),
            );
          }
        });
      }
    });
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    setState(() {
      isLoading = true;
    });

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    String responseMessage;
    try {
      await gSheetsApi.updateRow('Generative', rowData, rowData[2]);
      await _saveToHive(rowData);
      responseMessage = 'Data successfully saved to Audit Database';

      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Generative');
      if (sheet != null) {
        final rowIndex = await _findRowByFieldNumber(sheet, row[2]);
        if (rowIndex != -1) {
          await _restoreGenerativeFormulas(gSheetsApi, sheet, rowIndex);
        }
      }
    } catch (e) {
      await _logErrorToActivity('Failed to save data: ${e.toString()}');
      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      setState(() {
        isLoading = false;
      });
    }

    if (mounted) {
      _navigateBasedOnResponse(context, responseMessage);
    }
  }

  Future<void> _restoreGenerativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue(
        '=IF(OR(AT$rowIndex=0;AT$rowIndex="");"Not Audited";"Audited")',
        row: rowIndex, column: 72);
    await sheet.values.insertValue(
        '=IF(OR(AG$rowIndex>0;AO$rowIndex>0);"Audited";"Not Audited")',
        row: rowIndex, column: 73);
    await sheet.values.insertValue(
        '=IFERROR(IF(OR(AG$rowIndex=0;AG$rowIndex="");"";WEEKNUM(AG$rowIndex;1));"0")',
        row: rowIndex, column: 34);
    await sheet.values.insertValue(
        '=IFERROR(IF(OR(AO$rowIndex=0;AO$rowIndex="");"";WEEKNUM(AO$rowIndex;1));"0")',
        row: rowIndex, column: 42);
    await sheet.values.insertValue(
        '=IFERROR(IF(OR(AT$rowIndex=0;AT$rowIndex="");"";WEEKNUM(AT$rowIndex;1));"0")',
        row: rowIndex, column: 47);
    await sheet.values.insertValue( // Standing Corp
        '=I$rowIndex-U$rowIndex',
        row: rowIndex, column: 24);
    await sheet.values.insertValue( // Hyperlink Coordinate
        '=IFERROR(IF(AND(LEFT(R$rowIndex;4)-0<6;LEFT(R$rowIndex;4)-0>-11);HYPERLINK("HTTP://MAPS.GOOGLE.COM/maps?q="&R$rowIndex;"LINK");"Not Found");"")',
        row: rowIndex, column: 25);
    await sheet.values.insertValue( // FASE
        '=IF(I$rowIndex=0;"Discard";IF(X$rowIndex=0;"Harvest";IF(TODAY()-W$rowIndex<46;"Vegetative";IF(AND(TODAY()-W$rowIndex>45;TODAY()-W$rowIndex<56);"Pre Flowering";IF(AND(TODAY()-W$rowIndex>55;TODAY()-W$rowIndex<66);"Flowering";IF(AND(TODAY()-W$rowIndex>65;TODAY()-W$rowIndex<80);"Close Out";IF(TODAY()-W$rowIndex>79;"Male Cutting";"")))))))',
        row: rowIndex, column: 27);
    await sheet.values.insertValue( // Week of Flowering Rev
        '=WEEKNUM(AB$rowIndex)',
        row: rowIndex, column: 29);
    await sheet.values.insertValue( // Week of Flowering PDN
        '=WEEKNUM(IF(F$rowIndex="ac01";J$rowIndex+60;J$rowIndex+57))',
        row: rowIndex, column: 30);
    await sheet.values.insertValue( // Effective Area Planted
        '=SUBSTITUTE(G$rowIndex; "."; ",")-SUBSTITUTE(H$rowIndex; "."; ",")',
        row: rowIndex, column: 9);
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
      _showLoadingDialogAndClose();
      _saveToGoogleSheets(row);
    }
  }

  bool _isDataValid() {
    // Check specific required fields for generative form
    return _dateAudit3Controller.text.isNotEmpty &&
        selectedFemaleShed2 != null &&
        selectedSheddingMale2 != null &&
        selectedSheddingFemale2 != null &&
        selectedStandingCropMale != null &&
        selectedStandingCropFemale != null &&
        selectedLSV != null &&
        selectedDetasselingObservation != null &&
        selectedAffectedFields != null &&
        selectedNickCover != null &&
        selectedCropUniformity != null &&
        selectedIsolation != null &&
        (selectedIsolation != 'Y' || (selectedIsolationType != null && selectedIsolationDistance != null)) &&
        selectedQPIR != null &&
        _dateClosedController.text.isNotEmpty &&
        selectedFlagging != null &&
        selectedRecommendation != null &&
        row[64].isNotEmpty && // Remarks
        row[65].isNotEmpty && // Recommendation PLD
        selectedReasonPLD != null &&
        selectedReasonTidakTeraudit != null;
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

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateBasedOnResponse(BuildContext context, String response) {
    if (response == 'Data successfully saved to Audit Database') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SuccessScreen(
            row: row,
            userName: userName,
            userEmail: userEmail,
            region: widget.region,
          ),
        ),
      );
    } else if (response == 'Failed to save data. Please try again.') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FailedScreen(),
        ),
      );
    } else {
      _showSnackbar('Unknown response: $response');
    }
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

  const SuccessScreen({
    super.key,
    required this.row,
    required this.userName,
    required this.userEmail,
    required this.region,
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
              onPressed: () async {
                _showLoadingDialog(context);
                final navigator = Navigator.of(context);
                await _saveBackActivityToGoogleSheets(region);
                navigator.pop();
                navigator.pop();
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
                'Confirm!',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialog(BuildContext context) {
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
  }

  Future<void> _saveBackActivityToGoogleSheets(String region) async {
    final String spreadsheetId = ConfigManager.getSpreadsheetId(region) ?? 'defaultSpreadsheetId';
    final String worksheetTitle = 'Aktivitas';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    final String timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    final String fieldNumber = row[2];
    final String regions = row[18];
    final String action = 'Update';
    final String status = 'Success';

    final List<String> rowData = [
      userEmail,
      userName,
      status,
      regions,
      action,
      'Generative - Audit 3',
      fieldNumber,
      timestamp,
    ];

    try {
      await gSheetsApi.addRow(worksheetTitle, rowData);
      debugPrint('Aktivitas berhasil dicatat di Database $worksheetTitle');
    } catch (e) {
      debugPrint('Gagal mencatat aktivitas di Database $worksheetTitle: $e');
    }
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