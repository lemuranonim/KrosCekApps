import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';

class PreHarvestEditScreen extends StatefulWidget {
  final List<String> row;

  const PreHarvestEditScreen({super.key, required this.row});

  @override
  PreHarvestEditScreenState createState() => PreHarvestEditScreenState();
}

class PreHarvestEditScreenState extends State<PreHarvestEditScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateAuditController;

  String? selectedMaleRowsChopping;
  String? selectedCropHealth;
  String? selectedRecommendation;

  final List<String> maleRowsChoppingItems = ['A', 'B'];
  final List<String> cropHealthItems = ['A', 'B', 'C'];
  final List<String> recommendationItems = ['Continue', 'Discard'];

  @override
  void initState() {
    super.initState();
    row = List<String>.from(widget.row);

    // Initialize text controllers with existing data
    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    // Initialize dropdown fields
    selectedMaleRowsChopping = row[32];
    selectedCropHealth = row[34];
    selectedRecommendation = row[36];
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
                _buildTextFormField('QA FI', 29),
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
    final String worksheetTitle = 'Pre Harvest';

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
