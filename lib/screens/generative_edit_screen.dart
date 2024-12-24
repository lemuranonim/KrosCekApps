import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName
import 'dart:async';  // Untuk menggunakan Timer
import 'package:hive_flutter/hive_flutter.dart';
import 'config_manager.dart';

class GenerativeEditScreen extends StatefulWidget {
  final List<String> row;
  final String region;
  final Function(List<String>) onSave; // Callback untuk mengirim data yang diperbarui

  const GenerativeEditScreen({
    super.key,
    required this.row,
    required this.region,
    required this.onSave});

  @override
  GenerativeEditScreenState createState() => GenerativeEditScreenState(); // Menghapus underscore agar public
}

class GenerativeEditScreenState extends State<GenerativeEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAudit1Controller;
  late TextEditingController _datePlantingRevController;
  late TextEditingController _dateAudit2Controller;
  late TextEditingController _dateAudit3Controller;
  late TextEditingController _dateClosedController;

  String userEmail = 'Fetching...'; // Variabel untuk email pengguna
  String userName = 'Fetching...';  // Variabel untuk menyimpan nama pengguna
  late String spreadsheetId;

  String? selectedDetaselingPlan;
  String? selectedTenagaKerjaDT;
  String? selectedRoguingProses;
  String? selectedRemarksRoguingProses;
  String? selectedTenagaKerjaDetasseling;
  String? selectedFemaleShed1;
  String? selectedSheddingMale1;
  String? selectedSheddingFemale1;
  String? selectedFemaleShed2;
  String? selectedSheddingMale2;
  String? selectedSheddingFemale2;
  String? selectedStandingCropMale;
  String? selectedStandingCropFemale;
  String? selectedLSV;
  String? selectedDetasselingObservation;
  String? selectedAffectedFields;
  String? selectedNickCover;
  String? selectedCropUniformity;
  String? selectedIsolation;
  String? selectedIsolationType;
  String? selectedIsolationDistance;
  String? selectedQPIR;
  String? selectedFlagging;
  String? selectedRecommendation;
  String? selectedReasonPLD;
  String? selectedReasonTidakTeraudit;

  final List<String> detaselingPlanItems = ['', 'Y', 'N'];
  final List<String> tenagaKerjaDTItems = ['', 'A', 'B', 'C', 'D', 'E'];
  final List<String> roguingProsesItems = ['', 'Y', 'N'];
  final List<String> remarksRoguingProsesItems = ['', 'A', 'B', 'C', 'D', 'E'];
  final List<String> tenagaKerjaDetasselingItems = ['', 'A', 'B'];
  final List<String> femaleShed1Items = ['', 'A', 'B', 'C', 'D'];
  final List<String> sheddingMale1Items = ['', 'A', 'B'];
  final List<String> sheddingFemale1Items = ['', 'A', 'B'];
  final List<String> femaleShed2Items = ['', 'A', 'B', 'C', 'D'];
  final List<String> sheddingMale2Items = ['', 'A', 'B'];
  final List<String> sheddingFemale2Items = ['', 'A', 'B'];
  final List<String> standingCropMaleItems = ['', 'A', 'B'];
  final List<String> standingCropFemaleItems = ['', 'A', 'B'];
  final List<String> lsvItems = ['', 'A', 'B'];
  final List<String> detasselingObservationItems = ['', 'A', 'B', 'C', 'D'];
  final List<String> affectedFieldsItems = ['', 'A', 'B'];
  final List<String> nickCoverItems = ['', 'A', 'B', 'C'];
  final List<String> cropUniformityItems = ['', 'A', 'B', 'C'];
  final List<String> isolationItems = ['', 'Y', 'N'];
  final List<String> isolationTypeItems = ['', 'A', 'B'];
  final List<String> isolationDistanceItems = ['', 'A', 'B', 'C', 'D'];
  final List<String> qPIRItems = ['', 'Y', 'N'];
  final List<String> flaggingItems = ['', 'GF', 'RFI', 'RFD', 'BF'];
  final List<String> recommendationItems = ['', 'Continue', 'Discard'];
  final List<String> reasonPLDItems = ['', 'A', 'B'];
  final List<String> reasonTidakTerauditItems = ['', 'A', 'B', 'C'];

  @override
  void initState() {
    super.initState();
    _loadUserCredentials(); // Panggil satu fungsi untuk mengambil nama dan email pengguna
    row = List<String>.from(widget.row);

    _initHive();
    _fetchSpreadsheetId();

    _dateAudit1Controller = TextEditingController(text: _convertToDateIfNecessary(row[32]));
    _datePlantingRevController = TextEditingController(text: _convertToDateIfNecessary(row[34]));
    _dateAudit2Controller = TextEditingController(text: _convertToDateIfNecessary(row[40]));
    _dateAudit3Controller = TextEditingController(text: _convertToDateIfNecessary(row[45]));
    _dateClosedController = TextEditingController(text: _convertToDateIfNecessary(row[61]));

    // Inisialisasi dropdown dengan nilai yang ada di row
    selectedDetaselingPlan = row[35];
    selectedTenagaKerjaDT = row[36];
    selectedRoguingProses = row[37];
    selectedRemarksRoguingProses = row[38];
    selectedTenagaKerjaDetasseling = row[39];
    selectedFemaleShed1 = row[42];
    selectedSheddingMale1 = row[43];
    selectedSheddingFemale1 = row[44];
    selectedFemaleShed2 = row[47];
    selectedSheddingMale2 = row[48];
    selectedSheddingFemale2 = row[49];
    selectedStandingCropMale = row[50];
    selectedStandingCropFemale = row[51];
    selectedLSV = row[52];
    selectedDetasselingObservation = row[53];
    selectedAffectedFields = row[54];
    selectedNickCover = row[55];
    selectedCropUniformity = row[56];
    selectedIsolation = row[57];
    selectedIsolationType = row[58];
    selectedIsolationDistance = row[59];
    selectedQPIR = row[60];
    selectedFlagging = row[62];
    selectedRecommendation = row[63];
    selectedReasonPLD = row[66];
    selectedReasonTidakTeraudit = row[67];
  }

  bool isLoading = false;  // Untuk mengatur status loading

  Future<void> _fetchSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  void _initHive() async {
    await Hive.initFlutter();
    await Hive.openBox('generativeData');  // Buat box Hive untuk menyimpan data vegetative
  }

  Future<void> _saveToHive(List<String> rowData) async {
    var box = await Hive.openBox('generativeData');
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
        title: const Text('Edit Generative Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                _buildDatePickerField('Date of Audit 1 (dd/MM)', 32, _dateAudit1Controller),
                _buildDatePickerField('Rev Planting Date Based', 34, _datePlantingRevController),

                const SizedBox(height: 10),

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
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 16),

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
                    helpText: 'A = CVL\nB = Offtype\nC = LSV\nD = Male Salah Baris\nE = All'
                ),

                const SizedBox(height: 16),

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
                ),

                const SizedBox(height: 10),

                _buildDatePickerField('Date of Audit 2 (dd/MM)', 40, _dateAudit2Controller),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'Female Shed.',
                  items: femaleShed1Items,
                  value: selectedFemaleShed1,
                  onChanged: (value) {
                    setState(() {
                      selectedFemaleShed1 = value;
                      row[42] = value ?? '';
                    });
                  },
                    helpText: 'A (GF) = 0-5 shedd / Ha\nB (RF) = 6-30 shedd / Ha\nC (BF) = >30 shedd / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Shedding Offtype & CVL Male',
                  items: sheddingMale1Items,
                  value: selectedSheddingMale1,
                  onChanged: (value) {
                    setState(() {
                      selectedSheddingMale1 = value;
                      row[43] = value ?? '';
                    });
                  },
                  helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Shedding Offtype & CVL Female',
                  items: sheddingFemale1Items,
                  value: selectedSheddingFemale1,
                  onChanged: (value) {
                    setState(() {
                      selectedSheddingFemale1 = value;
                      row[44] = value ?? '';
                    });
                  },
                  helpText: 'A = 0-5 plants / Ha\nB = > 5 plants / Ha',
                ),

                const SizedBox(height: 10),

                _buildDatePickerField('Date of Audit 3 (dd/MM)', 45, _dateAudit3Controller),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'Female Shed.',
                  items: femaleShed2Items,
                  value: selectedFemaleShed2,
                  onChanged: (value) {
                    setState(() {
                      selectedFemaleShed2 = value;
                      row[47] = value ?? '';
                    });
                  },
                  helpText: 'A (GF) = 0-5 shedd / Ha\nB (RF) = 6-30 shedd / Ha\nC (BF) = >30 shedd / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Shedding Offtype & CVL M',
                  items: sheddingMale2Items,
                  value: selectedSheddingMale2,
                  onChanged: (value) {
                    setState(() {
                      selectedSheddingMale2 = value;
                      row[48] = value ?? '';
                    });
                  },
                  helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Shedding Offtype & CVL F',
                  items: sheddingFemale2Items,
                  value: selectedSheddingFemale2,
                  onChanged: (value) {
                    setState(() {
                      selectedSheddingFemale2 = value;
                      row[49] = value ?? '';
                    });
                  },
                  helpText: 'A = 0-5 plants / Ha\nB = > 5 plants / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Standing crop Offtype & CVL M',
                  items: standingCropMaleItems,
                  value: selectedStandingCropMale,
                  onChanged: (value) {
                    setState(() {
                      selectedStandingCropMale = value;
                      row[50] = value ?? '';
                    });
                  },
                  helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Standing crop Offtype & CVL F',
                  items: standingCropFemaleItems,
                  value: selectedStandingCropFemale,
                  onChanged: (value) {
                    setState(() {
                      selectedStandingCropFemale = value;
                      row[51] = value ?? '';
                    });
                  },
                  helpText: 'A (GF) = 0-5 plants / Ha\nB (RF) = >5-10 plants / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'LSV Ditemukan',
                  items: lsvItems,
                  value: selectedLSV,
                  onChanged: (value) {
                    setState(() {
                      selectedLSV = value;
                      row[52] = value ?? '';
                    });
                  },
                  helpText: 'A = 0 plants / Ha\nB = > 0 plants / Ha',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Detasseling Process Observation',
                  items: detasselingObservationItems,
                  value: selectedDetasselingObservation,
                  onChanged: (value) {
                    setState(() {
                      selectedDetasselingObservation = value;
                      row[53] = value ?? '';
                    });
                  },
                  helpText: 'A=Best (0,5)\nB=Good (5,5)\nC=Poor (5,7)\nD=Very Poor (>7)',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Affected by other fields',
                  items: affectedFieldsItems,
                  value: selectedAffectedFields,
                  onChanged: (value) {
                    setState(() {
                      selectedAffectedFields = value;
                      row[54] = value ?? '';
                    });
                  },
                    helpText: 'A (GF) = Not Affected\nB (RF) = Severly Affected (if distance <50 mtr)',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Nick Cover',
                  items: nickCoverItems,
                  value: selectedNickCover,
                  onChanged: (value) {
                    setState(() {
                      selectedNickCover = value;
                      row[55] = value ?? '';
                    });
                  },
                    helpText: 'A = Good Nick - Male early or 1% Male Shedd at 5% Silk or reverse\nB = >10-25 % receptive silks at either end & no male shedding\nC = >25% receptive silks at either end & no male shedding',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Crop Uniformity',
                  items: cropUniformityItems,
                  value: selectedCropUniformity,
                  onChanged: (value) {
                    setState(() {
                      selectedCropUniformity = value;
                      row[56] = value ?? '';
                    });
                  },
                    helpText: 'A=Good\nB= Fair\nC=Poor'
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Isolation (Y/N)',
                  items: isolationItems,
                  value: selectedIsolation,
                  onChanged: (value) {
                    setState(() {
                      selectedIsolation = value;
                      row[57] = value ?? '';
                    });
                  },
                    helpText: 'Y = Yes\nN = No'
                ),

                const SizedBox(height: 16),

                if (selectedIsolation == 'Y')
                  Column(
                    children: [
                      _buildDropdownFormField(
                        label: 'If "YES" IsolationType',
                        items: isolationTypeItems,
                        value: selectedIsolationType,
                        onChanged: (value) {
                          setState(() {
                            selectedIsolationType = value;
                            row[58] = value ?? '';
                          });
                        },
                          helpText: 'A : Seed Production\nB : Jagung Komersial'
                      ),
                      const SizedBox(height: 16),
                      _buildDropdownFormField(
                        label: 'If "YES" IsolationDist. (m)',
                        items: isolationDistanceItems,
                        value: selectedIsolationDistance,
                        onChanged: (value) {
                          setState(() {
                            selectedIsolationDistance = value;
                            row[59] = value ?? '';
                          });
                        },
                          helpText: 'A (GF) = >300 m\nB (GF) = >200-<300 m\nC (RF) = >100 & <200 m\nD (RF) = <100 m',
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'QPIR Applied',
                  items: qPIRItems,
                  value: selectedQPIR,
                  onChanged: (value) {
                    setState(() {
                      selectedQPIR = value;
                      row[60] = value ?? '';
                    });
                  },
                  helpText: 'Y = Ada\nN = Tidak Ada',
                ),

                const SizedBox(height: 10),

                _buildDatePickerField('Closed out Date', 61, _dateClosedController),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'FLAGGING',
                  items: flaggingItems,
                  value: selectedFlagging,
                  onChanged: (value) {
                    setState(() {
                      selectedFlagging = value;
                      row[62] = value ?? '';
                    });
                  },
                    helpText: 'GF/RFI/RFD/BF',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Recommendation',
                  items: recommendationItems,
                  value: selectedRecommendation,
                  onChanged: (value) {
                    setState(() {
                      selectedRecommendation = value;
                      row[63] = value ?? '';
                    });
                  },
                    helpText: 'Continue to Next Process/Discard',
                ),

                const SizedBox(height: 16),

                _buildTextFormField('Remarks', 64),
                _buildTextFormField('Recommendation PLD (Ha)', 65),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'Reason PLD',
                  items: reasonPLDItems,
                  value: selectedReasonPLD,
                  onChanged: (value) {
                    setState(() {
                      selectedReasonPLD = value;
                      row[66] = value ?? '';
                    });
                  },
                    helpText: 'A : No Plant\nB : Class D (Uniformity)',
                ),

                const SizedBox(height: 16),

                _buildDropdownFormField(
                  label: 'Reason Tidak Teraudit',
                  items: reasonTidakTerauditItems,
                  value: selectedReasonTidakTeraudit,
                  onChanged: (value) {
                    setState(() {
                      selectedReasonTidakTeraudit = value;
                      row[67] = value ?? '';
                    });
                  },
                    helpText: 'A= Discard/PLD\nB= Lokasi tidak ditemukan\nC = Mised Out',
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
      // debugPrint("Error converting number to date: $e"); // Mengganti print dengan debugPrint
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
