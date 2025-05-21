import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class VegetativeEditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave;

  const VegetativeEditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave,
  });

  @override
  VegetativeEditScreenState createState() => VegetativeEditScreenState();
}

class VegetativeEditScreenState extends State<VegetativeEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;
  late TextEditingController _actualPlantingDateController;
  late TextEditingController _coDetasselingController;
  late TextEditingController _fieldSizeController;
  late TextEditingController _maleSplitController;
  late TextEditingController _sowingRatioController;
  late TextEditingController _remarksController;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;
  late GoogleSheetsApi gSheetsApi;

  String? selectedFI;
  List<String> fiList = [];

  String? selectedSplitField;
  String? selectedIsolationProblem;
  String? selectedContaminantType;
  String? selectedContaminantDistance;
  String? selectedCropUniformity;
  String? selectedOfftypeInMale;
  String? selectedOfftypeInFemale;
  String? selectedPreviousCrop;
  String? selectedFIRApplied;
  String? selectedPOIAccuracy;
  String? selectedFlagging;
  String? selectedRecommendation;

  final List<String> splitFieldItems = ['A', 'B'];
  final List<String> isolationProblemItems = ['Y', 'N'];
  final List<String> contaminantTypeItems = ['A', 'B'];
  final List<String> contaminantDistanceItems = ['A', 'B', 'C', 'D'];
  final List<String> cropUniformityItems = ['A', 'B', 'C'];
  final List<String> offtypeItems = ['A', 'B'];
  final List<String> firAppliedItems = ['Y', 'N'];
  final List<String> poiAccuracyItems = ['Valid', 'Not Valid'];
  final List<String> flaggingItems = ['GF', 'RF'];
  final List<String> recommendationItems = ['Continue', 'Discard'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchSpreadsheetId();
      await _loadFIList(widget.region);
    });
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[33]));
    _actualPlantingDateController = TextEditingController(text: _convertToDateIfNecessary(row[35]));
    _coDetasselingController = TextEditingController(text: row[32]);
    _fieldSizeController = TextEditingController(text: row[36].replaceAll("'", ""));
    _maleSplitController = TextEditingController(text: row[37].replaceAll("'", ""));
    _sowingRatioController = TextEditingController(text: row[38]);
    _remarksController = TextEditingController(text: row[51]);

    _loadFIList(widget.region);

    // Initialize dropdown fields
    selectedSplitField = row[39];
    selectedIsolationProblem = row[40];
    selectedContaminantType = row[41];
    selectedContaminantDistance = row[42];
    selectedCropUniformity = row[43];
    selectedOfftypeInMale = row[44];
    selectedOfftypeInFemale = row[45];
    selectedPreviousCrop = row[46];
    selectedFIRApplied = row[47];
    selectedPOIAccuracy = row[48];
    selectedFlagging = row[49];
    selectedRecommendation = row[50];
  }

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();
  }

  Future<void> _loadFIList(String region) async {
    setState(() => isLoading = true);

    try {
      final gSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
      await gSheetsApi.init();
      final List<String> fetchedFI = await gSheetsApi.fetchFIByRegion('FI', region);

      setState(() {
        fiList = fetchedFI;
        selectedFI = row[31];
      });
    } catch (e) {
      debugPrint('Gagal mengambil data FI: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('vegetativeData');
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('vegetativeData');
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
            'Edit Vegetative Field',
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: const LinearProgressIndicator(
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),

                  // Main Card Container
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Field Information Section
                          _buildSectionHeader('Field Information', Icons.info_outline),

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
                          _buildSectionHeader('Audit Information', Icons.assignment),
                          _buildFIDropdownField(
                            'QA FI',
                            selectedFI,
                            fiList,
                                (value) {
                              setState(() {
                                selectedFI = value;
                                row[31] = value ?? '';
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            'Co Detasseling',
                            _coDetasselingController,
                            Icons.people,
                            validator: (value) => value == null || value.toString().isEmpty ? 'Harus diisi' : null,
                            onChanged: (value) {
                              setState(() {
                                row[32] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDateField(
                            'Date of Audit',
                            _dateAuditController,
                                (date) {
                              setState(() {
                                row[33] = date;
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select a date' : null,
                          ),
                          const SizedBox(height: 10),
                          _buildDateField(
                            'Actual Female Planting Date',
                            _actualPlantingDateController,
                                (date) {
                              setState(() {
                                row[35] = date;
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select a date' : null,
                          ),
                          const SizedBox(height: 10),

                          // Field Metrics Section
                          _buildSectionHeader('Field Metrics', Icons.straighten),
                          _buildNumericField(
                            'Field Size by Audit (Ha)',
                            _fieldSizeController,
                            Icons.crop_square,
                            validator: (value) => value == null || value.toString().isEmpty ? 'This field is required' : null,
                            onChanged: (value) {
                              setState(() {
                                row[36] = "'$value";
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildNumericField(
                            'Male Split by Audit',
                            _maleSplitController,
                            Icons.view_week,
                            validator: (value) => value == null || value.toString().isEmpty ? 'This field is required' : null,
                            onChanged: (value) {
                              setState(() {
                                row[37] = "'$value";
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            'Sowing Ratio by Audit',
                            _sowingRatioController,
                            Icons.compare_arrows,
                            validator: (value) => value == null || value.toString().isEmpty ? 'This field is required' : null,
                            onChanged: (value) {
                              setState(() {
                                row[38] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 10),

                          // Field Conditions Section
                          _buildSectionHeader('Field Conditions', Icons.landscape),
                          _buildDropdownField(
                            'Split Field by Audit',
                            selectedSplitField,
                            splitFieldItems,
                                (value) {
                              setState(() {
                                selectedSplitField = value;
                                row[39] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'A = No\nB = Yes',
                            icon: Icons.call_split,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            'Isolation Problem by Audit',
                            selectedIsolationProblem,
                            isolationProblemItems,
                                (value) {
                              setState(() {
                                selectedIsolationProblem = value;
                                row[40] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'Y = Yes\nN = No',
                            icon: Icons.security,
                          ),
                          const SizedBox(height: 10),
                          if (selectedIsolationProblem == 'Y')
                            Column(
                              children: [
                                _buildDropdownField(
                                  'If "YES" Contaminant Type',
                                  selectedContaminantType,
                                  contaminantTypeItems,
                                      (value) {
                                    setState(() {
                                      selectedContaminantType = value;
                                      row[41] = value ?? '';
                                    });
                                  },
                                  validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                                  helpText: 'A = Seed Production\nB = Jagung Komersial',
                                  icon: Icons.category,
                                ),
                                const SizedBox(height: 10),

                                _buildDropdownField(
                                  'If "YES" Contaminant Distance',
                                  selectedContaminantDistance,
                                  contaminantDistanceItems,
                                      (value) {
                                    setState(() {
                                      selectedContaminantDistance = value;
                                      row[42] = value ?? '';
                                    });
                                  },
                                  validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                                  helpText: 'A = >300 m\nB = >200-<300 m\nC = >100 & <200 m\nD = <100 m',
                                  icon: Icons.social_distance,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          const SizedBox(height: 10),

                          // Crop Quality Section
                          _buildSectionHeader('Crop Quality', Icons.eco),
                          _buildDropdownField(
                            'Crop Uniformity',
                            selectedCropUniformity,
                            cropUniformityItems,
                                (value) {
                              setState(() {
                                selectedCropUniformity = value;
                                row[43] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'A = Good\nB = Fair\nC = Poor',
                            icon: Icons.grain,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            'Offtype in Male',
                            selectedOfftypeInMale,
                            offtypeItems,
                                (value) {
                              setState(() {
                                selectedOfftypeInMale = value;
                                row[44] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'A = No\nB = Yes',
                            icon: Icons.male,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            'Offtype in Female',
                            selectedOfftypeInFemale,
                            offtypeItems,
                                (value) {
                              setState(() {
                                selectedOfftypeInFemale = value;
                                row[45] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'A = No\nB = Yes',
                            icon: Icons.female,
                          ),
                          const SizedBox(height: 10),

                          // Field History Section
                          _buildSectionHeader('Field History & Management', Icons.history),
                          _buildDropdownField(
                            'Previous Crop by Audit',
                            selectedPreviousCrop,
                            offtypeItems,
                                (value) {
                              setState(() {
                                selectedPreviousCrop = value;
                                row[46] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'A = Not Corn\nB = Corn After Corn',
                            icon: Icons.history_edu,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            'FIR Applied',
                            selectedFIRApplied,
                            firAppliedItems,
                                (value) {
                              setState(() {
                                selectedFIRApplied = value;
                                row[47] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'Y = Ada\nN = Tidak Ada',
                            icon: Icons.check_circle_outline,
                          ),
                          const SizedBox(height: 10),

                          // Field Validation Section
                          _buildSectionHeader('Field Validation', Icons.verified),
                          _buildDropdownField(
                            'POI Accuracy',
                            selectedPOIAccuracy,
                            poiAccuracyItems,
                                (value) {
                              setState(() {
                                selectedPOIAccuracy = value;
                                row[48] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'POI Accuracy (Valid/Not Valid)',
                            icon: Icons.location_searching,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            'Flagging (GF/RF)',
                            selectedFlagging,
                            flaggingItems,
                                (value) {
                              setState(() {
                                selectedFlagging = value;
                                row[49] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'Flagging (GF/RF)',
                            icon: Icons.flag,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            'Recommendation',
                            selectedRecommendation,
                            recommendationItems,
                                (value) {
                              setState(() {
                                selectedRecommendation = value;
                                row[50] = value ?? '';
                              });
                            },
                            validator: (value) => value == null || value.toString().isEmpty ? 'Please select an option' : null,
                            helpText: 'Continue to Next Process/Discard',
                            icon: Icons.recommend,
                          ),
                          const SizedBox(height: 10),

                          // Remarks Section
                          _buildSectionHeader('Additional Information', Icons.note_add),
                          _buildTextField(
                            'Remarks',
                            _remarksController,
                            Icons.comment,
                            maxLines: 3,
                            onChanged: (value) {
                              setState(() {
                                row[51] = value;
                              });
                            },
                          ),
                          const SizedBox(height: 30),

                          // Save Button
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _showConfirmationDialog(context);
                                } else {
                                  // Show error message if validation fails
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Please fill all required fields'),
                                      backgroundColor: Colors.red.shade700,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
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

  // Implement the new form field builders that include validation
  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon, {
        String? Function(String?)? validator,
        void Function(String)? onChanged,
        int maxLines = 1,
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
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: "$label *", // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.green.shade700),
          prefixIcon: Icon(icon, color: Colors.green.shade600),
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
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumericField(
      String label,
      TextEditingController controller,
      IconData icon, {
        String? Function(String?)? validator,
        void Function(String)? onChanged,
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
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: "$label *", // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.green.shade700),
          prefixIcon: Icon(icon, color: Colors.green.shade600),
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
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateField(
      String label,
      TextEditingController controller,
      void Function(String) onDateSelected, {
        String? Function(String?)? validator,
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
        validator: validator ?? (value) {
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
              onDateSelected(formattedDate);
            });
          }
        },
      ),
    );
  }

  Widget _buildFIDropdownField(String label, String? value, List<String> items, Function(String?) onChanged) {
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
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "$label *", // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.green.shade700),
          prefixIcon: Icon(Icons.person, color: Colors.green.shade600),
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
        hint: const Text('Select Field Inspector'),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Field Inspector is required';
          }
          return null;
        },
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7, // Adjust width as needed
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        }).toList(),
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
        isExpanded: true, // Make dropdown take full width
      ),
    );
  }

  Widget _buildDropdownField(
      String label,
      String? value,
      List<String> items,
      Function(String?) onChanged, {
        String? Function(String?)? validator,
        String? helpText,
        IconData? icon,
      }) {
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
            hint: Text('Select an option'),
            onChanged: onChanged,
            validator: validator ?? (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an option';
              }
              return null;
            },
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
          const SizedBox(height: 5),
          Text(
            helpText,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green.shade800, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
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

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showLoadingDialogAndClose();
                _saveToGoogleSheets(row);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
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
                "Ngrantos sekedap...",
                style: TextStyle(color: Colors.white, fontSize: 18),
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
    setState(() => isLoading = true);

    String responseMessage;
    try {
      await gSheetsApi.updateRow('Vegetative', rowData, rowData[2]);
      await _saveToHive(rowData);
      responseMessage = 'Data successfully saved to Audit Database';

      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Vegetative');
      if (sheet != null) {
        final rowIndex = await _findRowByFieldNumber(sheet, row[2]);
        if (rowIndex != -1) {
          await _restoreVegetativeFormulas(gSheetsApi, sheet, rowIndex);
        }
      }
    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      setState(() {
        isLoading = false;
      });
    }

    if (mounted) _navigateBasedOnResponse(context, responseMessage);
  }

  Future<void> _restoreVegetativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Cek Result
        '=IF(OR(AH$rowIndex=0;AH$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 56);
    await sheet.values.insertValue( // Week of Reporting
        '=IFERROR(IF(OR(AH$rowIndex=0;AH$rowIndex="");"";WEEKNUM(AH$rowIndex;1));"0")',
        row: rowIndex, column: 35);
    await sheet.values.insertValue( // Standing Crops
        '=I$rowIndex-U$rowIndex',
        row: rowIndex, column: 25);
    await sheet.values.insertValue( // Hyperlink Coordinate
        '=IFERROR(IF(AND(LEFT(R$rowIndex;4)-0<6;LEFT(R$rowIndex;4)-0>-11);HYPERLINK("HTTP://MAPS.GOOGLE.COM/maps?q="&R$rowIndex;"LINK");"Not Found");"")',
        row: rowIndex, column: 26);
    await sheet.values.insertValue( // Fase
        '=IF(I$rowIndex=0;"Discard";IF(Y$rowIndex=0;"Harvest";IF(TODAY()-J$rowIndex<46;"Vegetative";IF(AND(TODAY()-J$rowIndex>45;TODAY()-J$rowIndex<56);"Pre Flowering";IF(AND(TODAY()-J$rowIndex>55;TODAY()-J$rowIndex<66);"Flowering";IF(AND(TODAY()-J$rowIndex>65;TODAY()-J$rowIndex<81);"Close Out";IF(TODAY()-J$rowIndex>80;"Male Cutting";"")))))))',
        row: rowIndex, column: 28);
    await sheet.values.insertValue( // Veg Audit (Est + 30 DAP)
        '=J$rowIndex+30',
        row: rowIndex, column: 29);
    await sheet.values.insertValue( // Week of Vegetative
        '=IF(OR(I$rowIndex=0;I$rowIndex="");"";WEEKNUM(AC$rowIndex;1))',
        row: rowIndex, column: 30);
    await sheet.values.insertValue( // Total Area Planted
        '=SUBSTITUTE(G$rowIndex; "."; ",")-SUBSTITUTE(H$rowIndex; "."; ",")',
        row: rowIndex, column: 9);
    debugPrint("Rumus berhasil diterapkan di Vegetative pada baris $rowIndex.");
  }

  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber) async {
    final List<List<String>> rows = await sheet.values.allRows();
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) {
        return i + 1;
      }
    }
    return -1;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown response: $response')),
      );
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
                minimumSize: const Size(200, 60), // Mengatur ukuran tombol (lebar x tinggi)
                backgroundColor: Colors.green.shade700, // Warna background tombol
                foregroundColor: Colors.white, // Warna teks tombol
                shape: RoundedRectangleBorder( // Membuat sudut tombol melengkung
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

  // Fungsi untuk menampilkan dialog loading
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
      'Vegetative',
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
                minimumSize: const Size(200, 60), // Mengatur ukuran tombol (lebar x tinggi)
                backgroundColor: Colors.red.shade700, // Warna background tombol
                foregroundColor: Colors.white, // Warna teks tombol
                shape: RoundedRectangleBorder( // Membuat sudut tombol melengkung
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