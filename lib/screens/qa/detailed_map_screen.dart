import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/master_fields_provider.dart';
import '../../providers/filter_data_provider.dart';

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

class DetailedMapScreen extends ConsumerStatefulWidget {
  final String? initialRegion;
  final String? initialDistrict;
  final String? initialSeason;

  const DetailedMapScreen({
    super.key,
    this.initialRegion,
    this.initialDistrict,
    this.initialSeason,
  });

  @override
  ConsumerState<DetailedMapScreen> createState() => _DetailedMapScreenState();
}

class _DetailedMapScreenState extends ConsumerState<DetailedMapScreen> {
  Map<String, dynamic>? _geojsonFeatures;

  late String _selectedWorksheetTitle;
  final List<String> _worksheetTitles = [
    'Vegetative',
    'Generative 1',
    'Generative 2',
    'Generative 3',
    'Pre-Harvest',
    'Harvest'
  ];

  String? _selectedRegionState;
  String? _selectedDistrictState;
  String? _selectedGrowingSeasonState;

  static const String _allRegionsSentinel = "Semua Region";
  static const String _allDistrictsSentinel = "Semua District";

  List<String> _availableRegions = [];
  List<String> _availableDistricts = [];
  List<String> _availableGrowingSeasons = [];

  List<List<String>> _filteredMapData = [];

  final List<Map<String, dynamic>> _kecamatanDataPoints = [];
  final Map<String, double> _kecamatanWorkload = {};
  final Map<String, Map<String, double>> _desaWorkloadByKecamatan = {};

  String? _selectedKecamatanKey;
  bool _isDetailPanelVisible = false;
  bool _isStreetView = true;

  // Definisi kolom (Index mapping for compatibility with old logic)
  final int colGrowingSeason = 1;
  final int colFieldNo = 2;
  final int colEffectiveArea = 8;
  final int colVillage = 11;
  final int colSubDistrict = 12;
  final int colDistrict = 13;
  final int colCoordinate = 17;
  final int colRegion = 18;

  bool _isLoadingGeoJson = true;
  bool _isLoadingData = true;
  bool _isMapReady = false;
  bool _initialZoomDone = false;

  final MapController _mapController = MapController();
  List<Polygon> _currentPolygons = [];

  @override
  void initState() {
    super.initState();
    _selectedWorksheetTitle = 'Vegetative';
    _selectedRegionState = widget.initialRegion ?? _allRegionsSentinel;
    _selectedDistrictState = widget.initialDistrict ?? _allDistrictsSentinel;
    _selectedGrowingSeasonState = widget.initialSeason;
    _initializeGeoJson();
  }

