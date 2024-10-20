import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';// Pastikan ini adalah API Anda untuk Google Sheets

class HarvestEditScreen extends StatefulWidget {
  final List<String> row;

  const HarvestEditScreen({super.key, required this.row});

  @override
  HarvestEditScreenState createState() => HarvestEditScreenState();
}

class HarvestEditScreenState extends State<HarvestEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

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
    row = List<String>.from(widget.row);

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    // Inisialisasi dropdown dengan nilai yang ada di row
    selectedEarConditionObservation = row[32];
    selectedCropHealth = row[34];
    selectedRecommendation = row[36];
    selectedReasonToDowngradeFlagging = row[38];
    selectedDowngradeFlaggingRecommendation = row[39];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Field Audit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

                const SizedBox(height: 10),

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
                      _showLoadingDialog();
                      _saveToGoogleSheets(row);
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
    final String worksheetTitle = 'Harvest';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    const maxRetries = 5;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await Future.delayed(const Duration(seconds: 2));
        await gSheetsApi.updateRow(worksheetTitle, rowData, rowData[2]);

        if (!mounted) return; // Pastikan widget masih mounted
        Navigator.of(context).pop(); // Tutup loading spinner

        if (!mounted) return; // Pastikan widget masih mounted sebelum menampilkan SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil disimpan!')),
        );

        if (!mounted) return; // Pastikan widget masih mounted sebelum melakukan navigasi
        Navigator.pop(context, rowData);
        return;

      } catch (e) {
        if (e.toString().contains('Quota exceeded')) {
          retryCount++;

          int delaySeconds = pow(2, retryCount).toInt();
          await Future.delayed(Duration(seconds: delaySeconds));

          if (retryCount == maxRetries) {
            if (!mounted) return; // Pastikan widget masih mounted
            Navigator.of(context).pop();

            if (!mounted) return; // Pastikan widget masih mounted sebelum menampilkan SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal menyimpan data setelah beberapa percobaan!')),
            );
            return;
          }
        } else {
          if (!mounted) return; // Pastikan widget masih mounted
          Navigator.of(context).pop();

          if (!mounted) return; // Pastikan widget masih mounted sebelum menampilkan SnackBar
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
      // jeda
    }
    return value;
  }
}

// Halaman Success untuk Harvest
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
