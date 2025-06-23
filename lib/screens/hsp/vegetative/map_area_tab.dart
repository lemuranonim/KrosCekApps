import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; // For JSON parsing
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:kroscek/screens/qa/vegetative/utils.dart';

import 'app_theme.dart';

String toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

List<_AreaModel> _parseGeoJsonInBackground(ParseGeoJsonArgs args) {
  final Map<String, dynamic> geojsonData = json.decode(args.geoJsonString);
  final List<dynamic> features = geojsonData['features'];
  final List<_AreaModel> areaModels = [];

  const String kabupatenPropertyKey = 'NAME_2';
  const String kecamatanPropertyKey = 'NAME_3';
  const String desaPropertyKey = 'NAME_4';
  const String kabupatenTypePropertyKey = 'ENGTYPE_2'; // Atau 'TYPE_2'

  ParsedDistrictInfo? parsedSelectedDistrict;
  final String? districtFilter = args.selectedSpreadsheetDistrict;
  if (districtFilter != null && districtFilter.isNotEmpty) {
    // districtFilter sudah pasti non-null di sini karena pengecekan di atas
    parsedSelectedDistrict = parseSpreadsheetDistrictName(districtFilter);
  }

  for (var feature in features) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];

    if (properties == null || geometry == null) continue;

    String? geoJsonNamaKabupaten = properties[kabupatenPropertyKey]?.toString();
    String? geoJsonTipeKabupaten = properties[kabupatenTypePropertyKey]?.toString();
    String? geoJsonNamaKecamatan = properties[kecamatanPropertyKey]?.toString();
    String? geoJsonNamaDesa = properties[desaPropertyKey]?.toString();

    // Kabupaten Match Logic
    bool kabupatenMatch;
    if (parsedSelectedDistrict != null) { // Filter district aktif
      if (geoJsonNamaKabupaten != null &&
          geoJsonNamaKabupaten.toLowerCase() == parsedSelectedDistrict.baseName.toLowerCase()) {
        // Nama dasar cocok, cek tipe jika ada
        final String? expectedGadmType = parsedSelectedDistrict.gadmTypeName;
        if (expectedGadmType != null && expectedGadmType.isNotEmpty) {
          kabupatenMatch = (geoJsonTipeKabupaten != null &&
              geoJsonTipeKabupaten.toLowerCase() == expectedGadmType.toLowerCase());
        } else {
          // Tidak ada tipe spesifik dari spreadsheet, cocokkan berdasarkan nama saja
          kabupatenMatch = true;
        }
      } else {
        // Nama dasar tidak cocok
        kabupatenMatch = false;
      }
    } else {
      // Tidak ada filter district aktif
      kabupatenMatch = true;
    }

    // Kecamatan Match Logic
    bool kecamatanMatch;
    final String? kecamatanFilter = args.selectedKecamatan;
    if (kecamatanFilter != null && kecamatanFilter.isNotEmpty) {
      kecamatanMatch = (geoJsonNamaKecamatan != null &&
          geoJsonNamaKecamatan.toLowerCase() == kecamatanFilter.toLowerCase());
    } else {
      // Tidak ada filter kecamatan aktif
      kecamatanMatch = true;
    }

    // Desa Match Logic
    bool desaMatch;
    final String? desaFilter = args.selectedDesa;
    if (desaFilter != null && desaFilter.isNotEmpty) {
      desaMatch = (geoJsonNamaDesa != null &&
          geoJsonNamaDesa.toLowerCase() == desaFilter.toLowerCase());
    } else {
      // Tidak ada filter desa aktif
      desaMatch = true;
    }

    if (kabupatenMatch && kecamatanMatch && desaMatch) {
      // Ambil koordinat (sesuaikan dengan struktur GeoJSON Anda)
      List<LatLng> polygonCoordinates = [];
      if (geometry['type'] == 'Polygon') {
        List<dynamic> coordinates = geometry['coordinates'][0];
        for (var coordPair in coordinates) {
          if (coordPair is List && coordPair.length >= 2 && coordPair[0] is num && coordPair[1] is num) {
            polygonCoordinates.add(LatLng(coordPair[1].toDouble(), coordPair[0].toDouble()));
          }
        }
      } else if (geometry['type'] == 'MultiPolygon') {
        List<dynamic> multiPolygonCoordinates = geometry['coordinates'];
        if (multiPolygonCoordinates.isNotEmpty) {
          List<dynamic> polygon = multiPolygonCoordinates[0][0];
          for (var coordPair in polygon) {
            if (coordPair is List && coordPair.length >= 2 && coordPair[0] is num && coordPair[1] is num) {
              polygonCoordinates.add(LatLng(coordPair[1].toDouble(), coordPair[0].toDouble()));
            }
          }
        }
      }

      if (polygonCoordinates.isNotEmpty && geoJsonNamaDesa != null) {
        areaModels.add(_AreaModel(
          name: toTitleCase(geoJsonNamaDesa),
          kecamatan: geoJsonNamaKecamatan != null ? toTitleCase(geoJsonNamaKecamatan) : null,
          kabupaten: geoJsonNamaKabupaten != null ? toTitleCase(geoJsonNamaKabupaten) : null,
          polygonCoordinates: polygonCoordinates,
          totalArea: 0.0, // Placeholder, isi dari sumber lain jika perlu
          auditedArea: 0.0, // Placeholder
        ));
      }
    }
  }
  return areaModels;
}

