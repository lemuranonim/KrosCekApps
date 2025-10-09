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

class Generative1EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave;

  const Generative1EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave,
  });

  @override
  Generative1EditScreenState createState() => Generative1EditScreenState();
}

class Generative1EditScreenState extends State<Generative1EditScreen> {
  late List<String> row;
  late GoogleSheetsApi gSheetsApi;
  final _formKey = GlobalKey<FormState>();

  String? selectedRecommendation;
  String? selectedFlagging;
  late TextEditingController _dateAudit1Controller;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;

  String? selectedFA;
  List<String> faList = [];

  String? selectedDetaselingPlan;
  String? selectedTenagaKerjaDT;
  String? selectedRoguingProses;
  String? selectedRemarksRoguingProses;
  String? selectedTenagaKerjaDetasseling;
  String? selectedCropUniformitySatu;

  final List<String> detaselingPlanItems = ['Y', 'N'];
  final List<String> tenagaKerjaDTItems = ['A', 'B', 'C', 'D', 'E'];
  final List<String> roguingProsesItems = ['Y', 'N'];
  final List<String> remarksRoguingProsesItems = ['A', 'B', 'C', 'D', 'E'];
  final List<String> tenagaKerjaDetasselingItems = ['A', 'B'];
  final List<String> cropUniformitySatuItems = ['1', '2', '3', '4', '5'];

  bool isLoading = false;

  bool get areAllAuditFieldsGloballyRequired {
    String flaggingAudit3 = (row.length > 63) ? row[63] : '';
    String recommendationAudit3 = (row.length > 65) ? row[65] : '';

    return recommendationAudit3 != 'Discard' && flaggingAudit3 != 'Discard';
  }

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

    _dateAudit1Controller = TextEditingController(text: _convertToDateIfNecessary(row[32]));

    _loadFAList(widget.region);

    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    gSheetsApi.init();

    selectedDetaselingPlan = row[35];
    selectedTenagaKerjaDT = row[36];
    selectedRoguingProses = row[37];
    selectedRemarksRoguingProses = row[38];
    selectedTenagaKerjaDetasseling = row[39];
    selectedCropUniformitySatu = row[40];
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
            'Field Audit 1 Edit',
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
                        _buildDatePickerField('Date of Audit 1 (dd/MM)', 32, _dateAudit1Controller),
                        const SizedBox(height: 10),

                        // Detasseling Section
                        _buildSectionHeader('Detasseling Assessment', Icons.agriculture),
                        _buildDropdownFormField(
                          label: 'Detaseling Plan (Mengacu Form)',
                          items: detaselingPlanItems,
                          value: selectedDetaselingPlan,
                          onChanged: (value) {
                            setState(() {
                              selectedDetaselingPlan = value;
                              row[35] = value ?? '';
                            });
                          },
                          helpText: 'Y = Yes\nN = No',
                          icon: Icons.assignment_turned_in,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Ketersediaan Tenaga kerja DT yang Cukup /Ha',
                          items: tenagaKerjaDTItems,
                          value: selectedTenagaKerjaDT,
                          onChanged: (value) {
                            setState(() {
                              selectedTenagaKerjaDT = value;
                              row[36] = value ?? '';
                            });
                          },
                          helpText: 'A = 100% 15 req- terpenuhi 15 TKD'
                              '\nB = 80% 15 req- terpenuhi 12 TKD'
                              '\nC = 60% 15 req-terpenuhi 9 TKD'
                              '\nD = 40% 15 req - terpenuhi 6 TKD'
                              '\nE = 20% 15 req - terpenuhi 3 TKD',
                          icon: Icons.people,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),

                        _buildSectionHeader('Roguing Process', Icons.grass),
                        _buildDropdownFormField(
                          label: 'Roguing Proses',
                          items: roguingProsesItems,
                          value: selectedRoguingProses,
                          onChanged: (value) {
                            setState(() {
                              selectedRoguingProses = value;
                              row[37] = value ?? '';
                            });
                          },
                          helpText: 'Y = Yes\nN = No',
                          icon: Icons.check_circle_outline,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Remarks Roguing Proses',
                          items: remarksRoguingProsesItems,
                          value: selectedRemarksRoguingProses,
                          onChanged: (value) {
                            setState(() {
                              selectedRemarksRoguingProses = value;
                              row[38] = value ?? '';
                            });
                          },
                          helpText: 'A = CVL\nB = Offtype\nC = LSV\nD = Male Salah Baris\nE = All',
                          icon: Icons.comment,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),

