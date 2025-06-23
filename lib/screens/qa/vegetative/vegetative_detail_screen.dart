import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:url_launcher/url_launcher.dart';  // Tambahkan ini untuk menggunakan url_launcher

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';
import 'vegetative_edit_screen.dart';

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
    });
  }

  void _setDataFromCache(Map<String, dynamic> cachedData) {
    setState(() {
      row = List<String>.from(cachedData['row']);
      latitude = cachedData['latitude'];
      longitude = cachedData['longitude'];
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

      final String coordinatesStr = fetchedRow[16];
      final coordinates = _parseCoordinates(coordinatesStr);

      latitude = coordinates['lat'] ?? defaultLat;
      longitude = coordinates['lng'] ?? defaultLng;

      setState(() {
        row = fetchedRow;
        isLoading = false;
      });
    } catch (e) {
      latitude = defaultLat;
      longitude = defaultLng;
      setState(() => isLoading = false);
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

  int _calculateDAP(List<String> row) {
    try {
      // Use _convertToDateIfNecessary to get the planting date
      final plantingDateString = row[9]; // Access planting date directly from row
      final plantingDate = _convertToDateIfNecessary(plantingDateString);

      // Parse the converted date string
      final parsedDate = DateFormat('dd/MM/yyyy').parse(plantingDate);
      final today = DateTime.now(); // Keep today as DateTime for calculation

      return today.difference(parsedDate).inDays; // Calculate the difference in days
    } catch (e) {
      return 0; // Return 0 if there's an error in parsing
    }
  }

  String getFormattedToday() {
    final today = DateTime.now();
    return DateFormat('dd/MM/yyyy').format(today);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          row != null ? row![2] : 'Loading...',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20, // Increased font size for better visibility
          ),
        ),
        backgroundColor: Colors.green.shade700, // Darker green for a premium look
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4, // Subtle elevation for depth
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20), // Rounded bottom corners
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Action for info button
              _showInfoDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: () async {
              await _fetchData();
              _saveDataToCache();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: Lottie.asset('assets/loading.json'))
          : SingleChildScrollView(
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
                _buildDetailRow('DAP', _calculateDAP(row!).toString()),
                _buildDetailRow('Desa', row![11]),
                _buildDetailRow('Kecamatan', row![12]),
                _buildDetailRow('Kabupaten', row![13]),
                _buildDetailRow('FA', row![14]),
                _buildDetailRow('Field SPV', row![15]),
                _buildDetail2Row('FASE', row![27]),
                _buildDetail2Row('Veg Audit (Est + 30 DAP)', _convertToDateIfNecessary(row![28])),
                _buildDetailRow('Week of Vegetative', row![29]),
              ]),
              const SizedBox(height: 20),
              _buildAdditionalInfoCard(
                  context, 'Field Audit', [
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
                _buildDetailRow('One Seed per Hole', row![47]),
                _buildDetailRow('Flagging', row![49]),
                _buildDetailRow('Recommendation', row![50]),
                _buildDetailRow('Remarks', row![51]),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Info Mase!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text('Yen diperluake, pencet tombol refresh kanggo nganyari data paling anyar, supoyo data lawas ora katon soko cache.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Tutup',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInteractiveMap() {
    // Gunakan latitude dan longitude yang sudah ada, dengan default jika null
    final mapCenterLat = latitude ?? defaultLat;
    final mapCenterLng = longitude ?? defaultLng;

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: latlng.LatLng(mapCenterLat, mapCenterLng), // Gunakan latlng.LatLng dari package
          initialZoom: 15.0, // Sesuaikan level zoom awal sesuai kebutuhan
          onTap: (tapPosition, point) {
            _openMaps();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.vegetative.kroscek',
          ),
          // Tambahkan Marker untuk menunjukkan lokasi
          if (latitude != null && longitude != null) // Hanya tampilkan marker jika koordinat valid
            MarkerLayer(
              markers: [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: latlng.LatLng(latitude!, longitude!), // Koordinat marker
                  child: Tooltip( // Tambahkan Tooltip jika ingin
                    message: 'Lokasi: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red.shade700,
                      size: 40.0,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinatesText() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        latitude != null && longitude != null
            ? 'Koordinat: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
            : 'Koordinat tidak tersedia',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: latitude != null && longitude != null ? Colors.green.shade800 : Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade100, width: 1.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.shade50],
            stops: const [0.7, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(76),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Divider(
                color: Colors.green,
                thickness: 0.8,
                height: 20,
              ),
              const SizedBox(height: 8),
              ...children.map((child) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: child,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoCard(BuildContext context, String title, List<Widget> children) {
    return Stack(
      children: [
        Card(
          elevation: 8, // Increased elevation for more depth
          color: Colors.white, // Clean white background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // More rounded corners
            side: BorderSide(color: Colors.green.shade200, width: 1.5), // Subtle border
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50),
          child: Padding(
            padding: const EdgeInsets.all(20.0), // More padding for spaciousness
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(76),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(), // Smooth scrolling
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: children,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: 30, // Moved to right side for better UX
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(102),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () async {
                await _navigateToEditScreen(context);
                await _fetchData();
                _saveDataToCache();
              },
              backgroundColor: Colors.green.shade600,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  height: 18,
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                value.isNotEmpty ? value : 'Kosong Lur...',
                style: TextStyle(
                  fontSize: 16,
                  color: value.isNotEmpty ? Colors.grey.shade700 : Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail2Row(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.green.shade200, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  Icons.arrow_right,
                  color: Colors.green.shade700,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                value.isNotEmpty ? value : 'Kosong Lur...',
                style: TextStyle(
                  fontSize: 16,
                  color: value.isNotEmpty ? Colors.grey.shade800 : Colors.grey.shade400,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
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
        // Mengambil jumlah digit desimal dari input
        List<String> parts = value.split(',');
        if (parts.length > 1) {
          int decimalPlaces = parts[1].length; // Hitung digit desimal
          return parsedNumber.toStringAsFixed(decimalPlaces); // Tampilkan sesuai input
        }
        return parsedNumber.toString(); // Jika tidak ada desimal, kembalikan angka asli
      }
    } catch (e) {
      // Tangani kesalahan parsing
    }
    return value; // Kembalikan nilai asli jika gagal parsing
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
