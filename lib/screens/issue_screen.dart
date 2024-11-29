import 'package:flutter/material.dart';
import 'google_sheets_api.dart'; // Import GoogleSheetsApi
import 'success_screen.dart';    // Import SuccessScreen untuk tampilan sukses
import 'package:http/http.dart' as http;  // Import http package for POST request
import 'dart:convert';  // Tambahkan ini untuk mendukung jsonEncode
import 'package:shared_preferences/shared_preferences.dart';  // Import SharedPreferences untuk userName

class IssueScreen extends StatefulWidget {
  final Function(List<String>) onSave;
  final String selectedFA; // Terima district dari HomeScreen

  const IssueScreen({super.key, required this.selectedFA, required this.onSave});

  @override
  IssueScreenState createState() => IssueScreenState();
}

class IssueScreenState extends State<IssueScreen> {
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
    } catch (e) {
      // Hapus print, tidak mencatat error
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

    // Simpan Navigator dan ScaffoldMessenger sebelum async
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Kirim data ke Google Sheets
      await _googleSheetsApi.addRow(_worksheetTitle, data);

      // Panggil fungsi untuk mengirim POST request ke Apps Script setelah berhasil menyimpan
      await _sendPostToHistory(data);

      // Setelah berhasil disimpan, navigasi ke halaman sukses
      navigator.push(
        MaterialPageRoute(
          builder: (context) => const SuccessScreen(),
        ),
      );
    } catch (e) {
      // Tampilkan error menggunakan ScaffoldMessenger yang disimpan
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan data')),
      );
    }
  }

  Future<void> _sendPostToHistory(List<String> rowData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userName = prefs.getString('userName') ?? 'Unknown User';

    final String url = 'https://script.google.com/macros/s/AKfycbwg3XKvFj9tsCCI9eJjHkcF508nqi-kFPXBfPeeJoOssdNTXgT10jV_VAlAebd7QzmZiw/exec';  // Sesuaikan dengan URL Apps Script Anda

    // Susun data yang akan dikirim dalam format JSON
    final Map<String, dynamic> historyData = {
      'pageType': 'issue',  // Tipe halaman, di sini adalah "issue"
      'action': 'add',  // Aksi yang dilakukan
      'rowData': rowData,  // Data yang disimpan
      'user': userName,  // Nama pengguna yang melakukan perubahan
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(historyData),  // Encode data ke format JSON
      );

      if (response.statusCode == 200) {
        debugPrint('Data berhasil dicatat di History');
      } else {
        debugPrint('Gagal mencatat data di History: ${response.body}');
        debugPrint('Response status: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error saat mengirim data ke History: $error');
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
