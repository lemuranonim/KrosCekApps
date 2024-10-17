import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';

class GenerativeEditScreen extends StatefulWidget {
  final List<String> row;

  const GenerativeEditScreen({super.key, required this.row});

  @override
  _GenerativeEditScreenState createState() => _GenerativeEditScreenState();
}

class _GenerativeEditScreenState extends State<GenerativeEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAudit1Controller;
  late TextEditingController _datePlantingRevController;
  late TextEditingController _dateAudit2Controller;
  late TextEditingController _dateAudit3Controller;
  late TextEditingController _dateClosedController;

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

  final List<String> detaselingPlanItems = ['Y', 'N'];
  final List<String> tenagaKerjaDTItems = ['Y', 'N'];
  final List<String> roguingProsesItems = ['Y', 'N'];
  final List<String> remarksRoguingProsesItems = ['A', 'B', 'C', 'D', 'E'];
  final List<String> tenagaKerjaDetasselingItems = ['A', 'B'];
  final List<String> femaleShed1Items = ['A', 'B', 'C', 'D'];
  final List<String> sheddingMale1Items = ['A', 'B'];
  final List<String> sheddingFemale1Items = ['A', 'B'];
  final List<String> femaleShed2Items = ['A', 'B', 'C', 'D'];
  final List<String> sheddingMale2Items = ['A', 'B'];
  final List<String> sheddingFemale2Items = ['A', 'B'];
  final List<String> standingCropMaleItems = ['A', 'B'];
  final List<String> standingCropFemaleItems = ['A', 'B'];
  final List<String> lsvItems = ['A', 'B'];
  final List<String> detasselingObservationItems = ['A', 'B', 'C', 'D'];
  final List<String> affectedFieldsItems = ['A', 'B'];
  final List<String> nickCoverItems = ['A', 'B', 'C'];
  final List<String> cropUniformityItems = ['A', 'B', 'C'];
  final List<String> isolationItems = ['Y', 'N'];
  final List<String> isolationTypeItems = ['A', 'B'];
  final List<String> isolationDistanceItems = ['A', 'B', 'C', 'D'];
  final List<String> qPIRItems = ['Y', 'N'];
  final List<String> flaggingItems = ['GF', 'RFI', 'RFD', 'BF'];
  final List<String> recommendationItems = ['Continue', 'Discard'];
  final List<String> reasonPLDItems = ['A', 'B'];
  final List<String> reasonTidakTerauditItems = ['A', 'B', 'C'];

  @override
  void initState() {
    super.initState();
    row = List<String>.from(widget.row);

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
                  label: 'Ketersediaan Tenaga kerja DT',
                  items: tenagaKerjaDTItems,
                  value: selectedTenagaKerjaDT,
                  onChanged: (value) {
                    setState(() {
                      selectedTenagaKerjaDT = value;
                      row[36] = value ?? '';
                    });
                  },
                  helpText: 'Y = Yes\nN = No',
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
                      _showLoadingDialog();  // Tampilkan loading spinner
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
    // Pastikan bahwa nilai value ada di dalam items, jika tidak, set ke null
    if (!items.contains(value)) {
      value = null;
    }

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: helpText,
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
    );
  }

  // Fungsi untuk menampilkan loading spinner
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';
    final String worksheetTitle = 'Generative';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    const maxRetries = 5; // Maksimum jumlah percobaan
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await Future.delayed(const Duration(
            seconds: 2)); // Delay sebelum melakukan permintaan tulis
        await gSheetsApi.updateRow(worksheetTitle, rowData, rowData[2]);

        Navigator.of(context).pop(); // Tutup loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil disimpan!')),
        );
        Navigator.pop(context,
            rowData); // Kembali ke halaman detail dengan data yang diperbarui
        return; // Berhenti jika permintaan berhasil

      } catch (e) {
        print('Error saving data: $e');

        if (e.toString().contains('Quota exceeded')) {
          retryCount++; // Tingkatkan retry count jika ada error kuota

          // Hitung durasi delay berdasarkan exponential backoff
          int delaySeconds = pow(2, retryCount).toInt();
          await Future.delayed(Duration(seconds: delaySeconds));

          if (retryCount == maxRetries) {
            // Jika mencapai maksimal percobaan, tampilkan pesan error
            Navigator.of(context)
                .pop(); // Tutup loading spinner jika terjadi error
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(
                  'Gagal menyimpan data setelah beberapa percobaan!')),
            );
            return;
          }
        } else {
          // Jika error bukan terkait kuota, langsung tampilkan error
          Navigator.of(context)
              .pop(); // Tutup loading spinner jika terjadi error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan data!')),
          );
          return;
        }
      }
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
        print("Error converting number to date: $e");
      }
      return value;
    }
}

// Halaman Success untuk Generative
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Success'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Data has been successfully saved!',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
