import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
  late TextEditingController _sowingRatioController;
  late TextEditingController _remarksController;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;
  late GoogleSheetsApi gSheetsApi;

  String? selectedFA;
  List<String> faList = [];

  String? selectedMaleSplit;
  String? selectedSplitField;
  String? selectedIsolationProblem;
  String? selectedContaminantType;
  String? selectedContaminantDistance;
  String? selectedCropUniformity;
  String? selectedOfftypeInMale;
  String? selectedOfftypeInFemale;
  String? selectedPreviousCrop;
  String? selectedFIRApplied;
  String? selectedFlagging;
  String? selectedRecommendation;

  final List<String> maleSplitItems = ['Y', 'N'];
  final List<String> splitFieldItems = ['A', 'B'];
  final List<String> isolationProblemItems = ['Y', 'N'];
  final List<String> contaminantTypeItems = ['A', 'B'];
  final List<String> contaminantDistanceItems = ['A', 'B', 'C', 'D'];
  final List<String> cropUniformityItems = ['1', '2', '3', '4', '5'];
  final List<String> offtypeItems = ['A', 'B'];
  final List<String> firAppliedItems = ['Y', 'N'];
  final List<String> flaggingItems = ['GF', 'RF'];
  final List<String> recommendationItems = ['Continue', 'Discard'];

  bool get areRecommendationFieldsRequired {
    return selectedRecommendation != null && selectedRecommendation != 'Discard';
  }

  bool isLoading = false;

  late TextEditingController _locationController;
  bool _isGettingLocation = false;
  bool _isLocationTagged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchSpreadsheetId();
      await _loadFAList(widget.region);
    });
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[33]));
    _actualPlantingDateController = TextEditingController(text: _convertToDateIfNecessary(row[35]));
    _coDetasselingController = TextEditingController(text: row[32]);
    _fieldSizeController = TextEditingController(text: row[36].replaceAll("'", ""));
    _sowingRatioController = TextEditingController(text: row[38]);
    _remarksController = TextEditingController(text: row[51]);

    _loadFAList(widget.region);

    // Initialize dropdown fields
    selectedMaleSplit = row[37];
    selectedSplitField = row[39];
    selectedIsolationProblem = row[40];
    selectedContaminantType = row[41];
    selectedContaminantDistance = row[42];
    selectedCropUniformity = row[43];
    selectedOfftypeInMale = row[44];
    selectedOfftypeInFemale = row[45];
    selectedPreviousCrop = row[46];
    selectedFIRApplied = row[47];
    selectedFlagging = row[49];
    selectedRecommendation = row[50];
    // Add a listener to update the UI when recommendation changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        // This will trigger a rebuild with the correct required field indicators
      });
    });
    _locationController = TextEditingController(text: row.length > 17 ? row[17] : 'No location set');
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Location services are disabled.');
        setState(() => _isGettingLocation = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackBar('Location permissions are denied.');
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackBar(
            'Location permissions are permanently denied, we cannot request permissions.');
        setState(() => _isGettingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: LocationAccuracy.high));

      String coordinates = '${position.latitude},${position.longitude}';

      setState(() {
        _locationController.text = coordinates;
        if (row.length > 17) {
          row[17] = coordinates;
        }

        // BARU: Set penanda menjadi true setelah lokasi berhasil didapat.
        _isLocationTagged = true;

        _isGettingLocation = false;
      });
      _showSnackbar('Location successfully tagged!');
    } catch (e) {
      _showErrorSnackBar('Failed to get location: $e');
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();
  }

  Future<void> _loadFAList(String region) async {
    setState(() => isLoading = true);

    try {
      final gSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
      await gSheetsApi.init();
      final List<String> fetchedFA = await gSheetsApi.fetchFIByRegion('FA', region);

      setState(() {
        faList = fetchedFA;
        selectedFA = row[14];
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
        backgroundColor: Colors.amber.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.amber.shade700, Colors.amber.shade100],
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
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

                          const SizedBox(height: 10),
                          _buildSectionHeader('Tag Location', Icons.my_location),
                          _buildLocationField(), // Memanggil widget baru
                          const SizedBox(height: 10),

                          const SizedBox(height: 20),
                          _buildRequiredFieldsNotice(),

                          // Audit Information Section
                          _buildSectionHeader('Audit Information', Icons.assignment),
                          _buildFADropdownField(
                            'FA',
                            selectedFA,
                            faList,
                                (value) {
                              setState(() {
                                selectedFA = value;
                                row[14] = value ?? '';
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'This field is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            'Co Detasseling',
                            _coDetasselingController,
                            Icons.people,
                            // Update the validator functions for all fields except FA and Date of Audit
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
                          ),
                          const SizedBox(height: 10),

                          // Field Metrics Section
                          _buildSectionHeader('Field Metrics', Icons.straighten),
                          _buildNumericField(
                            'Field Size by Audit (Ha)',
                            _fieldSizeController,
                            Icons.crop_square,
                            onChanged: (value) {
                              setState(() {
                                row[36] = "'$value";
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Male Split by Audit',
                            value: selectedMaleSplit,
                            items: maleSplitItems,
                            onChanged: (value) {
                              setState(() {
                                selectedMaleSplit = value;
                                row[37] = value ?? '';
                              });
                            },
                            helpText: 'Y = Yes\nN = No',
                            icon: Icons.view_week,
                          ),
                          const SizedBox(height: 10),
                          _buildTextField(
                            'Sowing Ratio by Audit',
                            _sowingRatioController,
                            Icons.compare_arrows,
                            onChanged: (value) {
                              setState(() {
                                // Always ensure the value starts with a single quote
                                row[38] = value.startsWith("'") ? value : "'$value";
                              });
                            },
                            helpText: 'Female:Male (tanpa spasi)',
                          ),
                          const SizedBox(height: 10),

                          // Field Conditions Section
                          _buildSectionHeader('Field Conditions', Icons.landscape),
                          _buildDropdownField(
                            label: 'Split Field by Audit',
                            value: selectedSplitField,
                            items: splitFieldItems,
                                onChanged: (value) {
                              setState(() {
                                selectedSplitField = value;
                                row[39] = value ?? '';
                              });
                            },
                            helpText: 'A = No\nB = Yes',
                            icon: Icons.call_split,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Isolation Problem by Audit',
                            value: selectedIsolationProblem,
                            items: isolationProblemItems,
                            onChanged: (value) {
                              setState(() {
                                selectedIsolationProblem = value;
                                row[40] = value ?? '';
                              });
                            },
                            helpText: 'Y = Yes\nN = No',
                            icon: Icons.security,
                          ),
                          const SizedBox(height: 10),
                          if (selectedIsolationProblem == 'Y')
                            Column(
                              children: [
                                _buildDropdownField(
                                  label: 'If "YES" Contaminant Type',
                                  value: selectedContaminantType,
                                  items: contaminantTypeItems,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedContaminantType = value;
                                      row[41] = value ?? '';
                                    });
                                  },
                                  helpText: 'A = Seed Production\nB = Jagung Komersial',
                                  icon: Icons.category,
                                ),
                                const SizedBox(height: 10),

                                _buildDropdownField(
                                  label: 'If "YES" Contaminant Distance',
                                  value: selectedContaminantDistance,
                                  items: contaminantDistanceItems,
                                  onChanged: (value) {
                                    setState(() {
                                      selectedContaminantDistance = value;
                                      row[42] = value ?? '';
                                    });
                                  },
                                  helpText: 'A = >300 m\nB = >200-<300 m\nC = >100 & <200 m\nD = <100 m',
                                  icon: Icons.social_distance,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          const SizedBox(height: 10),
                          // Crop Quality Section
                          _buildSectionHeader('Crop Performance', Icons.eco),
                          _buildDropdownField(
                            label: 'Crop Uniformity',
                            value: selectedCropUniformity,
                            items: cropUniformityItems,
                            onChanged: (value) {
                              setState(() {
                                selectedCropUniformity = value;
                                row[43] = value ?? '';
                              });
                            },
                            helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                            icon: Icons.grain,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Offtype in Male',
                            value: selectedOfftypeInMale,
                            items: offtypeItems,
                            onChanged: (value) {
                              setState(() {
                                selectedOfftypeInMale = value;
                                row[44] = value ?? '';
                              });
                            },
                            helpText: 'A = No\nB = Yes',
                            icon: Icons.male,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Offtype in Female',
                            value: selectedOfftypeInFemale,
                            items: offtypeItems,
                            onChanged: (value) {
                              setState(() {
                                selectedOfftypeInFemale = value;
                                row[45] = value ?? '';
                              });
                            },
                            helpText: 'A = No\nB = Yes',
                            icon: Icons.female,
                          ),
                          const SizedBox(height: 10),

                          // Field History Section
                          _buildSectionHeader('Field History & Management', Icons.history),
                          _buildDropdownField(
                            label: 'Previous Crop by Audit',
                            value: selectedPreviousCrop,
                            items: offtypeItems,
                            onChanged: (value) {
                              setState(() {
                                selectedPreviousCrop = value;
                                row[46] = value ?? '';
                              });
                            },
                            helpText: 'A = Not Corn\nB = Corn After Corn',
                            icon: Icons.history_edu,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'One Seed per Hole',
                            value: selectedFIRApplied,
                            items: firAppliedItems,
                            onChanged: (value) {
                              setState(() {
                                selectedFIRApplied = value;
                                row[47] = value ?? '';
                              });
                            },
                            helpText: 'Y = Yes\nN = No',
                            icon: Icons.hdr_weak_rounded,
                          ),
                          const SizedBox(height: 10),

                          // Field Validation Section
                          _buildSectionHeader('Field Validation', Icons.verified),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Flagging (GF/RF)',
                            value: selectedFlagging,
                            items: flaggingItems,
                            onChanged: (value) {
                              setState(() {
                                selectedFlagging = value;
                                row[49] = value ?? '';
                              });
                            },
                            helpText: 'Flagging (GF/RF)',
                            icon: Icons.flag,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Recommendation',
                            value: selectedRecommendation,
                            items: recommendationItems,
                            onChanged: (value) {
                              setState(() {
                                selectedRecommendation = value;
                                row[50] = value ?? '';
                              });
                            },
                            helpText: 'Continue to Next Process/Discard',
                            icon: Icons.recommend,
                          ),
                          // Add this after the Recommendation dropdown
                          if (selectedRecommendation == 'Discard')
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(vertical: 16),
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
                                      'When "Discard" is selected, only FA and Date of Audit are required. Other fields are optional.',
                                      style: TextStyle(
                                        color: Colors.amber.shade800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                                  if (_validateForm()) {
                                    _showConfirmationDialog();
                                  } else {
                                    _showErrorSnackBar('Please complete all required fields');
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(220, 60),
                                backgroundColor: Colors.amber.shade700,
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

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Coordinates (Lat, Long)',
              style: TextStyle(
                color: Colors.amber.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            // BARIS DI BAWAH INI DIHAPUS/DIKOMENTARI
            // const Text(' *', style: TextStyle(color: Colors.red, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _locationController,
          readOnly: true,
          style: TextStyle(
            color: _isLocationTagged ? Colors.black : Colors.red,
            fontStyle: _isLocationTagged ? FontStyle.normal : FontStyle.italic,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.gps_fixed, color: _isLocationTagged ? Colors.amber.shade600 : Colors.red),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.amber.shade200),
            ),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: _isGettingLocation
          // MODIFIKASI: Mengubah warna indikator loading
              ? CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
          )
              : ElevatedButton.icon(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location, color: Colors.white), // Pastikan ikon putih
            label: const Text('Tag Current Location'),
            style: ElevatedButton.styleFrom(
              // MODIFIKASI: Mengubah warna tombol agar sesuai tema
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ),
      ],
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
              selectedRecommendation == 'Discard'
                  ? 'Only FA and Date of Audit are required when Recommendation is Discard'
                  : 'Fields marked with * are required and must be filled',
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
        String? helpText,
        void Function(String)? onChanged,
        int maxLines = 1,
      }) {
    bool isRequired = selectedRecommendation == 'Continue';

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
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              labelText: isRequired ? "$label *" : label, // Add asterisk to indicate required field
              labelStyle: TextStyle(color: Colors.amber.shade700),
              prefixIcon: Icon(icon, color: Colors.amber.shade600),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return 'This field is required when Recommendation is Continue';
              }
              return null;
            },
            onChanged: onChanged,
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

  Widget _buildNumericField(
      String label,
      TextEditingController controller,
      IconData icon, {
        void Function(String)? onChanged,
      }) {
    bool isRequired = selectedRecommendation == 'Continue';
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
          labelText: isRequired ? "$label *" : label, // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.amber.shade700),
          prefixIcon: Icon(icon, color: Colors.amber.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
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
    bool isRequired = selectedRecommendation == 'Continue';
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
          labelText: isRequired ? "$label *" : label, // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.amber.shade700),
          prefixIcon: Icon(Icons.calendar_today, color: Colors.amber.shade600),
          suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.amber.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
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
                    primary: Colors.amber.shade700,
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

  Widget _buildFADropdownField(
      String label,
      String? value,
      List<String> items,
      Function(String?) onChanged, {
        String? Function(String?)? validator, // Add validator parameter
      }) {
    bool isRequired = selectedRecommendation == 'Continue' || selectedRecommendation == 'Discard';
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
          labelText: isRequired ? "$label *" : label, // Add asterisk to indicate required field
          labelStyle: TextStyle(color: Colors.amber.shade700),
          prefixIcon: Icon(Icons.person, color: Colors.amber.shade600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        initialValue: value,
        hint: const Text('Select Field Inspector'),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
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
        icon: Icon(Icons.arrow_drop_down, color: Colors.amber.shade700),
        isExpanded: true, // Make dropdown take full width
      ),
    );
  }

  Widget _buildDropdownField({
      required String label,
      required List<String> items,
      required String? value,
      required Function(String?) onChanged,
        String? hint,
        String? helpText,
        IconData? icon,
      }) {
    bool isRequired = selectedRecommendation == 'Continue';

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
              labelText: isRequired ? "$label *" : label, // Add asterisk to indicate required field
              labelStyle: TextStyle(color: Colors.amber.shade700),
              prefixIcon: icon != null ? Icon(icon, color: Colors.amber.shade600) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: value,
            hint: Text(hint ?? 'Select an option'),
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return 'This field is required when Recommendation is Continue';
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
            icon: Icon(Icons.arrow_drop_down, color: Colors.amber.shade700),
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
            Icon(icon, color: Colors.amber.shade800, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade800,
              ),
            ),
          ],
        ),
        const Divider(thickness: 2, color: Colors.amber),
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
            Icon(icon, color: Colors.amber.shade700),
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

  // Add this new validation method to replace the previous one
  bool _validateForm() {

    // Get the current form validation state
    bool baseFieldsValid = selectedFA != null && selectedFA!.isNotEmpty &&
        _dateAuditController.text.isNotEmpty;

    if (!baseFieldsValid) {
      _showErrorSnackBar('FA and Date of Audit are required fields.');
      return false;
    }

    // If recommendation is null, it's not valid
    if (selectedRecommendation == null || selectedRecommendation!.isEmpty) {
      _showErrorSnackBar('Please select a Recommendation.');
      return false;
    }
    // If recommendation is "Discard", we only need to validate FA and Date of Audit
    if (selectedRecommendation == 'Discard') {
      return true; // Base fields are already validated
    }

    // For "Continue", specific fields must be validated
    bool additionalFieldsValid =
        selectedMaleSplit != null && selectedMaleSplit!.isNotEmpty &&
        selectedSplitField != null && selectedSplitField!.isNotEmpty &&
        selectedIsolationProblem != null && selectedIsolationProblem!.isNotEmpty &&
        (selectedIsolationProblem == 'N' || (
            selectedContaminantType != null && selectedContaminantType!.isNotEmpty &&
            selectedContaminantDistance != null && selectedContaminantDistance!.isNotEmpty)) &&
        selectedCropUniformity != null && selectedCropUniformity!.isNotEmpty &&
        selectedOfftypeInMale != null && selectedOfftypeInMale!.isNotEmpty &&
        selectedOfftypeInFemale != null && selectedOfftypeInFemale!.isNotEmpty &&
        selectedPreviousCrop != null && selectedPreviousCrop!.isNotEmpty &&
        selectedFIRApplied != null && selectedFIRApplied!.isNotEmpty &&
        selectedFlagging != null && selectedFlagging!.isNotEmpty &&
    row[32].isNotEmpty &&
    row[33].isNotEmpty &&
    row[35].isNotEmpty &&
    row[36].isNotEmpty &&
    row[37].isNotEmpty &&
    row[38].isNotEmpty; // Ensure Date o

    if (!additionalFieldsValid) {
      _showErrorSnackBar('When Recommendation is Continue, all assessment fields are required.');
      return false;
    }

    return true;
  }

  Future<void> _showConfirmationDialog() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Save', style: TextStyle(color: Colors.amber.shade800)),
        content: const Text('Are you sure you want to save the changes? All fields must be filled correctly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
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
            phase: 'Vegetative',
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
      // Check if widget is still mounted and dialog was shown
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Use a microtask to ensure the navigation happens after the current frame
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SuccessScreen(
                  row: row,
                  userName: userName,
                  userEmail: userEmail,
                  region: widget.region,
                  phase: 'Vegetative',
                ),
              ),
            );
          }
        });
      }
    });
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    if (!mounted) return;
    setState(() => isLoading = true);

    String responseMessage;
    try {
      // 1. Cari tahu di baris mana data akan diperbarui
      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Vegetative');
      if (sheet == null) {
        throw Exception('Worksheet "Vegetative" tidak ditemukan.');
      }
      final rowIndex = await _findRowByFieldNumber(sheet, rowData[2]);
      if (rowIndex == -1) {
        throw Exception('Data dengan Field Number ${rowData[2]} tidak ditemukan.');
      }

      // 2. Siapkan Map berisi data yang akan diupdate [columnIndex: value]
      final Map<int, String> updates = {
        18: _locationController.text, // Kolom R: Koordinat
        15: selectedFA ?? '', // Kolom P: FA
        33: _coDetasselingController.text, // Kolom AG: Co Detasseling
        34: _dateAuditController.text, // Kolom AH: Date of Audit
        36: _actualPlantingDateController.text, // Kolom AJ: Actual Female Planting Date
        37: "'${_fieldSizeController.text}", // Kolom AK: Field Size
        38: selectedMaleSplit ?? '', // Kolom AL: Male Split
        39: "'${_sowingRatioController.text}", // Kolom AM: Sowing Ratio
        40: selectedSplitField ?? '', // Kolom AN: Split Field
        41: selectedIsolationProblem ?? '', // Kolom AO: Isolation Problem
        42: selectedContaminantType ?? '', // Kolom AP: Contaminant Type
        43: selectedContaminantDistance ?? '', // Kolom AQ: Contaminant Distance
        44: selectedCropUniformity ?? '', // Kolom AR: Crop Uniformity
        45: selectedOfftypeInMale ?? '', // Kolom AS: Offtype in Male
        46: selectedOfftypeInFemale ?? '', // Kolom AT: Offtype in Female
        47: selectedPreviousCrop ?? '', // Kolom AU: Previous Crop
        48: selectedFIRApplied ?? '', // Kolom AV: One Seed per Hole
        50: selectedFlagging ?? '', // Kolom AX: Flagging
        51: selectedRecommendation ?? '', // Kolom AY: Recommendation
        52: _remarksController.text, // Kolom AZ: Remarks
      };

      // 3. Panggil fungsi baru untuk memperbarui sel-sel spesifik
      await gSheetsApi.updateSpecificCells('Vegetative', rowIndex, updates);

      // 4. Simpan ke cache lokal (Hive) dengan data terbaru
      updates.forEach((colIndex, value) {
        if ((colIndex - 1) < row.length) {
          row[colIndex - 1] = value;
        }
      });
      await _saveToHive(row);

      responseMessage = 'Data successfully saved to Audit Database';

      // 5. Kembalikan rumus (fungsi ini tetap penting)
      await _restoreVegetativeFormulas(gSheetsApi, sheet, rowIndex);

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }

    if (mounted) {
      // Navigasi tidak perlu diubah
      _navigateBasedOnResponse(context, responseMessage);
    }
  }

  Future<void> _restoreVegetativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue(
        '=IF(OR(AH$rowIndex=""; AH$rowIndex=0; NOT(ISNUMBER(AH$rowIndex)); IFERROR(YEAR(AH$rowIndex)<2024; FALSE)); "NOT Audited"; "Audited")',
        row: rowIndex, column: 56);
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

