import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'vegetative_edit_screen.dart'; // Pastikan Anda memiliki file edit screen terpisah
import 'google_sheets_api.dart'; // Pastikan Anda menggunakan API Google Sheets

class VegetativeDetailScreen extends StatefulWidget {
  final String fieldNumber; // Field number yang digunakan untuk mengambil data terbaru

  const VegetativeDetailScreen({super.key, required this.fieldNumber});

  @override
  _VegetativeDetailScreenState createState() => _VegetativeDetailScreenState();
}

class _VegetativeDetailScreenState extends State<VegetativeDetailScreen> {
  List<String>? row;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData(); // Ambil data terbaru saat halaman dimuat pertama kali
  }

  // Ambil data terbaru dari Google Sheets berdasarkan fieldNumber
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA'; // ID Google Sheets Anda
    final String worksheetTitle = 'Vegetative';

    try {
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData(worksheetTitle);
      // Filter data berdasarkan fieldNumber
      final fetchedRow = data.firstWhere((row) => row[2] == widget.fieldNumber);

      setState(() {
        row = fetchedRow;
        isLoading = false; // Matikan indikator loading setelah data berhasil diambil
      });
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          row != null ? row![2] : 'Loading...',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Tampilkan loading jika sedang mengambil data
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailCard('Field Information', [
                _buildDetailRow('Season', row![1]),
                _buildDetailRow('Farmer', row![3]),
                _buildDetailRow('Grower', row![4]),
                _buildDetailRow('Hybrid', row![5]),
                _buildDetailRow('Effective Area (Ha)', row![8]),
                _buildDetailRow('Planting Date PDN', _convertToDateIfNecessary(row![9])),
                _buildDetailRow('Desa', row![11]),
                _buildDetailRow('Kecamatan', row![12]),
                _buildDetailRow('Kabupaten', row![13]),
                _buildDetailRow('Field SPV', row![15]),
                _buildDetailRow('FA', row![16]),
                _buildDetailRow('Week of Vegetative', row![29]),
              ]),
              const SizedBox(height: 20),
              _buildAdditionalInfoCard('Field Audit', [
                _buildDetailRow('QA FI', row![31]),
                _buildDetailRow('Co Detasseling', row![32]),
                _buildDetailRow('Date of Audit', _convertToDateIfNecessary(row![33])),
                _buildDetailRow('Actual Female Planting Date', _convertToDateIfNecessary(row![35])),
                _buildDetailRow('Field Size by Audit (Ha)', _convertToFixedDecimalIfNecessary(row![36])),
                _buildDetailRow('Male Split by Audit', row![37]),
                _buildDetailRow('Sowing Ratio by Audit', row![38]),
                _buildDetailRow('Split Field by Audit', row![39]),
                _buildDetailRow('Isolation Problem by Audit', row![40]),
                _buildDetailRow('If "YES" Contaminant Type', row![41]),
                _buildDetailRow('If "YES" Contaminant Dist.', row![42]),
                _buildDetailRow('Crop Uniformity', row![43]),
                _buildDetailRow('Offtype in Male', row![44]),
                _buildDetailRow('Offtype in Female', row![45]),
                _buildDetailRow('Previous Crop by Audit', row![46]),
                _buildDetailRow('FIR Applied', row![47]),
                _buildDetailRow('POI Accuracy', row![48]),
                _buildDetailRow('Flagging', row![49]),
                _buildDetailRow('Recommendation', row![50]),
                _buildDetailRow('Remarks', row![51]),
              ]),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _navigateToEditScreen(context); // Pindah ke halaman edit dan tunggu hasil
          await _fetchData(); // Setelah kembali dari halaman edit, ambil data terbaru
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.edit, color: Colors.white),
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
                  color: Colors.green
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
                  color: Colors.green
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
                  fontWeight: FontWeight.w500
              )
          ),
          Text(
              value.isNotEmpty ? value : 'Kosong Lur...',
              style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey
              )
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

  String _convertToFixedDecimalIfNecessary(String value) {
    try {
      final parsedNumber = double.tryParse(value);
      if (parsedNumber != null) {
        return parsedNumber.toStringAsFixed(1); // Membulatkan ke 1 desimal
      }
    } catch (e) {
      print("Error converting number to fixed decimal: $e");
    }
    return value;
  }

  Future<void> _navigateToEditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VegetativeEditScreen(row: row!), // Pindah ke halaman edit dengan data row
      ),
    );

    if (updatedRow != null) {
      setState(() {
        row = updatedRow;  // Update row setelah di-edit
      });
    }
  }
}
