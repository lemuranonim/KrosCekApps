import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName
import 'dart:async';  // Untuk menggunakan Timer
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

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

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

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    // Inisialisasi dropdown dengan nilai yang ada di row
    selectedEarConditionObservation = row[32];
    selectedCropHealth = row[34];
    selectedRecommendation = row[36];
    selectedReasonToDowngradeFlagging = row[38];
    selectedDowngradeFlaggingRecommendation = row[39];
  }

  bool isLoading = false;  // Untuk mengatur status loading

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('harvestData');  // Buat box Hive untuk menyimpan data vegetative
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('harvestData');
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
        title: const Text('Edit Harvest Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Tampilkan progress bar di atas form jika sedang loading
                if (isLoading) const LinearProgressIndicator(),  // Tambahkan di sini

                _buildTextFormField('QA FI', 29),
                _buildDatePickerField('Date of Audit (dd/MM)', 30, _dateAuditController),

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
                ),

                _buildTextFormField('Moisture Content - %', 33),

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
                ),

                _buildTextFormField('Remarks', 35),

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
                ),

                const SizedBox(height: 10),

                _buildTextFormField('Date of Downgrade Flagging', 37),

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
                ),

                const SizedBox(height: 20),

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
                ),

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
      padding: const EdgeInsets.symmetric(vertical: 10.0),
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
              row[index] = formattedDate;
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
      await gSheetsApi.updateRow('Harvest', rowData, rowData[2]);
      await _saveToHive(rowData); // Update data di Hive juga

      _showSnackbar('Data successfully saved to Google Sheets');
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

  const SuccessScreen({
    super.key,
    required this.row,
    required this.userName,
    required this.userEmail,
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
                await _saveBackActivityToGoogleSheets();

                // Tutup dialog loading
                navigator.pop();

                // Kembali ke layar sebelumnya
                navigator.pop();
              },
              child: const Text('Back'),
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

  Future<void> _saveBackActivityToGoogleSheets() async {
    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';
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
      action,
      'Harvest',
      fieldNumber,
      timestamp,
    ];

    try {
      await gSheetsApi.addRow(worksheetTitle, rowData);
      debugPrint('Aktivitas berhasil dicatat di Google Sheets');
    } catch (e) {
      debugPrint('Gagal mencatat aktivitas di Google Sheets: $e');
    }
  }
}

Future<void> _logErrorToActivity(String message) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> logs = prefs.getStringList('activityLogs') ?? [];
  logs.add('${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}: $message');
  await prefs.setStringList('activityLogs', logs);
}
