import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/google_sheets_api.dart';

// --- AppTheme Class ---
class AppTheme {
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color accent = Color(0xFF1976D2);
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);
  static const Color background = Color(0xFFF5F5F5);
}
// --- End AppTheme Class ---

class DetailedMapScreen extends StatefulWidget {
  final String spreadsheetId; // Diperlukan untuk mengambil data
  final String initialWorksheetTitle;
  final String? initialRegion;
  final String? initialDistrict;
  final String? initialSeason;
  final String? initialQASpv;

  const DetailedMapScreen({
    super.key,
    required this.spreadsheetId,
    required this.initialWorksheetTitle,
    this.initialRegion,
    this.initialDistrict,
    this.initialSeason,
    this.initialQASpv,
  });

  @override
  State<DetailedMapScreen> createState() => _DetailedMapScreenState();
}

class _DetailedMapScreenState extends State<DetailedMapScreen> {
  late GoogleSheetsApi _googleSheetsApi;
  Map<String, dynamic>? _geojsonFeatures;

  late String _selectedWorksheetTitle;
  final List<String> _worksheetTitles = ['Vegetative', 'Generative', 'Pre Harvest', 'Harvest'];

  String? _selectedRegionState;
  String? _selectedDistrictState;
  String? _selectedGrowingSeasonState;
  String? _selectedWeekState;

  // UBAH: Menambahkan konstanta untuk "Semua Region" dan "Semua Minggu"
  // Ini membuat kode lebih mudah dibaca dan di-maintain daripada menggunakan string langsung.
  static const String _allRegionsSentinel = "Semua Region";
  static const String _allWeeksSentinel = "Semua Minggu";

  List<String> _availableRegions = [];
  List<String> _availableDistricts = [];
  List<String> _availableGrowingSeasons = [];
  List<String> _availableWeeks = [];

  List<List<String>> _currentSheetData = [];
  List<List<String>> _filteredMapData = [];

  final List<Map<String, dynamic>> _kecamatanDataPoints = [];
  final Map<String, double> _kecamatanWorkload = {};
  final Map<String, Map<String, double>> _desaWorkloadByKecamatan = {};

  String? _selectedKecamatanKey;
  bool _isDetailPanelVisible = false;
  bool _isStreetView = true;

  // Definisi kolom
  final int colGrowingSeason = 1; // B
  final int colFieldNo = 2; // C
  final int colEffectiveArea = 8; // I
  final int colVillage = 11; // L
  final int colSubDistrict = 12; // M
  final int colDistrict = 13; // N
  final int colCoordinate = 17; // R
  final int colRegion = 18; // S

  int get colWeek {
    switch (_selectedWorksheetTitle) {
      case 'Vegetative': return 29;
      case 'Generative': return 29;
      case 'Pre Harvest': return 27;
      case 'Harvest': return 27;
      default: return 29;
    }
  }

  bool _isLoadingGeoJson = true;
  bool _isLoadingData = true;
  bool _isMapReady = false;
  bool _initialZoomDone = false;

  final MapController _mapController = MapController();
  List<Polygon> _currentPolygons = [];

  @override
  void initState() {
    super.initState();
    _googleSheetsApi = GoogleSheetsApi(widget.spreadsheetId);
    _selectedWorksheetTitle = widget.initialWorksheetTitle;

    _selectedRegionState = widget.initialRegion ?? _allRegionsSentinel;
    _selectedDistrictState = widget.initialDistrict;
    _selectedGrowingSeasonState = widget.initialSeason;
    _selectedWeekState = _allWeeksSentinel;

    // UBAH: Panggil fungsi untuk memuat konfigurasi dan data secara berurutan
    _initializeScreen();
  }

  // UBAH: Buat fungsi inisialisasi baru untuk mengatur urutan loading
  Future<void> _initializeScreen() async {
    await _loadRegionConfig(); // Muat konfigurasi region terlebih dahulu
    _initializeGeoJson();
    _fetchDataForWorksheet(_selectedWorksheetTitle);
  }

