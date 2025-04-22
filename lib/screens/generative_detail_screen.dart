import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Tambahkan ini untuk menggunakan url_launcher
import 'generative1_edit_screen.dart';
import 'generative2_edit_screen.dart';
import 'generative3_edit_screen.dart';
import 'google_sheets_api.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lottie/lottie.dart';
import 'config_manager.dart';

class GenerativeDetailScreen extends StatefulWidget {
  final String fieldNumber;
  final String region;

  const GenerativeDetailScreen({
    super.key,
    required this.fieldNumber,
    required this.region,
  });

  @override
  GenerativeDetailScreenState createState() => GenerativeDetailScreenState();
}

class GenerativeDetailScreenState extends State<GenerativeDetailScreen> {
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
    _initializeHive();
    _determineSpreadsheetId();
    _loadDataFromCacheOrFetch();
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
    final box = await Hive.openBox('generativeData');
    final cacheKey = 'detailScreenData_${widget.fieldNumber}'; // Kunci unik per fieldNumber
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
    final box = Hive.box('generativeData');
    final cacheKey = 'detailScreenData_${widget.fieldNumber}';
    box.put(cacheKey, {
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
      final List<List<String>> data = await gSheetsApi.getSpreadsheetData('Generative');
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
      return {'lat': null, 'lng': null};
    }
  }

  String _buildStaticMapUrl(double? latitude, double? longitude) {
    const String apiKey = 'AIzaSyDNZoDIH3DjLrz77c-ihr0HLhYrgPtfKKc';
    const String baseUrl = 'https://maps.googleapis.com/maps/api/staticmap';
    const int zoomLevel = 15;
    const String mapSize = '600x400';

    final double lat = latitude ?? defaultLat;
    final double lng = longitude ?? defaultLng;

    return '$baseUrl?center=$lat,$lng&zoom=$zoomLevel&size=$mapSize'
        '&markers=color:red%7C$lat,$lng&key=$apiKey';
  }

