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

class HarvestEditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave;

  const HarvestEditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave});

  @override
  HarvestEditScreenState createState() => HarvestEditScreenState();
}

class HarvestEditScreenState extends State<HarvestEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;

  String? selectedFA;
  List<String> faList = [];

  String? selectedEarConditionObservation;
  String? selectedCropUniformity;
  String? selectedCropHealth;
  String? selectedRecommendation;
  String? selectedReasonToDowngradeFlagging;
  String? selectedDowngradeFlaggingRecommendation;

  final List<String> earConditionObservationItems = ['2', '3', '4'];
  final List<String> cropUniformityItems = ['1', '2', '3', '4', '5'];
  final List<String> cropHealthItems = ['1', '2', '3', '4', '5'];
  final List<String> recommendationItems = ['Continue', 'Discard'];
  final List<String> reasonToDowngradeFlaggingItems = ['A', 'B', 'C', 'D'];
  final List<String> downgradeFlaggingRecommendationItems = ['RFI', 'RFD'];

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

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    _loadFAList(widget.region);

    selectedEarConditionObservation = row[32];
    selectedCropHealth = row[34];
    selectedRecommendation = row[36];
    selectedReasonToDowngradeFlagging = row[38];
    selectedDowngradeFlaggingRecommendation = row[39];
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
    await Hive.openBox('harvestData');
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('harvestData');
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
            'Edit Harvest Field',
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
                            backgroundColor: Colors.amber,
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
                        const SizedBox(height: 10),
                        _buildSectionHeader('Tag Location'),
                        _buildLocationField(), // Memanggil widget baru
                        const SizedBox(height: 10),

                        const SizedBox(height: 20),
                        _buildRequiredFieldsNotice(),

                        // Audit Information Section
                        _buildSectionHeader('Audit Information'),
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
                        _buildDatePickerField('Date of Audit (dd/MM)', 30, _dateAuditController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a date';
                              }
                              return null;
                            }),
                        const SizedBox(height: 10),

                        // Ear Condition Section
                        _buildSectionHeader('Ear Condition Assessment'),
                        _buildDropdownFormField(
                          label: 'Ear Condition Observation',
                          items: earConditionObservationItems,
                          value: selectedEarConditionObservation,
                          onChanged: (value) {
                            setState(() {
                              selectedEarConditionObservation = value;
                              row[32] = value ?? '';
                            });
                          },
                          helpText: 'Stage 2 : 2\nStage 3 : 3\nStage 4 : 4',
                          icon: Icons.agriculture,
                        ),
                        const SizedBox(height: 10),
                        // Crop Health Section
                        _buildSectionHeader('Crop Performance'),
                        _buildDropdownFormField(
                          label: 'Crop Uniformity',
                          items: cropUniformityItems,
                          value: selectedCropUniformity,
                          onChanged: (value) {
                            setState(() {
                              selectedCropUniformity = value;
                              row[33] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.grass,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Crop Health',
                          items: cropHealthItems,
                          value: selectedCropHealth,
                          onChanged: (value) {
                            setState(() {
                              selectedCropHealth = value;
                              row[34] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.health_and_safety,
                        ),
                        const SizedBox(height: 10),
                        _buildTextFormField(
                          'Remarks',
                          35,
                          icon: Icons.comment,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Recommendation',
                          items: recommendationItems,
                          value: selectedRecommendation,
                          onChanged: (value) {
                            setState(() {
                              selectedRecommendation = value;
                              row[36] = value ?? '';
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
                                    'When "Discard" is selected, only HSP FA and Date of Audit are required. Other fields are optional.',
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

                        // Downgrade Flagging Section
                        _buildSectionHeader('Downgrade Flagging'),
                        _buildTextFormField(
                          'Date of Downgrade Flagging',
                          37,
                          icon: Icons.calendar_today,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormFieldDowngrade(
                          label: 'Reason to Downgrade Flagging',
                          items: reasonToDowngradeFlaggingItems,
                          value: selectedReasonToDowngradeFlagging,
                          onChanged: (value) {
                            setState(() {
                              selectedReasonToDowngradeFlagging = value;
                              row[38] = value ?? '';
                            });
                          },
                          helpText: 'A = Suspect Mix Material\nB = Not Accessable during Detasseling\nC = Not Sure during Harvest\nD = Other (please mention in remarks)',
                          icon: Icons.flag,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormFieldDowngrade(
                          label: 'Downgrade Flagging Recommendation',
                          items: downgradeFlaggingRecommendationItems,
                          value: selectedDowngradeFlaggingRecommendation,
                          onChanged: (value) {
                            setState(() {
                              selectedDowngradeFlaggingRecommendation = value;
                              row[39] = value ?? '';
                            });
                          },
                          helpText: 'RFI / RFD',
                          icon: Icons.assignment_turned_in,
                        ),
                        const SizedBox(height: 30),

                        // Save Button
                        // Update the save button in the build method
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

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.amber.shade800,
          ),
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
                  ? 'Only HSP FA and Date of Audit are required when Recommendation is Discard'
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

  Widget _buildTextFormField(
      String label,
      int index, {
        IconData? icon,
        String? Function(String?)? validator,
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
        initialValue: row[index].isNotEmpty ? row[index].replaceAll("'", "") : "",
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: "$label *", // Add asterisk to indicate required field
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
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            String cleanedValue = value.replaceAll("'", "");
            row[index] = "'$cleanedValue";
          });
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
        value: value,
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

  Widget _buildDatePickerField(String label, int index, TextEditingController controller, {String? Function(String?)? validator}) {
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
              labelText: isRequired ? "$label *" : label, // Add asterisk only if required
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
            value: value,
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

  Widget _buildDropdownFormFieldDowngrade({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    String? hint,
    String? helpText,
    IconData? icon,
  }) {
    bool isRequired = selectedRecommendation == 'Discard';

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
              labelText: isRequired ? "$label *" : label, // Add asterisk only if required
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
            value: value,
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
                  phase: 'Harvest',
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

    // Panggil GoogleSheetsApi dari instance yang sudah ada
    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    String responseMessage;
    try {
      // 1. Cari tahu di baris mana data akan diperbarui
      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Harvest');
      if (sheet == null) {
        throw Exception('Worksheet "Harvest" tidak ditemukan.');
      }
      final rowIndex = await _findRowByFieldNumber(sheet, rowData[2]);
      if (rowIndex == -1) {
        throw Exception('Data dengan Field Number ${rowData[2]} tidak ditemukan.');
      }

      // 2. Siapkan Map berisi data yang akan diupdate [columnIndex: value]
      // Indeks kolom di gsheets dimulai dari 1, BUKAN 0
      final Map<int, String> updates = {
        18: _locationController.text, // Kolom R: Koordinat
        15: selectedFA ?? '', // Kolom AD: HSP FA
        31: _dateAuditController.text, // Kolom AE: Date of Audit
        33: selectedEarConditionObservation ?? '', // Kolom AG: Ear Condition
        34: selectedCropUniformity ?? '', // Kolom AH: Crop Uniformity
        35: selectedCropHealth ?? '', // Kolom AI: Crop Health
        36: row[35], // Kolom AJ: Remarks (dari _buildTextFormField)
        37: selectedRecommendation ?? '', // Kolom AK: Recommendation
        38: row[37], // Kolom AL: Date of Downgrade Flagging (dari _buildTextFormField)
        39: selectedReasonToDowngradeFlagging ?? '', // Kolom AM: Reason to Downgrade
        40: selectedDowngradeFlaggingRecommendation ?? '', // Kolom AN: Downgrade Recommendation
      };

      // 3. Panggil fungsi baru untuk memperbarui sel-sel spesifik
      await gSheetsApi.updateSpecificCells('Harvest', rowIndex, updates);

      // 4. Simpan ke cache lokal (Hive) dengan data terbaru
      updates.forEach((colIndex, value) {
        if ((colIndex - 1) < row.length) {
          row[colIndex - 1] = value;
        }
      });
      await _saveToHive(row);

      responseMessage = 'Data successfully saved to Audit Database';

      // 5. Kembalikan rumus
      await _restoreHarvestFormulas(gSheetsApi, sheet, rowIndex);

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data Harvest: ${e.toString()}');
      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }

    if (mounted) {
      _navigateBasedOnResponse(context, responseMessage);
    }
  }

  Future<void> _restoreHarvestFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue(
        '=IF(OR(AE$rowIndex=""; AE$rowIndex=0; NOT(ISNUMBER(AE$rowIndex)); IFERROR(YEAR(AE$rowIndex)<2024; FALSE)); "NOT Audited"; "Audited")',
        row: rowIndex, column: 44);
    debugPrint("Rumus berhasil diterapkan di Harvest pada baris $rowIndex.");
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

  Future<void> _showConfirmationDialog() async {
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.save_outlined, color: Colors.amber.shade700),
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

  bool _isDataValid() {

    // Check if HSP FA and Date of Audit are filled (always required)
    bool basicFieldsValid = selectedFA != null && selectedFA!.isNotEmpty &&
        _dateAuditController.text.isNotEmpty;

    if (!basicFieldsValid) {
      _showErrorSnackBar('HSP FA and Date of Audit are required fields.');
      return false;
    }

    // If recommendation is null, it's not valid
    if (selectedRecommendation == null || selectedRecommendation!.isEmpty) {
      _showErrorSnackBar('Please select a Recommendation.');
      return false;
    }

    // If recommendation is "Discard", only base fields are required
    if (selectedRecommendation == 'Discard') {
      return true; // Base fields are already validated
    }

    // If recommendation is "Continue", additional fields are required
    bool additionalFieldsValid =
        selectedEarConditionObservation != null && selectedEarConditionObservation!.isNotEmpty &&
            selectedCropUniformity != null && selectedCropUniformity!.isNotEmpty &&
            selectedCropHealth != null && selectedCropHealth!.isNotEmpty &&
            row[35].isNotEmpty; // Crop Health Remarks

    if (!additionalFieldsValid) {
      _showErrorSnackBar('When Recommendation is Continue, all assessment fields are required.');
      return false;
    }

    return true;
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
            phase: 'Harvest',
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
      _showErrorSnackBar('Unknown response: $response');
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
      // Handle error
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