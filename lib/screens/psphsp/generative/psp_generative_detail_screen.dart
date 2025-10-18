import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

import 'audit5_edit_screen.dart';
import 'audit6_edit_screen.dart';
import 'audit_maturity_edit_screen.dart';
import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

class PspGenerativeDetailScreen extends StatefulWidget {
  final String fieldNumber;
  final String region;

  const PspGenerativeDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  PspGenerativeDetailScreenState createState() => PspGenerativeDetailScreenState();
}

class PspGenerativeDetailScreenState extends State<PspGenerativeDetailScreen> {
  List<String>? row;
  bool isLoading = true;
  double? latitude;
  double? longitude;

  final double defaultLat = -7.637017;
  final double defaultLng = 112.8272303;
  final PageController _pageController = PageController();
  late String spreadsheetId;

  @override
  void initState() {
    super.initState();
    // PERBAIKAN: Memanggil satu fungsi async untuk memastikan urutan eksekusi yang benar.
    _initializeAndLoadData();
  }

  // FUNGSI BARU: Menggabungkan inisialisasi dan pengambilan data dalam urutan yang benar.
  Future<void> _initializeAndLoadData() async {
    await _initializeHive();
    await _determineSpreadsheetId(); // Sekarang kita menunggu (await) fungsi ini selesai.
    await _loadDataFromCacheOrFetch();
  }

  Future<void> _determineSpreadsheetId() async {
    spreadsheetId =
        ConfigManager.getSpreadsheetId(widget.region) ?? 'defaultSpreadsheetId';
  }

  Future<void> _initializeHive() async {
    // Tidak perlu inisialisasi Hive di sini jika sudah diinisialisasi di main.dart
    // Namun, jika belum, baris ini penting.
    // await Hive.initFlutter();
  }

