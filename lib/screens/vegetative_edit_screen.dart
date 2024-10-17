import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';  // Pastikan ini adalah API Anda untuk Google Sheets

class VegetativeEditScreen extends StatefulWidget {
  final List<String> row;

  const VegetativeEditScreen({super.key, required this.row});

  @override
  _VegetativeEditScreenState createState() => _VegetativeEditScreenState();
}

class _VegetativeEditScreenState extends State<VegetativeEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;
  late TextEditingController _actualPlantingDateController;

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

  final List<String> splitFieldItems = ['A', 'B'];
  final List<String> isolationProblemItems = ['Y', 'N'];
  final List<String> contaminantTypeItems = ['A', 'B'];
  final List<String> contaminantDistanceItems = ['A', 'B', 'C', 'D'];
  final List<String> cropUniformityItems = ['A', 'B', 'C'];
  final List<String> offtypeItems = ['A', 'B'];
  final List<String> firAppliedItems = ['Y', 'N'];
  final List<String> poiAccuracyItems = ['Valid', 'Not Valid'];
  final List<String> flaggingItems = ['GF', 'RF'];
  final List<String> recommendationItems = ['Continue', 'Discard'];

  @override
  void initState() {
    super.initState();
    row = List<String>.from(widget.row);

    // Initialize text controllers with existing data
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

  // Fungsi untuk membangun field date picker
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

  // Fungsi untuk menyimpan data yang diedit ke Google Sheets
  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA'; // ID Google Sheets Anda
    final String worksheetTitle = 'Vegetative'; // Nama worksheet

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init(); // Inisialisasi API Google Sheets

    const maxRetries = 5; // Maksimum jumlah percobaan
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await Future.delayed(const Duration(seconds: 2)); // Delay sebelum melakukan permintaan tulis
        await gSheetsApi.updateRow(worksheetTitle, rowData, rowData[2]);

        Navigator.of(context).pop(); // Tutup loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil disimpan!')),
        );
        Navigator.pop(context, rowData); // Kembali ke halaman detail dengan data yang diperbarui
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
            Navigator.of(context).pop(); // Tutup loading spinner jika terjadi error
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan data setelah beberapa percobaan!')),
            );
            return;
          }
        } else {
          // Jika error bukan terkait kuota, langsung tampilkan error
          Navigator.of(context).pop(); // Tutup loading spinner jika terjadi error
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