  Future<void> _openMaps() async {
    final lat = latitude ?? defaultLat;
    final lng = longitude ?? defaultLng;

    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$lat,$lng');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl);
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
    ? Center(child: Lottie.asset('assets/loading.json'))
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
              _buildInteractiveMap(),
              const SizedBox(height: 10),
              _buildCoordinatesText(),
              const SizedBox(height: 10),
              _buildDetailCard('Field Information', [
                _buildDetailRow('Season', row![1]),
                _buildDetailRow('Farmer', row![3]),
                _buildDetailRow('Grower', row![4]),
                _buildDetailRow('Hybrid', row![5]),
                _buildDetailRow('Effective Area (Ha)', _convertToFixedDecimalIfNecessary(row![8])),
                _buildDetailRow('Planting Date PDN', _convertToDateIfNecessary(row![9])),
                _buildDetail2Row('Flowering (Est + 57 DAP)', _convertToDateIfNecessary(row![27])),
                _buildDetail2Row('FASE', row![26]),
                _buildDetailRow('Desa', row![11]),
                _buildDetailRow('Kecamatan', row![12]),
                _buildDetailRow('Kabupaten', row![13]),
                _buildDetailRow('Field SPV', row![15]),
                _buildDetailRow('FA', row![16]),
                _buildDetailRow('Date Flowering (Est + 57 DAP)', _convertToDateIfNecessary(row![27])),
                _buildDetailRow('Week of Flowering Rev', row![28]),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Tengah secara vertikal
                  children: [
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: 3, // Jumlah halaman audit
                      effect: WormEffect(
                        dotHeight: 10,
                        dotWidth: 10,
                        activeDotColor: Colors.green,
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
                          _buildAudit1Section(
                            context, 'Field Audit 1', [
                            _buildDetailRow('QA FI', row![31]),
                            _buildDetailRow('Date of Audit 1 (dd/MM)', _convertToDateIfNecessary(row![32])),
                            _buildDetailRow('Rev Planting Date Based', _convertToDateIfNecessary(row![34])),
                            _buildDetailRow('Detaseling Plan (Form)', row![35]),
                            _buildDetailRow('Labor Availability for DT', row![36]),
                            _buildDetailRow('Roguing Proses', row![37]),
                            _buildDetailRow('Remarks Roguing Proses', row![38]),
                            _buildDetailRow('Labor Detasseling Process', row![39]),
                          ]),

                            // Audit 2
                          _buildAudit2Section(
                            context, 'Field Audit 2', [
                            _buildDetailRow('Date of Audit 2 (dd/MM)', _convertToDateIfNecessary(row![40])),
                            _buildDetailRow('Female Shed.', row![42]),
                            _buildDetailRow('Shedding Offtype & CVL M', row![43]),
                            _buildDetailRow('Shedding Offtype & CVL F', row![44]),
                          ]),

                            // Audit 3
                          _buildAudit3Section(
                              context, 'Field Audit 3', [
                            _buildDetailRow('Date of Audit 3 (dd/MM)', _convertToDateIfNecessary(row![45])),
                            _buildDetailRow('Female Shed.', row![47]),
                            _buildDetailRow('Shedding Offtype & CVL M', row![48]),
                            _buildDetailRow('Shedding Offtype & CVL F', row![49]),
                            _buildDetailRow('StandingCropOfftype&CVLm', row![50]),
                            _buildDetailRow('StandingCropOfftype&CVLf', row![51]),
                            _buildDetailRow('LSV Ditemukan', row![52]),
                            _buildDetailRow('Detasseling Process Observ.', row![53]),
                            _buildDetailRow('Affected by other fields', row![54]),
                            _buildDetailRow('Nick Cover', row![55]),
                            _buildDetailRow('Crop Uniformity', row![56]),
                            _buildDetailRow('Isolation (Y/N)', row![57]),
                            _buildDetailRow('If "YES" IsolationType', row![58]),
                            _buildDetailRow('If "YES" IsolationDist. (m)', row![59]),
                            _buildDetailRow('QPIR Applied', row![60]),
                            _buildDetailRow('Closed out Date', _convertToDateIfNecessary(row![61])),
                            _buildDetailRow('FLAGGING', row![62]),
                            _buildDetailRow('Recommendation', row![63]),
                            _buildDetailRow('Remarks', row![64]),
                            _buildDetailRow('Recommendation PLD (Ha)', _convertToFixedDecimalIfNecessary(row![65])),
                            _buildDetailRow('Reason PLD', row![66]),
                            _buildDetailRow('Reason Tidak Teraudit', row![67]),
                          ]),

                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
        backgroundColor: Colors.green,
        shape: const CircleBorder(),
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: const BottomAppBar(
        color: Colors.green,
        shape: CircularNotchedRectangle(),
        child: SizedBox(height: 60.0),
      ),
    );
  }

  Widget _buildInteractiveMap() {
    return GestureDetector(
      onTap: _openMaps,
      child: _mapImageUrl.isNotEmpty
          ? Image.network(
        _mapImageUrl,
        fit: BoxFit.cover,
        height: 250,
        width: double.infinity,
      )
          : const SizedBox.shrink(),
    );
  }

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
                  color: Colors.green),
            ),
            const SizedBox(height: 10),
            Column(children: children),
          ],
        ),
      ),
    );
  }

  // Widget _buildAuditSection(BuildContext context, String title, List<Widget> children) {
  //   return Card(
  //     elevation: 4,
  //     color: Colors.green[50],
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(10),
  //     ),
  //     margin: const EdgeInsets.all(8), // Memberikan margin untuk jarak antar card
  //     child: Padding(
  //       padding: const EdgeInsets.all(14.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           Text(
  //             title,
  //             textAlign: TextAlign.center,
  //             style: const TextStyle(
  //               color: Colors.green,
  //               fontSize: 18,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           const SizedBox(height: 20),
  //
  //           // Menampilkan daftar detail audit
  //           ...children,
  //
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildAudit1Section(BuildContext context, String title, List<Widget> children) {
    // Scroll controller untuk mengatur scroll bar
    final ScrollController scrollController = ScrollController();

    return Stack( // Menggunakan Stack untuk menempatkan FAB di atas Card
      children: [
        Card(
          elevation: 4,
          color: Colors.green[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50), // Memberi ruang untuk FAB
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Tambahkan ScrollBar
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
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
          bottom: 6, // Posisi FAB di bawah card
          left: MediaQuery.of(context).size.width / 2 - 28, // FAB di tengah card
          child: FloatingActionButton(
            onPressed: () async {
              await _navigateToGenerative1EditScreen(
                  context); // Navigasi ke layar edit
              await _fetchData();
              _saveDataToCache();
            },
            backgroundColor: Colors.green,
            shape: const CircleBorder(),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildAudit2Section(BuildContext context, String title, List<Widget> children) {
    // Scroll controller untuk mengatur scroll bar
    final ScrollController scrollController = ScrollController();

    return Stack( // Menggunakan Stack untuk menempatkan FAB di atas Card
      children: [
        Card(
          elevation: 4,
          color: Colors.green[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50), // Memberi ruang untuk FAB
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Tambahkan ScrollBar
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
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
          bottom: 6, // Posisi FAB di bawah card
          left: MediaQuery.of(context).size.width / 2 - 28, // FAB di tengah card
          child: FloatingActionButton(
            onPressed: () async {
              await _navigateToGenerative2EditScreen(
                  context); // Navigasi ke layar edit
              await _fetchData();
              _saveDataToCache();
            },
            backgroundColor: Colors.green,
            shape: const CircleBorder(),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildAudit3Section(BuildContext context, String title, List<Widget> children) {
    // Scroll controller untuk mengatur scroll bar
    final ScrollController scrollController = ScrollController();

    return Stack( // Menggunakan Stack untuk menempatkan FAB di atas Card
      children: [
        Card(
          elevation: 4,
          color: Colors.green[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 50), // Memberi ruang untuk FAB
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Tambahkan ScrollBar
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
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
          bottom: 6, // Posisi FAB di bawah card
          left: MediaQuery.of(context).size.width / 2 - 28, // FAB di tengah card
          child: FloatingActionButton(
            onPressed: () async {
              await _navigateToGenerative3EditScreen(
                  context); // Navigasi ke layar edit
              await _fetchData();
              _saveDataToCache();
            },
            backgroundColor: Colors.green,
            shape: const CircleBorder(),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // Widget _buildAdditionalInfoCard(String title, List<Widget> children) {
  //   return Card(
  //     color: Colors.green[50],
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
  //                 color: Colors.green),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : 'Kosong Lur...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              softWrap: true,
              overflow: TextOverflow.visible,
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
              style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
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


  Future<void> _navigateToGenerative1EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Generative1EditScreen(
          row: row!,
          region: widget.region,
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
        row = updatedRow;
      });
    }
  }

  Future<void> _navigateToGenerative2EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Generative2EditScreen(
          row: row!,
          region: widget.region,
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
        row = updatedRow;
      });
    }
  }

  Future<void> _navigateToGenerative3EditScreen(BuildContext context) async {
    final updatedRow = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Generative3EditScreen(
          row: row!,
          region: widget.region,
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
        row = updatedRow;
      });
    }
  }
}
