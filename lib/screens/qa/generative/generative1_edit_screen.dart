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

  String? selectedFI;
  List<String> fiList = [];

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
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAudit1Controller = TextEditingController(text: _convertToDateIfNecessary(row[32]));

    _loadFIList(widget.region);

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
  }

  Future<void> _loadFIList(String region) async {
    setState(() {
      isLoading = true;
    });

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
      setState(() {
        isLoading = false;
      });
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

  Widget _buildFIDropdownField(String label, String? value, List<String> items, Function(String?) onChanged, {bool defaultRequired = true}) {
    bool required = areAllAuditFieldsGloballyRequired || defaultRequired; // defaultRequired adalah true jika field selalu wajib kecuali kondisi global berlaku
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
          labelText: required ? "$label *" : label, // Add asterisk to indicate required field
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
        validator: (val) {
          if (required && (val == null || val.isEmpty)) {
          return '$label is required';
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

              String flaggingAudit3 = (row.length > 63) ? row[63] : '';
              String recommendationAudit3 = (row.length > 65) ? row[65] : '';

              if (flaggingAudit3 == 'Discard' && recommendationAudit3 == 'Discard') {
                if (row.length > 41) {
                  row[41] = formattedDate;
                  debugPrint('Date of Audit 2 (row[41]) secara otomatis diatur ke: $formattedDate');
                }
              }
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

  Future<bool> _saveToGoogleSheets(List<String> rowData) async {
    if (!mounted) return false;
    setState(() => isLoading = true);

    try {
      // 2. Cari tahu di baris mana data akan diperbarui
      final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Generative');
      if (sheet == null) {
        throw Exception('Worksheet "Generative" tidak ditemukan.');
      }
      final rowIndex = await _findRowByFieldNumber(sheet, rowData[2]);
      if (rowIndex == -1) {
        throw Exception('Data dengan Field Number ${rowData[2]} tidak ditemukan.');
      }

      final Map<int, String> updates = {
        18: _locationController.text, // Kolom R: Koordinat
        32: selectedFI ?? '', // Kolom AF: QA FI
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
      await _logActivityAfterSave();
      // 6. Kembalikan rumus
      await _restoreGenerativeFormulas(gSheetsApi, sheet, rowIndex);

      return true;

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data Generative-1: ${e.toString()}');
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
        'Generative - Audit 1', // Phase
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
              phase: 'Generative - Audit 1',
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
    if (areAllAuditFieldsGloballyRequired) {
      // Semua field di Generative1EditScreen menjadi wajib
      return selectedFI != null && selectedFI!.isNotEmpty &&
          _dateAudit1Controller.text.isNotEmpty &&
          selectedDetaselingPlan != null && selectedDetaselingPlan!.isNotEmpty &&
          selectedTenagaKerjaDT != null && selectedTenagaKerjaDT!.isNotEmpty &&
          selectedRoguingProses != null && selectedRoguingProses!.isNotEmpty &&
          selectedRemarksRoguingProses != null && selectedRemarksRoguingProses!.isNotEmpty &&
          selectedTenagaKerjaDetasseling != null && selectedTenagaKerjaDetasseling!.isNotEmpty &&
          selectedCropUniformitySatu != null && selectedCropUniformitySatu!.isNotEmpty;
    } else {
      String flaggingAudit3 = (row.length > 63) ? row[63] : '';
      String recommendationAudit3 = (row.length > 65) ? row[65] : '';
      bool isSpecialDiscardCondition = flaggingAudit3 == 'Discard' && recommendationAudit3 == 'Discard';
      if (isSpecialDiscardCondition) {
        // Sesuai permintaan: Hanya 'QA FI' dan 'Date of Audit 1' yang wajib
        if (selectedFI == null || selectedFI!.isEmpty) {
          _showErrorSnackBar('QA FI is required.');
          return false;
        }
        if (_dateAudit1Controller.text.isEmpty) {
          _showErrorSnackBar('Date of Audit 1 is required.');
          return false;
        }
        return true; // Data valid, field lain boleh kosong
      }

      return selectedFI != null && selectedFI!.isNotEmpty &&
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