                        _buildSectionHeader('Workforce Effectiveness', Icons.engineering),
                        _buildDropdownFormField(
                          label: 'Tenaga Kerja Detasseling Process',
                          items: tenagaKerjaDetasselingItems,
                          value: selectedTenagaKerjaDetasseling,
                          onChanged: (value) {
                            setState(() {
                              selectedTenagaKerjaDetasseling = value;
                              row[39] = value ?? '';
                            });
                          },
                          helpText: 'A = Effective\nB = Tidak Effective',
                          icon: Icons.rate_review,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildSectionHeader('Crop Performance', Icons.eco),
                        _buildDropdownFormField(
                          label: 'Crop Uniformity (Gen.1)',
                          items: cropUniformitySatuItems,
                          value: selectedCropUniformitySatu,
                          onChanged: (value) {
                            setState(() {
                              selectedCropUniformitySatu = value;
                              row[40] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.bar_chart,
                          required: areAllAuditFieldsGloballyRequired,
                        ),

                        const SizedBox(height: 30),
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

  Widget _buildDatePickerField(String label, int index, TextEditingController controller, {bool defaultRequired = true}) {
    bool required = areAllAuditFieldsGloballyRequired || defaultRequired;
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
                  phase: 'Generative - Audit 1',
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
      // 1. Dapatkan instance gSheetsApi yang sudah diinisialisasi
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init(); // Pastikan inisialisasi selesai

      // 2. Cari tahu di baris mana data akan diperbarui
      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Generative');
      if (sheet == null) {
        throw Exception('Worksheet "Generative" tidak ditemukan.');
      }
      final rowIndex = await _findRowByFieldNumber(sheet, rowData[2]);
      if (rowIndex == -1) {
        throw Exception('Data dengan Field Number ${rowData[2]} tidak ditemukan.');
      }

      // 3. Siapkan Map berisi data yang akan diupdate [columnIndex: value]
      // Indeks kolom di gsheets dimulai dari 1 (A=1, B=2, dst.)
      final Map<int, String> updates = {
        18: _locationController.text, // Kolom R: Koordinat
        15: selectedFA ?? '', // Kolom AF: QA FA
        33: _dateAudit1Controller.text, // Kolom AG: Date of Audit 1
        36: selectedDetaselingPlan ?? '', // Kolom AJ: Detaseling Plan
        37: selectedTenagaKerjaDT ?? '', // Kolom AK: Ketersediaan Tenaga kerja DT
        38: selectedRoguingProses ?? '', // Kolom AL: Roguing Proses
        39: selectedRemarksRoguingProses ?? '', // Kolom AM: Remarks Roguing Proses
        40: selectedTenagaKerjaDetasseling ?? '', // Kolom AN: Tenaga Kerja Detasseling Process
        41: selectedCropUniformitySatu ?? '', // Kolom AO: Crop Uniformity (Gen.1)
      };

      // 4. Panggil fungsi baru untuk memperbarui sel-sel spesifik
      await gSheetsApi.updateSpecificCells('Generative', rowIndex, updates);

      // 5. Simpan ke cache lokal (Hive) dengan data terbaru
      updates.forEach((colIndex, value) {
        if ((colIndex - 1) < row.length) {
          row[colIndex - 1] = value;
        }
      });
      await _saveToHive(row);

      responseMessage = 'Data successfully saved to Audit Database';

      // 6. Kembalikan rumus
      await _restoreGenerativeFormulas(gSheetsApi, sheet, rowIndex);

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data Generative-1: ${e.toString()}');
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

  Future<void> _restoreGenerativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Check Result
        '=IF(OR(BL$rowIndex=0;BL$rowIndex="");"Not Audited";"Audited")',
        row: rowIndex, column: 73);
    await sheet.values.insertValue( // Check Progress
        '=IF(OR(AG$rowIndex=""; AG$rowIndex=0; NOT(ISNUMBER(AG$rowIndex)); IFERROR(YEAR(AG$rowIndex)<2024; FALSE); AP$rowIndex=""; AP$rowIndex=0; NOT(ISNUMBER(AP$rowIndex)); IFERROR(YEAR(AP$rowIndex)<2024; FALSE)); "Not Audited"; "Audited")',
        row: rowIndex, column: 74);
    debugPrint("Rumus berhasil diterapkan di Generative pada baris $rowIndex.");
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

    if (areAllAuditFieldsGloballyRequired) {
      // Semua field di Generative1EditScreen menjadi wajib
      return selectedFA != null && selectedFA!.isNotEmpty &&
          _dateAudit1Controller.text.isNotEmpty &&
          selectedDetaselingPlan != null && selectedDetaselingPlan!.isNotEmpty &&
          selectedTenagaKerjaDT != null && selectedTenagaKerjaDT!.isNotEmpty &&
          selectedRoguingProses != null && selectedRoguingProses!.isNotEmpty &&
          selectedRemarksRoguingProses != null && selectedRemarksRoguingProses!.isNotEmpty &&
          selectedTenagaKerjaDetasseling != null && selectedTenagaKerjaDetasseling!.isNotEmpty &&
          selectedCropUniformitySatu != null && selectedCropUniformitySatu!.isNotEmpty;
    } else {
      // Jika kondisi global Audit 3 tidak membuat semua field wajib,
      // maka hanya field yang memang wajib secara individual di Audit 1 yang divalidasi.
      // Dari kode asli, jika `selectedFlagging` (tidak terdefinisi di sini, kita asumsikan merujuk pada flagging Audit 3) adalah 'Discard',
      // maka hanya tanggal audit yang wajib.
      String flaggingAudit3 = (row.length > 63) ? row[63] : '';
      if (flaggingAudit3 == 'Discard') {
        // Hanya QA FI dan tanggal audit 1 yang wajib jika flagging AU3 adalah discard
        if (selectedFA == null || selectedFA!.isEmpty) {
          _showErrorSnackBar('QA FI is required.');
          return false;
        }
        if (_dateAudit1Controller.text.isEmpty) {
          _showErrorSnackBar('Date of Audit 1 is required.');
          return false;
        }
        return true; // Field lain opsional
      }

      // Validasi standar jika flagging AU3 bukan discard (tapi recommendation AU3 mungkin discard)
      // Dalam kasus ini, semua field di AU1 tetap wajib seperti semula.
      // Ini karena permintaan Anda berfokus pada "selain discard" untuk *kedua* kondisi di AU3 agar *semuanya* jadi wajib.
      // Jika hanya salah satu yang discard di AU3, maka validasi standar AU1 berlaku.
      return selectedFA != null && selectedFA!.isNotEmpty &&
          _dateAudit1Controller.text.isNotEmpty &&
          selectedDetaselingPlan != null && selectedDetaselingPlan!.isNotEmpty &&
          selectedTenagaKerjaDT != null && selectedTenagaKerjaDT!.isNotEmpty &&
          selectedRoguingProses != null && selectedRoguingProses!.isNotEmpty &&
          selectedRemarksRoguingProses != null && selectedRemarksRoguingProses!.isNotEmpty &&
          selectedTenagaKerjaDetasseling != null && selectedTenagaKerjaDetasseling!.isNotEmpty &&
          selectedCropUniformitySatu != null && selectedCropUniformitySatu!.isNotEmpty;
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
            phase: 'Generative - Audit 1',
          ),
        ),
      );
    } else if (response == 'Failed to save data. Please try again.') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FailedScreen(), // Buat halaman FailedScreen untuk tampilan gagal
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
      // debugPrint("Error converting number to date: $e"); // Mengganti print dengan debugPrint
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

  // Alternatif 1: Menggunakan Proses Dua Langkah
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
                backgroundColor: Colors.red. shade700, // Warna background tombol
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