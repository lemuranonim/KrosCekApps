import 'package:flutter/material.dart';
import 'google_sheets_api.dart'; // Import GoogleSheetsApi
import 'success_screen.dart';    // Import SuccessScreen untuk tampilan sukses

class IssueScreen extends StatefulWidget {
  final String selectedFA; // Terima district dari HomeScreen

  const IssueScreen({super.key, required this.selectedFA});

  @override
  _IssueScreenState createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  // Inisialisasi GoogleSheetsApi
  final GoogleSheetsApi _googleSheetsApi = GoogleSheetsApi('1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA');
  final String _worksheetTitle = 'Issue';

  @override
  void initState() {
    super.initState();
    _initGoogleSheets();
  }

  // Inisialisasi Google Sheets API
  Future<void> _initGoogleSheets() async {
    try {
      await _googleSheetsApi.init();
      print('Google Sheets API berhasil diinisialisasi.');
    } catch (e) {
      print('Error inisialisasi Google Sheets API: $e');
    }
  }

  Future<void> _submitData() async {
    final String issueTitle = _titleController.text.trim();
    final String detailIssue = _detailController.text.trim();
    final String area = widget.selectedFA; // Ambil district dari HomeScreen

    // Validasi jika data kosong
    if (issueTitle.isEmpty || detailIssue.isEmpty || area.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mohon isi semua kolom')),
      );
      return;
    }

    // Data yang akan dikirim ke Google Sheets
    final List<String> data = [
      issueTitle,
      area,
      detailIssue,
    ];

    try {
      // Kirim data ke Google Sheets
      await _googleSheetsApi.addRow(_worksheetTitle, data);

      // Setelah berhasil disimpan, navigasi ke halaman sukses
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const SuccessScreen(),
        ),
      );
    } catch (e) {
      print('Error submitting data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
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
            _buildDropdownField('Area (District)', widget.selectedFA), // Dropdown District
            _buildMultilineField('Detail issue', _detailController), // Multiline Field untuk detail issue
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitData, // Panggil submit data
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