  Future<void> _initializeGeoJson() async {
    if (mounted) setState(() => _isLoadingGeoJson = true);
    try {
      final String response =
          await rootBundle.loadString('assets/gadm41_IDN_3.json');
      final data = json.decode(response);
      if (mounted) {
        setState(() {
          _geojsonFeatures = data;
          _isLoadingGeoJson = false;
        });
        _applyAllFiltersAndBuildMap();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _geojsonFeatures = null;
          _isLoadingGeoJson = false;
        });
      }
    }
  }

  void _applyAllFiltersAndBuildMap() {
    final fieldsAsync = ref.read(masterFieldsProvider);
    fieldsAsync.whenData((fields) {
      if (!mounted) return;
      setState(() => _isLoadingData = true);

      _availableRegions = [
        _allRegionsSentinel,
        ...ref.read(uniqueRegionsProvider)
      ];
      _availableDistricts = [
        _allDistrictsSentinel,
        ...ref.read(uniqueDistrictsProvider(
            _selectedRegionState == _allRegionsSentinel
                ? null
                : _selectedRegionState))
      ];

      final seasons = fields
          .map((f) => f['growing_season']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _availableGrowingSeasons = seasons;

      _filteredMapData = fields.where((f) {
        bool matchRegion = _selectedRegionState == _allRegionsSentinel ||
            f['region'] == _selectedRegionState;
        bool matchDistrict = _selectedDistrictState == _allDistrictsSentinel ||
            f['district_kab'] == _selectedDistrictState;
        bool matchSeason = _selectedGrowingSeasonState == null ||
            f['growing_season'] == _selectedGrowingSeasonState;
        return matchRegion && matchDistrict && matchSeason;
      }).map((f) => [
            '', // 0
            f['growing_season']?.toString() ?? '', // 1
            f['field_number']?.toString() ?? '', // 2
            '',
            '',
            '',
            '',
            '',
            f['effective_area']?.toString() ?? '0', // 8
            '',
            '',
            f['village']?.toString() ?? '', // 11
            f['sub_district']?.toString() ?? '', // 12
            f['district_kab']?.toString() ?? '', // 13
            '',
            '',
            '',
            '${f['latitude']},${f['longitude']}', // 17
            f['region']?.toString() ?? '', // 18
          ]).toList();

      _calculateKecamatanWorkloadAndDesa(_filteredMapData);

      if (mounted) {
        setState(() {
          _currentPolygons = _buildPolygons();
          _isLoadingData = false;
        });
        _triggerMapActionsIfNeeded();
      }
    });
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
      final String uniqueKecamatanKey =
          '${normalizedDistrictName}_$normalizedKecamatanName';

      double effectiveArea = 0.0;
      try {
        effectiveArea =
            double.tryParse(effectiveAreaStr.replaceAll(',', '.')) ?? 0.0;
      } catch (e) {
        /* ignore */
      }

      _kecamatanWorkload.update(uniqueKecamatanKey, (value) => value + effectiveArea,
          ifAbsent: () => effectiveArea);
      _desaWorkloadByKecamatan.putIfAbsent(uniqueKecamatanKey, () => {});
      _desaWorkloadByKecamatan[uniqueKecamatanKey]!.update(
          desaRaw, (value) => value + effectiveArea,
          ifAbsent: () => effectiveArea);
    }
  }

  void _triggerMapActionsIfNeeded() {
    if (mounted &&
        _isMapReady &&
        !_isLoadingGeoJson &&
        !_isLoadingData &&
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

  String _getValue(List<String> row, int index, String defaultValue) {
    return row.isNotEmpty && index >= 0 && index < row.length
        ? row[index]
        : defaultValue;
  }

  Color _getKecamatanColor(String kecamatanKey) {
    double workload = _kecamatanWorkload[kecamatanKey] ?? 0.0;
    int alphaValue = 220;

    if (workload <= 0) {
      return Colors.lightGreenAccent.shade100.withAlpha(150);
    } else if (workload <= 3.5) {
      return Colors.green.shade200.withAlpha(alphaValue);
    } else if (workload <= 7.0) {
      return Colors.green.shade500.withAlpha(alphaValue);
    } else if (workload <= 10.0) {
      return Colors.green.shade800.withAlpha(alphaValue);
    } else if (workload <= 11.5) {
      return Colors.yellow.shade200.withAlpha(alphaValue);
    } else if (workload <= 13.5) {
      return Colors.yellow.shade500.withAlpha(alphaValue);
    } else if (workload <= 15.0) {
      return Colors.amber.shade700.withAlpha(alphaValue);
    } else if (workload <= 16.5) {
      return Colors.orange.shade200.withAlpha(alphaValue);
    } else if (workload <= 18.5) {
      return Colors.orange.shade500.withAlpha(alphaValue);
    } else if (workload <= 20.0) {
      return Colors.deepOrange.shade500.withAlpha(alphaValue);
    } else if (workload <= 25.0) {
      return Colors.red.shade200.withAlpha(alphaValue);
    } else if (workload <= 30.0) {
      return Colors.red.shade500.withAlpha(alphaValue);
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

      bool isAllDistricts = _selectedDistrictState == _allDistrictsSentinel;
      bool isAllRegions = _selectedRegionState == _allRegionsSentinel;
      bool districtMatch = isAllDistricts ||
          normalizedGeoKabName == _normalizeName(_selectedDistrictState!);

      bool shouldDisplay = (districtMatch &&
              (_kecamatanWorkload.containsKey(uniqueGeoKecamatanKey) ||
                  isAllDistricts)) ||
          (isAllRegions &&
              _kecamatanWorkload.containsKey(uniqueGeoKecamatanKey));

      if (shouldDisplay) {
        final Color fillColor = _getKecamatanColor(uniqueGeoKecamatanKey);
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
                  label: uniqueGeoKecamatanKey));
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
                    label: uniqueGeoKecamatanKey));
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
    }
    if (allPointsInView.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(allPointsInView),
            padding: const EdgeInsets.all(30.0)));
      } catch (e) {
        _mapController.move(const LatLng(-7.5, 112.5), 8.0);
      }
    } else {
      _mapController.move(const LatLng(-7.5, 112.5), 8.0);
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
      if (gideonKecNameRaw == null || gideonKabNameRaw == null) {
        continue;
      }

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
            _normalizeName(_getValue(row, colSubDistrict, ""));
        final String normalizedDistName =
            _normalizeName(_getValue(row, colDistrict, ""));
        final String uniqueKeyFromRow =
            '${normalizedDistName}_$normalizedKecName';

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
              _kecamatanDataPoints
                  .add({'lat': lat, 'lng': lng, 'area': area, 'label': fieldNo});
            }
          }
        }
      }
      _currentPolygons = _buildPolygons();
      if (_isMapReady && !dontZoom) _fitBoundsForSelectedKecamatan(tappedKecKey);
    });
  }

  Widget _buildDetailPanel() {
    if (_selectedKecamatanKey == null ||
        !_desaWorkloadByKecamatan.containsKey(_selectedKecamatanKey)) {
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
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(25),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4))
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
                  child: Text("Kec. $displayName",
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark),
                      overflow: TextOverflow.ellipsis)),
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
                  }),
            ],
          ),
          Text("Kab./Kota: $displayDistrictName",
              style: const TextStyle(fontSize: 14, color: AppTheme.textMedium)),
          const SizedBox(height: 8),
          Text("Total Area Efektif: ${totalWorkloadKecamatan.toStringAsFixed(2)} Ha",
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
                            Text(desaName,
                                style: const TextStyle(fontSize: 14)),
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
      LatLng vertB =
          polygonVertices.elementAt((j + 1) % polygonVertices.length);
      if (((vertA.latitude <= point.latitude && point.latitude < vertB.latitude) ||
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.shade50.withAlpha(100)]),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.green.shade400,
                        Colors.green.shade600
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.green.withAlpha(76),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ]),
                  child: const Icon(Icons.tune_rounded,
                      color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('FILTER PETA',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildEnhancedFilterDropdown<String>(
                      labelText: 'Fase',
                      value: _selectedWorksheetTitle,
                      items: _worksheetTitles,
                      hintText: "Pilih Fase",
                      icon: Icons.description_rounded,
                      iconColor: Colors.blue.shade600,
                      onChanged: (newValue) {
                        if (newValue != null) {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedWorksheetTitle = newValue);
                          _applyAllFiltersAndBuildMap();
                        }
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildEnhancedFilterDropdown<String>(
                      labelText: 'Musim Tanam',
                      value: _selectedGrowingSeasonState,
                      items: _availableGrowingSeasons,
                      hintText: "Pilih Musim",
                      icon: Icons.eco_rounded,
                      iconColor: Colors.teal.shade600,
                      onChanged: (newValue) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedGrowingSeasonState = newValue;
                          _applyAllFiltersAndBuildMap();
                        });
                      })),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildEnhancedFilterDropdown<String>(
                      labelText: 'Region',
                      value: _selectedRegionState,
                      items: _availableRegions,
                      hintText: "Pilih Region",
                      icon: Icons.location_city_rounded,
                      iconColor: Colors.purple.shade600,
                      onChanged: (newValue) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedRegionState = newValue;
                          _selectedDistrictState = _allDistrictsSentinel;
                          _applyAllFiltersAndBuildMap();
                        });
                      })),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildEnhancedFilterDropdown<String>(
                      labelText: 'District',
                      value: _selectedDistrictState,
                      items: _availableDistricts,
                      hintText: "Pilih District",
                      icon: Icons.location_on_rounded,
                      iconColor: Colors.orange.shade600,
                      onChanged: (newValue) {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedDistrictState = newValue;
                          _applyAllFiltersAndBuildMap();
                        });
                      })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterDropdown<T>(
      {required String labelText,
      required T? value,
      required List<T> items,
      required Function(T?) onChanged,
      required String hintText,
      required IconData icon,
      required Color iconColor,
      bool isLoading = false,
      bool isEnabled = true}) {
    String displayHint = isLoading
        ? "Loading..."
        : (items.isEmpty && value == null ? "Tidak ada data" : hintText);
    final hasValue = value != null && items.contains(value);
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: isEnabled && hasValue
                    ? iconColor.withAlpha(30)
                    : Colors.grey.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ]),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isEnabled && hasValue
                      ? iconColor.withAlpha(150)
                      : Colors.grey.shade300,
                  width: 2)),
          child: DropdownButtonFormField<T>(
            decoration: InputDecoration(
              labelText: labelText,
              labelStyle: TextStyle(
                  color: isEnabled && hasValue ? iconColor : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.3),
              floatingLabelStyle: TextStyle(
                  color: iconColor, fontWeight: FontWeight.bold, fontSize: 13),
              prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: isEnabled && hasValue
                          ? iconColor.withAlpha(40)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon,
                      color: isEnabled && hasValue ? iconColor : Colors.grey.shade600,
                      size: 20)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              isDense: true,
            ),
            initialValue: hasValue ? value : null,
            hint: Text(displayHint,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down_rounded,
                color: isEnabled ? iconColor : Colors.grey.shade400, size: 28),
            items: items.map((T itemValue) {
              final isItemSelected = itemValue == value;
              return DropdownMenuItem<T>(
                  value: itemValue,
                  child: Text(itemValue.toString(),
                      style: TextStyle(
                          fontSize: 14,
                          color: isItemSelected ? iconColor : Colors.black87,
                          fontWeight:
                              isItemSelected ? FontWeight.bold : FontWeight.w600),
                      overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: !isEnabled || isLoading ? null : onChanged,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
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
        title: const Text('Workload Map (Supabase)',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
          Colors.green.shade700,
          Colors.green.shade600,
          Colors.green.shade800
        ]))),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(-7.5, 112.5),
                    initialZoom: 8.0,
                    onMapReady: () {
                      setState(() => _isMapReady = true);
                      _triggerMapActionsIfNeeded();
                    },
                    onTap: (tapPosition, latLng) {
                      String? tappedKey;
                      for (final polygon in _currentPolygons.reversed) {
                        if (isPointInPolygon(latLng, polygon.points)) {
                          tappedKey = polygon.label;
                          break;
                        }
                      }
                      if (tappedKey != null) {
                        _handleKecamatanTap(tappedKey);
                      } else {
                        setState(() {
                          _selectedKecamatanKey = null;
                          _isDetailPanelVisible = false;
                          _kecamatanDataPoints.clear();
                          _currentPolygons = _buildPolygons();
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                        urlTemplate: _isStreetView
                            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                            : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.kroscek.app'),
                    if (_currentPolygons.isNotEmpty)
                      PolygonLayer(polygons: _currentPolygons),
                  ],
                ),
                if (_isDetailPanelVisible && _selectedKecamatanKey != null)
                  Positioned(bottom: 10, left: 10, child: _buildDetailPanel()),
                Positioned(
                    top: 10,
                    right: 10,
                    child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        onPressed: () =>
                            setState(() => _isStreetView = !_isStreetView),
                        child: Icon(_isStreetView ? Icons.satellite_alt : Icons.map,
                            color: AppTheme.primary))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
