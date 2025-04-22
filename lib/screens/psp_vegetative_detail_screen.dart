import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';  // Tambahkan ini untuk menggunakan url_launcher
import 'audit1_edit_screen.dart';
import 'audit2_edit_screen.dart';
import 'audit3_edit_screen.dart';
import 'audit4_edit_screen.dart';
import 'google_sheets_api.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'config_manager.dart';

class PspVegetativeDetailScreen extends StatefulWidget {
  final String fieldNumber;
  final String region;

  const PspVegetativeDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  PspVegetativeDetailScreenState createState() => PspVegetativeDetailScreenState();
}

class PspVegetativeDetailScreenState extends State<PspVegetativeDetailScreen> {
  List<String>? row;
  bool isLoading = true;

  String _mapImageUrl = ''; // URL untuk Google Static Maps
  double? latitude;
  double? longitude;

  final double defaultLat = -7.637017;
  final double defaultLng = 112.8272303;
  final PageController _pageController = PageController();
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
    final box = await Hive.openBox('pspVegetativeData');
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
    final box = Hive.box('pspVegetativeData');
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

      final String coordinatesStr = fetchedRow[20];
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
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : LiquidPullToRefresh(
        onRefresh: _refreshData,  // Menentukan fungsi untuk refresh
        color: Colors.redAccent,
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
                  _buildDetailRow('Type Seed', row![3]),
                  _buildDetailRow('Farmer', row![4]),
                  _buildDetailRow('Grower/Agent', row![5]),
                  _buildDetailRow('PS Code', row![6]),
                  _buildDetailRow('Total Area Planted', _convertToFixedDecimalIfNecessary(row![7])),
                  _buildDetailRow('Effective Area (Ha)', _convertToFixedDecimalIfNecessary(row![9])),
                  _buildDetailRow('Previous Crope', row![10]),
                  _buildDetailRow('Planting Date', _convertToDateIfNecessary(row![11])),
                  _buildDetail2Row('Est. Date Audit 1', _convertToDateIfNecessary(row![28])),
                  _buildDetail2Row('FASE', row![24]),
                  _buildDetailRow('Desa', row![14]),
                  _buildDetailRow('Kecamatan', row![15]),
                  _buildDetailRow('Kabupaten', row![16]),
                  _buildDetailRow('Field SPV', row![18]),
                  _buildDetailRow('FA', row![19]),
                ]),
                const SizedBox(height: 20),
                // Field Audit (Menggunakan PageView untuk scroll horizontal)
                SizedBox(
                  height: 800, // Tinggi untuk PageView
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Tengah secara vertikal
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: 4, // Jumlah halaman audit
                        effect: WormEffect(
                          dotHeight: 10,
                          dotWidth: 10,
                          activeDotColor: Colors.redAccent,
                          dotColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          scrollDirection: Axis.horizontal,
                          children: [
                            // Audit 1
                            _buildAuditSection(
                                context, 'AUDIT 1', [
                              _buildDetailRow('QA FI', row![26]),
                              _buildDetailRow('Co-Rog', row![27]),
                              const SizedBox(height: 20),
                              _buildDetailRow('Week of Audit 1', row?[31] ?? 'Kosong'),
                              _buildDetailRow('Date Of Audit 1',
                                  _convertToDateIfNecessary(row?[30] ?? '0')),
                              _buildDetailRow('Rev Tgl Tanam',
                                  _convertToDateIfNecessary(row?[32] ?? '0')),
                              _buildDetailRow('Field Size by Audit (Ha)',
                                  _convertToFixedDecimalIfNecessary(row?[33] ?? '0')),
                              _buildDetailRow('Previous Crop Actual', row?[34] ?? 'Kosong'),
                              _buildDetailRow('Isolation Audit 1', row?[35] ?? 'Kosong'),
                              _buildDetailRow('Isolation Type', row?[36] ?? 'Kosong'),
                              _buildDetailRow('Isolation Distance', row?[37] ?? 'Kosong'),
                              _buildDetailRow('Audit 1 Offtype', row?[38] ?? 'Kosong'),
                              _buildDetailRow('Audit 1 Volunteer', row?[39] ?? 'Kosong'),
                              _buildDetailRow('Corp Health', row?[40] ?? 'Kosong'),
                              _buildDetailRow('Crop Uniformity', row?[41] ?? 'Kosong'),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.center, // Menempatkan FAB di tengah horizontal
                                child: FloatingActionButton(
                                  onPressed: () async {
                                    await _navigateToAudit1EditScreen(context); // Navigasi ke layar edit
                                    await _fetchData();
                                    _saveDataToCache();
                                  },
                                  backgroundColor: Colors.redAccent,
                                  shape: const CircleBorder(),
                                  child: const Icon(Icons.edit, color: Colors.white),
                                ),
                              ),
                            ]),

                            // Audit 2
                            _buildAuditSection(
                                context, 'AUDIT 2', [
                              _buildDetailRow('Week of Audit 2', row?[45] ?? 'Kosong'),
                              _buildDetailRow('Date Of Audit 2',
                                  _convertToDateIfNecessary(row?[44] ?? '0')),
                              _buildDetailRow('Audit 2 Offtype', row?[46] ?? 'Kosong'),
                              _buildDetailRow('Audit 2 Volunteer', row?[47] ?? 'Kosong'),
                              _buildDetailRow('Audit 2 LSV', row?[48] ?? 'Kosong'),
                              _buildDetailRow('Corp Health', row?[49] ?? 'Kosong'),
                              _buildDetailRow('Crop Uniformity', row?[50] ?? 'Kosong'),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.center, // Menempatkan FAB di tengah horizontal
                                child: FloatingActionButton(
                                  onPressed: () async {
                                    await _navigateToAudit2EditScreen(context); // Navigasi ke layar edit
                                    await _fetchData();
                                    _saveDataToCache();
                                  },
                                  backgroundColor: Colors.redAccent,
                                  shape: const CircleBorder(),
                                  child: const Icon(Icons.edit, color: Colors.white),
                                ),
                              ),
                            ]),

                            // Audit 3
                            _buildAuditSection(
                                context, 'AUDIT 3', [
                              _buildDetailRow('Week of Audit 3', row?[54] ?? 'Kosong'),
                              _buildDetailRow('Date Of Audit 3',
                                  _convertToDateIfNecessary(row?[53] ?? '0')),
                              _buildDetailRow('Audit 3 Offtype', row?[55] ?? 'Kosong'),
                              _buildDetailRow('Audit 3 Volunteer', row?[56] ?? 'Kosong'),
                              _buildDetailRow('Audit 3 LSV', row?[57] ?? 'Kosong'),
                              _buildDetailRow('Corp Health', row?[58] ?? 'Kosong'),
                              _buildDetailRow('Crop Uniformity', row?[59] ?? 'Kosong'),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.center, // Menempatkan FAB di tengah horizontal
                                child: FloatingActionButton(
                                  onPressed: () async {
                                    await _navigateToAudit3EditScreen(context); // Navigasi ke layar edit
                                    await _fetchData();
                                    _saveDataToCache();
                                  },
                                  backgroundColor: Colors.redAccent,
                                  shape: const CircleBorder(),
                                  child: const Icon(Icons.edit, color: Colors.white),
                                ),
                              ),
                            ]),

                            // Audit 4
                            _buildAuditSection(
                                context, 'AUDIT 4', [
                              _buildDetailRow('Week of Audit 4', row?[63] ?? 'Kosong'),
                              _buildDetailRow('Date Of Audit 4',
                                  _convertToDateIfNecessary(row?[62] ?? '0')),
                              _buildDetailRow('Audit 4 Offtype', row?[64] ?? 'Kosong'),
                              _buildDetailRow('Audit 4 Volunteer', row?[65] ?? 'Kosong'),
                              _buildDetailRow('Audit 4 LSV', row?[66] ?? 'Kosong'),
                              _buildDetailRow('Corp Health', row?[67] ?? 'Kosong'),
                              _buildDetailRow('Crop Uniformity', row?[68] ?? 'Kosong'),
                              _buildDetailRow('Isolation Audit 4', row?[69] ?? 'Kosong'),
                              _buildDetailRow('Isolation Type', row?[70] ?? 'Kosong'),
                              _buildDetailRow('Isolation Distance', row?[71] ?? 'Kosong'),
                              _buildDetailRow('Flagging', row?[72] ?? 'Kosong'),
                              _buildDetailRow('Recommendation', row?[73] ?? 'Kosong'),
                              _buildDetailRow('Recommendation PLD', row?[74] ?? 'Kosong'),
                              _buildDetailRow('Remarks', row?[75] ?? 'Kosong'),
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.center, // Menempatkan FAB di tengah horizontal
                                child: FloatingActionButton(
                                  onPressed: () async {
                                    await _navigateToAudit4EditScreen(context); // Navigasi ke layar edit
                                    await _fetchData();
                                    _saveDataToCache();
                                  },
                                  backgroundColor: Colors.redAccent,
                                  shape: const CircleBorder(),
                                  child: const Icon(Icons.edit, color: Colors.white),
                                ),
                              ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _fetchData();
          _saveDataToCache();
        },
        backgroundColor: Colors.redAccent,
        shape: const CircleBorder(),
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const BottomAppBar(
        color: Colors.redAccent,
        shape: CircularNotchedRectangle(),
        child: SizedBox(height: 60.0),
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
                  color: Colors.redAccent
              ),
            ),
            const SizedBox(height: 10),
            Column(children: children),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 4,
      color: Colors.red[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(8), // Memberikan margin untuk jarak antar card
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Menampilkan daftar detail audit
            ...children,

          ],
        ),
      ),
    );
  }

  // Widget _buildAdditionalInfoCard(String title, List<Widget> children) {
  //   return Card(
  //     color: Colors.red[50],
  //     elevation: 4,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             title,
  //             style: const TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //                 color: Colors.redAccent
  //             ),
  //           ),
  //           const SizedBox(height: 10),
  //           Column(children: children),
  //         ],
  //       ),
  //     ),
  //   );
  // }

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

  Widget _buildDetail2Row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Menyelaraskan konten agar vertikal
        children: [
          Expanded( // Menggunakan Expanded untuk mengatasi masalah overflow pada teks
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10), // Menambahkan sedikit ruang antara label dan value
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Kosong Lur...',
              style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
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

  // Fungsi untuk menavigasi ke layar edit Audit 1
  Future<void> _navigateToAudit1EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Audit1EditScreen(
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
  // Fungsi untuk menavigasi ke layar edit Audit 2
  Future<void> _navigateToAudit2EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Audit2EditScreen(
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
  // Fungsi untuk menavigasi ke layar edit Audit 3
  Future<void> _navigateToAudit3EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Audit3EditScreen(
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
  // Fungsi untuk menavigasi ke layar edit Audit 4
  Future<void> _navigateToAudit4EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Audit4EditScreen(
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
