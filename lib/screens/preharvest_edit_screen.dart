import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:gsheets/gsheets.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName
import 'dart:async';  // Untuk menggunakan Timer
import 'package:hive_flutter/hive_flutter.dart';
import 'config_manager.dart';

class PreHarvestEditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave;

  const PreHarvestEditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave});

  @override
  PreHarvestEditScreenState createState() => PreHarvestEditScreenState();
}

class PreHarvestEditScreenState extends State<PreHarvestEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedFI; // FI yang dipilih
  List<String> fiList = []; // Daftar FI untuk dropdown

  String? selectedMaleRowsChopping;
  String? selectedCropHealth;
  String? selectedRecommendation;

  final List<String> maleRowsChoppingItems = ['A', 'B'];
  final List<String> cropHealthItems = ['A', 'B', 'C'];
  final List<String> recommendationItems = ['Continue', 'Discard'];

  @override
  void initState() {
    super.initState();
    _loadUserCredentials();
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    // Initialize text controllers with existing data
    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    _loadFIList(widget.region);

    // Initialize dropdown fields
    selectedMaleRowsChopping = row[32];
    selectedCropHealth = row[34];
    selectedRecommendation = row[36];
  }

  bool isLoading = false;  // Untuk mengatur status loading

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  Future<void> _loadFIList(String region) async {
    setState(() {
      isLoading = true; // Tampilkan loading
    });

    try {
      final gSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
      await gSheetsApi.init(); // Inisialisasi API
      final List<String> fetchedFI = await gSheetsApi.fetchFIByRegion('FI', region);

      setState(() {
        fiList = fetchedFI; // Perbarui daftar FI
        selectedFI = row[31]; // Tetapkan nilai awal dari data row[31]
      });
    } catch (e) {
      debugPrint('Gagal mengambil data FI: $e');
    } finally {
      setState(() {
        isLoading = false; // Sembunyikan loading
      });
    }
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('preHarvestData');  // Buat box Hive untuk menyimpan data vegetative
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('preHarvestData');
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
        title: const Text('Edit Pre Harvest Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

                _buildFIDropdownField('QA FI', 29),
                _buildDatePickerField('Date of Audit (dd/MM)', 30, _dateAuditController),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'Male rows chopping (Max 85 DAP)',
                  items: maleRowsChoppingItems,
                  value: selectedMaleRowsChopping,
                  onChanged: (value) {
                    setState(() {
                      selectedMaleRowsChopping = value;
                      row[32] = value ?? '';
                    });
                  },
                  helpText: 'A = Complete\nB = Not Complete',
                ),

                _buildTextFormField('Male rows chopping Remarks', 33),

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

                _buildTextFormField('Crop Health Remarks', 35),

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

  // Fungsi untuk membangun field teks biasa
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

  Widget _buildFIDropdownField(String label, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        value: selectedFI, // FI yang dipilih
        items: fiList.map((String fi) {
          return DropdownMenuItem<String>(
            value: fi,
            child: Text(fi),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedFI = value; // Update nilai yang dipilih
            row[index] = value ?? ''; // Simpan ke row[index]
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

    String responseMessage;
    try {
      await gSheetsApi.updateRow('Pre Harvest', rowData, rowData[2]);
      await _saveToHive(rowData);
      responseMessage = 'Data successfully saved to Audit Database';
    } catch (e) {
      await _logErrorToActivity('Gagal menyimpan data: ${e.toString()}');
      if (rowData.isNotEmpty && rowData.length > 2 && rowData[2].isNotEmpty) {
        final gSheetsApi = GoogleSheetsApi(spreadsheetId);
        await gSheetsApi.init();
        final Worksheet? sheet = gSheetsApi.spreadsheet.worksheetByTitle('Pre Harvest');

        if (sheet != null) {
          final int rowIndex = await _findRowByFieldNumber(sheet, row[2]);
          if (rowIndex != -1) {
            await _restorePreHarvestFormulas(gSheetsApi, sheet, rowIndex);
          }
        }
      } else {
        debugPrint("Field number tidak valid, tidak dapat menerapkan rumus.");
      }

      responseMessage = 'Failed to save data. Please try again.';
    } finally {
      setState(() {
        isLoading = false; // Sembunyikan loader
      });
    }

    // Lakukan navigasi setelah async selesai, pastikan `mounted` masih true
    if (mounted) {
      _navigateBasedOnResponse(context, responseMessage);
    }
  }

  Future<void> _restorePreHarvestFormulas(GoogleSheetsApi gSheetsApi, Worksheet sheet, int rowIndex) async {
    await sheet.values.insertValue( // Cek Result
        '=IF(OR(AE$rowIndex=0;AE$rowIndex="");"NOT Audited";"Audited")',
        row: rowIndex, column: 40);
    await sheet.values.insertValue( // Week of Reporting
        '=IFERROR(IF(OR(AE$rowIndex=0;AE$rowIndex="");"";WEEKNUM(AE$rowIndex;1));"")',
        row: rowIndex, column: 32);
    await sheet.values.insertValue( // Standing Crops
        '=I$rowIndex-U$rowIndex',
        row: rowIndex, column: 23);
    await sheet.values.insertValue( // Hyperlink Coordinate
        '=IFERROR(IF(AND(LEFT(R$rowIndex;4)-0<6;LEFT(R$rowIndex;4)-0>-11);HYPERLINK("HTTP://MAPS.GOOGLE.COM/maps?q="&R$rowIndex;"LINK");"Not Found");"")',
        row: rowIndex, column: 24);
    await sheet.values.insertValue( // Fase
        '=IF(I$rowIndex=0;"Discard";IF(Y$rowIndex=0;"Harvest";IF(TODAY()-J$rowIndex<46;"Vegetative";IF(AND(TODAY()-J$rowIndex>45;TODAY()-J$rowIndex<56);"Pre Flowering";IF(AND(TODAY()-J$rowIndex>55;TODAY()-J$rowIndex<66);"Flowering";IF(AND(TODAY()-J$rowIndex>65;TODAY()-J$rowIndex<81);"Close Out";IF(TODAY()-J$rowIndex>80;"Male Cutting";"")))))))',
        row: rowIndex, column: 26);
    await sheet.values.insertValue( // Pre Harvest (Est + 80 DAP)
        '=J$rowIndex+80',
        row: rowIndex, column: 27);
    await sheet.values.insertValue( // Week of Pre Harvest
        '=IF(OR(I$rowIndex=0;I$rowIndex="");"";WEEKNUM(AC$rowIndex;1))',
        row: rowIndex, column: 28);
    await sheet.values.insertValue( // Effective Area (Ha)
        '=G$rowIndex-H$rowIndex',
        row: rowIndex, column: 9);
    await sheet.values.insertValue( // Discard Area (Ha)
        '=TEXT(H$rowIndex; "#,##0.00")',
        row: rowIndex, column: 8);
    await sheet.values.insertValue( // Total Area Planted (Ha)
        '=TEXT(G$rowIndex; "#,##0.00")',
        row: rowIndex, column: 7);

    debugPrint("Rumus berhasil diterapkan di Pre Harvest pada baris $rowIndex.");
  }

  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber) async { // Mencari baris berdasarkan fieldNumber

    final List<List<String>> rows = await sheet.values.allRows(); // Ambil semua baris
    for (int i = 0; i < rows.length; i++) { // Iterasi setiap baris
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) { // Kolom ke-3 untuk fieldNumber
        return i + 1; // Index baris di Google Sheets dimulai dari 1
      }
    }
    return -1; // Tidak ditemukan
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
      // Tampilkan pesan error atau tetap di halaman
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
      'Pre Harvest',
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
        backgroundColor: Colors.red,
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
                backgroundColor: Colors.red, // Warna background tombol
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
