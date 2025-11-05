import 'dart:async';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

class AktivitasDashboard extends StatefulWidget {
  const AktivitasDashboard({super.key});

  @override
  State<AktivitasDashboard> createState() => _AktivitasDashboardState();
}

class _AktivitasDashboardState extends State<AktivitasDashboard> {
  List<AktivitasData> _aktivitasData = [];
  List<AktivitasData> _filteredData = [];
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  String _selectedRegion = '';
  bool _isLoading = true;
  late Box _aktivitasBox;

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
      if (!Hive.isBoxOpen('aktivitasData')) {
        _aktivitasBox = await Hive.openBox('aktivitasData');
      } else {
        _aktivitasBox = Hive.box('aktivitasData');
      }
    } catch (e) {
      debugPrint('Error initializing Hive: $e');
      await Hive.close();
      _aktivitasBox = await Hive.openBox('aktivitasData');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeServices() async {
    await ConfigManager.loadConfig();
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
      final cachedData = _aktivitasBox.get(_selectedRegion);

      if (cachedData != null) {
        if (cachedData is List) {
          _setDataFromCache(List<Map<String, dynamic>>.from(cachedData));
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
      await _aktivitasBox.delete(_selectedRegion);
    }

    await _fetchData();
  }

  void _setDataFromCache(List<Map<String, dynamic>> cachedData) {
    try {
      setState(() {
        _aktivitasData = cachedData.map((data) => AktivitasData.fromMap(data)).toList();
        _filteredData = List.from(_aktivitasData);
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
      final rows = await _googleSheetsApi!.getSpreadsheetData('Aktivitas')
          .timeout(const Duration(seconds: 15));

      final aktivitasList = <AktivitasData>[];

      for (final row in rows.skip(1)) { // Skip header
        try {
          // Pastikan row memiliki cukup kolom
          if (row.length < 8) continue; // Sesuaikan dengan jumlah kolom yang dibutuhkan

          final email = row[0].toString().trim();
          final name = row[1].toString().trim();
          final status = row[2].toString().trim();
          final region = row[3].toString().trim();
          final aksi = row[4].toString().trim();
          final sheet = row[5].toString().trim();
          final fieldNumber = row[6].toString().trim();
          final timestampStr = row[7].toString().trim();

          final timestamp = _parseDateTime(timestampStr);

          if (timestamp != null) {
            aktivitasList.add(AktivitasData(
              email: email,
              name: name,
              status: status,
              region: region,
              aksi: aksi,
              sheet: sheet,
              fieldNumber: fieldNumber,
              timestamp: timestamp,
            ));
          } else {
            debugPrint('Gagal parse timestamp: $timestampStr');
          }
        } catch (e) {
          debugPrint('Error parsing row: $e\nRow: $row');
        }
      }

      _updateData(aktivitasList);
      await _saveDataToCache(aktivitasList);
    } on TimeoutException catch (_) {
      _showErrorMessage('Timeout: Server tidak merespons');
    } catch (e) {
      _showErrorMessage('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _parseDateTime(String dateTimeStr) {
    try {
      // Coba format dengan timezone (dari contoh data: 11/01/2025 16:06:17)
      final formats = [
        DateFormat('dd/MM/yyyy HH:mm:ss'), // Format utama
        DateFormat('MM/dd/yyyy HH:mm:ss'),  // Format alternatif
        DateFormat('yyyy-MM-dd HH:mm:ss'),  // Format alternatif
        DateFormat('dd/MM/yyyy'),           // Fallback hanya tanggal
      ];

      for (final format in formats) {
        try {
          return format.parse(dateTimeStr);
        } catch (_) {}
      }

      // Coba parse dari format Excel (serial number)
      final serial = double.tryParse(dateTimeStr);
      if (serial != null) {
        return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing datetime: $e');
      return null;
    }
  }

  void _updateData(List<AktivitasData> newData) {
    if (!mounted) return;

    debugPrint('Data baru diterima: ${newData.length} items');
    if (newData.isNotEmpty) {
      debugPrint('Contoh data pertama:');
      debugPrint('Email: ${newData[0].email}');
      debugPrint('Timestamp: ${newData[0].timestamp}');
      debugPrint('Sheet: ${newData[0].sheet}');
    }

    setState(() {
      _aktivitasData = newData;
      _filteredData = List.from(newData);
    });
  }

  Future<void> _saveDataToCache(List<AktivitasData> data) async {
    try {
      final dataToCache = data.map((e) => e.toMap()).toList();
      await _aktivitasBox.put(_selectedRegion, dataToCache);
    } catch (e) {
      debugPrint('Error saving to cache: $e');
      try {
        await Hive.close();
        _aktivitasBox = await Hive.openBox('aktivitasData');
        final dataToCache = data.map((e) => e.toMap()).toList();
        await _aktivitasBox.put(_selectedRegion, dataToCache);
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
      _filteredData = _aktivitasData.where((data) {
        final matchesSearch = data.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            data.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            data.sheet.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            data.fieldNumber.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesFilter = true;
        if (_selectedFilter == 'Hari Ini') {
          matchesFilter = data.timestamp.day == now.day &&
              data.timestamp.month == now.month &&
              data.timestamp.year == now.year;
        } else if (_selectedFilter == 'Minggu Ini') {
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));
          matchesFilter = data.timestamp.isAfter(startOfWeek) && data.timestamp.isBefore(endOfWeek);
        } else if (_selectedFilter == 'Bulan Ini') {
          matchesFilter = data.timestamp.month == now.month && data.timestamp.year == now.year;
        }

        return matchesSearch && matchesFilter;
      }).toList();
    });
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/admin'),
          ),
          title: const Text('Aktivitas Dashboard',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            value: _selectedRegion.isEmpty ? null : _selectedRegion,
            hint: Text(
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
                      displayText,
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
              padding: const EdgeInsets.symmetric(vertical: 6),
              offset: const Offset(0, -10),
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 48,
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
                  _filterData(); // Tambahkan ini untuk memastikan filter diaplikasikan
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredData.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada data aktivitas untuk region $_selectedRegion',
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
                    DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Sheet', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Field Number', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Waktu', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: List<DataRow>.generate(
                    _filteredData.length,
                        (index) {
                      final data = _filteredData[index];
                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(data.email, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(data.name, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(data.status, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(data.aksi, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(data.sheet, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(data.fieldNumber, overflow: TextOverflow.ellipsis)),
                          DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(data.timestamp))),
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
}

class AktivitasData {
  final String email;
  final String name;
  final String status;
  final String region;
  final String aksi;
  final String sheet;
  final String fieldNumber;
  final DateTime timestamp;

  AktivitasData({
    required this.email,
    required this.name,
    required this.status,
    required this.region,
    required this.aksi,
    required this.sheet,
    required this.fieldNumber,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'status': status,
      'region': region,
      'aksi': aksi,
      'sheet': sheet,
      'fieldNumber': fieldNumber,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory AktivitasData.fromMap(Map<String, dynamic> map) {
    return AktivitasData(
      email: map['email'] as String,
      name: map['name'] as String,
      status: map['status'] as String,
      region: map['region'] as String,
      aksi: map['aksi'] as String,
      sheet: map['sheet'] as String,
      fieldNumber: map['fieldNumber'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}