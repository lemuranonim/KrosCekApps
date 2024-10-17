import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'google_sheets_api.dart';

class HarvestDetailScreen extends StatefulWidget {
  final List<String> row;

  const HarvestDetailScreen({super.key, required this.row});

  @override
  _HarvestDetailScreenState createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen> {
  List<String> row;

  _HarvestDetailScreenState() : row = [];

  @override
  void initState() {
    super.initState();
    row = List<String>.from(widget.row);
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
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailCard('Field Information', [
                _buildDetailRow('Season', row[1]),
                _buildDetailRow('Farmer', row[3]),
                _buildDetailRow('Grower', row[4]),
                _buildDetailRow('Hybrid', row[5]),
                _buildDetailRow('EffectiveAreaHa', _convertToFixedDecimalIfNecessary(row[8])),
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
                _buildDetailRow('Ear Condition Observation', row[32]),
                _buildDetailRow('Moisture Content - %', row[33]),
                _buildDetailRow('Crop Health', row[34]),
                _buildDetailRow('Remarks', row[35]),
                _buildDetailRow('Recommendation', row[36]),
                _buildDetailRow('Date of Downgrade Flag.', row[37]),
                _buildDetailRow('ReasonToDowngradeFlag.', row[38]),
                _buildDetailRow('DowngradeFlaggingRecom.', row[39]),
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
            value.isNotEmpty ? value : 'Kosong Lur...',
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
        builder: (context) => EditHarvestScreen(row: row),
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

// Halaman Edit untuk Harvest
class EditHarvestScreen extends StatefulWidget {
  final List<String> row;

  const EditHarvestScreen({super.key, required this.row});

  @override
  _EditHarvestScreenState createState() => _EditHarvestScreenState();
}

class _EditHarvestScreenState extends State<EditHarvestScreen> {
  late List<String> row;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dateAuditController;

  String? selectedEarConditionObservation;
  String? selectedCropHealth;
  String? selectedRecommendation;
  String? selectedReasonToDowngradeFlagging;
  String? selectedDowngradeFlaggingRecommendation;

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
                  items: ['2', '3', '2'],
                  value: selectedEarConditionObservation,
                  onChanged: (value) {
                    setState(() {
                      selectedEarConditionObservation = value;
                      row[32] = value ?? '';
                    });
                  },
                ),

                _buildTextFormField('Moisture Content - %', 33),

                _buildDropdownFormField(
                  label: 'Crop Health',
                  items: ['A', 'B', 'C'],
                  value: selectedCropHealth,
                  onChanged: (value) {
                    setState(() {
                      selectedCropHealth = value;
                      row[34] = value ?? '';
                    });
                  },
                ),

                _buildTextFormField('Remarks', 35),

                _buildDropdownFormField(
                  label: 'Recommendation',
                  items: ['Continue', 'Discard'],
                  value: selectedRecommendation,
                  onChanged: (value) {
                    setState(() {
                      selectedRecommendation = value;
                      row[36] = value ?? '';
                    });
                  },
                ),

                _buildTextFormField('Date of Downgrade Flagging', 37),

                _buildDropdownFormField(
                  label: 'Reason to Downgrade Flagging',
                  items: ['A', 'B', 'C', 'D'],
                  value: selectedReasonToDowngradeFlagging,
                  onChanged: (value) {
                    setState(() {
                      selectedReasonToDowngradeFlagging = value;
                      row[38] = value ?? '';
                    });
                  },
                ),

                const SizedBox(height: 10),

                _buildDropdownFormField(
                  label: 'Downgrade Flagging Recommendation',
                  items: ['RFI', 'RFD'],
                  value: selectedDowngradeFlaggingRecommendation,
                  onChanged: (value) {
                    setState(() {
                      selectedDowngradeFlaggingRecommendation = value;
                      row[39] = value ?? '';
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

  Widget _buildDropdownFormField({
    required String label,
    required List<String> items,
    required String? value,
    required Function(String?) onChanged,
  }) {
    // Jika nilai tidak ada di dalam daftar item, set nilai awal menjadi null
    if (!items.contains(value)) {
      value = null;
    }

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
    final String worksheetTitle = 'Harvest';

    final gSheetsApi = GoogleSheetsApi(spreadsheetId);
    await gSheetsApi.init();

    try {
      await gSheetsApi.updateRow(worksheetTitle, rowData, rowData[2]);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SuccessScreen()),
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
