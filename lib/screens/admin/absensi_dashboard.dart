import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class AbsensiDashboard extends StatefulWidget {
  const AbsensiDashboard({super.key});

  @override
  State<AbsensiDashboard> createState() => _AbsensiDashboardState();
}

class _AbsensiDashboardState extends State<AbsensiDashboard> {
  List<AbsensiData> _absensiData = [];
  List<AbsensiData> _filteredData = [];
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  String _selectedRegion = '';
  bool _isLoading = true;
  late Box _absensiBox;

  final List<String> _filterOptions = ['Semua', 'Hari Ini', 'Minggu Ini', 'Bulan Ini'];
  String? _spreadsheetId;
  GoogleSheetsApi? _googleSheetsApi;

  @override
  void initState() {
    super.initState();
    _initializeApp().catchError((e) {
      _showErrorMessage('Gagal inisialisasi: ${e.toString()}');
    });
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeHive();
      await _initializeServices();
      await _loadDataFromCacheOrFetch();
    } catch (e) {
      debugPrint('Initialization error: $e');
      rethrow;
    }
  }

  Future<void> _initializeHive() async {
    try {
      if (!Hive.isBoxOpen('absensiData')) {
        _absensiBox = await Hive.openBox('absensiData');
      } else {
        _absensiBox = Hive.box('absensiData');
      }
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
      await Hive.close();
      _absensiBox = await Hive.openBox('absensiData');
    }
  }

  @override
  void dispose() {
    // Tidak perlu menutup box di sini karena akan digunakan selama aplikasi berjalan
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await ConfigManager.loadConfig();
    // Hapus pemanggilan _determineSpreadsheetId() dari sini
    // Karena region belum dipilih di awal
  }

  Future<void> _determineSpreadsheetId() async {
    try {
      if (_selectedRegion.isEmpty) {
        setState(() => _spreadsheetId = null);
        return;
      }

      final newId = ConfigManager.getSpreadsheetId(_selectedRegion);

      if (newId == null || newId.isEmpty) {
        throw Exception("Spreadsheet ID untuk region $_selectedRegion tidak ditemukan");
      }

      setState(() => _spreadsheetId = newId);
    } catch (e) {
      debugPrint("Error menentukan Spreadsheet ID: $e");
      setState(() => _spreadsheetId = null);
      rethrow;
    }
  }

  Future<void> _loadDataFromCacheOrFetch() async {
    if (_selectedRegion.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final cachedData = _absensiBox.get(_selectedRegion);

      if (cachedData != null) {
        // Pastikan cachedData adalah List
        if (cachedData is List) {
          _setDataFromCache(List<Map<String, dynamic>>.from(cachedData));
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
      await _absensiBox.delete(_selectedRegion);
    }

    await _fetchData();
  }

  void _setDataFromCache(List<Map<String, dynamic>> cachedData) {
    try {
      setState(() {
        _absensiData = cachedData.map((data) => AbsensiData.fromMap(data)).toList();
        _filteredData = List.from(_absensiData);
      });
    } catch (e) {
      debugPrint('Error parsing cached data: $e');
      throw Exception('Format cache tidak valid');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted || _spreadsheetId == null || _spreadsheetId!.isEmpty || _googleSheetsApi == null) return;

    setState(() => _isLoading = true);

    try {
      await _googleSheetsApi!.init();
      final rows = await _googleSheetsApi!.getSpreadsheetData('Absen Log')
          .timeout(const Duration(seconds: 15));

      final absensiList = <AbsensiData>[];

      for (final row in rows.skip(1)) {
        try {
          if (row.length < 4) continue;

          // Remove null-aware operators since row elements are guaranteed to be non-null
          final name = row[0].toString().trim();
          final dateStr = row[1].toString().trim();
          final timeStr = row[2].toString().trim();
          final location = row[3].toString().trim();

          final date = _parseDate(dateStr);
          final time = _parseTime(timeStr);

          if (date != null && time != null) {
            absensiList.add(AbsensiData(
              name: name,
              date: date,
              time: time,
              location: location,
            ));
          }
        } catch (e) {
          debugPrint('Error parsing row: $e');
        }
      }

      _updateData(absensiList);
      await _saveDataToCache(absensiList);
    } on TimeoutException catch (_) {
      _showErrorMessage('Timeout: Server tidak merespons');
    } catch (e) {
      _showErrorMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateData(List<AbsensiData> newData) {
    if (!mounted) return;

    setState(() {
      _absensiData = newData;
      _filteredData = List.from(newData);
    });
  }

  Future<void> _saveDataToCache(List<AbsensiData> data) async {
    try {
      final dataToCache = data.map((e) => e.toMap()).toList();
      await _absensiBox.put(_selectedRegion, dataToCache);
    } catch (e) {
      debugPrint('Error saving to cache: $e');
      try {
        await Hive.close();
        _absensiBox = await Hive.openBox('absensiData');
        final dataToCache = data.map((e) => e.toMap()).toList();
        await _absensiBox.put(_selectedRegion, dataToCache);
      } catch (e) {
        debugPrint('Retry failed: $e');
      }
    }
  }

  Future<void> _refreshData() async {
    await _fetchData();
    _filterData();
  }

  void _filterData() {
    final now = DateTime.now();
    setState(() {
      _filteredData = _absensiData.where((data) {
        final matchesSearch = data.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            data.dateFormatted.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            data.timeFormatted.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesFilter = true;
        if (_selectedFilter == 'Hari Ini') {
          matchesFilter = data.date.day == now.day &&
              data.date.month == now.month &&
              data.date.year == now.year;
        } else if (_selectedFilter == 'Minggu Ini') {
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          matchesFilter = data.date.isAfter(startOfWeek) && data.date.isBefore(endOfWeek);
        } else if (_selectedFilter == 'Bulan Ini') {
          matchesFilter = data.date.month == now.month && data.date.year == now.year;
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final serial = double.tryParse(dateStr);
      if (serial != null) {
        return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
      }

      final formats = [
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('yyyy-MM-dd'),
      ];

      for (final format in formats) {
        try {
          return format.parse(dateStr);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return null;
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }

      final decimalTime = double.tryParse(timeStr);
      if (decimalTime != null) {
        final totalSeconds = (decimalTime * 86400).round();
        final hour = totalSeconds ~/ 3600;
        final minute = (totalSeconds % 3600) ~/ 60;
        return TimeOfDay(hour: hour, minute: minute);
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return null;
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return PopScope(
      // Callback saat pengguna menekan tombol back
      canPop: false, // Mencegah pop langsung
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        // didPop akan false karena canPop: false
        context.go('/admin');
        return;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text('Absensi Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
            ),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildRegionDropdown(),
            const SizedBox(height: 10),
            _buildFilterSection(),
            const SizedBox(height: 10),
            _buildSearchSection(),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDataTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionDropdown() {

    final displayText = _selectedRegion.isEmpty ? 'Pilih Region!' : _selectedRegion;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.green.shade50],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(51),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.green.withAlpha(102),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Tambah padding vertical
        child: DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: _selectedRegion.isEmpty ? null : _selectedRegion,

            hint: Text( // Tambahkan hint untuk teks default
              'Pilih Region!',
              style: TextStyle(
                color: Colors.green.shade800.withAlpha((0.6 * 255).round()),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),

            isExpanded: true,
            customButton: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText, // Gunakan variabel displayText
                      style: TextStyle(
                        color: _selectedRegion.isEmpty
                            ? Colors.green.shade800.withAlpha((0.6 * 255).round())
                            : Colors.green.shade800,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.expand_more, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            dropdownStyleData: DropdownStyleData(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha(51),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              maxHeight: MediaQuery.of(context).size.height * 0.4,
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.symmetric(vertical: 6), // Tambah padding untuk dropdown items
              offset: const Offset(0, -10), // Sesuaikan posisi dropdown
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 48, // Tinggi setiap item dropdown
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
            style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            items: ConfigManager.regions.keys.map((String region) {
              return DropdownMenuItem<String>(
                value: region,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _selectedRegion == region
                        ? Colors.green.shade50
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        region,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 15,
                          fontWeight: _selectedRegion == region
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) async {
              if (value == null || value == _selectedRegion) return;

              setState(() => _isLoading = true);

              try {
                setState(() => _selectedRegion = value);
                await _determineSpreadsheetId();
                if (_spreadsheetId != null) {
                  _googleSheetsApi = GoogleSheetsApi(_spreadsheetId!);
                  await _fetchData();
                }
              } catch (e) {
                debugPrint('Error changing region: $e');
                _showErrorMessage('Gagal mengubah region: ${e.toString()}');
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(51),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.green.withAlpha(102),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.filter_alt_outlined,
                    color: Colors.white,
                    size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Filter:',
                style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    icon: Icon(Icons.arrow_drop_down,
                        color: Colors.green.shade700),
                    items: _filterOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(value),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFilter = value;
                          _filterData();
                        });
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Total: ${_filteredData.length}',
                  style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(51),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.green.withAlpha(102),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Cari nama, tanggal, atau waktu...',
            hintStyle: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.only(left: 8, right: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                color: Colors.white,
                size: 16,
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          style: TextStyle(
            color: Colors.green.shade800,
            fontSize: 14,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _filterData();
            });
          },
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_selectedRegion.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 50, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Silakan pilih region terlebih dahulu',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_spreadsheetId == null || _spreadsheetId!.isEmpty) {
      return Center(
        child: Text(
          'Spreadsheet ID tidak ditemukan untuk region $_selectedRegion',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    // Handle ketika sedang loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle ketika tidak ada data
    if (_filteredData.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data absensi untuk region $_selectedRegion',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(51),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 20,
                  horizontalMargin: 12,
                  headingRowColor: WidgetStateColor.resolveWith(
                        (states) => Colors.green.withAlpha(25),
                  ),
                  columns: const [
                    DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Lokasi', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: List<DataRow>.generate(
                    _filteredData.length,
                        (index) {
                      final data = _filteredData[index];
                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(data.name, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(data.dateFormatted)),
                          DataCell(Text(data.timeFormatted)),
                          DataCell(Text(data.location, overflow: TextOverflow.ellipsis)),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.map, color: Colors.green, size: 20),
                              onPressed: () => _openMaps(data.location),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openMaps(String location) async {
    try {
      final coordinates = _parseCoordinates(location);
      final lat = coordinates['lat'] ?? 0.0;
      final lng = coordinates['lng'] ?? 0.0;

      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _showErrorMessage('Tidak dapat membuka peta');
      }
    } catch (e) {
      _showErrorMessage('Format lokasi tidak valid');
    }
  }

  Map<String, double?> _parseCoordinates(String location) {
    try {
      final parts = location.split(',');
      return {
        'lat': double.tryParse(parts[0].trim()),
        'lng': double.tryParse(parts[1].trim()),
      };
    } catch (e) {
      return {'lat': null, 'lng': null};
    }
  }
}

class AbsensiData {
  final String name;
  final DateTime date;
  final TimeOfDay time;
  final String location;

  AbsensiData({
    required this.name,
    required this.date,
    required this.time,
    required this.location,
  });

  String get dateFormatted => DateFormat('dd/MM/yyyy').format(date);
  String get timeFormatted => '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date.millisecondsSinceEpoch,
      'hour': time.hour,
      'minute': time.minute,
      'location': location,
    };
  }

  factory AbsensiData.fromMap(Map<String, dynamic> map) {
    return AbsensiData(
      name: map['name'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      time: TimeOfDay(hour: map['hour'] as int, minute: map['minute'] as int),
      location: map['location'] as String,
    );
  }
}