  Future<void> _loadRegionConfig() async {
    try {
      final configSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('filter')
          .get();

      if (configSnapshot.exists) {
        final data = configSnapshot.data();
        if (data != null && data.containsKey('qa') && data['qa'] is List) {
          final regionsFromConfig = List<String>.from(data['qa']);
          if (mounted) {
            setState(() {
              _availableRegions = [_allRegionsSentinel, ...regionsFromConfig];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading region config: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat konfigurasi region: $e')));
      }
    }
  }

  Future<void> _initializeGeoJson() async {
    if (mounted) setState(() => _isLoadingGeoJson = true);
    try {
      final String response = await rootBundle.loadString('assets/gadm41_IDN_3.json');
      final data = json.decode(response);
      if (mounted) {
        setState(() { _geojsonFeatures = data; _isLoadingGeoJson = false; });
        _triggerMapActionsIfNeeded();
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
      if (mounted) {
        setState(() { _geojsonFeatures = null; _isLoadingGeoJson = false; });
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data peta: $e')));
      }
    }
  }

  Future<void> _fetchDataForWorksheet(String worksheetName) async {
    if (!mounted) return;
    setState(() {
      _isLoadingData = true;
      _currentSheetData = [];

      // Tidak perlu lagi mereset _availableRegions karena sudah fix dari config
      if (worksheetName != _selectedWorksheetTitle) {
        _selectedRegionState = _allRegionsSentinel;
      }
      _availableDistricts = []; _selectedDistrictState = null;
      _availableGrowingSeasons = []; _selectedGrowingSeasonState = null;
      _availableWeeks = [_allWeeksSentinel]; _selectedWeekState = _allWeeksSentinel;
      _kecamatanDataPoints.clear(); _selectedKecamatanKey = null; _isDetailPanelVisible = false;
      _initialZoomDone = false;
    });

    try {
      await _googleSheetsApi.init();
      final data = await _googleSheetsApi.getSpreadsheetData(worksheetName);

      if (mounted) {
        setState(() {
          _currentSheetData = data;
          _selectedWorksheetTitle = worksheetName;
          _isLoadingData = false;
        });
        // UBAH: Nama fungsi diubah agar lebih sesuai
        _extractFiltersFromSheetData();
      }
    } catch (e) {
      debugPrint("Error loading sheet data for $worksheetName: $e");
      if (mounted) {
        setState(() => _isLoadingData = false);
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data $worksheetName: $e')));
      }
    }
  }

  void _extractFiltersFromSheetData() {
    if (!mounted || _currentSheetData.isEmpty || _currentSheetData.length <= 1) {
      if (mounted) {
        setState(() {
          _availableRegions = [_allRegionsSentinel]; // UBAH: Pastikan sentinel ada
          _availableDistricts = [];
          _availableGrowingSeasons = []; _availableWeeks = [_allWeeksSentinel];
          if (_availableRegions.isEmpty) _selectedRegionState = null;
          if (_availableDistricts.isEmpty) _selectedDistrictState = null;
          if (_availableGrowingSeasons.isEmpty) _selectedGrowingSeasonState = null;
          _selectedWeekState = _allWeeksSentinel;
        });
        _applyAllFiltersAndBuildMap();
      }
      return;
    }
    final dataRows = _currentSheetData.skip(1);

    // final regions = <String>{};
    final seasons = <String>{};

    for (final row in dataRows) {
      // final regionVal = _getValue(row, colRegion, "");
      // if (regionVal.isNotEmpty) regions.add(regionVal);
      final seasonVal = _getValue(row, colGrowingSeason, "");
      if (seasonVal.isNotEmpty) seasons.add(seasonVal);
    }

    if(mounted){
      setState(() {
        // UBAH: Tambahkan "Semua Region" ke daftar yang tersedia di dropdown.
        // _availableRegions = [_allRegionsSentinel, ...regions.toList()..sort()];
        _availableGrowingSeasons = seasons.toList()..sort();

        // UBAH: Atur default ke "Semua Region" jika pilihan sebelumnya tidak valid.
        // if (_selectedRegionState == null || !_availableRegions.contains(_selectedRegionState)) {
        //   _selectedRegionState = _allRegionsSentinel;
        // }
        if (_selectedGrowingSeasonState == null || !_availableGrowingSeasons.contains(_selectedGrowingSeasonState)) {
          _selectedGrowingSeasonState = _availableGrowingSeasons.isNotEmpty ? _availableGrowingSeasons.first : null;
        }
      });
      _populateAvailableDistricts();
    }
  }

  void _populateAvailableDistricts() {
    if (!mounted) {
      _populateAvailableWeeks();
      return;
    }

    List<String> newDistricts = [];
    if (_currentSheetData.isNotEmpty) {
      final dataRows = _currentSheetData.skip(1);
      final districtsSet = <String>{};
      for (final row in dataRows) {
        // UBAH: Logika baru untuk menangani "Semua Region".
        // Jika "Semua Region" terpilih, regionMatch akan selalu true.
        final bool isAllRegionsSelected = _selectedRegionState == _allRegionsSentinel;
        final bool regionMatch = isAllRegionsSelected || _getValue(row, colRegion, "") == _selectedRegionState;

        if (regionMatch) {
          final districtValue = _getValue(row, colDistrict, "");
          if (districtValue.isNotEmpty) districtsSet.add(districtValue);
        }
      }
      newDistricts = districtsSet.toList()..sort();
    }

    String? oldSelectedDistrict = _selectedDistrictState;
    bool listChanged = _availableDistricts.length != newDistricts.length || !_availableDistricts.every(newDistricts.contains);

    if (listChanged) {
      _availableDistricts = newDistricts;
    }

    if (_selectedDistrictState == null || !_availableDistricts.contains(_selectedDistrictState)) {
      _selectedDistrictState = _availableDistricts.isNotEmpty ? _availableDistricts.first : null;
    }

    if (mounted) {
      if (listChanged || oldSelectedDistrict != _selectedDistrictState) {
        setState(() {});
      }
    }
    _populateAvailableWeeks();
  }

  void _populateAvailableWeeks() {
    if (!mounted) {
      _applyAllFiltersAndBuildMap();
      return;
    }

    List<String> newSpecificWeeks = [];
    if (_currentSheetData.isNotEmpty) {
      final dataRows = _currentSheetData.skip(1);
      final weeksSet = <String>{};
      for (final row in dataRows) {
        // UBAH: Sesuaikan logika pencocokan region
        bool regionMatch = _selectedRegionState == _allRegionsSentinel || _selectedRegionState == null || _getValue(row, colRegion, "") == _selectedRegionState;
        bool districtMatch = _selectedDistrictState == null || _getValue(row, colDistrict, "") == _selectedDistrictState;
        bool seasonMatch = _selectedGrowingSeasonState == null || _getValue(row, colGrowingSeason, "") == _selectedGrowingSeasonState;

        if (regionMatch && districtMatch && seasonMatch) {
          final weekVal = _getValue(row, colWeek, "");
          if (weekVal.isNotEmpty) weeksSet.add(weekVal);
        }
      }
      newSpecificWeeks = weeksSet.toList()..sort((a, b) {
        int? valA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
        int? valB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
        if (valA != null && valB != null) return valA.compareTo(valB);
        return a.compareTo(b);
      });
    }

    final newAvailableWeeksWithAll = [_allWeeksSentinel, ...newSpecificWeeks];
    String? oldSelectedWeek = _selectedWeekState;
    bool listChanged = _availableWeeks.length != newAvailableWeeksWithAll.length || !_listEquals(_availableWeeks, newAvailableWeeksWithAll);


    _availableWeeks = newAvailableWeeksWithAll;

    if (_selectedWeekState == null || !_availableWeeks.contains(_selectedWeekState)) {
      _selectedWeekState = _allWeeksSentinel;
    }

    if (mounted) {
      if (listChanged || oldSelectedWeek != _selectedWeekState) {
        setState(() {});
      }
    }
    _applyAllFiltersAndBuildMap();
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _applyAllFiltersAndBuildMap() {
    if (!mounted) return;
    setState(() => _isLoadingData = true);

    _filteredMapData = List.from(_currentSheetData.length > 1 ? _currentSheetData.skip(1) : <List<String>>[]);

    // UBAH: INI BAGIAN PALING PENTING.
    // Filter region hanya diterapkan jika pilihan BUKAN "Semua Region".
    if (_selectedRegionState != null && _selectedRegionState != _allRegionsSentinel) {
      _filteredMapData = _filteredMapData.where((row) => _getValue(row, colRegion, "") == _selectedRegionState).toList();
    }
    // Filter lainnya tetap berjalan seperti biasa.
    if (_selectedDistrictState != null) {
      _filteredMapData = _filteredMapData.where((row) => _getValue(row, colDistrict, "") == _selectedDistrictState).toList();
    }
    if (_selectedGrowingSeasonState != null) {
      _filteredMapData = _filteredMapData.where((row) => _getValue(row, colGrowingSeason, "") == _selectedGrowingSeasonState).toList();
    }
    if (_selectedWeekState != null && _selectedWeekState != _allWeeksSentinel) {
      _filteredMapData = _filteredMapData.where((row) => _getValue(row, colWeek, "") == _selectedWeekState).toList();
    }

    _calculateKecamatanWorkloadAndDesa(_filteredMapData);

    if (mounted) {
      setState(() {
        _currentPolygons = _buildPolygons();
        _isLoadingData = false;
        if (_selectedKecamatanKey != null && !_kecamatanWorkload.containsKey(_selectedKecamatanKey)) {
          _selectedKecamatanKey = null;
          _isDetailPanelVisible = false;
          _kecamatanDataPoints.clear();
        } else if (_selectedKecamatanKey != null) {
          _handleKecamatanTap(_selectedKecamatanKey!, dontZoom: true);
        }
      });
      _triggerMapActionsIfNeeded();
    }
  }

  void _calculateKecamatanWorkloadAndDesa(List<List<String>> dataToProcess) {
    _kecamatanWorkload.clear();
    _desaWorkloadByKecamatan.clear();
    for (final row in dataToProcess) {
      final String kecamatanRaw = _getValue(row, colSubDistrict, "").trim();
      final String desaRaw = _getValue(row, colVillage, "").trim();
      final String districtRaw = _getValue(row, colDistrict, "").trim();
      final String effectiveAreaStr = _getValue(row, colEffectiveArea, "0");

      if (kecamatanRaw.isEmpty || districtRaw.isEmpty) continue;

      final String normalizedKecamatanName = _normalizeName(kecamatanRaw);
      final String normalizedDistrictName = _normalizeName(districtRaw);
      final String uniqueKecamatanKey = '${normalizedDistrictName}_$normalizedKecamatanName';

      double effectiveArea = 0.0;
      try { effectiveArea = double.tryParse(effectiveAreaStr.replaceAll(',', '.')) ?? 0.0; } catch (e) { /* ignore */ }

      _kecamatanWorkload.update(uniqueKecamatanKey, (value) => value + effectiveArea, ifAbsent: () => effectiveArea);
      _desaWorkloadByKecamatan.putIfAbsent(uniqueKecamatanKey, () => {});
      _desaWorkloadByKecamatan[uniqueKecamatanKey]!.update(desaRaw, (value) => value + effectiveArea, ifAbsent: () => effectiveArea);
    }
  }

  void _triggerMapActionsIfNeeded() {
    if (mounted && _isMapReady && !_isLoadingGeoJson && !_isLoadingData && !_initialZoomDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          _autoZoomToFilteredArea();
          if(mounted) setState(() => _initialZoomDone = true);
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

  String _getValue(List<String> row, int index, String defaultValue) {
    return row.isNotEmpty && index >= 0 && index < row.length ? row[index] : defaultValue;
  }

  Color _getKecamatanColor(String kecamatanKey) {
    double workload = _kecamatanWorkload[kecamatanKey] ?? 0.0;
    int alphaValue = 220;

    if (workload <= 0) {
      return Colors.lightGreenAccent.shade100.withAlpha(150);
    }
    else if (workload <= 3.5) {
      return Colors.green.shade200.withAlpha(alphaValue);
    } else if (workload <= 7.0) {
      return Colors.green.shade500.withAlpha(alphaValue);
    } else if (workload <= 10.0) {
      return Colors.green.shade800.withAlpha(alphaValue);
    }
    else if (workload <= 11.5) {
      return Colors.yellow.shade200.withAlpha(alphaValue);
    } else if (workload <= 13.5) {
      return Colors.yellow.shade500.withAlpha(alphaValue);
    } else if (workload <= 15.0) {
      return Colors.amber.shade700.withAlpha(alphaValue);
    }
    else if (workload <= 16.5) {
      return Colors.orange.shade200.withAlpha(alphaValue);
    } else if (workload <= 18.5) {
      return Colors.orange.shade500.withAlpha(alphaValue);
    } else if (workload <= 20.0) {
      return Colors.deepOrange.shade500.withAlpha(alphaValue);
    }
    else if (workload <= 25.0) {
      return Colors.red.shade200.withAlpha(alphaValue);
    } else if (workload <= 30.0) {
      return Colors.red.shade500.withAlpha(alphaValue);
    } else {
      return Colors.red.shade900.withAlpha(alphaValue);
    }
  }

  List<Polygon> _buildPolygons() {
    if (_geojsonFeatures == null || _geojsonFeatures!['features'] == null ) return [];
    final List<Polygon> polygons = [];
    final features = _geojsonFeatures!['features'] as List;

    for (final feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties == null || geometry == null || geometry['coordinates'] == null) continue;

      final String? gideonKecNameRaw = properties['NAME_3']?.toString();
      final String? gideonKabNameRaw = properties['NAME_2']?.toString();
      if (gideonKecNameRaw == null || gideonKecNameRaw.isEmpty || gideonKabNameRaw == null || gideonKabNameRaw.isEmpty) continue;

      final String normalizedGeoKecName = _normalizeName(gideonKecNameRaw);
      final String normalizedGeoKabName = _normalizeName(gideonKabNameRaw);
      final String uniqueGeoKecamatanKey = '${normalizedGeoKabName}_$normalizedGeoKecName';

      // UBAH: Sesuaikan logika pencocokan distrik
      bool isAllDistricts = _selectedDistrictState == null;
      bool isAllRegions = _selectedRegionState == _allRegionsSentinel;
      bool districtMatch = isAllDistricts || normalizedGeoKabName == _normalizeName(_selectedDistrictState!);

      // Tampilkan poligon jika:
      // 1. Distriknya cocok DAN (Workload ada ATAU Semua distrik dipilih)
      // 2. ATAU Semua region dipilih DAN workload ada untuk kunci kecamatan tersebut
      bool shouldDisplay = (districtMatch && (_kecamatanWorkload.containsKey(uniqueGeoKecamatanKey) || isAllDistricts)) || (isAllRegions && _kecamatanWorkload.containsKey(uniqueGeoKecamatanKey));

      if (shouldDisplay) {
        final Color fillColor = _getKecamatanColor(uniqueGeoKecamatanKey);
        final bool isSelectedKecamatan = _selectedKecamatanKey == uniqueGeoKecamatanKey;
        final type = geometry['type'];
        final coordinates = geometry['coordinates'];
        try {
          if (type == 'Polygon') {
            final List<LatLng> points = (coordinates.first as List)
                .map<LatLng>((point) => LatLng(point.last as double, point.first as double)).toList();
            if (points.isNotEmpty) polygons.add(Polygon(points: points, color: fillColor, borderColor: isSelectedKecamatan ? AppTheme.accent : AppTheme.primaryDark.withAlpha(178), borderStrokeWidth: isSelectedKecamatan ? 2.5 : 0.7, label: uniqueGeoKecamatanKey));
          } else if (type == 'MultiPolygon') {
            for (final polygonCoords in coordinates) {
              final List<LatLng> points = (polygonCoords.first as List)
                  .map<LatLng>((point) => LatLng(point.last as double, point.first as double)).toList();
              if (points.isNotEmpty) polygons.add(Polygon(points: points, color: fillColor, borderColor: isSelectedKecamatan ? AppTheme.accent : AppTheme.primaryDark.withAlpha(178), borderStrokeWidth: isSelectedKecamatan ? 2.5 : 0.7, label: uniqueGeoKecamatanKey));
            }
          }
        } catch (e) { /* ignore */ }
      }
    }
    return polygons;
  }

  void _autoZoomToFilteredArea() {
    if (!mounted || !_isMapReady || _isLoadingGeoJson || _geojsonFeatures == null) {
      return;
    }
    List<LatLng> allPointsInView = [];
    if(_currentPolygons.isNotEmpty){
      for(final polygon in _currentPolygons) {
        allPointsInView.addAll(polygon.points);
      }
      // UBAH: Jangan hanya zoom ke distrik jika "Semua Region" aktif dan tidak ada distrik terpilih
    } else if (_selectedDistrictState != null) {
      final features = _geojsonFeatures!['features'] as List;
      for (final feature in features) {
        final properties = feature['properties'];
        if (properties == null) {
          continue;
        }
        final String? gideonKabNameRaw = properties['NAME_2']?.toString();
        if (gideonKabNameRaw == null) {
          continue;
        }
        if (_normalizeName(gideonKabNameRaw) == _normalizeName(_selectedDistrictState!)) {
          final geometry = feature['geometry'];
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          try {
            if (type == 'Polygon') {
              allPointsInView.addAll((coordinates.first as List).map<LatLng>((point) => LatLng(point.last as double, point.first as double)));
            } else if (type == 'MultiPolygon') {
              for (final pC in coordinates) {
                allPointsInView.addAll((pC.first as List).map<LatLng>((point) => LatLng(point.last as double, point.first as double)));
              }
            }
          } catch(e) {/* ignore */}
        }
      }
    }

    if (allPointsInView.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(allPointsInView), padding: const EdgeInsets.all(30.0)));
      } catch (e) { _mapController.move(LatLng(-2.548926, 118.0148634), 5.0); }
    } else {
      _mapController.move(LatLng(-2.548926, 118.0148634), 5.0);
    }
  }

  void _centerMapOnCurrentFeatures() {
    if (!mounted || !_isMapReady) return;

    List<LatLng> pointsToFit = [];

    if (_kecamatanDataPoints.isNotEmpty) {
      for (var dataPoint in _kecamatanDataPoints) {
        pointsToFit.add(LatLng(dataPoint['lat'] as double, dataPoint['lng'] as double));
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
          _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(40.0),
              )
          );
        }
      } catch (e) {
        debugPrint("Error centering map on features: $e");
        if (pointsToFit.isNotEmpty) {
          _mapController.move(pointsToFit.first, 10.0);
        } else {
          _mapController.move(LatLng(-2.548926, 118.0148634), 5.0);
        }
      }
    } else {
      _autoZoomToFilteredArea();
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada fitur untuk dipusatkan pada filter saat ini.'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _fitBoundsForSelectedKecamatan(String kecamatanKey) {
    if (!mounted || !_isMapReady || _geojsonFeatures == null) return;
    final features = _geojsonFeatures!['features'] as List;
    List<LatLng> kecamatanPoints = [];

    for (final feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties == null || geometry == null || geometry['coordinates'] == null) continue;

      final String? gideonKecNameRaw = properties['NAME_3']?.toString();
      final String? gideonKabNameRaw = properties['NAME_2']?.toString();
      if (gideonKecNameRaw == null || gideonKabNameRaw == null) continue;

      if ('${_normalizeName(gideonKabNameRaw)}_${_normalizeName(gideonKecNameRaw)}' == kecamatanKey) {
        final type = geometry['type'];
        final coordinates = geometry['coordinates'];
        try {
          if (type == 'Polygon') {
            kecamatanPoints.addAll((coordinates.first as List).map<LatLng>((p) => LatLng(p.last as double, p.first as double)));
          } else if (type == 'MultiPolygon') {
            for (final pC in coordinates) {
              kecamatanPoints.addAll((pC.first as List).map<LatLng>((p) => LatLng(p.last as double, p.first as double)));
            }
          }
        } catch (e) {/* ignore */}
        break;
      }
    }
    if (kecamatanPoints.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(kecamatanPoints), padding: const EdgeInsets.all(20.0)));
      } catch (e) { debugPrint("Error fitting camera to selected kecamatan bounds: $e"); }
    }
  }

  void _handleKecamatanTap(String tappedKecKey, {bool dontZoom = false}) {
    if (!mounted) return;
    setState(() {
      _selectedKecamatanKey = tappedKecKey;
      _isDetailPanelVisible = true;
      _kecamatanDataPoints.clear();

      for (final row in _filteredMapData) {
        final String normalizedKecName = _normalizeName(_getValue(row, colSubDistrict, ""));
        final String normalizedDistName = _normalizeName(_getValue(row, colDistrict, ""));
        final String uniqueKeyFromRow = '${normalizedDistName}_$normalizedKecName';

        if (uniqueKeyFromRow == tappedKecKey) {
          final coordStr = _getValue(row, colCoordinate, "");
          final parts = coordStr.split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());
            final areaStr = _getValue(row, colEffectiveArea, "0");
            final area = double.tryParse(areaStr.replaceAll(',', '.')) ?? 0.0;
            final fieldNo = _getValue(row, colFieldNo, "N/A");

            if (lat != null && lng != null) {
              _kecamatanDataPoints.add({'lat': lat, 'lng': lng, 'area': area, 'label': fieldNo});
            }
          }
        }
      }
      _currentPolygons = _buildPolygons();
      if(_isMapReady && !dontZoom) {
        _fitBoundsForSelectedKecamatan(tappedKecKey);
      }
    });
  }

  Widget _buildDetailPanel() {
    if (_selectedKecamatanKey == null ||
        !_desaWorkloadByKecamatan.containsKey(_selectedKecamatanKey) ||
        _desaWorkloadByKecamatan[_selectedKecamatanKey!] == null) {
      return const SizedBox.shrink();
    }
    final desaData = _desaWorkloadByKecamatan[_selectedKecamatanKey!]!;
    final kecamatanNameParts = _selectedKecamatanKey!.split('_');
    final displayName = kecamatanNameParts.length > 1 ? kecamatanNameParts.sublist(1).join(' ') : _selectedKecamatanKey!;
    final displayDistrictName = kecamatanNameParts.first;
    final totalWorkloadKecamatan = _kecamatanWorkload[_selectedKecamatanKey!] ?? 0.0;

    return Container(
      width: 300,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Kec. $displayName",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 24, color: AppTheme.textMedium),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _selectedKecamatanKey = null;
                    _isDetailPanelVisible = false;
                    _kecamatanDataPoints.clear();
                    _currentPolygons = _buildPolygons();
                  });
                },
              ),
            ],
          ),
          Text("Kab./Kota: $displayDistrictName", style: const TextStyle(fontSize: 14, color: AppTheme.textMedium)),
          const SizedBox(height: 8),
          Text("Total Area Efektif: ${totalWorkloadKecamatan.toStringAsFixed(2)} Ha", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.accent)),
          const Divider(height: 20, thickness: 1),
          Text("Desa/Kelurahan (${desaData.length}):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Expanded(
            child: desaData.isEmpty
                ? const Center(child: Text("Tidak ada data desa.", style: TextStyle(color: AppTheme.textMedium, fontSize: 14)))
                : ListView.builder(
              shrinkWrap: true,
              itemCount: desaData.length,
              itemBuilder: (context, index) {
                String desaName = desaData.keys.elementAt(index);
                double workload = desaData[desaName] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(desaName, style: const TextStyle(fontSize: 14)),
                      Text("${workload.toStringAsFixed(2)} Ha", style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool isPointInPolygon(LatLng point, List<LatLng> polygonVertices) {
    if (polygonVertices.isEmpty) return false;
    int intersectCount = 0;
    for (int j = 0; j < polygonVertices.length; j++) {
      LatLng vertA = polygonVertices.elementAt(j);
      LatLng vertB = polygonVertices.elementAt((j + 1) % polygonVertices.length);
      if (((vertA.latitude <= point.latitude && point.latitude < vertB.latitude) ||
          (vertB.latitude <= point.latitude && point.latitude < vertA.latitude)) &&
          (point.longitude < (vertB.longitude - vertA.longitude) * (point.latitude - vertA.latitude) / (vertB.latitude - vertA.latitude) + vertA.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  Widget _buildFilterBar() {
    return Container(
        padding: const EdgeInsets.all(8.0),
        color: AppTheme.primaryLight.withAlpha(25),
        child: Column(
          children: [
            Row(children: [
              _buildFilterDropdown<String>( labelText: 'Worksheet', value: _selectedWorksheetTitle, items: _worksheetTitles, hintText: "Pilih Worksheet",
                onChanged: (newValue) {
                  if (newValue != null && newValue != _selectedWorksheetTitle) {
                    _fetchDataForWorksheet(newValue);
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown<String>( labelText: 'Musim Tanam', value: _selectedGrowingSeasonState, items: _availableGrowingSeasons, hintText: "Pilih Musim",
                isLoading: _isLoadingData && _availableGrowingSeasons.isEmpty,
                onChanged: (newValue) {
                  if (newValue != _selectedGrowingSeasonState) {
                    setState(() {
                      _selectedGrowingSeasonState = newValue;
                      _selectedKecamatanKey = null; _isDetailPanelVisible = false; _kecamatanDataPoints.clear();
                      _populateAvailableWeeks();
                    });
                  }
                },
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _buildFilterDropdown<String>( labelText: 'Region', value: _selectedRegionState, items: _availableRegions, hintText: "Pilih Region",
                isLoading: _isLoadingData && _availableRegions.length <= 1, // UBAH: Cek jika hanya ada sentinel
                onChanged: (newValue) {
                  if (newValue != _selectedRegionState) {
                    setState(() {
                      _selectedRegionState = newValue;
                      // UBAH: Saat region diganti, reset district dan week.
                      // Ini memberikan alur yang lebih logis bagi pengguna.
                      _selectedDistrictState = null;
                      _availableDistricts = [];
                      _selectedWeekState = _allWeeksSentinel;
                      _availableWeeks = [_allWeeksSentinel];
                      _selectedKecamatanKey = null; _isDetailPanelVisible = false; _kecamatanDataPoints.clear();
                      // UBAH: Reset zoom agar peta bisa menyesuaikan dengan area baru.
                      _initialZoomDone = false;
                    });
                    _populateAvailableDistricts();
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown<String>( labelText: 'District', value: _selectedDistrictState, items: _availableDistricts, hintText: "Pilih District",
                isLoading: _isLoadingData && _availableDistricts.isEmpty, // UBAH: Kondisi loading disederhanakan
                onChanged: (newValue) {
                  if (newValue != _selectedDistrictState) {
                    setState(() {
                      _selectedDistrictState = newValue;
                      // UBAH: Reset week dan peta saat district diganti.
                      _selectedWeekState = _allWeeksSentinel;
                      _availableWeeks = [_allWeeksSentinel];
                      _selectedKecamatanKey = null; _isDetailPanelVisible = false; _kecamatanDataPoints.clear();
                      _initialZoomDone = false;
                    });
                    _populateAvailableWeeks();
                  }
                },
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _buildFilterDropdown<String>( labelText: 'Minggu Ke-', value: _selectedWeekState, items: _availableWeeks, hintText: "Filter Minggu",
                isLoading: _isLoadingData && _availableWeeks.length <= 1, // UBAH: Kondisi loading disederhanakan
                onChanged: (newValue) {
                  if (newValue != _selectedWeekState) {
                    setState(() {
                      _selectedWeekState = newValue ?? _allWeeksSentinel;
                      _selectedKecamatanKey = null; _isDetailPanelVisible = false; _kecamatanDataPoints.clear();
                    });
                    _applyAllFiltersAndBuildMap();
                  }
                },
              ),
              Expanded(child: Container()),
            ])
          ],
        )
    );
  }

  Widget _buildFilterDropdown<T>({
    required String labelText,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String hintText,
    bool isLoading = false,
  }) {
    String displayHint = isLoading ? "Loading..." : (items.isEmpty && value == null ? "Tidak ada data" : hintText);

    return Expanded(
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
          fillColor: Colors.white,
          filled: true,
        ),
        initialValue: value,
        hint: Text(displayHint, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        isExpanded: true,
        items: items.map((T itemValue) {
          return DropdownMenuItem<T>(
            value: itemValue,
            child: Text(itemValue.toString(), style: TextStyle(fontSize: 14, color: AppTheme.textDark), overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: isLoading || (items.isEmpty && value == null && !items.contains(value)) ? null : onChanged, // UBAH: Penyesuaian kondisi disabled
        style: TextStyle(color: AppTheme.textDark, fontSize: 14),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 10,
      right: 10,
      child: Column(
        children: [
          FloatingActionButton(
              heroTag: "zoomInDMS",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if(_isMapReady) _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 0.5);
              },
              child: const Icon(Icons.add, color: AppTheme.primaryDark)
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "zoomOutDMS",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if(_isMapReady) _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 0.5);
              },
              child: const Icon(Icons.remove, color: AppTheme.primaryDark)
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "centerFeaturesDMS",
              mini: true,
              backgroundColor: Colors.white,
              tooltip: 'Pusatkan Peta ke Fitur',
              onPressed: _centerMapOnCurrentFeatures,
              child: const Icon(Icons.center_focus_strong, color: AppTheme.primaryDark)
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
              heroTag: "layerToggleDMS",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () => setState(() => _isStreetView = !_isStreetView),
              child: Icon(_isStreetView ? Icons.satellite_alt : Icons.map, color: AppTheme.primaryDark)
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showOverallLoading = _isLoadingGeoJson || (_isLoadingData && _currentSheetData.isEmpty);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Workload Map - ${_selectedWorksheetTitle.isNotEmpty ? _selectedWorksheetTitle : "..."}', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: showOverallLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
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
                      // Balik urutan poligon agar poligon yang lebih kecil/di atas bisa diketuk
                      for (final polygon in _currentPolygons.reversed) {
                        if (polygon.points.isNotEmpty && isPointInPolygon(latLng, polygon.points)) {
                          tappedKey = polygon.label;
                          break;
                        }
                      }
                      if (tappedKey != null && _kecamatanWorkload.containsKey(tappedKey)) {
                        _handleKecamatanTap(tappedKey);
                      } else {
                        setState(() {
                          bool needsRebuild = _selectedKecamatanKey != null;
                          _selectedKecamatanKey = null;
                          _isDetailPanelVisible = false;
                          _kecamatanDataPoints.clear();
                          if(needsRebuild) _currentPolygons = _buildPolygons();
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isStreetView
                          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                          : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      subdomains: _isStreetView ? const ['a', 'b', 'c'] : const [],
                      userAgentPackageName: 'com.example.app',
                    ),
                    if (_currentPolygons.isNotEmpty) PolygonLayer(polygons: _currentPolygons),
                  ],
                ),
                if (_isDetailPanelVisible && _selectedKecamatanKey != null)
                  Positioned(
                    bottom: 10, left: 10,
                    child: _buildDetailPanel(), // UBAH: Hapus right: 10 agar panel tidak stretch
                  ),
                _buildMapControls(),
              ],
            ),
          ),
          if (_isLoadingData && !showOverallLoading) // UBAH: Tampilkan loading bar saat filter
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text("Memproses data peta...", style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}