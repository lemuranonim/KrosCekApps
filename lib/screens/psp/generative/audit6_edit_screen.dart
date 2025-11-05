import 'dart:async'; // Untuk menggunakan Timer

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences untuk userName

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class Audit6EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave; // Callback untuk mengirim data yang diperbarui

  const Audit6EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave,
  });

  @override
  Audit6EditScreenState createState() => Audit6EditScreenState();
}

class Audit6EditScreenState extends State<Audit6EditScreen> {
  late List<String> row;
  late GoogleSheetsApi gSheetsApi;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...'; // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedLSV;
  String? selectedCropHealth;
  String? selectedCropUniformity;
  String? selectedIsolationAudit6;
  String? selectedIsolationType;
  String? selectedIsolationDistance;
  String? selectedNickingObservation;
  String? selectedFlagging;
  String? selectedRecommendation;

  final List<String> lsvItems = ['YES', 'NO'];
  final List<String> cropHealthItems = ['1', '2', '3', '4', '5'];
  final List<String> cropUniformityItems = ['1', '2', '3', '4', '5'];
  final List<String> isolationAudit6Items = ['A', 'B'];
  final List<String> isolationTypeItems = ['A', 'B'];
  final List<String> isolationDistanceItems = ['A', 'B'];
  final List<String> nickingObservationItems = ['YES', 'NO'];
  final List<String> flaggingItems = ['GF', 'OF', 'RF', 'Discard'];
  final List<String> recommendationItems = ['Continue to Next Process', 'Discard'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[46]));

    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    gSheetsApi.init();

    // Initialize dropdown fields, set to null if empty
    selectedLSV = row[52].isNotEmpty ? row[52] : null;
    selectedCropHealth = row[53].isNotEmpty ? row[53] : null;
    selectedCropUniformity = row[54].isNotEmpty ? row[54] : null;
    selectedIsolationAudit6 = row[55].isNotEmpty ? row[55] : null;
    selectedIsolationType = row[56].isNotEmpty ? row[56] : null;
    selectedIsolationDistance = row[57].isNotEmpty ? row[57] : null;
    selectedNickingObservation = row[58].isNotEmpty ? row[58] : null;
    selectedFlagging = row[59].isNotEmpty ? row[59] : null;
    selectedRecommendation = row[60].isNotEmpty ? row[60] : null;
  }

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('pspGenerativeData');
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('pspGenerativeData');
    final cacheKey = 'detailScreenData_${rowData[2]}'; // Menggunakan fieldNumber atau ID unik lainnya sebagai kunci
    await box.put(cacheKey, rowData); // Simpan hanya rowData ke Hive
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
            'Edit Audit 6',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            )
        ),
        backgroundColor: Colors.redAccent.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.redAccent.shade700, Colors.redAccent.shade100],
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
                            backgroundColor: Colors.redAccent,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        const SizedBox(height: 10),

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
                        _buildInfoCard(
                          title: 'FI',
                          value: row[26],
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionHeader('Audit Information', Icons.assignment),
                        _buildDatePickerField('Date of Audit 6', 46, _dateAuditController),
                        const SizedBox(height: 10),
                        _buildTextFormField('Standing crop Offtype', 48, icon: Icons.warning_rounded),
                        const SizedBox(height: 10),
                        _buildTextFormField('Standing crop Volunteer', 49, icon: Icons.forest_rounded),
                        const SizedBox(height: 10),
                        _buildTextFormField('Offtype Sheed', 50, icon: Icons.grass_rounded),
                        const SizedBox(height: 10),
                        _buildTextFormField('Volunteer Seed', 51, icon: Icons.auto_awesome_rounded),
                        const SizedBox(height: 10),

                        _buildDropdownFormField(
                          label: 'LSV',
                          items: lsvItems,
                          value: selectedLSV,
                          onChanged: (value) {
                            setState(() {
                              selectedLSV = value;
                              row[52] = value ?? '';
                            });
                          },
                          helpText: 'YES/NO',
                          icon: Icons.coronavirus_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'LSV wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Crop Health',
                          items: cropHealthItems,
                          value: selectedCropHealth,
                          onChanged: (value) {
                            setState(() {
                              selectedCropHealth = value;
                              row[53] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.health_and_safety_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Crop Health wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Crop Uniformity',
                          items: cropUniformityItems,
                          value: selectedCropUniformity,
                          onChanged: (value) {
                            setState(() {
                              selectedCropUniformity = value;
                              row[54] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.grid_on_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Crop Uniformity wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Isolation Audit 6',
                          items: isolationAudit6Items,
                          value: selectedIsolationAudit6,
                          onChanged: (value) {
                            setState(() {
                              selectedIsolationAudit6 = value;
                              row[55] = value ?? '';
                            });
                          },
                          helpText: 'A = Yes\nB = No',
                          icon: Icons.no_adult_content_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Isolation Audit 6 wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Isolation Type',
                          items: isolationTypeItems,
                          value: selectedIsolationType,
                          onChanged: (value) {
                            setState(() {
                              selectedIsolationType = value;
                              row[56] = value ?? '';
                            });
                          },
                          helpText: 'A = Other seed production\nB = Commercial',
                          icon: Icons.fence_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Isolation Type wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Isolation Distance',
                          items: isolationDistanceItems,
                          value: selectedIsolationDistance,
                          onChanged: (value) {
                            setState(() {
                              selectedIsolationDistance = value;
                              row[57] = value ?? '';
                            });
                          },
                          helpText: 'A = >400\nB = <400',
                          icon: Icons.social_distance_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Isolation Distance wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Nicking Observation',
                          items: nickingObservationItems,
                          value: selectedNickingObservation,
                          onChanged: (value) {
                            setState(() {
                              selectedNickingObservation = value;
                              row[58] = value ?? '';
                            });
                          },
                          helpText: 'YES/NO',
                          icon: Icons.schedule_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Nicking Observation wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Flagging',
                          items: flaggingItems,
                          value: selectedFlagging,
                          onChanged: (value) {
                            setState(() {
                              selectedFlagging = value;
                              row[59] = value ?? '';
                            });
                          },
                          helpText: 'Flagging (GF/OF/RF/Discard)',
                          icon: Icons.flag_rounded,
                          validator: (value) => (value == null || value.isEmpty) ? 'Flagging wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildDropdownFormField(
                          label: 'Recommendation',
                          items: recommendationItems,
                          value: selectedRecommendation,
                          onChanged: (value) {
                            setState(() {
                              selectedRecommendation = value;
                              row[60] = value ?? '';
                            });
                          },
                          helpText: 'Continue to Next Process/Discard',
                          icon: Icons.recommend,
                          validator: (value) => (value == null || value.isEmpty) ? 'Recommendation wajib dipilih' : null,
                        ),
                        const SizedBox(height: 10),
                        _buildTextFormField('Recommendation PLD', 61, icon: Icons.recommend),
                        const SizedBox(height: 10),
                        _buildTextFormField('Remarks', 62, icon: Icons.comment, isRequired: false),

                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _showLoadingAndSaveInBackground();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(220, 60),
                              backgroundColor: Colors.redAccent.shade700,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(String label, int index, {IconData? icon, int maxLines = 1, bool isRequired = true}) {
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
        initialValue: row[index],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.redAccent.shade700),
          prefixIcon: icon != null ? Icon(icon, color: Colors.red.shade600) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            row[index] = value;
          });
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label wajib diisi';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.red.shade800, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
          ],
        ),
        const Divider(thickness: 2, color: Colors.redAccent),
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
            Icon(icon, color: Colors.redAccent.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          labelText: label,
          labelStyle: TextStyle(color: Colors.redAccent.shade700),
          prefixIcon: Icon(Icons.calendar_today, color: Colors.red.shade600),
          suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.redAccent.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
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
                    primary: Colors.redAccent.shade700,
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
              controller.text = formattedDate; row[index] = formattedDate;
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label wajib dipilih';
          }
          return null;
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
    String? Function(String?)? validator,
  }) {
    if (value != null && !items.contains(value)) {
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
              labelText: label,
              labelStyle: TextStyle(color: Colors.redAccent.shade700),
              prefixIcon: icon != null ? Icon(icon, color: Colors.red.shade600) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.redAccent.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            initialValue: value,
            hint: Text(hint ?? 'Select an option'),
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            dropdownColor: Colors.white,
            icon: Icon(Icons.arrow_drop_down, color: Colors.redAccent.shade700),
            validator: validator,
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
                builder: (context) => PspSuccessScreen(
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

  void _showLoadingAndSaveInBackground() {
    _showLoadingDialogAndClose();
    _saveToHive(row);
    _saveToGoogleSheets(row);
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    setState(() => isLoading = true);

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
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      setState(() {
        isLoading = false; // Sembunyikan loader
      });
    }

    if (mounted) _navigateBasedOnResponse(context, responseMessage);
  }

  Future<void> _restoreGenerativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Cek Audit 5
        '=IF(OR(AE$rowIndex=0;AE$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 75);
    await sheet.values.insertValue( // Cek Audit 6
        '=IF(OR(AU$rowIndex=0;AU$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 77);
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

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateBasedOnResponse(BuildContext context, String response) {
    if (response == 'Data successfully saved to Audit Database') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PspSuccessScreen(
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
          builder: (context) => const PspFailedScreen(),
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
      // jeda
    }
    return value;
  }
}

class PspSuccessScreen extends StatelessWidget {
  final List<String> row;
  final String userName;
  final String userEmail;
  final String region;

  const PspSuccessScreen({
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
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.redAccent, size: 100),
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
                backgroundColor: Colors.redAccent,
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
    final String action = 'Update';
    final String status = 'Success';

    final List<String> rowData = [
      userEmail,
      userName,
      status,
      'PSP Audit 6',
      action,
      'Generative',
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

class PspFailedScreen extends StatelessWidget {
  const PspFailedScreen({super.key});

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