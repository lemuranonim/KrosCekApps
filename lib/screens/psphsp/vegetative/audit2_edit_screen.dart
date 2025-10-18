import 'dart:async'; // Untuk menggunakan Timer

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences untuk userName

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class Audit2EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave; // Callback untuk mengirim data yang diperbarui

  const Audit2EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave,
  });

  @override
  Audit2EditScreenState createState() => Audit2EditScreenState();
}

class Audit2EditScreenState extends State<Audit2EditScreen> {
  late List<String> row;
  late GoogleSheetsApi gSheetsApi;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...'; // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedCropHealth;
  String? selectedCropUniformity;

  final List<String> cropHealthItems = ['1', '2', '3', '4', '5'];
  final List<String> cropUniformityItems = ['1', '2', '3', '4', '5'];

  bool isLoading = false;

  bool get isDiscardMode {
    if (widget.row.length > 73) {
      return widget.row[73] == 'Discard';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[44]));

    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    gSheetsApi.init();

    // Initialize dropdown fields, set to null if empty
    selectedCropHealth = row[49].isNotEmpty ? row[49] : null;
    selectedCropUniformity = row[50].isNotEmpty ? row[50] : null;
  }

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('pspVegetativeData'); // Buat box Hive untuk menyimpan data vegetative
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('pspVegetativeData');
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
            'Edit Audit 2',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            )
        ),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade700, Colors.orange.shade100],
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
                            backgroundColor: Colors.orange,
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

                        _buildInfoCard(
                          title: 'FI',
                          value: row[26],
                          icon: Icons.person,
                        ),

                        const SizedBox(height: 20),
                        _buildSectionHeader('Audit Information', Icons.assignment),
                        _buildDatePickerField('Date of Audit 2', 44, _dateAuditController),
                        const SizedBox(height: 10),
                        _buildTextFormField('Audit 2 Offtype', 46, icon: Icons.text_fields),
                        const SizedBox(height: 10),
                        _buildTextFormField('Audit 2 Volunteer', 47, icon: Icons.group),
                        const SizedBox(height: 10),
                        _buildTextFormField('Audit 2 LSV', 48, icon: Icons.check_circle),

                        const SizedBox(height: 10),
                        _buildSectionHeader('Crop Management', Icons.agriculture),
                        _buildDropdownFormField(
                          label: 'Crop Health',
                          items: cropHealthItems,
                          value: selectedCropHealth,
                          onChanged: (value) {
                            setState(() {
                              selectedCropHealth = value;
                              row[49] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.health_and_safety,
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
                              row[50] = value ?? '';
                            });
                          },
                          helpText: '1 (Very Poor)\n2 (Poor)\n3 (Fair)\n4 (Good)\n5 (Best)',
                          icon: Icons.grass,
                          validator: (value) => (value == null || value.isEmpty) ? 'Crop Uniformity wajib dipilih' : null,
                        ),

                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Memvalidasi form sebelum menyimpan
                              if (_formKey.currentState!.validate()) {
                                // Jika form valid, lanjutkan proses penyimpanan
                                _showLoadingAndSaveInBackground();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(220, 60),
                              backgroundColor: Colors.orange.shade700,
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

  Widget _buildTextFormField(String label, int index, {IconData? icon, int maxLines = 1}) {
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
          labelStyle: TextStyle(color: Colors.orange.shade700),
          prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade600) : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            row[index] = value;
          });
        },
        // VALIDATOR ditambahkan di sini
        validator: (value) {
          if (isDiscardMode) {
            return null; // Tidak wajib jika mode discard aktif
          }
          if (value == null || value.isEmpty) {
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
            Icon(icon, color: Colors.orange.shade800, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ),
        const Divider(thickness: 2, color: Colors.orange),
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
            Icon(icon, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded( // Menambahkan Expanded untuk menghindari overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    overflow: TextOverflow.ellipsis, // Menghindari teks keluar
                    maxLines: 1, // Membatasi jumlah baris
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis, // Menghindari teks keluar
                    maxLines: 1, // Membatasi jumlah baris
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
          labelStyle: TextStyle(color: Colors.orange.shade700),
          prefixIcon: Icon(Icons.calendar_today, color: Colors.orange.shade600),
          suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
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
                    primary: Colors.orange.shade700,
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
        // VALIDATOR ditambahkan di sini
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
    // Menambahkan parameter validator
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
              labelStyle: TextStyle(color: Colors.orange.shade700),
              prefixIcon: icon != null ? Icon(icon, color: Colors.orange.shade600) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
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
            icon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
            // Menggunakan validator yang dilewatkan
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
        isLoading = false; // Sembunyikan loader
      });
    }

    if (mounted) _navigateBasedOnResponse(context, responseMessage);
  }

  Future<void> _restoreVegetativeFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Cek Audit 1
        '=IF(OR(AE$rowIndex=0;AE$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 84);
    await sheet.values.insertValue( // Cek Audit 2
        '=IF(OR(AS$rowIndex=0;AS$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 86);
    await sheet.values.insertValue( // Cek Audit 3
        '=IF(OR(BB$rowIndex=0;BB$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 88);
    await sheet.values.insertValue( // Cek Audit 4
        '=IF(OR(BK$rowIndex=0;BK$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 90);
    await sheet.values.insertValue( // Week of Audit 1
        '=IFERROR(IF(OR(AE$rowIndex=0;AE$rowIndex="");"";WEEKNUM(AE$rowIndex;1));"")',
        row: rowIndex, column: 30);
    await sheet.values.insertValue( // Week of Audit 2
        '=IFERROR(IF(OR(AS$rowIndex=0;AS$rowIndex="");"";WEEKNUM(AS$rowIndex;1));"")',
        row: rowIndex, column: 46);
    await sheet.values.insertValue( // Week of Audit 3
        '=IFERROR(IF(OR(BB$rowIndex=0;BB$rowIndex="");"";WEEKNUM(BB$rowIndex;1));"")',
        row: rowIndex, column: 55);
    await sheet.values.insertValue( // Week of Audit 4
        '=IFERROR(IF(OR(BK$rowIndex=0;BK$rowIndex="");"";WEEKNUM(BK$rowIndex;1));"")',
        row: rowIndex, column: 64);
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

// ... (Kelas PspSuccessScreen, PspFailedScreen, dan _logErrorToActivity tetap sama)
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
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.orange, size: 100),
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
                backgroundColor: Colors.orange, // Warna background tombol
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
      'PSP Audit 2',
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
        backgroundColor: Colors.orange.shade700,
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
                backgroundColor: Colors.orange.shade700, // Warna background tombol
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