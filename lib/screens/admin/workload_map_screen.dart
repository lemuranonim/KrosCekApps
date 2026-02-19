// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; // Deteksi Web
import 'package:flutter/gestures.dart'; // Untuk Scroll Mouse
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../services/config_manager.dart';
import '../services/google_sheets_api.dart';

// Class ini membuat ListView bisa digeser pakai Mouse di browser
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class AppTheme {
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent = Color(0xFF1976D2);
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);
  static const Color background = Color(0xFFF5F5F5);
}

class WorkloadMapScreen extends StatefulWidget {
  const WorkloadMapScreen({super.key});

  @override
  State<WorkloadMapScreen> createState() => _WorkloadMapScreenState();
}

class _WorkloadMapScreenState extends State<WorkloadMapScreen> {
  String? _selectedRegion;
  List<String> _regionOptions = [];
  String? _error;

  Map<String, dynamic>? _geojsonFeatures;
  final Map<String, dynamic> _geoJsonLookup = {};
  String _selectedWorksheetTitle = 'Generative';
  final List<String> _worksheetTitles = ['Vegetative', 'Generative', 'Pre Harvest', 'Harvest'];
  static const List<String> _excludedRegions = ['PSP', 'PSP QA', 'QA Plant Inspection', 'HSP SWC', 'SWC'];

  String? _selectedDistrictState;
  String? _selectedGrowingSeasonState;
  List<String> _selectedWeeksState = [];

  static const String _allRegionsSentinel = "Semua Region";

  List<String> _availableDistricts = [];
  List<String> _availableGrowingSeasons = [];
  List<String> _availableWeeks = [];

  List<Map<String, dynamic>> _currentSheetData = [];
  List<Map<String, dynamic>> _filteredMapData = [];

  final List<Map<String, dynamic>> _kecamatanDataPoints = [];
  final Map<String, double> _kecamatanWorkload = {};
  final Map<String, Map<String, double>> _desaWorkloadByKecamatan = {};

  String? _selectedKecamatanKey;
  bool _isDetailPanelVisible = false;
  bool _isStreetView = true;

  bool _isLoading = true;
  bool _isLoadingGeoJson = true;
  bool _isMapReady = false;
  bool _initialZoomDone = false;

