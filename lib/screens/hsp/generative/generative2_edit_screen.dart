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

class Generative2EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave;

  const Generative2EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave});

  @override
  Generative2EditScreenState createState() => Generative2EditScreenState();
}

class Generative2EditScreenState extends State<Generative2EditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  String? selectedRecommendation;
  String? selectedFlagging;
  late TextEditingController _dateAudit2Controller;

  String userEmail = 'Fetching...';
  String userName = 'Fetching...';
  late String spreadsheetId;

  String? selectedFemaleShed1;
  String? selectedSheddingMale1;
  String? selectedSheddingFemale1;
  String? selectedCropUniformityDua;

  final List<String> femaleShed1Items = ['A', 'B', 'C', 'D'];
  final List<String> sheddingMale1Items = ['A', 'B'];
  final List<String> sheddingFemale1Items = ['A', 'B'];
  final List<String> cropUniformityDuaItems = ['1', '2', '3', '4', '5'];

  bool isLoading = false;

  bool get areAllAuditFieldsGloballyRequired {
    String flaggingAudit3 = (row.length > 63) ? row[63] : '';
    String recommendationAudit3 = (row.length > 65) ? row[65] : '';
    return recommendationAudit3 != 'Discard' && flaggingAudit3 != 'Discard';
  }

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAudit2Controller = TextEditingController(text: _convertToDateIfNecessary(row[40]));

    selectedFemaleShed1 = row[43];
    selectedSheddingMale1 = row[44];
    selectedSheddingFemale1 = row[45];
    selectedCropUniformityDua = row[46];
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
            'Field Audit 2 Edit',
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

                        const SizedBox(height: 20),
                        _buildRequiredFieldsNotice(),

                        // Audit Information Section
                        _buildSectionHeader('Audit 2 Information'),
                        _buildDatePickerField('Date of Audit 2 (dd/MM)', 41, _dateAudit2Controller),
                        const SizedBox(height: 10),

                        // Female Shedding Section
                        _buildSectionHeader('Female Shedding Assessment'),
                        _buildDropdownFormField(
                          label: 'Female Shedding',
                          items: femaleShed1Items,
                          value: selectedFemaleShed1,
                          onChanged: (value) {
                            setState(() {
                              selectedFemaleShed1 = value;
                              row[43] = value ?? '';
                            });
                          },
                          helpText: 'A (GF) = 0-5 shedd / Ha\nB (RF) = 6-30 shedd / Ha\nC (BF) = >30 shedd / Ha',
                          icon: Icons.spa,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),

                        // Shedding Offtype Section
                        _buildSectionHeader('Shedding Offtype Assessment'),
                        _buildDropdownFormField(
                          label: 'Shedding Offtype & CVL Male',
                          items: sheddingMale1Items,
                          value: selectedSheddingMale1,
                          onChanged: (value) {
                            setState(() {
                              selectedSheddingMale1 = value;
                              row[44] = value ?? '';
                            });
                          },
                          helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                          icon: Icons.male,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Shedding Offtype & CVL Female',
                          items: sheddingFemale1Items,
                          value: selectedSheddingFemale1,
                          onChanged: (value) {
                            setState(() {
                              selectedSheddingFemale1 = value;
                              row[45] = value ?? '';
                            });
                          },
                          helpText: 'A = 0-5 plants / Ha\nB = > 5 plants / Ha',
                          icon: Icons.female,
                          required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 10),
                        // Crop Uniformity Section
                        _buildSectionHeader('Crop Performance'),
                        _buildDropdownFormField(
                          label: 'Crop Uniformity (Gen.2)',
                          items: cropUniformityDuaItems,
                          value: selectedCropUniformityDua,
                          onChanged: (value) {
                            setState(() {
                              selectedCropUniformityDua = value;
                              row[46] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.crop,
                            required: areAllAuditFieldsGloballyRequired,
                        ),
                        const SizedBox(height: 30),

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
            value: value,
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
                  phase: 'Generative - Audit 2',
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

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    String responseMessage;
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
        42: _dateAudit2Controller.text, // Kolom AP: Date of Audit 2
        44: selectedFemaleShed1 ?? '', // Kolom AR: Female Shedding
        45: selectedSheddingMale1 ?? '', // Kolom AS: Shedding Offtype & CVL Male
        46: selectedSheddingFemale1 ?? '', // Kolom AT: Shedding Offtype & CVL Female
        47: selectedCropUniformityDua ?? '', // Kolom AU: Crop Uniformity (Gen.2)
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

      responseMessage = 'Data successfully saved to Audit Database';

      // 5. Kembalikan rumus
      await _restoreGenerativeFormulas(gSheetsApi, sheet, rowIndex);

    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data Generative-2: ${e.toString()}');
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
    // Pastikan _dateAudit2Controller diinisialisasi dengan benar dan merujuk ke row[41] jika itu yang diedit.
    // Saat ini di initState: _dateAudit2Controller = TextEditingController(text: _convertToDateIfNecessary(row[40]));
    // Tapi di build: _buildDatePickerField('Date of Audit 2 (dd/MM)', 41, _dateAudit2Controller),
    // Ini berarti nilai yang divalidasi adalah `_dateAudit2Controller.text` yang akan diisi oleh tanggal dari `row[41]`.

    if (areAllAuditFieldsGloballyRequired) {
      // Semua field di Generative2EditScreen menjadi wajib
      return _dateAudit2Controller.text.isNotEmpty &&
          selectedFemaleShed1 != null && selectedFemaleShed1!.isNotEmpty &&
          selectedSheddingMale1 != null && selectedSheddingMale1!.isNotEmpty &&
          selectedSheddingFemale1 != null && selectedSheddingFemale1!.isNotEmpty &&
          selectedCropUniformityDua != null && selectedCropUniformityDua!.isNotEmpty;
    } else {
      String flaggingAudit3 = (row.length > 63) ? row[63] : '';
      if (flaggingAudit3 == 'Discard') {
        // Hanya tanggal audit 2 yang wajib jika flagging AU3 adalah discard
        if (_dateAudit2Controller.text.isEmpty) {
          _showErrorSnackBar('Date of Audit 2 is required.');
          return false;
        }
        return true; // Field lain opsional
      }

      // Validasi standar jika flagging AU3 bukan discard
      return _dateAudit2Controller.text.isNotEmpty &&
          selectedFemaleShed1 != null && selectedFemaleShed1!.isNotEmpty &&
          selectedSheddingMale1 != null && selectedSheddingMale1!.isNotEmpty &&
          selectedSheddingFemale1 != null && selectedSheddingFemale1!.isNotEmpty &&
          selectedCropUniformityDua != null && selectedCropUniformityDua!.isNotEmpty;
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

  void _navigateBasedOnResponse(BuildContext context, String response) {
    if (response == 'Data successfully saved to Audit Database') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SuccessScreen(
            row: row,
            userName: userName,
            userEmail: userEmail,
            region: widget.region,
            phase: 'Generative - Audit 2',
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
                minimumSize: const Size(200, 60),
                backgroundColor: Colors.red. shade700,
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