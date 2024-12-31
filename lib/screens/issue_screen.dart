import 'package:flutter/material.dart';
import 'google_sheets_api.dart';
import 'success_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_manager.dart'; // Import ConfigManager

class IssueScreen extends StatefulWidget {
  final Function(List<String>) onSave;
  final String selectedFA; // Terima district dari HomeScreen

  const IssueScreen({
    super.key,
    required this.selectedFA,
    required this.onSave,
  });

  @override
  IssueScreenState createState() => IssueScreenState();
}

class IssueScreenState extends State<IssueScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  String? _spreadsheetId; // Tambahkan variabel Spreadsheet ID
  final String _worksheetTitle = 'Issue';

  @override
  void initState() {
    super.initState();
    _loadSpreadsheetId(); // Ambil Spreadsheet ID sesuai Region
  }

  // Ambil Spreadsheet ID dari ConfigManager
  Future<void> _loadSpreadsheetId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? selectedRegion = prefs.getString('selectedRegion');
    if (selectedRegion != null) {
      setState(() {
        _spreadsheetId = ConfigManager.getSpreadsheetId(selectedRegion);
      });
    }
  }

  Future<void> _submitData() async {
    final String issueTitle = _titleController.text.trim();
    final String detailIssue = _detailController.text.trim();
    final String area = widget.selectedFA; // Ambil district dari HomeScreen

    // Validasi input
    if (_spreadsheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Region terlebih dahulu sebelum menyimpan issue!')),
      );
      return;
    }
    if (issueTitle.isEmpty || detailIssue.isEmpty || area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi semua kolom')),
      );
      return;
    }

    final List<String> data = [
      issueTitle,
      area,
      detailIssue,
    ];

    final GoogleSheetsApi googleSheetsApi = GoogleSheetsApi(_spreadsheetId!); // Inisialisasi dinamis
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await googleSheetsApi.init(); // Inisialisasi API
      await googleSheetsApi.addRow(_worksheetTitle, data); // Kirim data ke Google Sheets

      navigator.push(
        MaterialPageRoute(
          builder: (context) => const SuccessScreen(),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan data')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Issue',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildTextField('Issue Title', _titleController),
            _buildDropdownField('Area (District)', widget.selectedFA),
            _buildMultilineField('Detail issue', _detailController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String selectedFA) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButton<String>(
          value: selectedFA,
          isExpanded: true,
          items: <String>[selectedFA].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            // Disable interaction (hanya satu pilihan)
          },
        ),
      ),
    );
  }

  Widget _buildMultilineField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        maxLines: 5, // Membuat kolom input menjadi multiline
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