class MapAreaTab extends StatefulWidget {
  final List<Map<String, dynamic>> areaDataForBubbles;
  final List<String> districts;
  final List<String> kecamatanList;
  final List<String> desaList;
  final String? initialSelectedDistrict;
  final String? initialSelectedKecamatan;
  final Function(String?, String?) onFilterChanged;

  const MapAreaTab({
    super.key,
    required this.areaDataForBubbles,
    required this.districts,
    required this.kecamatanList,
    required this.desaList,
    this.initialSelectedDistrict,
    this.initialSelectedKecamatan,
    required this.onFilterChanged,
  });

  @override
  MapAreaTabState createState() => MapAreaTabState();
}

class MapAreaTabState extends State<MapAreaTab> {
  bool _isLoading = true;
  String? _errorMessage;
  LatLng? _centerPoint;
  double _initialZoomLevel = 10.0;
  MapViewMode _currentMapMode = MapViewMode.street;
  String? _selectedDistrict;
  String? _selectedKecamatan;
  String? _selectedDesa;
  final MapController _mapController = MapController();
  Position? _currentPosition;

  final Map<String, _AggregatedAreaData> _aggregatedData = {};
  List<String> _availableVillages = [];
  List<String> _availableKecamatans = [];
  final List<_AreaModel> _allGeometries = [];
  final List<_AreaModel> _areaGeometries = [];

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.initialSelectedDistrict;
    _selectedKecamatan = widget.initialSelectedKecamatan;
    _selectedDesa = null;
    _loadMapData();
    _getCurrentLocation();
  }

  @override
  void didUpdateWidget(covariant MapAreaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.areaDataForBubbles != oldWidget.areaDataForBubbles ||
        widget.initialSelectedDistrict != oldWidget.initialSelectedDistrict ||
        widget.initialSelectedKecamatan != oldWidget.initialSelectedKecamatan) {
      _selectedDistrict = widget.initialSelectedDistrict;
      _selectedKecamatan = widget.initialSelectedKecamatan;
      _loadMapData();
    }
  }

  Future<void> _loadMapData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _aggregateAreaData();
      await _prepareAreaGeometries();
      _calculateMapBounds();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load map: ${e.toString()}';
      });
      debugPrint('Error loading map data: $e');
    }
  }

  void _aggregateAreaData() {
    _aggregatedData.clear();

    for (var data in widget.areaDataForBubbles) {
      final String district = toTitleCase(data['district'] ?? 'Unknown District');
      final String kecamatan = toTitleCase(data['kecamatan'] ?? 'Unknown Kecamatan');
      final String desa = toTitleCase(data['village'] ?? 'Unknown Desa');
      final double areaValue = data['value']?.toDouble() ?? 0.0;
      final bool isAudited = data['isAudited'] ?? false;

      final String districtKey = district;
      final String kecamatanKey = '$district - $kecamatan';
      final String desaKey = '$district - $kecamatan - $desa';

      _aggregatedData[districtKey] ??= _AggregatedAreaData(name: district, totalArea: 0.0, auditedArea: 0.0);
      _aggregatedData[districtKey]!.totalArea += areaValue;
      if (isAudited) _aggregatedData[districtKey]!.auditedArea += areaValue;

      _aggregatedData[kecamatanKey] ??= _AggregatedAreaData(name: kecamatan, parentDistrict: district, totalArea: 0.0, auditedArea: 0.0);
      _aggregatedData[kecamatanKey]!.totalArea += areaValue;
      if (isAudited) _aggregatedData[kecamatanKey]!.auditedArea += areaValue;

      _aggregatedData[desaKey] ??= _AggregatedAreaData(name: desa, parentKecamatan: kecamatan, parentDistrict: district);
      _aggregatedData[desaKey]!.totalArea += areaValue;
      if (isAudited) _aggregatedData[desaKey]!.auditedArea += areaValue;
    }
    debugPrint('Aggregated data for ${_aggregatedData.length} areas');
  }

  Future<void> _prepareAreaGeometries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _areaGeometries.clear();
    });

    try {
      const String assetPath = 'assets/gadm41_IDN_4.json';
      debugPrint('Loading GeoJSON: $assetPath');
      final String geoJsonString = await rootBundle.loadString(assetPath);

      // Specify the type parameters for compute
      List<_AreaModel> parsedGeometries = await compute<ParseGeoJsonArgs, List<_AreaModel>>(
          _parseGeoJsonInBackground,
          ParseGeoJsonArgs(geoJsonString: geoJsonString)
      );
      debugPrint('GeoJSON parsed. Found ${parsedGeometries.length} polygons.');

      _allGeometries.addAll(parsedGeometries);
      _linkAndFilterGeometries();

    } catch (e) {
      debugPrint('!!! ERROR loading or parsing GeoJSON: $e !!!');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load map: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _linkAndFilterGeometries() {
    _areaGeometries.clear();
    _aggregateAreaData();

    for (var area in _allGeometries) {
      bool districtFilterOk = _selectedDistrict == null || (area.kabupaten == _selectedDistrict);
      if (!districtFilterOk) continue;

      bool kecamatanFilterOk = _selectedKecamatan == null || (area.kecamatan == _selectedKecamatan);
      if (!kecamatanFilterOk) continue;

      bool desaFilterOk = _selectedDesa == null || (area.name == _selectedDesa);
      if (!desaFilterOk) continue;

      String aggregationKey = '${area.kabupaten} - ${area.kecamatan} - ${area.name}';
      _AggregatedAreaData? areaData = _aggregatedData[aggregationKey];

      _areaGeometries.add(
          _AreaModel(
            name: area.name,
            kecamatan: area.kecamatan,
            kabupaten: area.kabupaten,
            polygonCoordinates: area.polygonCoordinates,
            totalArea: areaData?.totalArea ?? 0.0,
            auditedArea: areaData?.auditedArea ?? 0.0,
          )
      );
    }

    debugPrint('Filtered geometries: ${_areaGeometries.length} polygons to display.');
    _updateAvailableKecamatan();
    _updateAvailableVillages();
    _calculateMapBounds();
    setState(() {});
  }

  void _updateAvailableKecamatan() {
    _availableKecamatans = _allGeometries
        .where((area) => _selectedDistrict == null || area.kabupaten == _selectedDistrict)
        .map((area) => area.kecamatan!)
        .toSet()
        .toList()..sort();
  }

  void _updateAvailableVillages() {
    _availableVillages = _allGeometries
        .where((area) =>
    (_selectedDistrict == null || area.kabupaten == _selectedDistrict) &&
        (_selectedKecamatan == null || area.kecamatan == _selectedKecamatan))
        .map((area) => area.name)
        .toSet()
        .toList()..sort();
  }

  void _onFilterChanged() {
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _linkAndFilterGeometries();
      setState(() {
        _isLoading = false;
      });
      widget.onFilterChanged(_selectedDistrict, _selectedKecamatan);
    });
  }

  void _calculateMapBounds() {
    if (_areaGeometries.isEmpty) {
      _centerPoint = const LatLng(-7.637017, 112.8272303);
      _initialZoomLevel = 8.0;
      return;
    }

    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (var area in _areaGeometries) {
      for (var point in area.polygonCoordinates) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    _centerPoint = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff > 10.0) {
      _initialZoomLevel = 5.0;
    } else if (maxDiff > 5.0) {
      _initialZoomLevel = 6.0;
    } else if (maxDiff > 2.0) {
      _initialZoomLevel = 8.0;
    } else if (maxDiff > 1.0) {
      _initialZoomLevel = 9.0;
    } else if (maxDiff > 0.5) {
      _initialZoomLevel = 10.0;
    } else if (maxDiff > 0.1) {
      _initialZoomLevel = 12.0;
    } else {
      _initialZoomLevel = 15.0;
    }

    _initialZoomLevel = (_initialZoomLevel * 0.9).clamp(3.0, 18.0);
    debugPrint('Map bounds calculated: Center(${_centerPoint!.latitude}, ${_centerPoint!.longitude}), Zoom: $_initialZoomLevel');
  }

  Color _getColorForArea(double totalArea) {
    if (totalArea <= 0) return Colors.grey.shade400.withAlpha(153);
    if (totalArea < 50) return Colors.yellow.withAlpha(153);
    if (totalArea < 200) return Colors.orange.withAlpha(153);
    if (totalArea < 500) return Colors.green.withAlpha(153);
    return Colors.blue.withAlpha(153);
  }

  Color _getBorderColorForArea(double totalArea) {
    if (totalArea <= 0) return Colors.grey.shade600;
    if (totalArea < 50) return Colors.yellow.shade800;
    if (totalArea < 200) return Colors.orange.shade800;
    if (totalArea < 500) return Colors.green.shade800;
    return Colors.blue.shade800;
  }

  TileLayer _getTileLayer() {
    switch (_currentMapMode) {
      case MapViewMode.street:
        return TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.kroscek',
        );
      case MapViewMode.satellite:
        return TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.kroscek',
        );
    }
  }

  Future<void> _getCurrentLocation() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      } catch (e) {
        debugPrint('Error getting current location: $e');
      }
    } else {
      debugPrint('Location permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Map Area (${_areaGeometries.length} Areas)',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showMapInfo,
            tooltip: 'Map Info',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMapData,
            tooltip: 'Refresh Map',
          ),
        ],
      ),
      body: _buildMapContent(),
    );
  }

  Widget _buildMapContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading map based on Area Data...',
              style: AppTheme.subtitle,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Map',
              style: AppTheme.heading2.copyWith(color: AppTheme.error),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(color: AppTheme.textMedium),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMapData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_areaGeometries.isEmpty && _errorMessage == null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.warning.withAlpha(50),
            child: Row(
              children: [
                Icon(Icons.warning, color: AppTheme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No geographic boundaries found for selected filters or data. Showing default map.',
                    style: AppTheme.body.copyWith(color: AppTheme.textDark, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildMapView()),
        ],
      );
    }

    return _buildMapView();
  }

  Widget _buildMapView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildDistrictFilter()),
                  const SizedBox(width: 8),
                  Expanded(child: _buildKecamatanFilter()),
                ],
              ),
              const SizedBox(height: 8),
              _buildDesaFilter(),
              const SizedBox(height: 8),
              _buildAreaLegend(),
            ],
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centerPoint ?? const LatLng(-7.637017, 112.8272303),
                  initialZoom: _initialZoomLevel,
                  maxZoom: 18.0,
                  minZoom: 3.0,
                  onTap: (_, __) {
                    // Clear selected area info
                  },
                ),
                children: [
                  _getTileLayer(),
                  if (_areaGeometries.isNotEmpty)
                    PolygonLayer(
                      polygons: _areaGeometries.map((area) {
                        return Polygon(
                          points: area.polygonCoordinates,
                          color: _getColorForArea(area.totalArea),
                          borderColor: _getBorderColorForArea(area.totalArea),
                          borderStrokeWidth: 1.5,
                        );
                      }).toList(),
                    ),
                  if (_currentPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 30.0,
                          height: 30.0,
                          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withAlpha(127),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMapTypeButton(
                                icon: Icons.map_outlined,
                                label: 'Street',
                                mode: MapViewMode.street,
                              ),
                              _buildMapTypeButton(
                                icon: Icons.satellite_alt_outlined,
                                label: 'Satellite',
                                mode: MapViewMode.satellite,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "zoomIn",
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "zoomOut",
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                        },
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "myLocation",
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          if (_currentPosition != null) {
                            _mapController.move(
                              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              14.0,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Unable to get current location. Please check permissions.')),
                            );
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "centerMarkers",
                        backgroundColor: AppTheme.info,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          if (_centerPoint != null) {
                            _mapController.move(_centerPoint!, _initialZoomLevel);
                          } else {
                            _mapController.move(const LatLng(-7.637017, 112.8272303), 8.0);
                          }
                        },
                        child: const Icon(Icons.center_focus_strong),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: "resetFilters",
                        backgroundColor: AppTheme.warning,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          setState(() {
                            _selectedDistrict = null;
                            _selectedKecamatan = null;
                            _selectedDesa = null;
                            widget.onFilterChanged(null, null);
                            _loadMapData();
                          });
                        },
                        child: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAreaLegend() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem(_getColorForArea(10), 'Small (<50 Ha)'),
        _buildLegendItem(_getColorForArea(100), 'Medium (<200 Ha)'),
        _buildLegendItem(_getColorForArea(300), 'Large (<500 Ha)'),
        _buildLegendItem(_getColorForArea(600), 'Very Large (≥500 Ha)'),
        _buildLegendItem(_getColorForArea(0), 'No Data'),
      ],
    );
  }

  Widget _buildMapTypeButton({
    required IconData icon,
    required String label,
    required MapViewMode mode,
  }) {
    final bool isSelected = _currentMapMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _currentMapMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight.withAlpha(50) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppTheme.primary) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryDark : AppTheme.textMedium,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryDark : AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedDistrict,
      decoration: InputDecoration(
        labelText: 'District',
        labelStyle: AppTheme.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Districts')),
        ...widget.districts.map((district) => DropdownMenuItem(
          value: district,
          child: Text(district, overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDistrict = value;
          _selectedKecamatan = null;
          _selectedDesa = null;
          _onFilterChanged();
        });
      },
      style: AppTheme.body,
    );
  }

  Widget _buildKecamatanFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedKecamatan,
      decoration: InputDecoration(
        labelText: 'Kecamatan',
        labelStyle: AppTheme.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Kecamatan')),
        ..._availableKecamatans.map((kecamatan) => DropdownMenuItem(
          value: kecamatan,
          child: Text(kecamatan, overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedKecamatan = value;
          _selectedDesa = null;
          _onFilterChanged();
        });
      },
      style: AppTheme.body,
    );
  }

  Widget _buildDesaFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedDesa,
      decoration: InputDecoration(
        labelText: 'Village',
        labelStyle: AppTheme.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Villages')),
        ..._availableVillages.map((desa) => DropdownMenuItem(
          value: desa,
          child: Text(desa, overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDesa = value;
          _onFilterChanged();
        });
      },
      style: AppTheme.body,
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showMapInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.accent),
            const SizedBox(width: 8),
            const Text('Map Area Info'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This map displays the distribution of areas (Villages/Desa) colored by their total effective area.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),

              const Text(
                'Color Legend (Area Size):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(Colors.yellow.withAlpha(153), 'Small Area (<50 Ha)'),
                    _buildLegendItem(Colors.orange.withAlpha(153), 'Medium Area (<200 Ha)'),
                    _buildLegendItem(Colors.green.withAlpha(153), 'Large Area (<500 Ha)'),
                    _buildLegendItem(Colors.blue.withAlpha(153), 'Very Large Area (≥500 Ha)'),
                    _buildLegendItem(Colors.grey.shade400.withAlpha(153), 'No Data / Zero Area'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Map Navigation Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.info.withAlpha(127)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Auto-focuses to areas with valid GeoJSON data'),
                    Text('• Automatic zoom level based on data spread'),
                    Text('• Manual zoom and pan with gestures'),
                    Text('• Shows your current location (if permission granted)'),
                        Text('• Switch between Street and Satellite map views'),
                    Text('• Filters for District, Kecamatan, and Village'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Data Source:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Geographic boundaries loaded from GeoJSON (gadm41_IDN_4.json). Field data (Area, Audit Status) from Vegetative worksheet.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: AppTheme.textMedium)),
          ),
        ],
      ),
    );
  }
}

enum MapViewMode {
  street,
  satellite,
}

class _AreaModel {
  final String name; // Name of the Village
  final String? kecamatan;
  final String? kabupaten;
  final List<LatLng> polygonCoordinates;
  final double totalArea;
  final double auditedArea;

  _AreaModel({
    required this.name,
    this.kecamatan,
    this.kabupaten,
    required this.polygonCoordinates,
    required this.totalArea,
    required this.auditedArea,
  });
}

class _AggregatedAreaData {
  final String name;
  final String? parentDistrict;
  final String? parentKecamatan; // Added for better aggregation
  double totalArea;
  double auditedArea;

  _AggregatedAreaData({
    required this.name,
    this.parentDistrict,
    this.parentKecamatan, // Added for better aggregation
    this.totalArea = 0.0,
    this.auditedArea = 0.0,
  });
}

class ParseGeoJsonArgs {
  final String geoJsonString;
  final String? selectedSpreadsheetDistrict;
  final String? selectedKecamatan;
  final String? selectedDesa;

  ParseGeoJsonArgs({
    required this.geoJsonString,
    this.selectedSpreadsheetDistrict,
    this.selectedKecamatan,
    this.selectedDesa,
  });
}