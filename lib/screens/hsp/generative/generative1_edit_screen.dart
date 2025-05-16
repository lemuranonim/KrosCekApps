import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late TextEditingController _dateAudit1Controller;
  late TextEditingController _datePlantingRevController;

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

  final List<String> detaselingPlanItems = ['Y', 'N'];
  final List<String> tenagaKerjaDTItems = ['A', 'B', 'C', 'D', 'E'];
  final List<String> roguingProsesItems = ['Y', 'N'];
  final List<String> remarksRoguingProsesItems = ['A', 'B', 'C', 'D', 'E'];
  final List<String> tenagaKerjaDetasselingItems = ['A', 'B'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAudit1Controller = TextEditingController(text: _convertToDateIfNecessary(row[32]));
    _datePlantingRevController = TextEditingController(text: _convertToDateIfNecessary(row[34]));

    _loadFIList(widget.region);

    gSheetsApi = GoogleSheetsApi(spreadsheetId);
    gSheetsApi.init();

    selectedDetaselingPlan = row[35];
    selectedTenagaKerjaDT = row[36];
    selectedRoguingProses = row[37];
    selectedRemarksRoguingProses = row[38];
    selectedTenagaKerjaDetasseling = row[39];
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

                        const SizedBox(height: 20),

                        // Audit Information Section
                        _buildSectionHeader('Audit Information', Icons.assignment),
                        _buildFIDropdownField('QA FI', 31),
                        const SizedBox(height: 10),
                        _buildDatePickerField('Date of Audit 1 (dd/MM)', 32, _dateAudit1Controller),
                        const SizedBox(height: 10),
                        _buildDatePickerField('Rev Planting Date Based', 34, _datePlantingRevController),
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
                        ),

                        const SizedBox(height: 30),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _showLoadingDialogAndClose();
                                _showLoadingAndSaveInBackground();
                                _showConfirmationDialog;
                                _saveToGoogleSheets(row);
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

  Widget _buildFIDropdownField(String label, int index) {
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
          labelText: label,
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
        value: selectedFI,
        items: fiList.map((String fi) {
          return DropdownMenuItem<String>(
            value: fi,
            child: SizedBox(
              width: double.infinity, // Memastikan lebar penuh
              child: Text(
                fi,
                overflow: TextOverflow.ellipsis, // Menghindari teks keluar
                maxLines: 1, // Membatasi jumlah baris
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedFI = value;
            row[index] = value ?? '';
          });
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
        isExpanded: true, // Memastikan dropdown mengisi ruang yang tersedia
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
              labelText: label,
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirm Save', style: TextStyle(color: Colors.green.shade800)),
        content: Text('Are you sure you want to save the changes?'),
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
      _validateAndSave();
    }
  }

  void _validateAndSave() {
    if (_formKey.currentState!.validate()) {
      if (_isDataValid()) {
        _showLoadingDialogAndClose();
        _saveToGoogleSheets(row);
      } else {
        _showSnackbar('Please complete all required fields');
      }
    }
  }

  bool _isDataValid() {
    return row.every((field) => field.isNotEmpty);
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
        backgroundColor: Colors.green,
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
      'Generative - Audit 1',
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