  @override
  void dispose() {
    // Tidak disarankan menutup Hive di sini karena bisa dibutuhkan oleh layar lain.
    // Sebaiknya, biarkan Hive terbuka selama aplikasi berjalan.
    // Hive.close(); 
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDataFromCacheOrFetch() async {
    final box = await Hive.openBox('pspGenerativeData');
    final cacheKey = 'detailScreenData_${widget.fieldNumber}';
    final cachedData = box.get(cacheKey);

    if (cachedData != null) {
      _setDataFromCache(Map<String, dynamic>.from(cachedData));
    } else {
      await _fetchData();
    }
  }

  Future<void> _saveDataToCache() async {
    if (row == null) return; // Jangan simpan cache jika data gagal diambil
    final box = await Hive.openBox('pspGenerativeData');
    final cacheKey = 'detailScreenData_${widget.fieldNumber}';
    await box.put(cacheKey, {
      'row': row,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  void _setDataFromCache(Map<String, dynamic> cachedData) {
    // PERBAIKAN: Menambahkan pengecekan 'mounted' untuk keamanan.
    if (!mounted) return;
    setState(() {
      row = List<String>.from(cachedData['row']);
      latitude = cachedData['latitude'];
      longitude = cachedData['longitude'];
      isLoading = false;
    });
  }

  Future<void> _fetchData() async {
    // PERBAIKAN: Menambahkan pengecekan 'mounted' sebelum setState.
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // Pastikan spreadsheetId sudah diinisialisasi
      if (spreadsheetId.isEmpty || spreadsheetId == 'defaultSpreadsheetId') {
        throw Exception("Spreadsheet ID tidak valid atau belum diatur.");
      }

      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData('Generative');
      final fetchedRow = data.firstWhere((row) => row[2] == widget.fieldNumber, orElse: () => []);

      if (fetchedRow.isEmpty) {
        throw Exception("Data untuk field number ${widget.fieldNumber} tidak ditemukan.");
      }

      final String coordinatesStr = fetchedRow.length > 20 ? fetchedRow[20] : '';
      final coordinates = _parseCoordinates(coordinatesStr);

      // PERBAIKAN: Menambahkan pengecekan 'mounted' lagi sebelum setState akhir.
      if (!mounted) return;
      setState(() {
        row = fetchedRow;
        latitude = coordinates['lat'] ?? defaultLat;
        longitude = coordinates['lng'] ?? defaultLng;
        isLoading = false;
      });
      // Setelah data berhasil diambil, simpan ke cache
      await _saveDataToCache();

    } catch (e) {
      // PERBAIKAN: Menambahkan pengecekan 'mounted' di blok catch.
      if (!mounted) return;
      setState(() {
        latitude = defaultLat;
        longitude = defaultLng;
        isLoading = false;
      });
      // Anda bisa menambahkan dialog atau snackbar untuk menampilkan error di sini
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mengambil data: ${e.toString()}'))
        );
      }
    }
  }

  // ... (Sisa kode dari _parseCoordinates sampai akhir tetap sama)
  // Pastikan Anda menyalin sisa kode Anda dari sini ke bawah.
  // Saya akan menyertakan sisa kodenya di bawah ini agar lengkap.

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

    // URL yang lebih kuat untuk Google Maps
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
      final plantingDateString = row[11];
      final plantingDate = _convertToDateIfNecessary(plantingDateString);

      final parsedDate = DateFormat('dd/MM/yyyy').parse(plantingDate);
      final today = DateTime.now();

      return today.difference(parsedDate).inDays;
    } catch (e) {
      return 0;
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
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.orange.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: () async {
              // Langsung panggil _fetchData untuk refresh
              await _fetchData();
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: Lottie.asset('assets/loading.json'))
          : row == null // Tambahkan pengecekan jika 'row' null setelah loading selesai
          ? const Center(child: Text("Gagal memuat data. Silakan coba lagi."))
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
                _buildDetailRow('Season', row![1]),
                _buildDetailRow('Type Seed', row![3]),
                _buildDetailRow('Farmer', row![4]),
                _buildDetailRow('Grower/Agent', row![5]),
                _buildDetailRow('PS Code', row![6]),
                _buildDetailRow('Total Area Planted', _convertToFixedDecimalIfNecessary(row![7])),
                _buildDetailRow('Effective Area (Ha)', _convertToFixedDecimalIfNecessary(row![9])),
                _buildDetailRow('Previous Crope', row![10]),
                _buildDetailRow('Planting Date', _convertToDateIfNecessary(row![11])),
                _buildDetailRow('DAP', _calculateDAP(row!).toString()),
                _buildDetail2Row('Est. Date Audit 5', _convertToDateIfNecessary(row![28])),
                _buildDetail2Row('FASE', row![24]),
                _buildDetailRow('Desa', row![14]),
                _buildDetailRow('Kecamatan', row![15]),
                _buildDetailRow('Kabupaten', row![16]),
                _buildDetailRow('Field SPV', row![18]),
                _buildDetailRow('FA', row![19]),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: 3,
                      effect: WormEffect(
                        dotHeight: 10,
                        dotWidth: 10,
                        activeDotColor: Colors.orange,
                        dotColor: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildAudit5Section(context, 'AUDIT 5', [
                            _buildDetailRow('QA FI', row?[26] ?? 'Kosong'),
                            _buildDetailRow('Co-Rog', row?[27] ?? 'Kosong'),
                            _buildDetailRow('Week of Audit 5', row?[31] ?? 'Kosong'),
                            _buildDetailRow('Date Of Audit 5', _convertToDateIfNecessary(row?[30] ?? '0')),
                            _buildDetailRow('Standing crop Offtype', row?[32] ?? 'Kosong'),
                            _buildDetailRow('Standing crop Volunteer', row?[33] ?? 'Kosong'),
                            _buildDetailRow('Offtype Sheed', row?[34] ?? 'Kosong'),
                            _buildDetailRow('Volunteer Sheed', row?[35] ?? 'Kosong'),
                            _buildDetailRow('LSV', row?[36] ?? 'Kosong'),
                            _buildDetailRow('Corp Health', row?[37] ?? 'Kosong'),
                            _buildDetailRow('Crop Uniformity', row?[38] ?? 'Kosong'),
                            _buildDetailRow('Isolation', row?[39] ?? 'Kosong'),
                            _buildDetailRow('Isolation Type', row?[40] ?? 'Kosong'),
                            _buildDetailRow('Isolation Distance', row?[41] ?? 'Kosong'),
                            _buildDetailRow('Nicking Observation', row?[42] ?? 'Kosong'),
                            _buildDetailRow('Flagging', row?[43] ?? 'Kosong'),
                          ]),
                          _buildAudit6Section(context, 'AUDIT 6', [
                            _buildDetailRow('Week of Audit 6', row?[47] ?? 'Kosong'),
                            _buildDetailRow('Date Of Audit 6', _convertToDateIfNecessary(row?[46] ?? '0')),
                            _buildDetailRow('Standing crop Offtype', row?[48] ?? 'Kosong'),
                            _buildDetailRow('Standing crop Volunteer', row?[49] ?? 'Kosong'),
                            _buildDetailRow('Offtype Sheed', row?[50] ?? 'Kosong'),
                            _buildDetailRow('Volunteer Sheed', row?[51] ?? 'Kosong'),
                            _buildDetailRow('LSV', row?[52] ?? 'Kosong'),
                            _buildDetailRow('Corp Health', row?[53] ?? 'Kosong'),
                            _buildDetailRow('Crop Uniformity', row?[54] ?? 'Kosong'),
                            _buildDetailRow('Isolation', row?[55] ?? 'Kosong'),
                            _buildDetailRow('Isolation Type', row?[56] ?? 'Kosong'),
                            _buildDetailRow('Isolation Distance', row?[57] ?? 'Kosong'),
                            _buildDetailRow('Nicking Observation', row?[58] ?? 'Kosong'),
                            _buildDetailRow('Flagging', row?[59] ?? 'Kosong'),
                            _buildDetailRow('Recommendation', row?[60] ?? 'Kosong'),
                            _buildDetailRow('Recommendation PLD', row?[61] ?? 'Kosong'),
                            _buildDetailRow('Remarks', row?[62] ?? 'Kosong'),
                          ]),
                          _buildAuditMaturitySection(context, 'AUDIT Maturity', [
                            _buildDetailRow('Week of Inspection', row?[66] ?? 'Kosong'),
                            _buildDetailRow('Date of Inspection', _convertToDateIfNecessary(row?[65] ?? '0')),
                            _buildDetailRow('Wet Cob Est', row?[67] ?? 'Kosong'),
                            _buildDetailRow('Ear Condition Observation (Maturity)', row?[68] ?? 'Kosong'),
                            _buildDetailRow('Corp Health', row?[69] ?? 'Kosong'),
                            _buildDetailRow('Remarks', row?[70] ?? 'Kosong'),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              )
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
              color: Colors.orange,
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
    final mapCenterLat = latitude ?? defaultLat;
    final mapCenterLng = longitude ?? defaultLng;

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: latlng.LatLng(mapCenterLat, mapCenterLng),
          initialZoom: 15.0,
          onTap: (tapPosition, point) {
            _openMaps();
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.vegetative.kroscek',
          ),
          if (latitude != null && longitude != null)
            MarkerLayer(
              markers: [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: latlng.LatLng(latitude!, longitude!),
                  child: Tooltip(
                    message: 'Lokasi: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.orange.shade700,
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(25),
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
          color: latitude != null && longitude != null ? Colors.orange.shade800 : Colors.grey,
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
        side: BorderSide(color: Colors.orange.shade100, width: 1.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.orange.shade50],
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
                    colors: [Colors.orange.shade600, Colors.orange.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withAlpha(76),
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
                color: Colors.orange,
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

  Widget _buildAudit5Section(BuildContext context, String title, List<Widget> children) {
    final ScrollController scrollController = ScrollController();

    return Stack(
      children: [
        Card(
          elevation: 8,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.orange.shade200, width: 1.5),
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withAlpha(76),
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
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: children,
                        ),
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
          right: 30,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withAlpha(102),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () async {
                await _navigateToAudit5EditScreen(context);
                // PERBAIKAN: Tidak perlu fetch data lagi di sini karena
                // data sudah di-update melalui callback onSave.
                // Cukup panggil _fetchData jika ingin sinkronisasi paksa dari server.
              },
              backgroundColor: Colors.orange.shade600,
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

  Widget _buildAudit6Section(BuildContext context, String title, List<Widget> children) {
    final ScrollController scrollController = ScrollController();

    return Stack(
      children: [
        Card(
          elevation: 8,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.orange.shade200, width: 1.5),
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withAlpha(76),
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
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: children,
                        ),
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
          right: 30,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withAlpha(102),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () async {
                await _navigateToAudit6EditScreen(context);
              },
              backgroundColor: Colors.orange.shade600,
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

  Widget _buildAuditMaturitySection(BuildContext context, String title, List<Widget> children) {
    final ScrollController scrollController = ScrollController();

    return Stack(
      children: [
        Card(
          elevation: 8,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.orange.shade200, width: 1.5),
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.orange.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withAlpha(76),
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
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: 6,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: children,
                        ),
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
          right: 30,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withAlpha(102),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () async {
                await _navigateToAuditMaturityEditScreen(context);
              },
              backgroundColor: Colors.orange.shade600,
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
                    color: Colors.orange.shade600,
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
          colors: [Colors.orange.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withAlpha(25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
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
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
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
                    color: Colors.orange.withAlpha(25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.orange.shade300),
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
        List<String> parts = value.split(',');
        if (parts.length > 1) {
          int decimalPlaces = parts[1].length;
          return parsedNumber.toStringAsFixed(decimalPlaces);
        }
        return parsedNumber.toString();
      }
    } catch (e) {
      // Tangani kesalahan parsing
    }
    return value;
  }

  Future<void> _navigateToAudit5EditScreen(BuildContext context) async {
    if (row == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Audit5EditScreen(
          row: row!,
          region: widget.region,
          onSave: (updatedActivity) {
            if (!mounted) return;
            setState(() {
              row = updatedActivity;
            });
            // Simpan ke cache setelah update lokal
            _saveDataToCache();
          },
        ),
      ),
    );
    // Jika ada hasil dari pop (meski callback sudah menangani), kita bisa refresh state
    if (result != null) {
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _navigateToAudit6EditScreen(BuildContext context) async {
    if (row == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Audit6EditScreen(
          row: row!,
          region: widget.region,
          onSave: (updatedActivity) {
            if (!mounted) return;
            setState(() {
              row = updatedActivity;
            });
            _saveDataToCache();
          },
        ),
      ),
    );
  }

  Future<void> _navigateToAuditMaturityEditScreen(BuildContext context) async {
    if (row == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuditMaturityEditScreen(
          row: row!,
          region: widget.region,
          onSave: (updatedActivity) {
            if (!mounted) return;
            setState(() {
              row = updatedActivity;
            });
            _saveDataToCache();
          },
        ),
      ),
    );
  }
}