import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';
import 'psp_success_screen.dart';

class PspIssueScreen extends StatefulWidget {
  final Function(List<String>) onSave;
  final String selectedFA;

  const PspIssueScreen({
    super.key,
    required this.selectedFA,
    required this.onSave,
  });

  @override
  PspIssueScreenState createState() => PspIssueScreenState();
}

class PspIssueScreenState extends State<PspIssueScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  String? _spreadsheetId;
  final String _worksheetTitle = 'Issue';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSpreadsheetId();
  }

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
    setState(() {
      _isLoading = true;
    });

    final String issueTitle = _titleController.text.trim();
    final String detailIssue = _detailController.text.trim();
    final String area = widget.selectedFA;

    if (_spreadsheetId == null) {
      _showErrorSnackBar('Please select a region before saving the issue!');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (issueTitle.isEmpty || detailIssue.isEmpty || area.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final List<String> data = [
      issueTitle,
      area,
      detailIssue,
    ];

    final GoogleSheetsApi googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
    final navigator = Navigator.of(context);

    try {
      await googleSheetsApi.init();
      await googleSheetsApi.addRow(_worksheetTitle, data);

      setState(() {
        _isLoading = false;
      });

      navigator.push(
        MaterialPageRoute(
          builder: (context) => const PspSuccessScreen(),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to save data');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report Issue',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.orange.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Issue Title',
                    _titleController,
                    Icons.title,
                    'Enter a descriptive title',
                  ),
                  const SizedBox(height: 16),
                  _buildAreaField('Area (District)', widget.selectedFA),
                  const SizedBox(height: 16),
                  _buildMultilineField(
                    'Detail Issue',
                    _detailController,
                    Icons.description,
                    'Describe the issue in detail',
                  ),
                  const SizedBox(height: 30),
                  _buildSubmitButton(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      String hint,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaField(String label, String selectedFA) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
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
                // Disable interaction
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultilineField(
      String label,
      TextEditingController controller,
      IconData icon,
      String hint,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitData,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? Center(child: Lottie.asset('assets/loading.json'))
          : const Text('Ngirim', style: TextStyle(fontSize: 16)),
    );
  }
}