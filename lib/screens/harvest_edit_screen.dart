import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:gsheets/gsheets.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'config_manager.dart';

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

  String? selectedFI;
  List<String> fiList = [];

  String? selectedEarConditionObservation;
  String? selectedCropHealth;
  String? selectedRecommendation;
  String? selectedReasonToDowngradeFlagging;
  String? selectedDowngradeFlaggingRecommendation;

  final List<String> earConditionObservationItems = ['2', '3', '4'];
  final List<String> cropHealthItems = ['A', 'B', 'C'];
  final List<String> recommendationItems = ['Continue', 'Discard'];
  final List<String> reasonToDowngradeFlaggingItems = ['A', 'B', 'C', 'D'];
  final List<String> downgradeFlaggingRecommendationItems = ['RFI', 'RFD'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    _loadFIList(widget.region);

    selectedEarConditionObservation = row[32];
    selectedCropHealth = row[34];
    selectedRecommendation = row[36];
    selectedReasonToDowngradeFlagging = row[38];
    selectedDowngradeFlaggingRecommendation = row[39];
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

                        // Audit Information Section
                        _buildSectionHeader('Audit Information'),

                        _buildFIDropdownField('QA FI', 29),
                        const SizedBox(height: 15),

                        _buildDatePickerField('Date of Audit (dd/MM)', 30, _dateAuditController),
                        const SizedBox(height: 15),

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
                          helpText: 'Kernel Milk Line (2; 3; 4)',
                          icon: Icons.agriculture,
                        ),
                        const SizedBox(height: 15),

                        _buildTextFormField(
                          'Moisture Content - %',
                          33,
                          icon: Icons.water_drop,
                        ),
                        const SizedBox(height: 15),

                        // Crop Health Section
                        _buildSectionHeader('Crop Health Assessment'),

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
                          helpText: 'A (Low)\nB (Moderate)\nC (High)',
                          icon: Icons.health_and_safety,
                        ),
                        const SizedBox(height: 15),

                        _buildTextFormField(
                          'Remarks',
                          35,
                          icon: Icons.comment,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 15),

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
                        const SizedBox(height: 20),

                        // Downgrade Flagging Section
                        _buildSectionHeader('Downgrade Flagging'),

                        _buildTextFormField(
                          'Date of Downgrade Flagging',
                          37,
                          icon: Icons.calendar_today,
                        ),
                        const SizedBox(height: 15),

                        _buildDropdownFormField(
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
                        const SizedBox(height: 15),

                        _buildDropdownFormField(
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

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
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
        initialValue: row[index].isNotEmpty ? "'${row[index]}" : "'0",
        maxLines: maxLines,
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
        onChanged: (value) {
          setState(() {
            String cleanedValue = value.replaceAll("'", "");
            row[index] = "'$cleanedValue";
          });
        },
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
            child: Text(fi),
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
    setState(() {
      isLoading = true;
    });

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    String responseMessage;
    try {
      await gSheetsApi.updateRow('Harvest', rowData, rowData[2]);
      await _saveToHive(rowData);
      responseMessage = 'Data successfully saved to Audit Database';
    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      if (rowData.isNotEmpty && rowData.length > 2 && rowData[2].isNotEmpty) {
        final gSheetsApi = GoogleSheetsApi(spreadsheetId);
        await gSheetsApi.init();
        final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Harvest');

        if (sheet != null) {
          final int rowIndex = await _findRowByFieldNumber(sheet, row[2]);
          if (rowIndex != -1) {
            await _restoreHarvestFormulas(gSheetsApi, sheet, rowIndex);
          }
        }
      } else {
        debugPrint("Field number tidak valid, tidak dapat menerapkan rumus.");
      }

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

  Future<void> _restoreHarvestFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue(
        '=IF(OR(AE$rowIndex=0;AE$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 44);
    await sheet.values.insertValue(
        '=IFERROR(IF(OR(AE$rowIndex=0;AE$rowIndex="");"";WEEKNUM(AE$rowIndex;1));"")',
        row: rowIndex, column: 32);
    await sheet.values.insertValue(
        '=I$rowIndex-U$rowIndex',
        row: rowIndex, column: 23);
    await sheet.values.insertValue(
        '=IFERROR(IF(AND(LEFT(R$rowIndex;4)-0<6;LEFT(R$rowIndex;4)-0>-11);HYPERLINK("HTTP://MAPS.GOOGLE.COM/maps?q="&R$rowIndex;"LINK");"Not Found");"")',
        row: rowIndex, column: 24);
    await sheet.values.insertValue(
        '=IF(I$rowIndex=0;"Discard";IF(Y$rowIndex=0;"Harvest";IF(TODAY()-J$rowIndex<46;"Vegetative";IF(AND(TODAY()-J$rowIndex>45;TODAY()-J$rowIndex<56);"Pre Flowering";IF(AND(TODAY()-J$rowIndex>55;TODAY()-J$rowIndex<66);"Flowering";IF(AND(TODAY()-J$rowIndex>65;TODAY()-J$rowIndex<81);"Close Out";IF(TODAY()-J$rowIndex>80;"Male Cutting";"")))))))',
        row: rowIndex, column: 26);
    await sheet.values.insertValue(
        '=J$rowIndex+110',
        row: rowIndex, column: 27);
    await sheet.values.insertValue(
        '=IF(OR(I$rowIndex=0;I$rowIndex="");"";WEEKNUM(AC$rowIndex;1))',
        row: rowIndex, column: 28);
    await sheet.values.insertValue(
        '=G$rowIndex-H$rowIndex',
        row: rowIndex, column: 9 );
    await sheet.values.insertValue(
        '=TEXT(H$rowIndex; "#,##0.00")',
        row: rowIndex, column: 8);
    await sheet.values.insertValue(
        '=TEXT(G$rowIndex; "#,##0.00")',
        row: rowIndex, column: 7);

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
      builder: (context) => AlertDialog(
        title: Text('Confirm Save'),
        content: Text('Are you sure you want to save the changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Save'),
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
          builder: (context) => FailedScreen(),
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
      // Handle error
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
      'Harvest',
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