import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';

class PreHarvestDetailScreen extends StatefulWidget {
  final List<String> row;

  const PreHarvestDetailScreen({super.key, required this.row});

  @override
  _PreHarvestDetailScreenState createState() => _PreHarvestDetailScreenState();
}

class _PreHarvestDetailScreenState extends State<PreHarvestDetailScreen> {
  List<String> row;

  String? selectedMaleRowsChopping;
  String? selectedCropHealth;
  String? selectedRecommendation;

  _PreHarvestDetailScreenState() : row = [];

  @override
  void initState() {
    super.initState();
    row = List<String>.from(widget.row);

    // Inisialisasi dropdown dengan nilai yang ada di row
    selectedMaleRowsChopping = row[32].isNotEmpty ? row[32] : null;
    selectedCropHealth = row[34].isNotEmpty ? row[34] : null;
    selectedRecommendation = row[36].isNotEmpty ? row[36] : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          row[2],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailCard('Field Information', [
                _buildDetailRow('Season', row[1]),
                _buildDetailRow('Farmer', row[3]),
                _buildDetailRow('Grower', row[4]),
                _buildDetailRow('Hybrid', row[5]),
                _buildDetailRow('Effective Area (Ha)', _convertToFixedDecimalIfNecessary(row[8])),
                _buildDetailRow('Planting Date PDN', _convertToDateIfNecessary(row[9])),
                _buildDetailRow('Desa', row[11]),
                _buildDetailRow('Kecamatan', row[12]),
                _buildDetailRow('Kabupaten', row[13]),
                _buildDetailRow('Field SPV', row[15]),
                _buildDetailRow('FA', row[16]),
              ]),
              const SizedBox(height: 20),
              _buildAdditionalInfoCard('Field Audit', [
                _buildDetailRow('QA FI', row[29]),
                _buildDetailRow('Date of Audit (dd/MM)', _convertToDateIfNecessary(row[30])),
                _buildDetailRow('MaleRowsChopping (MRC)', row[32]),
                _buildDetailRow('MRC Remarks', row[33]),
                _buildDetailRow('Crop Health', row[34]),
                _buildDetailRow('Crop Health Remarks', row[35]),
                _buildDetailRow('Recommendation', row[36]),
              ]),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _navigateToEditScreen(context);
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.edit),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: SizedBox(height: 50.0),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Column(children: children),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoCard(String title, List<Widget> children) {
    return Card(
      color: Colors.green[50],
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 10),
            Column(children: children),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value.isNotEmpty ? value : 'Kosong Lur...', // Menangani nilai kosong dengan aman
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
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

  void _navigateToEditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPreHarvestScreen(row: row),
      ),
    );

    if (updatedRow != null) {
      setState(() {
        row = updatedRow;
      });
    }
  }
}

// Fungsi untuk mengubah angka menjadi format 1 desimal jika diperlukan
String _convertToFixedDecimalIfNecessary(String value) {
  try {
    final parsedNumber = double.tryParse(value);
    if (parsedNumber != null) {
      return parsedNumber.toStringAsFixed(1); // Membulatkan ke 1 desimal
    }
  } catch (e) {
    print("Error converting number to fixed decimal: $e");
  }
  return value; // Kembalikan nilai asli jika bukan angka
}

// Halaman Edit untuk Pre Harvest
class EditPreHarvestScreen extends StatefulWidget {
  final List<String> row;

  const EditPreHarvestScreen({super.key, required this.row});

  @override
  _EditPreHarvestScreenState createState() => _EditPreHarvestScreenState();
}

class _EditPreHarvestScreenState extends State<EditPreHarvestScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();

  String? selectedMaleRowsChopping;
  String? selectedCropHealth;
  String? selectedRecommendation;
  late TextEditingController _dateAuditController;

  @override
  void initState() {
    super.initState();

    row = List<String>.from(widget.row);

    _dateAuditController = TextEditingController(text: _convertToDateIfNecessary(row[30]));

    selectedMaleRowsChopping = row[32].isNotEmpty ? row[32] : null;
    selectedCropHealth = row[34].isNotEmpty ? row[34] : null;
    selectedRecommendation = row[36].isNotEmpty ? row[36] : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pre Harvest Field'),
        backgroundColor: Colors.green,
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

                _buildDropdownFormField(
                  label: 'Male rows chopping',
                  items: ['A', 'B'],
                  value: selectedMaleRowsChopping,
                  onChanged: (value) {
                    setState(() {
                      selectedMaleRowsChopping = value;
                      row[32] = value ?? '';  // Pastikan tidak simpan null
                    });
                  },
                ),

                _buildTextFormField('Male rows chopping Remarks', 33),

                _buildDropdownFormField(
                  label: 'Crop Health',
                  items: ['A', 'B', 'C'],
                  value: selectedCropHealth,
                  onChanged: (value) {
                    setState(() {
                      selectedCropHealth = value;
                      row[34] = value ?? '';  // Pastikan tidak simpan null
                    });
                  },
                ),

                _buildTextFormField('Crop Health Remarks', 35),

                _buildDropdownFormField(
                  label: 'Recommendation',
                  items: ['Continue', 'Discard'],
                  value: selectedRecommendation,
                  onChanged: (value) {
                    setState(() {
                      selectedRecommendation = value;
                      row[36] = value ?? '';  // Pastikan tidak simpan null
                    });
                  },
                ),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _saveToGoogleSheets(row);
                    }
                  },
                  child: const Text('Save'),
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

  Widget _buildDropdownFormField({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      value: value,
      onChanged: onChanged,
      items: items.map<DropdownMenuItem<String>>((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
    );
  }

  Future<void> _saveToGoogleSheets(List<String> rowData) async {
    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';
    final String worksheetTitle = 'Pre Harvest';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    try {
      // Ambil fieldNumber dari data
      String fieldNumber = rowData[2]; // Asumsi bahwa fieldNumber ada di kolom ke-3

      // Periksa apakah baris dengan fieldNumber ada di Google Sheets
      bool rowExists = await gSheetsApi.checkRowExists(worksheetTitle, fieldNumber);
      if (!rowExists) {
        print('Baris dengan fieldNumber $fieldNumber tidak ditemukan.');
        throw Exception('Data tidak ditemukan untuk diperbarui.');
      }

      // Lakukan pembaruan jika baris ditemukan
      await gSheetsApi.updateRow(worksheetTitle, rowData, fieldNumber);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SuccessScreen()),
      );
    } catch (e) {
      print('Error saving data: $e');
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

// Halaman Success untuk Pre Harvest
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
