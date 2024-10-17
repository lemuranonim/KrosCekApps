import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'generative_edit_screen.dart';
import 'google_sheets_api.dart';

class GenerativeDetailScreen extends StatefulWidget { // Halaman detail untuk Generative
  final String fieldNumber;

  const GenerativeDetailScreen({super.key, required this.fieldNumber});

  @override
  GenerativeDetailScreenState createState() => GenerativeDetailScreenState(); // Menghapus underscore agar menjadi public
}

class GenerativeDetailScreenState extends State<GenerativeDetailScreen> {
  List<String> row = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA'; // ID Google Sheets Anda
    final String worksheetTitle = 'Generative';

    try {
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData(worksheetTitle);

      final fetchedRow = data.firstWhere(
            (row) => row[2] == widget.fieldNumber,
        orElse: () => [],
      );

      setState(() {
        row = fetchedRow.isNotEmpty ? fetchedRow : ['Data not found'];
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching data: $e"); // Ganti print dengan debugPrint
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
          row.isNotEmpty ? row[2] : 'Loading...',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                _buildDetailRow('QA FI', row[31]),
                _buildDetailRow('Date of Audit 1 (dd/MM)', _convertToDateIfNecessary(row[32])),
                _buildDetailRow('Rev Planting Date Based', _convertToDateIfNecessary(row[34])),
                _buildDetailRow('Detaseling Plan (Form)', row[35]),
                _buildDetailRow('Labor Availability for DT', row[36]),
                _buildDetailRow('Roguing Proses', row[37]),
                _buildDetailRow('Remarks Roguing Proses', row[38]),
                _buildDetailRow('Labor Detasseling Process', row[39]),
                _buildDetailRow('Date of Audit 2 (dd/MM)', _convertToDateIfNecessary(row[40])),
                _buildDetailRow('Female Shed.', row[42]),
                _buildDetailRow('Shedding Offtype & CVL M', row[43]),
                _buildDetailRow('Shedding Offtype & CVL F', row[44]),
                _buildDetailRow('Date of Audit 3 (dd/MM)', _convertToDateIfNecessary(row[45])),
                _buildDetailRow('Female Shed.', row[47]),
                _buildDetailRow('Shedding Offtype & CVL M', row[48]),
                _buildDetailRow('Shedding Offtype & CVL F', row[49]),
                _buildDetailRow('StandingCropOfftype&CVLm', row[50]),
                _buildDetailRow('StandingCropOfftype&CVLf', row[51]),
                _buildDetailRow('LSV Ditemukan', row[52]),
                _buildDetailRow('Detasseling Process Observ.', row[53]),
                _buildDetailRow('Affected by other fields', row[54]),
                _buildDetailRow('Nick Cover', row[55]),
                _buildDetailRow('Crop Uniformity', row[56]),
                _buildDetailRow('Isolation (Y/N)', row[57]),
                _buildDetailRow('If "YES" IsolationType', row[58]),
                _buildDetailRow('If "YES" IsolationDist. (m)', row[59]),
                _buildDetailRow('QPIR Applied', row[60]),
                _buildDetailRow('Closed out Date', _convertToDateIfNecessary(row[61])),
                _buildDetailRow('FLAGGING', row[62]),
                _buildDetailRow('Recommendation', row[63]),
                _buildDetailRow('Remarks', row[64]),
                _buildDetailRow('Recommendation PLD (Ha)', _convertToFixedDecimalIfNecessary(row[65])),
                _buildDetailRow('Reason PLD', row[66]),
                _buildDetailRow('Reason Tidak Teraudit', row[67]),
              ]),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _navigateToEditScreen(context);
          await _fetchData();
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
      debugPrint("Error converting number to date: $e"); // Ganti print dengan debugPrint
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
      debugPrint("Error converting number to fixed decimal: $e"); // Ganti print dengan debugPrint
    }
    return value;
  }

  Future<void> _navigateToEditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerativeEditScreen(row: row),
      ),
    );

    if (updatedRow != null) {
      setState(() {
        row = updatedRow;
      });
    }
  }
}