  final MapController _mapController = MapController();
  List<Polygon> _currentPolygons = [];
  bool _isLegendVisible = true;
  final Map<String, String> _regionLoadingStatus = {}; // Untuk melacak status tiap region

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    try {
      await ConfigManager.loadConfig();
      if (mounted) {
        final allRegionsFromConfig = ConfigManager.getAllRegionNames();

        // Filter menggunakan list _excludedRegions
        final filteredRegions = allRegionsFromConfig
            .where((region) => !_excludedRegions.contains(region))
            .toList();

        setState(() {
          _regionOptions = [_allRegionsSentinel, ...filteredRegions..sort()];
        });
      }
      await _initializeGeoJson();
    } catch (e) {
      // ... error handling
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeGeoJson() async {
    setState(() => _isLoadingGeoJson = true);
    try {
      final String response = await rootBundle.loadString('assets/gadm41_IDN_3.json');
      final data = json.decode(response);

      // --- MULAI OPTIMASI ---
      _geoJsonLookup.clear(); // Bersihkan data lama
      if (data['features'] != null) {
        final features = data['features'] as List;

        // Loop sekali saja saat awal (Startup)
        for (final feature in features) {
          final properties = feature['properties'];
          if (properties == null) continue;

          final String? gideonKecNameRaw = properties['NAME_3']?.toString();
          final String? gideonKabNameRaw = properties['NAME_2']?.toString();

          if (gideonKecNameRaw != null && gideonKabNameRaw != null) {
            // Kita buat KUNCI UNIK yang sama persis dengan logika Excel
            final String normalizedKec = _normalizeName(gideonKecNameRaw);
            final String normalizedKab = _normalizeName(gideonKabNameRaw);

            // Contoh Key: "SRAGEN_GEMOLONG"
            final String uniqueKey = '${normalizedKab}_$normalizedKec';

            // Simpan ke "Katalog"
            _geoJsonLookup[uniqueKey] = feature;
          }
        }
      }
      // --- SELESAI OPTIMASI ---

      if (mounted) {
        setState(() {
          _geojsonFeatures = data;
          _isLoadingGeoJson = false;
        });
        _triggerMapActionsIfNeeded();
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
      if (mounted) {
        setState(() {
          _geojsonFeatures = null;
          _isLoadingGeoJson = false;
        });
      }
    }
  }

  // Cache untuk menyimpan data yang sudah di-fetch
  static final Map<String, Map<String, List<Map<String, dynamic>>>> _dataCache = {};
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheDuration;
  }

  Future<void> _onRegionChanged(String? newRegion) async {
    if (newRegion == null) return;

    setState(() {
      _isLoading = true;
      _selectedRegion = newRegion;
      _selectedDistrictState = null; // Reset eksplisit
      _selectedGrowingSeasonState = null; // Reset eksplisit
      _selectedWeeksState.clear();
      _currentSheetData.clear();
      _filteredMapData.clear();
    });

    try {
      // Langsung panggil fetch, ekstraksi filter akan dipanggil di dalam fetch
      await _fetchDataForWorksheet(_selectedWorksheetTitle);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchDataFromFirestore(String worksheetName) async {
    try {
      debugPrint('🔍 [Fetch] Start: $worksheetName for $_selectedRegion');
      final List<Map<String, dynamic>> allData = [];

      if (_selectedRegion == _allRegionsSentinel) {
        // 1. Cek Cache
        if (_isCacheValid() && _dataCache.containsKey(worksheetName)) {
          debugPrint('⚡ [Cache] Using full cached data');
          if (mounted) {
            setState(() {
              _currentSheetData = List.from(_dataCache[worksheetName]!.values.expand((x) => x));
              _isLoading = false;
            });
            // Update filter setelah cache dimuat
            Future.microtask(() => _extractFiltersFromSheetData());
          }
          return;
        }

        final regions = ConfigManager.regions;

        // 2. Filter region yang dikecualikan (EXCLUDED)
        final targetRegions = regions.entries
            .where((entry) => !_excludedRegions.contains(entry.key))
            .toList();

        debugPrint('📋 [Fetch] Total valid regions to fetch: ${targetRegions.length}');

        final Map<String, List<Map<String, dynamic>>> regionDataMap = {};

        // --- LOGIKA BATCHING (PERBAIKAN UTAMA) ---
        // Kita ambil data per 5 region sekaligus, bukan 30 sekaligus.
        // Ini mencegah Timeout dan Rate Limit Google API.
        const int batchSize = 5;

        for (int i = 0; i < targetRegions.length; i += batchSize) {
          final int end = (i + batchSize < targetRegions.length) ? i + batchSize : targetRegions.length;
          final batch = targetRegions.sublist(i, end);

          debugPrint('🔄 [Fetch] Processing batch ${i ~/ batchSize + 1} (${batch.length} regions)...');

          // Eksekusi 1 Batch secara paralel
          final List<Future<Map<String, dynamic>>> batchFutures = batch.map((entry) {
            return _fetchSingleRegionData(entry.key, entry.value, worksheetName);
          }).toList();

          final results = await Future.wait(batchFutures);

          // Proses hasil batch
          for (final result in results) {
            if (result.isNotEmpty && result.containsKey('regionName')) {
              final String rName = result['regionName'];
              final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(result['data']);

              if (data.isNotEmpty) {
                regionDataMap[rName] = data;
                allData.addAll(data);
              }
            }
          }

          // Optional: Update UI sebagian agar user melihat progress (angka baris bertambah)
          if (mounted) {
            setState(() {
              // Update status baris terkumpul sementara (opsional)
            });
          }

          // Jeda sedikit antar batch untuk "mendinginkan" koneksi
          if (end < targetRegions.length) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        // --- AKHIR BATCHING ---

        // Simpan ke Cache
        _dataCache[worksheetName] = regionDataMap;
        _lastCacheTime = DateTime.now();

      } else {
        // Logika Single Region (Tidak perlu batching)
        // Cek apakah region ini masuk daftar blokir (double check)
        if (_excludedRegions.contains(_selectedRegion)) {
          setState(() => _isLoading = false);
          return;
        }

        final spreadsheetId = ConfigManager.getSpreadsheetId(_selectedRegion ?? '');
        if (spreadsheetId == null) {
          setState(() => _isLoading = false);
          return;
        }
        final result = await _fetchSingleRegionData(_selectedRegion!, spreadsheetId, worksheetName);
        if (result.containsKey('data')) {
          allData.addAll(result['data'] as List<Map<String, dynamic>>);
        }
      }

      debugPrint('📦 [Fetch] Total Data Terkumpul: ${allData.length} baris');

      if (mounted) {
        setState(() {
          _currentSheetData = allData;
          _isLoading = false;
        });
        // PENTING: Panggil fungsi filter setelah data diupdate
        Future.microtask(() => _extractFiltersFromSheetData());
      }
    } catch (e) {
      debugPrint('❌ [Fetch] Error Global: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✨ NEW: Fetch single region data (untuk parallel execution)
  Future<Map<String, dynamic>> _fetchSingleRegionData(
      String regionName,
      String spreadsheetId,
      String worksheetName
      ) async {
    try {
      if (mounted) setState(() => _regionLoadingStatus[regionName] = "Memuat...");

      final googleSheetsApi = GoogleSheetsApi(spreadsheetId);
      final initSuccess = await googleSheetsApi.init();

      if (!initSuccess) {
        if (mounted) setState(() => _regionLoadingStatus[regionName] = "Gagal Init");
        return {};
      }

      final rows = await googleSheetsApi.getSpreadsheetData(worksheetName);
      if (rows.isEmpty || rows.length <= 1) {
        if (mounted) setState(() => _regionLoadingStatus[regionName] = "Data Kosong");
        return {};
      }

      // --- LOGIKA MAPPING KOLOM (PERBAIKAN UTAMA DISINI) ---
      final List<String> headers = rows[0].map((e) => e.toString().toLowerCase()).toList();

      int getIdx(List<String> queries, int defaultIdx) {
        for (var q in queries) {
          int found = headers.indexWhere((h) => h.contains(q));
          if (found != -1) return found;
        }
        return defaultIdx;
      }

      // 1. Cari KABUPATEN (Target: Kab. Kediri, Kab. Blitar, dll)
      // HAPUS kata 'district' dari sini agar tidak salah ambil kecamatan
      final int districtIdx = getIdx(['kabupaten', 'kab.', 'kota', 'regency', 'city'], 13);

      // 2. Cari KECAMATAN (Target: Wates, Ringinrejo, dll)
      // MASUKKAN 'district' di sini karena District = Kecamatan dalam bahasa Inggris
      final int subDistrictIdx = getIdx(['kecamatan', 'kec.', 'sub district', 'district', 'distrik'], 12);

      final int seasonIdx = getIdx(['growing season', 'musim'], 1);
      final int villageIdx = getIdx(['village', 'desa', 'kelurahan'], 11);
      final int coordIdx = getIdx(['coordinate', 'koordinat'], 17);
      final int areaIdx = getIdx(['effective area', 'luas'], 8);
      final int fieldIdx = getIdx(['field no', 'nomor lahan'], 2);

      int weekIdx = headers.indexWhere((h) => h.contains('minggu ke') || h.contains('week'));
      if (weekIdx == -1) weekIdx = (worksheetName == 'Vegetative' || worksheetName == 'Generative') ? 29 : 27;

      final List<Map<String, dynamic>> data = [];
      final dataRows = rows.skip(1);

      for (final row in dataRows) {
        final growingSeason = _getValue(row, seasonIdx, '').trim();
        if (growingSeason.isEmpty || growingSeason.startsWith('#')) continue;

        // Ambil data berdasarkan index yang sudah dikoreksi di atas
        String kabVal = _getValue(row, districtIdx, '').trim();
        String kecVal = _getValue(row, subDistrictIdx, '').trim();

        // Normalisasi sedikit agar dropdown lebih rapi (Opsional)
        if (kabVal.isNotEmpty && !kabVal.toUpperCase().startsWith("KAB") && !kabVal.toUpperCase().startsWith("KOTA")) {
          // Jika data excel cuma "KEDIRI", kita bisa biarkan atau tambah prefix.
          // Untuk aman, biarkan apa adanya dari Excel.
        }

        data.add({
          'worksheet': worksheetName,
          'region': regionName,
          'growingSeason': growingSeason,
          'fieldNo': _getValue(row, fieldIdx, ''),
          'effectiveArea': _getValue(row, areaIdx, '0'),
          'village': _getValue(row, villageIdx, ''),
          'subDistrict': kecVal, // Ini akan berisi Kecamatan (Wates)
          'district': kabVal,    // Ini akan berisi Kabupaten (Kediri)
          'coordinate': _getValue(row, coordIdx, ''),
          'week': _getValue(row, weekIdx, ''),
        });
      }

      if (mounted) setState(() => _regionLoadingStatus[regionName] = "Selesai (${data.length})");
      return { 'regionName': regionName, 'data': data };

    } catch (e) {
      if (mounted) setState(() => _regionLoadingStatus[regionName] = "Error");
      return {};
    }
  }

  String _getValue(List<String> row, int index, String defaultValue) {
    return row.isNotEmpty && index >= 0 && index < row.length
        ? row[index]
        : defaultValue;
  }

  void _showRegionSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pilih Region',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Region list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _regionOptions.length,
                  itemBuilder: (context, index) {
                    final region = _regionOptions[index];
                    final isSelected = _selectedRegion == region;
                    final isAllRegions = region == _allRegionsSentinel;

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (region != _selectedRegion) {
                          HapticFeedback.lightImpact();
                          _onRegionChanged(region);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isAllRegions
                                    ? Colors.amber.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isAllRegions
                                    ? Icons.public_rounded
                                    : Icons.location_on_rounded,
                                size: 20,
                                color: isAllRegions
                                    ? Colors.amber.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                region,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : AppTheme.textDark,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetSubFilters() {
    _selectedDistrictState = null;
    _selectedGrowingSeasonState = null;
    _selectedWeeksState.clear();
    _availableDistricts.clear();
    _availableGrowingSeasons.clear();
    _availableWeeks.clear();
    _kecamatanWorkload.clear();
    _desaWorkloadByKecamatan.clear();
    _currentPolygons.clear();
    _selectedKecamatanKey = null;
    _isDetailPanelVisible = false;
    _initialZoomDone = false;
  }

  Future<void> _fetchDataForWorksheet(String worksheetName) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _selectedWorksheetTitle = worksheetName;
      _currentSheetData.clear();
      _filteredMapData.clear();
      _resetSubFilters();
    });

    await _fetchDataFromFirestore(worksheetName);
    if (mounted) _extractFiltersFromSheetData();
  }

  void _extractFiltersFromSheetData() {
    debugPrint('🔍 [Filter] Extracting filters from ${_currentSheetData.length} records');

    if (!mounted || _currentSheetData.isEmpty) {
      debugPrint('⚠️ [Filter] No data to extract filters from');
      setState(() {
        _availableGrowingSeasons.clear();
        _availableDistricts.clear();
        _availableWeeks.clear();
      });
      _applyAllFiltersAndBuildMap();
      return;
    }

    final seasons = <String>{};

    for (final row in _currentSheetData) {
      final seasonVal = row['growingSeason']?.toString() ?? '';
      if (seasonVal.isNotEmpty && !seasonVal.startsWith('#')) {
        seasons.add(seasonVal);
      }
    }

    debugPrint('📊 [Filter] Found ${seasons.length} unique seasons: $seasons');

    if (mounted) {
      setState(() {
        _availableGrowingSeasons = seasons.toList()..sort();
        if (_selectedGrowingSeasonState == null ||
            !_availableGrowingSeasons.contains(_selectedGrowingSeasonState)) {
          _selectedGrowingSeasonState = _availableGrowingSeasons.isNotEmpty
              ? _availableGrowingSeasons.first
              : null;
        }
        debugPrint('✅ [Filter] Selected season: $_selectedGrowingSeasonState');
      });
      _populateAvailableDistricts();
    }
  }

  void _populateAvailableDistricts() {
    if (!mounted) return;

    final districtsSet = <String>{};
    final String? currentSeason = _selectedGrowingSeasonState;

    for (final row in _currentSheetData) {
      final String rowSeason = row['growingSeason']?.toString().trim() ?? '';

      if (currentSeason == null || rowSeason == currentSeason) {
        // Ambil data District (sekarang isinya Kabupaten/Kota)
        String districtValue = row['district']?.toString().trim() ?? '';

        // Filter sampah data
        if (districtValue.isNotEmpty &&
            !districtValue.startsWith('#') &&
            districtValue.toLowerCase() != 'district' && // Cegah header terbawa
            districtValue.toLowerCase() != 'kabupaten') {

          districtsSet.add(districtValue);
        }
      }
    }

    setState(() {
      _availableDistricts = districtsSet.toList()..sort();

      // Reset seleksi jika district yang dipilih sebelumnya tidak valid lagi
      if (_selectedDistrictState != null && !_availableDistricts.contains(_selectedDistrictState)) {
        _selectedDistrictState = null;
      }
    });

    _populateAvailableWeeks();
  }

  void _populateAvailableWeeks() {
    if (!mounted) return;

    debugPrint('🔍 [Filter] Populating weeks for season: $_selectedGrowingSeasonState, district: $_selectedDistrictState');
    final weeksSet = <String>{};

    for (final row in _currentSheetData) {
      bool regionMatch = _selectedRegion == _allRegionsSentinel ||
          row['region']?.toString() == _selectedRegion;
      bool districtMatch = _selectedDistrictState == null ||
          row['district']?.toString() == _selectedDistrictState;
      bool seasonMatch = _selectedGrowingSeasonState == null ||
          row['growingSeason']?.toString() == _selectedGrowingSeasonState;

      if (regionMatch && districtMatch && seasonMatch) {
        final weekVal = row['week']?.toString().trim() ?? '';
        if (weekVal.isNotEmpty && !weekVal.startsWith('#')) {
          weeksSet.add(weekVal);
        }
      }
    }

    debugPrint('📊 [Filter] Found ${weeksSet.length} weeks: $weeksSet');

    final newSpecificWeeks = weeksSet.toList()
      ..sort((a, b) {
        int? valA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
        int? valB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
        if (valA != null && valB != null) return valA.compareTo(valB);
        return a.compareTo(b);
      });

    setState(() {
      _availableWeeks = newSpecificWeeks;
      _selectedWeeksState.removeWhere((week) => !_availableWeeks.contains(week));
      debugPrint('✅ [Filter] Available weeks updated');
    });

    _applyAllFiltersAndBuildMap();
  }

  void _applyAllFiltersAndBuildMap() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Gunakan where secara bertahap untuk keamanan data
    Iterable<Map<String, dynamic>> filtered = _currentSheetData;

    // 1. Filter Musim (Wajib ada)
    if (_selectedGrowingSeasonState != null) {
      filtered = filtered.where((row) =>
      row['growingSeason']?.toString().trim() == _selectedGrowingSeasonState);
    }

    // 2. Filter District (Hanya filter jika user memilih district spesifik)
    if (_selectedDistrictState != null && _selectedDistrictState!.isNotEmpty) {
      filtered = filtered.where((row) =>
      row['district']?.toString().trim() == _selectedDistrictState);
    }

    // 3. Filter Minggu (Hanya filter jika ada minggu yang dicentang)
    if (_selectedWeeksState.isNotEmpty) {
      filtered = filtered.where((row) =>
          _selectedWeeksState.contains(row['week']?.toString().trim()));
    }

    _filteredMapData = filtered.toList();

    debugPrint('🗺️ [Map] Building map with ${_filteredMapData.length} records');

    _calculateKecamatanWorkloadAndDesa(_filteredMapData);

    setState(() {
      _currentPolygons = _buildPolygons();
      _isLoading = false;
    });
  }

  void _calculateKecamatanWorkloadAndDesa(List<Map<String, dynamic>> dataToProcess) {
    _kecamatanWorkload.clear();
    _desaWorkloadByKecamatan.clear();

    for (final row in dataToProcess) {
      final String kecamatanRaw = row['subDistrict']?.toString().trim() ?? '';
      final String desaRaw = row['village']?.toString().trim() ?? '';
      final String districtRaw = row['district']?.toString().trim() ?? '';
      final effectiveArea = _parseDouble(row['effectiveArea']);

      if (kecamatanRaw.isEmpty || districtRaw.isEmpty) continue;

      final String normalizedKecamatanName = _normalizeName(kecamatanRaw);
      final String normalizedDistrictName = _normalizeName(districtRaw);
      final String uniqueKecamatanKey =
          '${normalizedDistrictName}_$normalizedKecamatanName';

      _kecamatanWorkload.update(
        uniqueKecamatanKey,
            (value) => value + effectiveArea,
        ifAbsent: () => effectiveArea,
      );

      _desaWorkloadByKecamatan.putIfAbsent(uniqueKecamatanKey, () => {});
      _desaWorkloadByKecamatan[uniqueKecamatanKey]!.update(
        desaRaw,
            (value) => value + effectiveArea,
        ifAbsent: () => effectiveArea,
      );
    }
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  void _triggerMapActionsIfNeeded() {
    if (mounted &&
        _isMapReady &&
        !_isLoadingGeoJson &&
        !_isLoading &&
        !_initialZoomDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          _autoZoomToFilteredArea();
          if (mounted) setState(() => _initialZoomDone = true);
        }
      });
    }
  }

  String _normalizeName(String name) {
    String normalized = name.toUpperCase();
    normalized = normalized.replaceAll("KOTA ADMINISTRASI ", "");
    normalized = normalized.replaceAll("KABUPATEN ", "");
    normalized = normalized.replaceAll("KOTA ", "");
    normalized = normalized.replaceAll("KECAMATAN ", "");
    normalized = normalized.replaceAll("KEC. ", "");
    normalized = normalized.replaceAll("KAB. ", "");
    normalized = normalized.replaceAll(".", "");
    normalized = normalized.replaceAll(",", "");
    normalized = normalized.replaceAll(" ", "");

    if (normalized.startsWith("KOTAADMINISTRASI")) {
      normalized = normalized.substring("KOTAADMINISTRASI".length);
    }
    if (normalized.startsWith("KABUPATEN")) {
      normalized = normalized.substring("KABUPATEN".length);
    }
    if (normalized.startsWith("KOTA")) {
      normalized = normalized.substring("KOTA".length);
    }
    if (normalized.startsWith("KECAMATAN")) {
      normalized = normalized.substring("KECAMATAN".length);
    }
    if (normalized.startsWith("KAB")) {
      normalized = normalized.substring("KAB".length);
    }
    if (normalized.startsWith("KEC")) {
      normalized = normalized.substring("KEC".length);
    }
    return normalized.trim();
  }

  Color _getKecamatanColor(double workload) {
    int alphaValue = 220;
    if (workload <= 0) {
      return Colors.green.shade100.withAlpha(150);
    } else if (workload <= 4.9) {
      return Colors.green.shade600.withAlpha(alphaValue);
    } else if (workload <= 9.9) {
      return Colors.amber.shade700.withAlpha(alphaValue);
    } else if (workload <= 19.9) {
      return Colors.orange.shade800.withAlpha(alphaValue);
    } else if (workload <= 29.9) {
      return Colors.deepOrange.shade700.withAlpha(alphaValue);
    } else if (workload <= 49.9) {
      return Colors.red.shade500.withAlpha(alphaValue);
    } else {
      return Colors.red.shade900.withAlpha(alphaValue);
    }
  }

  List<Polygon> _buildPolygons() {
    if (_kecamatanWorkload.isEmpty || _geoJsonLookup.isEmpty) {
      return [];
    }

    final List<Polygon> polygons = [];

    for (final entry in _kecamatanWorkload.entries) {
      final String uniqueKey = entry.key; // Format: KAB_KEC
      final double workload = entry.value;

      // 1. Coba cari Exact Match (Cepat)
      var feature = _geoJsonLookup[uniqueKey];

      // 2. FALLBACK (Penting!): Jika null, cari berdasarkan nama Kecamatan saja
      // Ini mengatasi masalah jika WATES dianggap District di Excel tapi Kecamatan di GeoJSON
      if (feature == null) {
        final parts = uniqueKey.split('_');
        if (parts.length > 1) {
          final String kecNameOnly = parts[1]; // Ambil bagian Kecamatan
          try {
            // Cari di seluruh values GeoJSON yang NAME_3 (Kecamatan) nya cocok
            final fallbackEntry = _geoJsonLookup.values.firstWhere((f) {
              final props = f['properties'];
              final String gideonKec = _normalizeName(props['NAME_3']?.toString() ?? '');
              return gideonKec == kecNameOnly;
            });
            feature = fallbackEntry;
          } catch (e) {
            // Tidak ketemu juga, skip
          }
        }
      }

      // Render Polygon jika feature ditemukan
      if (feature != null) {
        final geometry = feature['geometry'];
        final Color fillColor = _getKecamatanColor(workload);
        final bool isSelectedKecamatan = _selectedKecamatanKey == uniqueKey;

        // Gunakan label dari feature asli agar konsisten dengan peta
        final String label = uniqueKey;

        if (geometry != null && geometry['coordinates'] != null) {
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

          try {
            List<LatLng> convertCoords(List rawCoords) {
              return rawCoords.map<LatLng>((point) =>
                  LatLng(point.last as double, point.first as double)
              ).toList();
            }

            if (type == 'Polygon') {
              final points = convertCoords(coordinates.first as List);
              if (points.isNotEmpty) {
                polygons.add(_createPolygonStyle(points, fillColor, isSelectedKecamatan, label));
              }
            } else if (type == 'MultiPolygon') {
              for (final polygonCoords in coordinates) {
                final points = convertCoords(polygonCoords.first as List);
                if (points.isNotEmpty) {
                  polygons.add(_createPolygonStyle(points, fillColor, isSelectedKecamatan, label));
                }
              }
            }
          } catch (e) {
            debugPrint('Error parsing geometry for $uniqueKey: $e');
          }
        }
      }
    }
    return polygons;
  }

  // Helper biar kode lebih rapi (tambahkan ini di bawah _buildPolygons)
  Polygon _createPolygonStyle(List<LatLng> points, Color color, bool isSelected, String label) {
    return Polygon(
      points: points,
      color: color,
      borderColor: isSelected
          ? AppTheme.accent
          : AppTheme.primaryDark.withAlpha(178),
      borderStrokeWidth: isSelected ? 2.5 : 0.7,
      label: label,
    );
  }

  void _autoZoomToFilteredArea() {
    if (!mounted || !_isMapReady || _isLoadingGeoJson || _geojsonFeatures == null) {
      return;
    }

    List<LatLng> allPointsInView = [];

    // Jika user memilih filter "District" (Kabupaten)
    if (_selectedDistrictState != null) {
      final features = _geojsonFeatures!['features'] as List;
      final targetName = _normalizeName(_selectedDistrictState!); // e.g. "KEDIRI"

      for (final feature in features) {
        final properties = feature['properties'];
        if (properties == null) continue;

        // Kita bandingkan dengan NAME_2 (Kabupaten/Kota di GeoJSON)
        final String kabNameGeo = _normalizeName(properties['NAME_2']?.toString() ?? '');

        if (kabNameGeo == targetName) {
          final geometry = feature['geometry'];
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          try {
            if (type == 'Polygon') {
              allPointsInView.addAll((coordinates.first as List).map<LatLng>(
                      (point) => LatLng(point.last as double, point.first as double)));
            } else if (type == 'MultiPolygon') {
              for (final pC in coordinates) {
                allPointsInView.addAll((pC.first as List).map<LatLng>(
                        (point) => LatLng(point.last as double, point.first as double)));
              }
            }
          } catch (e) { /* ignore */ }
        }
      }
    }
    // Jika tidak ada filter district, tapi ada polygon kecamatan yang tampil
    else if (_currentPolygons.isNotEmpty) {
      for (final polygon in _currentPolygons) {
        allPointsInView.addAll(polygon.points);
      }
    }

    if (allPointsInView.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(allPointsInView),
            padding: const EdgeInsets.all(30.0)));
      } catch (e) {
        // Fallback
      }
    } else {
      // Default view
      _mapController.move(LatLng(-2.548926, 118.0148634), 5.0);
    }
  }

