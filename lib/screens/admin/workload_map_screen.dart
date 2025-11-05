import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../services/config_manager.dart';

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
  String _selectedWorksheetTitle = 'Generative';
  final List<String> _worksheetTitles = ['Vegetative', 'Generative', 'Pre Harvest', 'Harvest'];

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
        setState(() {
          _regionOptions = [_allRegionsSentinel, ...allRegionsFromConfig..sort()];
        });
      }
      await _initializeGeoJson();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Gagal memuat konfigurasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeGeoJson() async {
    setState(() => _isLoadingGeoJson = true);
    try {
      final String response = await rootBundle.loadString('assets/gadm41_IDN_3.json');
      final data = json.decode(response);
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

  Future<void> _onRegionChanged(String? newRegion) async {
    if (newRegion == null) return;

    setState(() {
      _isLoading = true;
      _selectedRegion = newRegion;
      _currentSheetData.clear();
      _filteredMapData.clear();
      _resetSubFilters();
    });

    try {
      await _fetchDataForWorksheet(_selectedWorksheetTitle);
      if (mounted) _extractFiltersFromSheetData();
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
      Query query = FirebaseFirestore.instance
          .collection('workload_data')
          .where('worksheet', isEqualTo: worksheetName);

      if (_selectedRegion != null && _selectedRegion != _allRegionsSentinel) {
        query = query.where('region', isEqualTo: _selectedRegion);
      }

      final querySnapshot = await query.get().timeout(const Duration(seconds: 30));

      final List<Map<String, dynamic>> data = [];
      for (final doc in querySnapshot.docs) {
        final docData = doc.data() as Map<String, dynamic>;
        // Filter data yang valid
        if (docData['growingSeason'] != null &&
            !docData['growingSeason'].toString().startsWith('#')) {
          data.add(docData);
        }
      }

      if (mounted) {
        setState(() {
          _currentSheetData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching from Firestore: $e');
      if (mounted) {
        setState(() {
          _currentSheetData = [];
          _isLoading = false;
        });
      }
      rethrow;
    }
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
    if (!mounted || _currentSheetData.isEmpty) {
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

    if (mounted) {
      setState(() {
        _availableGrowingSeasons = seasons.toList()..sort();
        if (_selectedGrowingSeasonState == null ||
            !_availableGrowingSeasons.contains(_selectedGrowingSeasonState)) {
          _selectedGrowingSeasonState = _availableGrowingSeasons.isNotEmpty
              ? _availableGrowingSeasons.first
              : null;
        }
      });
      _populateAvailableDistricts();
    }
  }

  void _populateAvailableDistricts() {
    if (!mounted) return;

    final districtsSet = <String>{};

    for (final row in _currentSheetData) {
      final bool isAllRegionsSelected = _selectedRegion == _allRegionsSentinel;
      final bool regionMatch = isAllRegionsSelected ||
          row['region']?.toString() == _selectedRegion;

      final bool seasonMatch = _selectedGrowingSeasonState == null ||
          row['growingSeason']?.toString() == _selectedGrowingSeasonState;

      if (regionMatch && seasonMatch) {
        final districtValue = row['district']?.toString() ?? '';
        if (districtValue.isNotEmpty && !districtValue.startsWith('#')) {
          districtsSet.add(districtValue);
        }
      }
    }

    setState(() {
      _availableDistricts = districtsSet.toList()..sort();
      if (_selectedDistrictState == null ||
          !_availableDistricts.contains(_selectedDistrictState)) {
        _selectedDistrictState = null;
      }
    });

    _populateAvailableWeeks();
  }

  void _populateAvailableWeeks() {
    if (!mounted) return;

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
    });

    _applyAllFiltersAndBuildMap();
  }

  void _applyAllFiltersAndBuildMap() {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _filteredMapData = List.from(_currentSheetData);

    if (_selectedRegion != null && _selectedRegion != _allRegionsSentinel) {
      _filteredMapData = _filteredMapData
          .where((row) => row['region']?.toString() == _selectedRegion)
          .toList();
    }
    if (_selectedDistrictState != null) {
      _filteredMapData = _filteredMapData
          .where((row) => row['district']?.toString() == _selectedDistrictState)
          .toList();
    }
    if (_selectedGrowingSeasonState != null) {
      _filteredMapData = _filteredMapData
          .where((row) =>
      row['growingSeason']?.toString() == _selectedGrowingSeasonState)
          .toList();
    }
    if (_selectedWeeksState.isNotEmpty) {
      _filteredMapData = _filteredMapData
          .where((row) =>
          _selectedWeeksState.contains(row['week']?.toString().trim() ?? ''))
          .toList();
    }

    _calculateKecamatanWorkloadAndDesa(_filteredMapData);

    if (mounted) {
      setState(() {
        _currentPolygons = _buildPolygons();
        _isLoading = false;
        if (_selectedKecamatanKey != null &&
            !_kecamatanWorkload.containsKey(_selectedKecamatanKey)) {
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
    } else if (workload <= 3.5) {
      return Colors.green.shade300.withAlpha(alphaValue);
    } else if (workload <= 7.0) {
      return Colors.green.shade600.withAlpha(alphaValue);
    } else if (workload <= 10.0) {
      return Colors.lime.shade700.withAlpha(alphaValue);
    } else if (workload <= 13.5) {
      return Colors.yellow.shade600.withAlpha(alphaValue);
    } else if (workload <= 16.5) {
      return Colors.amber.shade700.withAlpha(alphaValue);
    } else if (workload <= 20.0) {
      return Colors.orange.shade800.withAlpha(alphaValue);
    } else if (workload <= 25.0) {
      return Colors.deepOrange.shade700.withAlpha(alphaValue);
    } else if (workload <= 30.0) {
      return Colors.red.shade700.withAlpha(alphaValue);
    } else {
      return Colors.red.shade900.withAlpha(alphaValue);
    }
  }

  List<Polygon> _buildPolygons() {
    if (_geojsonFeatures == null || _geojsonFeatures!['features'] == null) {
      return [];
    }
    final List<Polygon> polygons = [];
    final features = _geojsonFeatures!['features'] as List;

    for (final feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties == null ||
          geometry == null ||
          geometry['coordinates'] == null) {
        continue;
      }

      final String? gideonKecNameRaw = properties['NAME_3']?.toString();
      final String? gideonKabNameRaw = properties['NAME_2']?.toString();
      if (gideonKecNameRaw == null ||
          gideonKecNameRaw.isEmpty ||
          gideonKabNameRaw == null ||
          gideonKabNameRaw.isEmpty) {
        continue;
      }

      final String normalizedGeoKecName = _normalizeName(gideonKecNameRaw);
      final String normalizedGeoKabName = _normalizeName(gideonKabNameRaw);
      final String uniqueGeoKecamatanKey =
          '${normalizedGeoKabName}_$normalizedGeoKecName';

      bool shouldDisplay =
      _kecamatanWorkload.containsKey(uniqueGeoKecamatanKey);

      if (shouldDisplay) {
        final double workload = _kecamatanWorkload[uniqueGeoKecamatanKey] ?? 0.0;
        final Color fillColor = _getKecamatanColor(workload);
        final bool isSelectedKecamatan =
            _selectedKecamatanKey == uniqueGeoKecamatanKey;
        final type = geometry['type'];
        final coordinates = geometry['coordinates'];
        try {
          if (type == 'Polygon') {
            final List<LatLng> points = (coordinates.first as List)
                .map<LatLng>((point) =>
                LatLng(point.last as double, point.first as double))
                .toList();
            if (points.isNotEmpty) {
              polygons.add(Polygon(
                points: points,
                color: fillColor,
                borderColor: isSelectedKecamatan
                    ? AppTheme.accent
                    : AppTheme.primaryDark.withAlpha(178),
                borderStrokeWidth: isSelectedKecamatan ? 2.5 : 0.7,
                label: uniqueGeoKecamatanKey,
              ));
            }
          } else if (type == 'MultiPolygon') {
            for (final polygonCoords in coordinates) {
              final List<LatLng> points = (polygonCoords.first as List)
                  .map<LatLng>((point) =>
                  LatLng(point.last as double, point.first as double))
                  .toList();
              if (points.isNotEmpty) {
                polygons.add(Polygon(
                  points: points,
                  color: fillColor,
                  borderColor: isSelectedKecamatan
                      ? AppTheme.accent
                      : AppTheme.primaryDark.withAlpha(178),
                  borderStrokeWidth: isSelectedKecamatan ? 2.5 : 0.7,
                  label: uniqueGeoKecamatanKey,
                ));
              }
            }
          }
        } catch (e) {
          /* ignore */
        }
      }
    }
    return polygons;
  }

  void _autoZoomToFilteredArea() {
    if (!mounted ||
        !_isMapReady ||
        _isLoadingGeoJson ||
        _geojsonFeatures == null) {
      return;
    }
    List<LatLng> allPointsInView = [];
    if (_currentPolygons.isNotEmpty) {
      for (final polygon in _currentPolygons) {
        allPointsInView.addAll(polygon.points);
      }
    } else if (_selectedDistrictState != null) {
      final features = _geojsonFeatures!['features'] as List;
      for (final feature in features) {
        final properties = feature['properties'];
        if (properties == null) continue;
        final String? gideonKabNameRaw = properties['NAME_2']?.toString();
        if (gideonKabNameRaw == null) continue;
        if (_normalizeName(gideonKabNameRaw) ==
            _normalizeName(_selectedDistrictState!)) {
          final geometry = feature['geometry'];
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          try {
            if (type == 'Polygon') {
              allPointsInView.addAll((coordinates.first as List).map<LatLng>(
                      (point) =>
                      LatLng(point.last as double, point.first as double)));
            } else if (type == 'MultiPolygon') {
              for (final pC in coordinates) {
                allPointsInView.addAll((pC.first as List).map<LatLng>(
                        (point) =>
                        LatLng(point.last as double, point.first as double)));
              }
            }
          } catch (e) {
            /* ignore */
          }
        }
      }
    }

    if (allPointsInView.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(allPointsInView),
            padding: const EdgeInsets.all(30.0)));
      } catch (e) {
        _mapController.move(LatLng(-2.548926, 118.0148634), 5.0);
      }
    } else {
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
    if (!mounted || !_isMapReady || _geojsonFeatures == null) return;
    final features = _geojsonFeatures!['features'] as List;
    List<LatLng> kecamatanPoints = [];

    for (final feature in features) {
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties == null ||
          geometry == null ||
          geometry['coordinates'] == null) {
        continue;
      }

      final String? gideonKecNameRaw = properties['NAME_3']?.toString();
      final String? gideonKabNameRaw = properties['NAME_2']?.toString();
      if (gideonKecNameRaw == null || gideonKabNameRaw == null) continue;

      if ('${_normalizeName(gideonKabNameRaw)}_${_normalizeName(gideonKecNameRaw)}' ==
          kecamatanKey) {
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
        break;
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

  Widget _buildDetailPanel() {
    if (_selectedKecamatanKey == null ||
        !_desaWorkloadByKecamatan.containsKey(_selectedKecamatanKey) ||
        _desaWorkloadByKecamatan[_selectedKecamatanKey!] == null) {
      return const SizedBox.shrink();
    }
    final desaData = _desaWorkloadByKecamatan[_selectedKecamatanKey!]!;
    final kecamatanNameParts = _selectedKecamatanKey!.split('_');
    final displayName = kecamatanNameParts.length > 1
        ? kecamatanNameParts.sublist(1).join(' ')
        : _selectedKecamatanKey!;
    final displayDistrictName = kecamatanNameParts.first;
    final totalWorkloadKecamatan =
        _kecamatanWorkload[_selectedKecamatanKey!] ?? 0.0;

    return Container(
      width: 300,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 24, color: AppTheme.textMedium),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
          Text("Kab./Kota: $displayDistrictName",
              style: const TextStyle(fontSize: 14, color: AppTheme.textMedium)),
          const SizedBox(height: 8),
          Text(
              "Total Area Efektif: ${totalWorkloadKecamatan.toStringAsFixed(2)} Ha",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent)),
          const Divider(height: 20, thickness: 1),
          Text("Desa/Kelurahan (${desaData.length}):",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Expanded(
            child: desaData.isEmpty
                ? const Center(
                child: Text("Tidak ada data desa.",
                    style: TextStyle(
                        color: AppTheme.textMedium, fontSize: 14)))
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
                      Expanded(
                        child: Text(desaName,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      Text("${workload.toStringAsFixed(2)} Ha",
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
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

  void _showMultiSelectWeekDialog() async {
    final List<String>? results = await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        return _MultiSelectWeekDialog(
          availableWeeks: _availableWeeks,
          initialSelectedWeeks: _selectedWeeksState,
        );
      },
    );

    if (results != null) {
      setState(() {
        _selectedWeeksState = results;
        _selectedKecamatanKey = null;
        _isDetailPanelVisible = false;
        _kecamatanDataPoints.clear();
        _initialZoomDone = false;
      });
      _applyAllFiltersAndBuildMap();
    }
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

  Widget _buildFilterBar() {
    return Container(
        padding: const EdgeInsets.all(8.0),
        color: AppTheme.primaryLight.withAlpha(25),
        child: Column(
          children: [
            Row(children: [
              _buildFilterDropdown<String>(
                labelText: 'Worksheet',
                value: _selectedWorksheetTitle,
                items: _worksheetTitles,
                hintText: "Pilih Worksheet",
                onChanged: (newValue) {
                  if (newValue != null && newValue != _selectedWorksheetTitle) {
                    _fetchDataForWorksheet(newValue);
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown<String>(
                labelText: 'Musim Tanam',
                value: _selectedGrowingSeasonState,
                items: _availableGrowingSeasons,
                hintText: "Pilih Musim",
                isLoading: _isLoading && _availableGrowingSeasons.isEmpty,
                onChanged: (newValue) {
                  if (newValue != _selectedGrowingSeasonState) {
                    setState(() {
                      _selectedGrowingSeasonState = newValue;
                      _selectedDistrictState = null;
                      _selectedWeeksState.clear();
                      _availableDistricts.clear();
                      _availableWeeks.clear();
                      _selectedKecamatanKey = null;
                      _isDetailPanelVisible = false;
                      _kecamatanDataPoints.clear();
                      _initialZoomDone = false;
                    });
                    _populateAvailableDistricts();
                  }
                },
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _buildFilterDropdown<String>(
                labelText: 'District',
                value: _selectedDistrictState,
                items: _availableDistricts,
                hintText: "Semua District",
                isLoading: _isLoading && _availableDistricts.isEmpty,
                onChanged: (newValue) {
                  if (newValue != _selectedDistrictState) {
                    setState(() {
                      _selectedDistrictState = newValue;
                      _selectedWeeksState.clear();
                      _availableWeeks.clear();
                      _selectedKecamatanKey = null;
                      _isDetailPanelVisible = false;
                      _kecamatanDataPoints.clear();
                      _initialZoomDone = false;
                    });
                    _populateAvailableWeeks();
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Minggu Ke-',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                  child: InkWell(
                    onTap: (_isLoading || _availableWeeks.isEmpty)
                        ? null
                        : _showMultiSelectWeekDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _isLoading
                                ? 'Loading...'
                                : (_availableWeeks.isEmpty
                                ? 'Tidak ada data'
                                : _getWeekFilterDisplayString()),
                            style: TextStyle(
                              fontSize: 14,
                              color: (_isLoading || _availableWeeks.isEmpty)
                                  ? Colors.grey.shade500
                                  : AppTheme.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ));
  }

  Widget _buildFilterDropdown<T>({
    required String labelText,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String hintText,
    bool isLoading = false,
  }) {
    List<DropdownMenuItem<T>> dropdownItems = items.map((T itemValue) {
      return DropdownMenuItem<T>(
        value: itemValue,
        child: Text(itemValue.toString(),
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
            overflow: TextOverflow.ellipsis),
      );
    }).toList();

    if (T == String && hintText.contains("District")) {
      dropdownItems.insert(
          0,
          DropdownMenuItem<T>(
            value: null,
            child: Text(hintText,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ));
    }

    String displayHint = isLoading
        ? "Loading..."
        : (items.isEmpty ? "Tidak ada data" : hintText);

    return Expanded(
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          labelText: labelText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
          fillColor: Colors.white,
          filled: true,
        ),
        value: (value != null && items.contains(value)) ? value : null,
        hint: Text(displayHint,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        isExpanded: true,
        items: dropdownItems,
        onChanged: isLoading || items.isEmpty ? null : onChanged,
        style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
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
      {'color': _getKecamatanColor(3.5), 'label': '> 0 - 3.5 Ha'},
      {'color': _getKecamatanColor(7.0), 'label': '> 3.5 - 7.0 Ha'},
      {'color': _getKecamatanColor(10.0), 'label': '> 7.0 - 10.0 Ha'},
      {'color': _getKecamatanColor(13.5), 'label': '> 10.0 - 13.5 Ha'},
      {'color': _getKecamatanColor(16.5), 'label': '> 13.5 - 16.5 Ha'},
      {'color': _getKecamatanColor(20.0), 'label': '> 16.5 - 20.0 Ha'},
      {'color': _getKecamatanColor(25.0), 'label': '> 20.0 - 25.0 Ha'},
      {'color': _getKecamatanColor(30.0), 'label': '> 25.0 - 30.0 Ha'},
      {'color': _getKecamatanColor(31.0), 'label': '> 30.0 Ha'},
    ];

    return Container(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
        title: DropdownButton<String>(
          value: _selectedRegion,
          hint: const Text("Pilih Region",
              style: TextStyle(color: Colors.white70)),
          dropdownColor: AppTheme.primaryDark,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          underline: Container(),
          items: _regionOptions.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: _isLoading ? null : _onRegionChanged,
        ),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _selectedRegion == null
                ? null
                : () => _onRegionChanged(_selectedRegion),
          )
        ],
      ),
      body: Column(
        children: [
          if (_selectedRegion != null) _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Error: $_error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
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
                      urlTemplate: _isStreetView
                          ? 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
                          : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      subdomains:
                      _isStreetView ? const ['a', 'b', 'c'] : const [],
                      userAgentPackageName: 'com.workload.kroscek',
                    ),
                    if (_currentPolygons.isNotEmpty)
                      PolygonLayer(polygons: _currentPolygons),
                  ],
                ),
                if (_isDetailPanelVisible &&
                    _selectedKecamatanKey != null)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _buildDetailPanel(),
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

class _MultiSelectWeekDialog extends StatefulWidget {
  final List<String> availableWeeks;
  final List<String> initialSelectedWeeks;

  const _MultiSelectWeekDialog({
    required this.availableWeeks,
    required this.initialSelectedWeeks,
  });

  @override
  State<_MultiSelectWeekDialog> createState() => _MultiSelectWeekDialogState();
}

class _MultiSelectWeekDialogState extends State<_MultiSelectWeekDialog> {
  late final List<String> _tempSelectedWeeks;

  @override
  void initState() {
    super.initState();
    _tempSelectedWeeks = List.from(widget.initialSelectedWeeks);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Minggu'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.availableWeeks.length,
          itemBuilder: (BuildContext context, int index) {
            final week = widget.availableWeeks[index];
            return CheckboxListTile(
              title: Text(week),
              value: _tempSelectedWeeks.contains(week),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _tempSelectedWeeks.add(week);
                  } else {
                    _tempSelectedWeeks.remove(week);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Batal'),
          onPressed: () {
            Navigator.pop(context, null);
          },
        ),
        TextButton(
          child: const Text('OK'),
          onPressed: () {
            Navigator.pop(context, _tempSelectedWeeks);
          },
        ),
      ],
    );
  }
}