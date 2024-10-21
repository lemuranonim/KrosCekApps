import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'harvest_edit_screen.dart';
import 'google_sheets_api.dart';

class HarvestDetailScreen extends StatefulWidget {
  final String fieldNumber;

  const HarvestDetailScreen({super.key, required this.fieldNumber});

  @override
  HarvestDetailScreenState createState() => HarvestDetailScreenState();
}

class HarvestDetailScreenState extends State<HarvestDetailScreen> {
  List<String> row = [];
  bool isLoading = true;

  String _mapImageUrl = ''; // URL untuk Google Static Maps
  double? latitude;
  double? longitude;

  // Koordinat default jika tidak ditemukan dalam data Google Sheets
  final double defaultLat = -7.637017;
  final double defaultLng = 112.8272303;


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';
    final String worksheetTitle = 'Harvest';

    try {
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData(worksheetTitle);
      final fetchedRow = data.firstWhere((row) => row[2] == widget.fieldNumber);

      final String coordinatesStr = fetchedRow[17]; // Example: '-7.986511,111.976340'
      final coordinates = _parseCoordinates(coordinatesStr);

      // Gunakan koordinat yang ditemukan atau default jika tidak ada
      latitude = coordinates['lat'] ?? defaultLat;
      longitude = coordinates['lng'] ?? defaultLng;

      // Buat URL untuk Google Static Maps
      _mapImageUrl = _buildStaticMapUrl(latitude, longitude);

      setState(() {
        row = fetchedRow;
        isLoading = false;
      });
    } catch (e) {
      // Jika terjadi error, gunakan koordinat default
      latitude = defaultLat;
      longitude = defaultLng;
      _mapImageUrl = _buildStaticMapUrl(latitude, longitude);

      setState(() {
        isLoading = false;
      });
    }
  }

  Map<String, double?> _parseCoordinates(String coordinatesStr) {
    try {
      final List<String> parts = coordinatesStr.split(',');
      final double latitude = double.parse(parts[0]);
      final double longitude = double.parse(parts[1]);
      return {'lat': latitude, 'lng': longitude};
    } catch (e) {
      return {'lat': null, 'lng': null}; // Nilai null jika parsing gagal
    }
  }

  String _buildStaticMapUrl(double? latitude, double? longitude) {
    const String apiKey = 'AIzaSyDNZoDIH3DjLrz77c-ihr0HLhYrgPtfKKc'; // Ganti dengan API Key Anda
    const String baseUrl = 'https://maps.googleapis.com/maps/api/staticmap';
    const int zoomLevel = 15;
    const String mapSize = '600x400';

    // Gunakan nilai default jika latitude atau longitude null
    final double lat = latitude ?? defaultLat; // Default ke yang diberikan
    final double lng = longitude ?? defaultLng; // Default ke yang diberikan

    // URL dengan marker di posisi lat/lng
    return '$baseUrl?center=$lat,$lng&zoom=$zoomLevel&size=$mapSize'
        '&markers=color:red%7C$lat,$lng&key=$apiKey';
  }

  Future<void> _openMaps() async {
    final lat = latitude ?? defaultLat;
    final lng = longitude ?? defaultLng;

    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$lat,$lng');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl); // Buka Google Maps
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl); // Buka Apple Maps sebagai alternatif
    } else {
      throw 'Tidak dapat membuka peta.';
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
              _buildInteractiveMap(),
              const SizedBox(height: 10),
              _buildCoordinatesText(),
              const SizedBox(height: 10),
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
                _buildDetailRow('Week of Harvest', buildWeekOfHarvest(row)),
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
                _buildDetailRow('Reason to Downgrade Flag.', row[38]),
                _buildDetailRow('Downgrade Flagging Recommendation', row[39]),
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

  // Widget untuk menampilkan peta statis dari Google Static Maps dengan GestureDetector
  Widget _buildInteractiveMap() {
    return GestureDetector(
      onTap: _openMaps, // Buka aplikasi maps saat peta diklik
      child: _mapImageUrl.isNotEmpty
          ? Image.network(
        _mapImageUrl,
        fit: BoxFit.cover,
        height: 250,
        width: double.infinity,
      )
          : const SizedBox.shrink(), // Tidak ada gambar jika URL tidak ada
    );
  }

  // Widget untuk menampilkan koordinat
  Widget _buildCoordinatesText() {
    return Text(
      latitude != null && longitude != null
          ? 'Koordinat: $latitude, $longitude'
          : 'Koordinat tidak tersedia',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded( // Menggunakan Expanded untuk mengatasi masalah overflow pada teks
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          // Menambahkan sedikit ruang antara label dan value
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Kosong Lur...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              softWrap: true, // Membungkus teks jika terlalu panjang
              overflow: TextOverflow.visible, // Memastikan teks tidak terpotong
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
        final date = DateTime(1899, 12, 30).add(
            Duration(days: parsedNumber.toInt()));
        return DateFormat('dd/MM/yyyy').format(date);
      }
    } catch (e) {
      // jeda
    }
    return value;
  }

  String _convertToFixedDecimalIfNecessary(String value) {
    try {
      final parsedNumber = double.tryParse(value);
      if (parsedNumber != null) {
        return parsedNumber.toStringAsFixed(1);
      }
    } catch (e) {
      // jeda
    }
    return value;
  }

  Future<void> _navigateToEditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HarvestEditScreen(row: row),
      ),
    );

    if (updatedRow != null) {
      setState(() {
        row = updatedRow;
      });
    }
  }
}

// Set untuk Validasi Week of Harvest

int getWeekNumber(DateTime date) {
  int dayOfYear = int.parse(DateFormat("D").format(date));
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

DateTime excelSerialToDate(int serial) {
  // Excel/Google Sheets menggunakan 30 Desember 1899 sebagai tanggal awal
  return DateTime(1899, 12, 30).add(Duration(days: serial));
}

String buildWeekOfHarvest(List<String> row) {
  // Cek apakah kolom I (row[8]) adalah 0 atau kosong
  if (row[8] == "0" || row[8].isEmpty) {
    return "";  // Jika benar, kembalikan string kosong
  }

  // Coba konversi row[26] (serial number Excel/Google Sheets) menjadi tanggal
  String dateStr = row[26];
  int? serialNumber = int.tryParse(dateStr);  // Coba konversi string menjadi integer serial number

  if (serialNumber != null) {
    // Jika serial number valid, ubah ke DateTime
    DateTime date = excelSerialToDate(serialNumber);

    // Hitung nomor minggu dan kembalikan hasilnya
    return getWeekNumber(date).toString();
  }
  return "Tanggal tidak tersedia";  // Jika serial number tidak valid
}
