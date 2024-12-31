import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName
import 'dart:async';  // Untuk menggunakan Timer
import 'package:hive_flutter/hive_flutter.dart';
import 'config_manager.dart';

class VegetativeEditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave; // Callback untuk mengirim data yang diperbarui

  const VegetativeEditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave});

  @override
  VegetativeEditScreenState createState() => VegetativeEditScreenState();
}

class VegetativeEditScreenState extends State<VegetativeEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;
  late TextEditingController _actualPlantingDateController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedSplitField;
  String? selectedIsolationProblem;
  String? selectedContaminantType;
  String? selectedContaminantDistance;
  String? selectedCropUniformity;
  String? selectedOfftypeInMale;
  String? selectedOfftypeInFemale;
  String? selectedPreviousCrop;
  String? selectedFIRApplied;
  String? selectedPOIAccuracy;
  String? selectedFlagging;
  String? selectedRecommendation;

  final List<String> splitFieldItems = ['', 'A', 'B'];
  final List<String> isolationProblemItems = ['', 'Y', 'N'];
  final List<String> contaminantTypeItems = ['', 'A', 'B'];
  final List<String> contaminantDistanceItems = ['', 'A', 'B', 'C', 'D'];
  final List<String> cropUniformityItems = ['', 'A', 'B', 'C'];
  final List<String> offtypeItems = ['', 'A', 'B'];
  final List<String> firAppliedItems = ['', 'Y', 'N'];
  final List<String> poiAccuracyItems = ['', 'Valid', 'Not Valid'];
  final List<String> flaggingItems = ['', 'GF', 'RF'];
  final List<String> recommendationItems = ['', 'Continue', 'Discard'];

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[33]));
    _actualPlantingDateController = TextEditingController(text: _convertToDateIfNecessary(row[35]));

    // Initialize dropdown fields
    selectedSplitField = row[39];
    selectedIsolationProblem = row[40];
    selectedContaminantType = row[41];
    selectedContaminantDistance = row[42];
    selectedCropUniformity = row[43];
    selectedOfftypeInMale = row[44];
    selectedOfftypeInFemale = row[45];
    selectedPreviousCrop = row[46];
    selectedFIRApplied = row[47];
    selectedPOIAccuracy = row[48];
    selectedFlagging = row[49];
    selectedRecommendation = row[50];
  }

  bool isLoading = false;  // Untuk mengatur status loading

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('vegetativeData');  // Buat box Hive untuk menyimpan data vegetative
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('vegetativeData');
    final cacheKey = 'detailScreenData_${rowData[2]}'; // Menggunakan fieldNumber atau ID unik lainnya sebagai kunci
    await box.put(cacheKey, rowData); // Simpan hanya rowData ke Hive
  }

  // Fungsi untuk mengambil userName dan userEmail dari SharedPreferences
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
        title: const Text('Edit Vegetative Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Tampilkan progress bar di atas form jika sedang loading
                if (isLoading) const LinearProgressIndicator(),  // Tambahkan di sini

                _buildTextFormField('QA FI', 31),
                _buildTextFormField('Co Detasseling', 32),
                _buildDatePickerField('Date of Audit', 33, _dateAuditController),
                _buildDatePickerField('Actual Female Planting Date', 35, _actualPlantingDateController),
                _buildTextFormField('Field Size by Audit (Ha)', 36),
                _buildTextFormField('Male Split by Audit', 37),
                _buildTextFormField('Sowing Ratio by Audit', 38),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'Split Field by Audit',
                  items: splitFieldItems,
                  value: selectedSplitField,
                  onChanged: (value) {
                    setState(() {
                      selectedSplitField = value;
                      row[39] = value ?? '';
                    });
                  },
                  helpText: 'A = No\nB = Yes',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Isolation Problem by Audit',
                  items: isolationProblemItems,
                  value: selectedIsolationProblem,
                  onChanged: (value) {
                    setState(() {
                      selectedIsolationProblem = value;
                      row[40] = value ?? '';
                    });
                  },
                  helpText: 'Y = Yes\nN = No',
                ),

                const SizedBox(height: 16),

                if (selectedIsolationProblem == 'Y')
                  Column(
                    children: [
                      _buildDropdownFormField(
                        label: 'If "YES" Contaminant Type',
                        items: contaminantTypeItems,
                        value: selectedContaminantType,
                        onChanged: (value) {
                          setState(() {
                            selectedContaminantType = value;
                            row[41] = value ?? '';
                          });
                        },
                        helpText: 'A = Seed Production\nB = Jagung Komersial',
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownFormField(
                        label: 'If "YES" Contaminant Distance',
                        items: contaminantDistanceItems,
                        value: selectedContaminantDistance,
                        onChanged: (value) {
                          setState(() {
                            selectedContaminantDistance = value;
                            row[42] = value ?? '';
                          });
                        },
                          helpText: 'A = >300 m\nB = >200-<300 m\nC = >100 & <200 m\nD = <100 m\n'
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Crop Uniformity',
                  items: cropUniformityItems,
                  value: selectedCropUniformity,
                  onChanged: (value) {
                    setState(() {
                      selectedCropUniformity = value;
                      row[43] = value ?? '';
                    });
                  },
                    helpText: 'A = Good\nB = Fair\nC = Poor'
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Offtype in Male',
                  items: offtypeItems,
                  value: selectedOfftypeInMale,
                  onChanged: (value) {
                    setState(() {
                      selectedOfftypeInMale = value;
                      row[44] = value ?? '';
                    });
                  },
                    helpText: 'A = No\nB = Yes'
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Offtype in Female',
                  items: offtypeItems,
                  value: selectedOfftypeInFemale,
                  onChanged: (value) {
                    setState(() {
                      selectedOfftypeInFemale = value;
                      row[45] = value ?? '';
                    });
                  },
                  helpText: 'A = No\nB = Yes',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Previous Crop by Audit',
                  items: offtypeItems,
                  value: selectedPreviousCrop,
                  onChanged: (value) {
                    setState(() {
                      selectedPreviousCrop = value;
                      row[46] = value ?? '';
                    });
                  },
                  helpText: 'A = Not Corn\nB = Corn After Corn',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'FIR Applied',
                  items: firAppliedItems,
                  value: selectedFIRApplied,
                  onChanged: (value) {
                    setState(() {
                      selectedFIRApplied = value;
                      row[47] = value ?? '';
                    });
                  },
                  helpText: 'Y = Ada\nN = Tidak Ada',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'POI Accuracy',
                  items: poiAccuracyItems,
                  value: selectedPOIAccuracy,
                  onChanged: (value) {
                    setState(() {
                      selectedPOIAccuracy = value;
                      row[48] = value ?? '';
                    });
                  },
                  helpText: 'POI Accuracy (Valid/Not Valid)',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Flagging (GF/RF)',
                  items: flaggingItems,
                  value: selectedFlagging,
                  onChanged: (value) {
                    setState(() {
                      selectedFlagging = value;
                      row[49] = value ?? '';
                    });
                  },
                  helpText: 'Flagging (GF/RF)',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Recommendation',
                  items: recommendationItems,
                  value: selectedRecommendation,
                  onChanged: (value) {
                    setState(() {
                      selectedRecommendation = value;
                      row[50] = value ?? '';
                    });
                  },
                  helpText: 'Continue to Next Process/Discard',
                ),

                _buildTextFormField('Remarks', 51),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _showLoadingDialogAndClose();  // Tampilkan loading spinner
                      _showLoadingAndSaveInBackground();
                      _showConfirmationDialog;
                      _saveToGoogleSheets(row); // Simpan data ke Google Sheets
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 60), // Mengatur ukuran tombol (lebar x tinggi)
                    backgroundColor: Colors.green, // Warna background tombol
                    foregroundColor: Colors.white, // Warna teks tombol
                    shape: RoundedRectangleBorder( // Membuat sudut tombol melengkung
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(fontSize: 20), // Ukuran teks lebih besar
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(String label, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: row[index],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          setState(() {
            row[index] = value;
          });
        },
      ),
    );
  }

  Widget _buildDatePickerField(String label, int index, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );

          if (pickedDate != null) {
            String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
            setState(() {
              controller.text = formattedDate;
              row[index] = formattedDate; // Update date in row
            });
          }
        },
      ),
    );
  }

  // Fungsi untuk membangun dropdown
  Widget _buildDropdownFormField({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
    String? hint,
    String? helpText,
  }) {
    // Jika nilai tidak ada di dalam daftar item, set nilai awal menjadi null
    if (!items.contains(value)) {
      value = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          value: value,
          hint: Text(hint ?? 'Survey membuktikan!'),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 5), // Spacer between dropdown and helper text
          Text(
            helpText,
            style: const TextStyle(
              fontStyle: FontStyle.italic, // Mengatur gaya italic pada helpText
              color: Colors.grey, // Warna teks
            ),
          ),
        ],
      ],
    );
  }

  // Fungsi untuk menampilkan loading spinner hanya selama 5 detik
  void _showLoadingDialogAndClose() {
    bool dialogShown = false;

    // Tampilkan dialog loading
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
                "Loading...",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        );
      },
    );

    // Timer untuk menutup dialog loading setelah 5 detik
    Timer(const Duration(seconds: 5), () {
      if (dialogShown && mounted) {
        // Tutup dialog jika masih aktif dan widget masih terpasang
        Navigator.of(context, rootNavigator: true).pop();

        // Lakukan navigasi ke layar Success dalam microtask tanpa async gap
        Future.microtask(() {
          if (mounted) { // Pastikan konteks masih valid
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
    // Tampilkan loading spinner dan success setelah 5 detik
    _showLoadingDialogAndClose();

    // Simpan data ke Hive
    _saveToHive(row);

    // Jalankan proses penyimpanan di latar belakang
    _saveToGoogleSheets(row);  // Panggil fungsi penyimpanan yang berjalan di background
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    setState(() {
      isLoading = true; // Tampilkan loader
    });

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    try {
      await gSheetsApi.updateRow('Vegetative', rowData, rowData[2]);
      await _saveToHive(rowData);

      _showSnackbar('Data successfully saved to Audit Database');
    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      _showSnackbar('Failed to save data. Please try again.');
    } finally {
      setState(() {
        isLoading = false; // Sembunyikan loader
      });
    }
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
    return row.every((field) => field.isNotEmpty); // Pastikan semua field terisi
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
      // jeda
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
                // Tampilkan dialog loading
                _showLoadingDialog(context);

                // Simpan instance NavigatorState untuk digunakan setelah async gap
                final navigator = Navigator.of(context);

                // Simpan data ke Google Sheets
                await _saveBackActivityToGoogleSheets(region);

                // Tutup dialog loading
                navigator.pop();

                // Kembali ke layar sebelumnya
                navigator.pop();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60), // Mengatur ukuran tombol (lebar x tinggi)
                backgroundColor: Colors.green, // Warna background tombol
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
                "Loading...",
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

Future<void> _logErrorToActivity(String message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> logs = prefs.getStringList('activityLogs') ?? [];
  logs.add('${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}: $message');
  await prefs.setStringList('activityLogs', logs);
}
