import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';  // Tambahkan ini untuk menggunakan url_launcher
import 'vegetative_edit_screen.dart';
import 'google_sheets_api.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'config_manager.dart';

class VegetativeDetailScreen extends StatefulWidget {
  final String fieldNumber;
  final String region;

  const VegetativeDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  VegetativeDetailScreenState createState() => VegetativeDetailScreenState();
}

class VegetativeDetailScreenState extends State<VegetativeDetailScreen> {
  List<String>? row;
  bool isLoading = true;

  String _mapImageUrl = ''; // URL untuk Google Static Maps
  double? latitude;
  double? longitude;

  final double defaultLat = -7.637017;
  final double defaultLng = 112.8272303;

  late String spreadsheetId;

  @override
  void initState() {
    super.initState();
    _initializeHive(); // Inisialisasi Hive saat aplikasi dimulai
    _determineSpreadsheetId().then((_) {
      _loadDataFromCacheOrFetch(); // Mulai memuat data setelah spreadsheetId diatur
    });
  }

  Future<void> _determineSpreadsheetId() async {
    spreadsheetId = ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  Future<void> _initializeHive() async {
    await Hive.initFlutter(); // Inisialisasi Hive Flutter
  }

  @override
  void dispose() {
    Hive.close(); // Tutup semua kotak Hive saat aplikasi keluar
    super.dispose();
  }

  // Fungsi utama untuk mengecek cache atau mengambil data dari Google Sheets
  Future<void> _loadDataFromCacheOrFetch() async {
    final box = await Hive.openBox('vegetativeData');
    final cacheKey = 'detailScreenData_${widget.fieldNumber}';
    final cachedData = box.get(cacheKey);

    if (cachedData != null) {
      // Konversi cachedData menjadi Map<String, dynamic>
      _setDataFromCache(Map<String, dynamic>.from(cachedData));
      setState(() => isLoading = false);
    } else {
      await _fetchData();
      await _saveDataToCache();
    }
  }

  Future<void> _saveDataToCache() async {
    final box = Hive.box('vegetativeData');
    final cacheKey = 'detailScreenData_${widget.fieldNumber}';
    await box.put(cacheKey, {
      'row': row,
      'latitude': latitude,
      'longitude': longitude,
      'mapImageUrl': _mapImageUrl,
    });
  }

  void _setDataFromCache(Map<String, dynamic> cachedData) {
    setState(() {
      row = List<String>.from(cachedData['row']);
      latitude = cachedData['latitude'];
      longitude = cachedData['longitude'];
      _mapImageUrl = cachedData['mapImageUrl'];
    });
  }

  // Fungsi _fetchData tetap sama untuk mengambil data dari Google Sheets
  Future<void> _fetchData() async {
    if (spreadsheetId.isEmpty) {
      throw Exception("Spreadsheet ID belum diatur.");
    }

    setState(() => isLoading = true);

    try {
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData('Vegetative');
      final fetchedRow = data.firstWhere((row) => row[2] == widget.fieldNumber);

      final String coordinatesStr = fetchedRow[17];
      final coordinates = _parseCoordinates(coordinatesStr);

      latitude = coordinates['lat'] ?? defaultLat;
      longitude = coordinates['lng'] ?? defaultLng;
      _mapImageUrl = _buildStaticMapUrl(latitude, longitude);

      setState(() {
        row = fetchedRow;
        isLoading = false;
      });
    } catch (e) {
      latitude = defaultLat;
      longitude = defaultLng;
      _mapImageUrl = _buildStaticMapUrl(latitude, longitude);
      setState(() => isLoading = false);
    }
  }

  // Fungsi untuk memperbarui data ketika pengguna melakukan pull-to-refresh
  Future<void> _refreshData() async {
    await _fetchData();  // Ambil data terbaru dari Google Sheets
    _saveDataToCache();  // Simpan data baru ke dalam cache
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

    final double lat = latitude ?? defaultLat;  // Default ke yang diberikan
    final double lng = longitude ?? defaultLng;  // Default ke yang diberikan

    return '$baseUrl?center=$lat,$lng&zoom=$zoomLevel&size=$mapSize'
        '&markers=color:red%7C$lat,$lng&key=$apiKey';
  }

  Future<void> _openMaps() async {
    final lat = latitude ?? defaultLat;
    final lng = longitude ?? defaultLng;

    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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
          row != null ? row![2] : 'Loading...',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LiquidPullToRefresh(
        onRefresh: _refreshData,  // Menentukan fungsi untuk refresh
        color: Colors.green,
        backgroundColor: Colors.white,
        showChildOpacityTransition: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              _buildInteractiveMap(), // Peta Statis
              const SizedBox(height: 10),
              _buildCoordinatesText(), // Tampilkan koordinat
              const SizedBox(height: 10),
              _buildDetailCard('Field Information', [
                _buildDetailRow('Season', row![1]),
                _buildDetailRow('Farmer', row![3]),
                _buildDetailRow('Grower', row![4]),
                _buildDetailRow('Hybrid', row![5]),
                _buildDetailRow('Effective Area (Ha)', _convertToFixedDecimalIfNecessary(row![8])),
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
                _buildDetailRow('Male Split by Audit', _convertToFixedDecimalIfNecessary(row![37])),
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
        crossAxisAlignment: CrossAxisAlignment.start, // Menyelaraskan konten agar vertikal
        children: [
          Expanded( // Menggunakan Expanded untuk mengatasi masalah overflow pada teks
            flex: 2,
            child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10), // Menambahkan sedikit ruang antara label dan value
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Kosong Lur...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              softWrap: true,  // Membungkus teks jika terlalu panjang
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
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
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
        builder: (context) => VegetativeEditScreen(
          row: row!,
          region: widget.region, // Tambahkan parameter region di sini
          onSave: (updatedActivity) {
            setState(() {
              row = updatedActivity;
            });
          },
        ),
      ),
    );

    if (updatedRow != null) {
      setState(() {
        row = updatedRow; // Update row setelah di-edit
      });
    }
  }
}