class SuccessScreen extends StatefulWidget {
  final List<String> row;
  final String userName;
  final String userEmail;
  final String region;
  final String phase; // BARU: Parameter untuk menampung nama Phase

  const SuccessScreen({
    super.key,
    required this.row,
    required this.userName,
    required this.userEmail,
    required this.region,
    required this.phase, // BARU: Wajib diisi saat dipanggil
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  bool _isSaving = false;

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
      ),
    );
  }

  Future<String> _getCurrentLocationForActivity() async {
    // ... (Fungsi ini tidak berubah, biarkan seperti adanya)
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showErrorSnackBar('Location services are disabled.');
        return 'Location Not Available';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showErrorSnackBar('Location permissions are denied.');
          return 'Location Not Available';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showErrorSnackBar('Location permissions are permanently denied.');
        return 'Location Not Available';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return '${position.latitude},${position.longitude}';
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to get location: $e');
      return 'Location Not Available';
    }
  }

  Future<void> _saveBackActivityToGoogleSheets(String region, String location) async {
    final String spreadsheetId = ConfigManager.getSpreadsheetId(region) ?? 'defaultSpreadsheetId';
    final String worksheetTitle = 'Aktivitas';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      debugPrint('Gagal: Worksheet "$worksheetTitle" tidak ditemukan.');
      _showErrorSnackBar('Worksheet "$worksheetTitle" tidak ditemukan.');
      return;
    }

    try {
      // LANGKAH 1A: Cari tahu jumlah baris saat ini untuk menentukan di mana baris baru akan berada.
      // Kita anggap kolom A selalu ada isinya untuk menghitung baris.
      final List<String> columnA = await sheet.values.column(1, fromRow: 1);
      final int nextRow = columnA.length + 1; // Baris baru akan ada di sini

      final String timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
      final String fieldNumber = widget.row[2];
      final String regions = widget.row.length > 18 ? widget.row[18] : '';
      final String action = 'Update';
      final String status = 'Success';

      // Siapkan data, tapi kolom ke-10 (kolom J) kita beri placeholder kosong.
      final List<String> rowData = [
        widget.userEmail,
        widget.userName,
        status,
        regions,
        action,
        widget.phase,
        fieldNumber,
        timestamp,
        location,
        '', // Placeholder untuk rumus
      ];

      // LANGKAH 1B: Tambahkan baris dengan data mentah (menggunakan ValueInputOption.RAW default)
      await sheet.values.appendRow(rowData);
      debugPrint('Langkah 1 Selesai: Data mentah ditambahkan di baris $nextRow.');

      // LANGKAH 2: Perbarui sel spesifik (kolom 10 atau 'J') di baris baru dengan rumus.
      if (location != 'Location Not Available' && location.contains(',')) {
        final String formula = '=HYPERLINK("http://maps.google.com/maps?q=$location"; "Linked")';

        // Perbarui hanya sel J[nextRow] dengan rumus.
        await sheet.values.insertValue(formula, column: 10, row: nextRow);
        debugPrint('Langkah 2 Selesai: Rumus disisipkan di sel J$nextRow.');
      }

    } catch (e) {
      debugPrint('Gagal dalam proses dua langkah: $e');
      _showErrorSnackBar('Gagal menyimpan aktivitas (dua langkah): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Fungsi build ini tidak berubah, biarkan seperti adanya)
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Success',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber.shade700,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.amber, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Data berhasil disimpan!',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                final navigator = Navigator.of(context);
                setState(() {
                  _isSaving = true;
                });
                final String currentLocation = await _getCurrentLocationForActivity();
                await _saveBackActivityToGoogleSheets(widget.region, currentLocation);
                if (!mounted) return;
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60),
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                'Confirm!',
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