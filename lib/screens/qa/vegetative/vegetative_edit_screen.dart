import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:flutter/services.dart';

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import '../../services/custom_numeric_keyboard.dart';

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
  late TextEditingController _sowingRatioFemaleController;
  late TextEditingController _sowingRatioMaleController;
  late TextEditingController _remarksController;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;
  late GoogleSheetsApi gSheetsApi;

  String? selectedFI;
  List<String> fiList = [];

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

  final FocusNode _fieldSizeFocusNode = FocusNode();
  final FocusNode _sowingRatioFemaleFocusNode = FocusNode();
  final FocusNode _sowingRatioMaleFocusNode = FocusNode();
  bool _isCustomKeyboardVisible = false;
  TextEditingController? _activeController;

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
    _fieldSizeController = TextEditingController(text: row[36].replaceAll('.', ','));
    _sowingRatioFemaleController = TextEditingController();
    _sowingRatioMaleController = TextEditingController();

    final initialRatio = row.length > 38 ? row[38].replaceAll("'", "") : '';
    if (initialRatio.contains(':')) {
      final parts = initialRatio.split(':');
      if (parts.length == 2) {
        _sowingRatioFemaleController.text = parts[0];
        _sowingRatioMaleController.text = parts[1];
      }
    }

    // Menambahkan listener untuk menggabungkan input secara otomatis
    _sowingRatioFemaleController.addListener(_updateSowingRatio);
    _sowingRatioMaleController.addListener(_updateSowingRatio);
    _remarksController = TextEditingController(text: row[51]);

    _loadFIList(widget.region);

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
    final initialLocation = (row.length > 16 && row[16].isNotEmpty) ? row[16] : 'No location set';
    _locationController = TextEditingController(text: initialLocation);
    _isLocationTagged = initialLocation.contains(',');

    _fieldSizeFocusNode.addListener(() {
      if (_fieldSizeFocusNode.hasFocus) {
        setState(() {
          _activeController = _fieldSizeController;
          _isCustomKeyboardVisible = true;
        });
      } else {
        // Cek jika tidak ada field lain yang fokus sebelum menyembunyikan keyboard
        if (!_sowingRatioFemaleFocusNode.hasFocus && !_sowingRatioMaleFocusNode.hasFocus) {
          setState(() {
            _isCustomKeyboardVisible = false;
          });
        }
      }
    });
    _sowingRatioFemaleFocusNode.addListener(() {
      if (_sowingRatioFemaleFocusNode.hasFocus) {
        setState(() {
          _activeController = _sowingRatioFemaleController;
          _isCustomKeyboardVisible = true;
        });
      } else {
        if (!_fieldSizeFocusNode.hasFocus && !_sowingRatioMaleFocusNode.hasFocus) {
          setState(() {
            _isCustomKeyboardVisible = false;
          });
        }
      }
    });

    // BARU: Tambahkan listener untuk Sowing Ratio Male
    _sowingRatioMaleFocusNode.addListener(() {
      if (_sowingRatioMaleFocusNode.hasFocus) {
        setState(() {
          _activeController = _sowingRatioMaleController;
          _isCustomKeyboardVisible = true;
        });
      } else {
        if (!_fieldSizeFocusNode.hasFocus && !_sowingRatioFemaleFocusNode.hasFocus) {
          setState(() {
            _isCustomKeyboardVisible = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fieldSizeFocusNode.dispose();
    _sowingRatioFemaleFocusNode.dispose();
    _sowingRatioMaleFocusNode.dispose();
    super.dispose();
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

  void _updateSowingRatio() {
    final female = _sowingRatioFemaleController.text;
    final male = _sowingRatioMaleController.text;
    setState(() {
      row[38] = "'$female:$male";
    });
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
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Ganti body dengan GestureDetector yang membungkus Stack
      body: GestureDetector(
        onTap: () {
          // Menghilangkan fokus jika mengetuk area di luar keyboard
          if (_isCustomKeyboardVisible) {
            FocusScope.of(context).unfocus();
          }
        },
        child: Stack(
          children: [
            // 1. KONTEN UTAMA ANDA (SELURUH FORM)
            Container(
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
                  // Gunakan SingleChildScrollView di sini agar form tetap bisa di-scroll
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
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          // Pindahkan Padding dan Column dari kode lama Anda ke sini
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Semua widget _build... Anda (dari _buildSectionHeader hingga tombol Simpan)
                                // diletakkan di sini.
                                // Contoh:
                                _buildSectionHeader('Field Information', Icons.info_outline),
                                _buildInfoCard(
                                  title: 'Field Number',
                                  value: row[2],
                                  icon: Icons.numbers,
                                ),
                                // ... (lanjutkan dengan semua widget lainnya hingga tombol Simpan)
                                // ...
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
                                  // Update the validator functions for all fields except QA FI and Date of Audit
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
                                      row[36] = value;
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
                                _buildSowingRatioField(),
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
                                            'When "Discard" is selected, only QA FI and Date of Audit are required. Other fields are optional.',
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

            // 2. KEYBOARD KUSTOM SEBAGAI OVERLAY
            if (_isCustomKeyboardVisible && _activeController != null) // Tambahkan cek null
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 8,
                  child: CustomNumericKeyboard(
                    // --- PERUBAHAN DI SINI ---
                    controller: _activeController!, // Gunakan controller yang aktif
                    onDone: () {
                      // Cukup hilangkan fokus dari scope utama
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSowingRatioField() {
    bool isRequired = selectedRecommendation == 'Continue';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label untuk field
        Row(
          children: [
            Icon(Icons.compare_arrows, color: Colors.green.shade800, size: 24),
            const SizedBox(width: 8),
            Text(
              isRequired ? "Sowing Ratio by Audit*" : "Sowing Ratio by Audit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Baris yang berisi dua input field dan pemisah
        Row(
          children: [
            // Input untuk Female
            Expanded(
              child: TextFormField(
                controller: _sowingRatioFemaleController,
                readOnly: true,
                focusNode: _sowingRatioFemaleFocusNode,
                showCursor: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Female',
                  labelStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                  ),
                ),
                validator: (value) {
                  if (isRequired && (value == null || value.isEmpty)) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),

            // Pemisah ":"
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(":", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),

            // Input untuk Male
            Expanded(
              child: TextFormField(
                controller: _sowingRatioMaleController,
                readOnly: true,
                focusNode: _sowingRatioMaleFocusNode,
                showCursor: true,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Male',
                  labelStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                  ),
                ),
                validator: (value) {
                  if (isRequired && (value == null || value.isEmpty)) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          "Isi rasio Female:Male (tanpa spasi)",
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      ],
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
                color: Colors.green.shade800,
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
            prefixIcon: Icon(Icons.gps_fixed, color: _isLocationTagged ? Colors.green.shade600 : Colors.red),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade200),
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          )
              : ElevatedButton.icon(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location, color: Colors.white), // Pastikan ikon putih
            label: const Text('Tag Current Location'),
            style: ElevatedButton.styleFrom(
              // MODIFIKASI: Mengubah warna tombol agar sesuai tema
              backgroundColor: Colors.green.shade700,
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
                  ? 'Only QA FI and Date of Audit are required when Recommendation is Discard'
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
        // BARU: Mengubah keyboard untuk menerima desimal dan memfilter input
        readOnly: true, // Mencegah keyboard bawaan muncul
        focusNode: _fieldSizeFocusNode, // Gunakan FocusNode yang sudah dibuat
        showCursor: true,
        // AKHIR DARI BARU
        decoration: InputDecoration(
          labelText: isRequired ? "$label *" : label,
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

  Widget _buildFIDropdownField(
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
        icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
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

  // Add this new validation method to replace the previous one
  bool _validateForm() {

    // Get the current form validation state
    bool baseFieldsValid = selectedFI != null && selectedFI!.isNotEmpty &&
        _dateAuditController.text.isNotEmpty;

    if (!baseFieldsValid) {
      _showErrorSnackBar('QA FI and Date of Audit are required fields.');
      return false;
    }

    // If recommendation is null, it's not valid
    if (selectedRecommendation == null || selectedRecommendation!.isEmpty) {
      _showErrorSnackBar('Please select a Recommendation.');
      return false;
    }
    // If recommendation is "Discard", we only need to validate QA FI and Date of Audit
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
            _sowingRatioFemaleController.text.isNotEmpty &&
            _sowingRatioMaleController.text.isNotEmpty;

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
        title: Row(
          children: [
            Icon(Icons.save_outlined, color: Colors.green.shade700),
            const SizedBox(width: 10),
            const Text('Confirm Save'),
          ],
        ),
        content: const Text('Are you sure you want to save the changes?'),
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
              phase: 'Vegetative',
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

  Future<bool> _saveToGoogleSheets(List<String> rowData) async {
    if (!mounted) return false;
    setState(() => isLoading = true);

    try {
      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Vegetative');
      if (sheet == null) {
        throw Exception('Worksheet "Vegetative" tidak ditemukan.');
      }
      final rowIndex = await _findRowByFieldNumber(sheet, rowData[2]);
      if (rowIndex == -1) {
        throw Exception('Data dengan Field Number ${rowData[2]} tidak ditemukan.');
      }

      final Map<int, String> updates = {
        18: _locationController.text,
        32: selectedFI ?? '',
        33: _coDetasselingController.text,
        34: _dateAuditController.text,
        36: _actualPlantingDateController.text,
        37: _fieldSizeController.text.replaceAll(',', '.'),
        38: selectedMaleSplit ?? '',
        39: row[38],
        40: selectedSplitField ?? '',
        41: selectedIsolationProblem ?? '',
        42: selectedContaminantType ?? '',
        43: selectedContaminantDistance ?? '',
        44: selectedCropUniformity ?? '',
        45: selectedOfftypeInMale ?? '',
        46: selectedOfftypeInFemale ?? '',
        47: selectedPreviousCrop ?? '',
        48: selectedFIRApplied ?? '',
        50: selectedFlagging ?? '',
        51: selectedRecommendation ?? '',
        52: _remarksController.text,
      };

      await gSheetsApi.updateSpecificCells('Vegetative', rowIndex, updates);

      updates.forEach((colIndex, value) {
        if ((colIndex - 1) < row.length) {
          row[colIndex - 1] = value;
        }
      });
      await _saveToHive(row);
      await _logActivityAfterSave(); // Panggil fungsi logging baru
      await _restoreVegetativeFormulas(gSheetsApi, sheet, rowIndex);

      return true; // Kembalikan true jika sukses

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      return false; // Kembalikan false jika gagal
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
        'Vegetative', // Phase
        fieldNumber,
        timestamp,
      ];

      await sheet.values.appendRow(rowData, fromColumn: 1);
    } catch (e) {
      debugPrint("Gagal mencatat aktivitas: $e");
      _logErrorToActivity("Gagal mencatat aktivitas: $e");
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