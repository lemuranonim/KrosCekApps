import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName
import 'dart:async';  // Untuk menggunakan Timer
import 'package:hive_flutter/hive_flutter.dart';
import 'config_manager.dart';

class Audit6EditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave; // Callback untuk mengirim data yang diperbarui

  const Audit6EditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave});

  @override
  Audit6EditScreenState createState() => Audit6EditScreenState();
}

class Audit6EditScreenState extends State<Audit6EditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedLSV;
  String? selectedCorpHealth;
  String? selectedCropUniformity;
  String? selectedIsolationAudit6;
  String? selectedIsolationType;
  String? selectedIsolationDistance;
  String? selectedNickingObservation;
  String? selectedFlagging;
  String? selectedRecommendation;

  final List<String> lsvItems = ['', 'YES', 'NO'];
  final List<String> corpHealthItems = ['', 'A', 'B', 'C'];
  final List<String> cropUniformityItems = ['', 'A', 'B', 'C'];
  final List<String> isolationAudit6Items = ['', 'A', 'B'];
  final List<String> isolationTypeItems = ['', 'A', 'B'];
  final List<String> isolationDistanceItems = ['', 'A', 'B'];
  final List<String> nickingObservationItems = ['', 'YES', 'NO'];
  final List<String> flaggingItems = ['', 'GF', 'OF', 'RF'];
  final List<String> recommendationItems = ['', 'Continue to Next Process', 'Discard'];

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[46]));

    // Initialize dropdown fields
    selectedLSV = row[52];
    selectedCorpHealth = row[53];
    selectedCropUniformity = row[54];
    selectedIsolationAudit6 = row[55];
    selectedIsolationType = row[56];
    selectedIsolationDistance = row[57];
    selectedNickingObservation = row[58];
    selectedFlagging = row[59];
    selectedRecommendation = row[60];
  }

  bool isLoading = false;  // Untuk mengatur status loading

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
        title: const Text('Edit Audit 6', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
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

                _buildDatePickerField('Date of Audit 6', 46, _dateAuditController),
                _buildTextFormField('Standing crop Offtype', 48),
                _buildTextFormField('Standing crop Volunteer', 49),
                _buildTextFormField('Offtype Sheed', 50),
                _buildTextFormField('Volunteer Seed', 51),

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
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Corp Health',
                  items: corpHealthItems,
                  value: selectedCorpHealth,
                  onChanged: (value) {
                    setState(() {
                      selectedCorpHealth = value;
                      row[53] = value ?? '';
                    });
                  },
                  helpText: 'A = GF (Good)\nB = GF (Fair)\nC = YF (Poor)',
                ),

                const SizedBox(height: 16),

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
                  helpText: 'A = GF (Good)\nB = GF (Fair)\nC = YF (Poor)',
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 16),

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
                  helpText: 'Flagging (GF/OF/RF)',
                ),

                const SizedBox(height: 16),

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
                ),

                _buildTextFormField('Recommendation PLD', 61),
                _buildTextFormField('Remarks', 62),

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
                    backgroundColor: Colors.redAccent, // Warna background tombol
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
        // Menambahkan tanda kutip tunggal di depan nilai saat ditampilkan
        initialValue: row[index].isNotEmpty ? "'${row[index]}" : "'0", // Default nilai '0'
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          setState(() {
            // Memastikan nilai disimpan sebagai string dengan tanda kutip tunggal di depan
            String cleanedValue = value.replaceAll("'", ""); // Menghapus tanda kutip sementara
            row[index] = "'$cleanedValue"; // Tambahkan tanda kutip kembali untuk menyimpan sebagai teks
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
      await gSheetsApi.updateRow('Generative', rowData, rowData[2]);
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
                backgroundColor: Colors.redAccent, // Warna background tombol
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

Future<void> _logErrorToActivity(String message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> logs = prefs.getStringList('activityLogs') ?? [];
  logs.add('${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}: $message');
  await prefs.setStringList('activityLogs', logs);
}