  void _centerMapOnCurrentFeatures() {
    if (!mounted || !_isMapReady) return;

    List<LatLng> pointsToFit = [];

    if (_kecamatanDataPoints.isNotEmpty) {
      for (var dataPoint in _kecamatanDataPoints) {
        pointsToFit.add(
            LatLng(dataPoint['lat'] as double, dataPoint['lng'] as double));
      }
    } else if (_currentPolygons.isNotEmpty) {
      for (final polygon in _currentPolygons) {
        if (polygon.points.isNotEmpty) {
          pointsToFit.addAll(polygon.points);
        }
      }
    }

    if (pointsToFit.isNotEmpty) {
      try {
        if (pointsToFit.length == 1) {
          _mapController.move(pointsToFit.first, 13.0);
        } else {
          LatLngBounds bounds = LatLngBounds.fromPoints(pointsToFit);
          _mapController.fitCamera(CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40.0),
          ));
        }
      } catch (e) {
        if (pointsToFit.isNotEmpty) {
          _mapController.move(pointsToFit.first, 10.0);
        } else {
          _mapController.move(LatLng(-2.548926, 118.0148634), 5.0);
        }
      }
    } else {
      _autoZoomToFilteredArea();
    }
  }

  void _fitBoundsForSelectedKecamatan(String kecamatanKey) {
    if (!mounted || !_isMapReady) return;

    // --- OPTIMASI: Langsung ambil dari katalog ---
    final feature = _geoJsonLookup[kecamatanKey];

    if (feature == null) return; // Tidak ketemu

    List<LatLng> kecamatanPoints = [];
    final geometry = feature['geometry'];

    if (geometry != null && geometry['coordinates'] != null) {
      final type = geometry['type'];
      final coordinates = geometry['coordinates'];
      try {
        if (type == 'Polygon') {
          kecamatanPoints.addAll((coordinates.first as List).map<LatLng>(
                  (p) => LatLng(p.last as double, p.first as double)));
        } else if (type == 'MultiPolygon') {
          for (final pC in coordinates) {
            kecamatanPoints.addAll((pC.first as List).map<LatLng>(
                    (p) => LatLng(p.last as double, p.first as double)));
          }
        }
      } catch (e) {
        /* ignore */
      }
    }

    if (kecamatanPoints.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(kecamatanPoints),
            padding: const EdgeInsets.all(20.0)));
      } catch (e) {
        /* ignore */
      }
    }
  }

  void _handleKecamatanTap(String tappedKecKey, {bool dontZoom = false}) {
    if (!mounted) return;
    setState(() {
      _selectedKecamatanKey = tappedKecKey;
      _isDetailPanelVisible = true;
      _kecamatanDataPoints.clear();

      for (final row in _filteredMapData) {
        final String normalizedKecName =
        _normalizeName(row['subDistrict']?.toString() ?? '');
        final String normalizedDistName =
        _normalizeName(row['district']?.toString() ?? '');
        final String uniqueKeyFromRow =
            '${normalizedDistName}_$normalizedKecName';

        if (uniqueKeyFromRow == tappedKecKey) {
          final coordStr = row['coordinate']?.toString() ?? '';
          final parts = coordStr.split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());
            final area = _parseDouble(row['effectiveArea']);
            final fieldNo = row['fieldNo']?.toString() ?? 'N/A';

            if (lat != null && lng != null) {
              _kecamatanDataPoints.add({
                'lat': lat,
                'lng': lng,
                'area': area,
                'label': fieldNo,
              });
            }
          }
        }
      }
      _currentPolygons = _buildPolygons();
      if (_isMapReady && !dontZoom) {
        _fitBoundsForSelectedKecamatan(tappedKecKey);
      }
    });
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              _selectedRegion == _allRegionsSentinel ? "Sinkronisasi Data Nasional" : "Memuat Data Region",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Menampilkan status per region yang sedang diproses
            if (_selectedRegion == _allRegionsSentinel)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Column(
                    children: _regionLoadingStatus.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: const TextStyle(fontSize: 12)),
                          Text(e.value, style: TextStyle(fontSize: 12, color: e.value.contains('Gagal') ? Colors.red : Colors.green)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Update parameter: Tambahkan ScrollController
  Widget _buildDetailPanel(ScrollController scrollController) {
    // 1. Validasi Data
    if (_selectedKecamatanKey == null ||
        !_desaWorkloadByKecamatan.containsKey(_selectedKecamatanKey)) {
      return const SizedBox.shrink();
    }

    // 2. Persiapkan Data
    final desaData = _desaWorkloadByKecamatan[_selectedKecamatanKey!]!;
    final kecamatanNameParts = _selectedKecamatanKey!.split('_');

    // Nama Kecamatan (Title Case sederhana)
    String displayName = kecamatanNameParts.length > 1
        ? kecamatanNameParts.sublist(1).join(' ')
        : _selectedKecamatanKey!;

    // Nama Kabupaten
    final displayDistrictName = kecamatanNameParts.first;

    // Total Workload
    final totalWorkloadKecamatan = _kecamatanWorkload[_selectedKecamatanKey!] ?? 0.0;

    // Ambil Warna Tema berdasarkan beban kerja (Hijau/Merah/dll)
    final Color themeColor = _getKecamatanColor(totalWorkloadKecamatan);

    // Sortir desa dari workload terbesar
    final sortedDesaEntries = desaData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 3. Bangun UI Panel
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        // Sudut atas membulat
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: AppScrollBehavior(),
        child: ListView(
          // PENTING: Sambungkan controller agar bisa di-scroll & di-drag
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // --- HEADER PANEL (Warna sesuai Status) ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: themeColor, // Background header mengikuti status workload
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indikator Drag (Garis kecil di tengah)
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Judul Kecamatan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "KECAMATAN",
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "Kab/Kota $displayDistrictName",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tombol Close
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _selectedKecamatanKey = null;
                            _isDetailPanelVisible = false;
                            // Reset state lain jika perlu
                          });
                        },
                      )
                    ],
                  ),
                ],
              ),
            ),

            // --- KARTU INFO UTAMA ---
            Transform.translate(
              offset: const Offset(0, -20), // Geser sedikit ke atas agar menumpuk header
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.analytics_outlined, color: themeColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Total Area Efektif",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  totalWorkloadKecamatan.toStringAsFixed(2),
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text("Ha",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // --- DAFTAR DESA ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Detail Desa/Kelurahan (${sortedDesaEntries.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Loop Daftar Desa
            ListView.builder(
              // Matikan scroll internal ListView ini agar ikut scroll induknya
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: sortedDesaEntries.length,
              itemBuilder: (context, index) {
                final entry = sortedDesaEntries[index];
                final double percent = totalWorkloadKecamatan > 0
                    ? (entry.value / totalWorkloadKecamatan)
                    : 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${entry.value.toStringAsFixed(2)} Ha",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: themeColor
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress Bar Sederhana
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool isPointInPolygon(LatLng point, List<LatLng> polygonVertices) {
    if (polygonVertices.isEmpty) return false;
    int intersectCount = 0;
    for (int j = 0; j < polygonVertices.length; j++) {
      LatLng vertA = polygonVertices.elementAt(j);
      LatLng vertB = polygonVertices.elementAt((j + 1) % polygonVertices.length);
      if (((vertA.latitude <= point.latitude &&
          point.latitude < vertB.latitude) ||
          (vertB.latitude <= point.latitude &&
              point.latitude < vertA.latitude)) &&
          (point.longitude <
              (vertB.longitude - vertA.longitude) *
                  (point.latitude - vertA.latitude) /
                  (vertB.latitude - vertA.latitude) +
                  vertA.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 10,
      right: 10,
      child: Column(
        children: [
          FloatingActionButton(
              heroTag: "zoomInWMS",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_isMapReady) {
                  _mapController.move(_mapController.camera.center,
                      _mapController.camera.zoom + 0.5);
                }
              },
              child: const Icon(Icons.add, color: AppTheme.primaryDark)),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "zoomOutWMS",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_isMapReady) {
                  _mapController.move(_mapController.camera.center,
                      _mapController.camera.zoom - 0.5);
                }
              },
              child: const Icon(Icons.remove, color: AppTheme.primaryDark)),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "centerFeaturesWMS",
              mini: true,
              backgroundColor: Colors.white,
              tooltip: 'Pusatkan Peta ke Fitur',
              onPressed: _centerMapOnCurrentFeatures,
              child: const Icon(Icons.center_focus_strong,
                  color: AppTheme.primaryDark)),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "layerToggleWMS",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => setState(() => _isStreetView = !_isStreetView),
              child: Icon(_isStreetView ? Icons.satellite_alt : Icons.map,
                  color: AppTheme.primaryDark)),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "legendToggleWMS",
              mini: true,
              backgroundColor: Colors.white,
              tooltip:
              _isLegendVisible ? 'Sembunyikan Legenda' : 'Tampilkan Legenda',
              onPressed: () {
                setState(() {
                  _isLegendVisible = !_isLegendVisible;
                });
              },
              child: const Icon(Icons.legend_toggle, color: AppTheme.primaryDark)),
        ],
      ),
    );
  }

  void _showMultiSelectWeekDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PremiumMultiSelectWeeks(
        availableWeeks: _availableWeeks,
        initialSelectedWeeks: _selectedWeeksState,
        onApply: (results) {
          setState(() {
            _selectedWeeksState = results;
            _selectedKecamatanKey = null;
            _isDetailPanelVisible = false;
            _kecamatanDataPoints.clear();
            _initialZoomDone = false;
          });
          _applyAllFiltersAndBuildMap();
        },
      ),
    );
  }

  String _getWeekFilterDisplayString() {
    if (_selectedWeeksState.isEmpty) {
      return 'Semua Minggu';
    } else if (_selectedWeeksState.length > 2) {
      return '${_selectedWeeksState.length} Minggu Dipilih';
    } else {
      return _selectedWeeksState.join(', ');
    }
  }

  // --- UI FILTER BAR BARU (PREMIUM) ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildModernSelector(
                label: 'Worksheet',
                value: _selectedWorksheetTitle,
                icon: Icons.assignment_outlined, // Fixed: Huruf kecil
                onTap: () => _showPremiumSelector(
                  title: "Pilih Worksheet",
                  items: _worksheetTitles,
                  selectedValue: _selectedWorksheetTitle,
                  onSelect: (val) => _fetchDataForWorksheet(val),
                ),
              ),
              const SizedBox(width: 12),
              _buildModernSelector(
                label: 'Musim Tanam',
                value: _selectedGrowingSeasonState ?? "Pilih Musim",
                icon: Icons.wb_sunny_outlined, // Fixed: Huruf kecil
                isLoading: _isLoading && _availableGrowingSeasons.isEmpty,
                onTap: () => _showPremiumSelector(
                  title: "Pilih Musim Tanam",
                  items: _availableGrowingSeasons,
                  selectedValue: _selectedGrowingSeasonState,
                  onSelect: (newValue) {
                    setState(() {
                      _selectedGrowingSeasonState = newValue;
                      _resetSubFilters();
                    });
                    _populateAvailableDistricts();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModernSelector(
                label: 'District',
                value: _selectedDistrictState ?? "Semua District",
                icon: Icons.location_city_outlined, // Fixed: Huruf kecil
                isLoading: _isLoading && _availableDistricts.isEmpty,
                onTap: () => _showPremiumSelector(
                  title: "Pilih District",
                  items: _availableDistricts,
                  selectedValue: _selectedDistrictState,
                  onSelect: (newValue) {
                    setState(() {
                      _selectedDistrictState = newValue;
                      _selectedWeeksState.clear();
                    });
                    _populateAvailableWeeks();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildModernSelector(
                label: 'Minggu Ke-',
                value: _isLoading ? 'Loading...' : (_availableWeeks.isEmpty ? 'Tidak ada data' : _getWeekFilterDisplayString()),
                icon: Icons.calendar_month_outlined, // Fixed: Huruf kecil
                onTap: (_isLoading || _availableWeeks.isEmpty) ? null : _showMultiSelectWeekDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNationalSummary() {
    if (_selectedRegion != _allRegionsSentinel || _isLoading) return const SizedBox.shrink();

    double totalArea = _filteredMapData.fold(0, (sum, item) => sum + _parseDouble(item['effectiveArea']));
    int totalFields = _filteredMapData.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(Icons.map, "$totalFields", "Total Lahan"),
          Container(width: 1, height: 30, color: Colors.white24),
          _buildSummaryItem(Icons.landscape, "${totalArea.toStringAsFixed(1)} Ha", "Luas Nasional"),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  // Widget Button untuk Selector
  Widget _buildModernSelector({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(icon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.unfold_more_rounded, size: 14, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modal Bottom Sheet untuk Pilih Item tunggal
  void _showPremiumSelector({
    required String title,
    required List<String> items,
    required String? selectedValue,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item == selectedValue;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    title: Text(item, style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primary) : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(item);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'Silakan Pilih Region',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          Text(
            'untuk memuat data peta workload.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final legendItems = [
      {'color': _getKecamatanColor(0), 'label': '0 Ha'},
      {'color': _getKecamatanColor(4.9), 'label': '> 0 - 4.9 Ha'},
      {'color': _getKecamatanColor(9.9), 'label': '> 5.0 - 9.9 Ha'},
      {'color': _getKecamatanColor(19.9), 'label': '> 10.0 - 19.9 Ha'},
      {'color': _getKecamatanColor(29.9), 'label': '> 20.0 - 29.9 Ha'},
      {'color': _getKecamatanColor(49.9), 'label': '> 30.0 - 49.9 Ha'},
      {'color': _getKecamatanColor(50.0), 'label': '> 50.0 Ha'},
    ];



    return AnimatedSlide(
      offset: _isLegendVisible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: _isLegendVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(220),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Area Efektif (Ha)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textDark),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 16.0,
                runSpacing: 4.0,
                alignment: WrapAlignment.center,
                children: legendItems.map((item) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            color: item['color'] as Color,
                            border: Border.all(color: Colors.black54, width: 0.5),
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item['label'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMedium),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        // Di dalam AppBar:
        leading: kIsWeb
            ? Container( // Jika WEB: Tampilkan tombol back khusus pop
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            // Aksi Back: Kembali ke Dashboard
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
          ),
        )
            : Container( // Jika MOBILE: Gunakan GoRouter seperti biasa
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.go('/admin'),
            padding: EdgeInsets.zero,
          ),
        ),
        title: GestureDetector(
          onTap: _isLoading ? null : _showRegionSelectionBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _selectedRegion == _allRegionsSentinel
                      ? Icons.public_rounded
                      : Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _selectedRegion ?? 'Pilih Region',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.unfold_more_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary,
                AppTheme.primaryDark,
              ],
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        actions: [
          // Cache indicator
          if (_isCacheValid())
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.orange.shade400,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.offline_bolt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Menu button
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              elevation: 8,
              offset: const Offset(0, 50),
              onSelected: (value) {
                if (value == 'clear_cache') {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _dataCache.clear();
                    _lastCacheTime = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle,
                                color: Colors.green, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Cache berhasil dihapus',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.white,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (value == 'refresh') {
                  HapticFeedback.mediumImpact();
                  if (_selectedRegion != null) {
                    _dataCache.clear();
                    _lastCacheTime = null;
                    _onRegionChanged(_selectedRegion!);
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade400, Colors.blue.shade600],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              size: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Refresh Data',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('Muat ulang data terbaru',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isCacheValid())
                  PopupMenuItem(
                    value: 'clear_cache',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.delete_sweep_rounded,
                                size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hapus Cache',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Bersihkan data tersimpan',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedRegion != null) _buildFilterBar(),
          _buildNationalSummary(),
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 4,
                        ),
                      ),
                      Icon(
                        _selectedRegion == _allRegionsSentinel
                            ? Icons.public
                            : Icons.location_on,
                        color: AppTheme.primary.withOpacity(0.5),
                        size: 40,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _selectedRegion == _allRegionsSentinel
                        ? 'Memuat data dari semua region...'
                        : 'Memuat data peta...',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedRegion == _allRegionsSentinel) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Ini mungkin memakan waktu beberapa saat',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            )
                : _error != null
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        "Terjadi Kesalahan",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ))
                : _selectedRegion == null
                ? _buildInitialPrompt()
                : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(-2.548926, 118.0148634),
                    initialZoom: 5.0,
                    onMapReady: () {
                      if (mounted) {
                        setState(() => _isMapReady = true);
                        _triggerMapActionsIfNeeded();
                      }
                    },
                    onTap: (tapPosition, latLng) {
                      String? tappedKey;
                      for (final polygon
                      in _currentPolygons.reversed) {
                        if (polygon.points.isNotEmpty &&
                            isPointInPolygon(
                                latLng, polygon.points)) {
                          tappedKey = polygon.label;
                          break;
                        }
                      }
                      if (tappedKey != null &&
                          _kecamatanWorkload
                              .containsKey(tappedKey)) {
                        _handleKecamatanTap(tappedKey);
                      } else {
                        setState(() {
                          bool needsRebuild =
                              _selectedKecamatanKey != null;
                          _selectedKecamatanKey = null;
                          _isDetailPanelVisible = false;
                          _kecamatanDataPoints.clear();
                          if (needsRebuild) {
                            _currentPolygons = _buildPolygons();
                          }
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      // 1. URL Template (Logic sudah benar)
                      urlTemplate: _isStreetView
                          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                          : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',

                      // 2. Subdomains (Logic sudah benar)
                      subdomains: const [],

                      // 3. PERBAIKAN DI SINI:
                      // Jangan gunakan 'null', gunakan string kosong '' agar tipe datanya tetap String (bukan String?)
                      userAgentPackageName: kIsWeb ? '' : 'com.workload.kroscek',
                    ),
                    if (_currentPolygons.isNotEmpty) PolygonLayer(polygons: _currentPolygons),
                    // TAMBAHKAN INI:
                    MarkerLayer(
                      markers: _kecamatanDataPoints.map((point) {
                        return Marker(
                          point: LatLng(point['lat'], point['lng']),
                          width: 30,
                          height: 30,
                          child: AnimatedPulseMarker(color: AppTheme.accent),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (_isLoading && _selectedRegion == _allRegionsSentinel)
                  _buildLoadingOverlay(),
                if (_isDetailPanelVisible && _selectedKecamatanKey != null)
                  Positioned.fill(
                    child: NotificationListener<DraggableScrollableNotification>(
                      onNotification: (notification) {
                        // Opsional: Logika jika ingin menutup saat di-swipe ke paling bawah
                        return true;
                      },
                      child: DraggableScrollableSheet(
                        initialChildSize: 0.35, // Tinggi awal (35% layar)
                        minChildSize: 0.15,     // Tinggi minimal (saat digeser ke bawah)
                        maxChildSize: 0.85,     // Tinggi maksimal (saat ditarik ke atas)
                        builder: (context, scrollController) {
                          // Kita kirim scrollController ke fungsi panel
                          return _buildDetailPanel(scrollController);
                        },
                      ),
                    ),
                  ),
                _buildMapControls(),
                if (_isLegendVisible)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: _buildLegend(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumMultiSelectWeeks extends StatefulWidget {
  final List<String> availableWeeks;
  final List<String> initialSelectedWeeks;
  final Function(List<String>) onApply;

  const _PremiumMultiSelectWeeks({
    required this.availableWeeks,
    required this.initialSelectedWeeks,
    required this.onApply,
  });

  @override
  State<_PremiumMultiSelectWeeks> createState() => _PremiumMultiSelectWeeksState();
}

class _PremiumMultiSelectWeeksState extends State<_PremiumMultiSelectWeeks> {
  late List<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tempSelected = List.from(widget.initialSelectedWeeks);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Pilih Minggu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _tempSelected.clear()),
                  child: const Text("Reset", style: TextStyle(color: Colors.redAccent)),
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableWeeks.length,
              itemBuilder: (context, index) {
                final week = widget.availableWeeks[index];
                final isSelected = _tempSelected.contains(week);
                return CheckboxListTile(
                  title: Text(week, style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.primary : AppTheme.textDark,
                  )),
                  value: isSelected,
                  activeColor: AppTheme.primary,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _tempSelected.add(week);
                      } else {
                        _tempSelected.remove(week);
                      }
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.onApply(_tempSelected);
                Navigator.pop(context);
              },
              child: const Text("Terapkan Filter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedPulseMarker extends StatefulWidget {
  final Color color;
  const AnimatedPulseMarker({super.key, required this.color});

  @override
  State<AnimatedPulseMarker> createState() => _AnimatedPulseMarkerState();
}

class _AnimatedPulseMarkerState extends State<AnimatedPulseMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Lingkaran denyut (Expanding)
            Container(
              width: 20 * _controller.value,
              height: 20 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(1 - _controller.value),
              ),
            ),
            // Titik tengah tetap
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}