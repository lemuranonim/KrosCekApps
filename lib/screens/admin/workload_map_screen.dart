// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/master_fields_provider.dart';

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

class WorkloadMapScreen extends ConsumerStatefulWidget {
  const WorkloadMapScreen({super.key});

  @override
  ConsumerState<WorkloadMapScreen> createState() => _WorkloadMapScreenState();
}

class _WorkloadMapScreenState extends ConsumerState<WorkloadMapScreen> {
  String? _selectedRegion;
  List<String> _regionOptions = [];

  Map<String, dynamic>? _geojsonFeatures;
  final Map<String, dynamic> _geoJsonLookup = {};
  String _selectedWorksheetTitle = 'Generative';
  final List<String> _worksheetTitles = ['Vegetative', 'Generative', 'Pre Harvest', 'Harvest'];

  String? _selectedDistrictState;
  String? _selectedGrowingSeasonState;
  List<String> _selectedWeeksState = [];

  static const String _allRegionsSentinel = "Semua Region";

  List<String> _availableDistricts = [];
  List<String> _availableGrowingSeasons = [];
  List<String> _availableWeeks = [];

  List<Map<String, dynamic>> _currentSupabaseData = [];
  List<Map<String, dynamic>> _filteredMapData = [];

  final List<Map<String, dynamic>> _kecamatanDataPoints = [];
  final Map<String, double> _kecamatanWorkload = {};
  final Map<String, Map<String, double>> _desaWorkloadByKecamatan = {};

  String? _selectedKecamatanKey;
  bool _isDetailPanelVisible = false;
  bool _isStreetView = true;

  bool _isLoadingData = true;
  bool _isLoadingGeoJson = true;
  bool _isMapReady = false;
  bool _initialZoomDone = false;

  final MapController _mapController = MapController();
  List<Polygon> _currentPolygons = [];
  final bool _isLegendVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeGeoJson();
  }

  Future<void> _initializeGeoJson() async {
    setState(() => _isLoadingGeoJson = true);
    try {
      final String response = await rootBundle.loadString('assets/gadm41_IDN_3.json');
      final data = json.decode(response);

      _geoJsonLookup.clear();
      if (data['features'] != null) {
        final features = data['features'] as List;
        for (final feature in features) {
          final properties = feature['properties'];
          if (properties == null) continue;

          final String? gideonKecNameRaw = properties['NAME_3']?.toString();
          final String? gideonKabNameRaw = properties['NAME_2']?.toString();

          if (gideonKecNameRaw != null && gideonKabNameRaw != null) {
            final String normalizedKec = _normalizeName(gideonKecNameRaw);
            final String normalizedKab = _normalizeName(gideonKabNameRaw);
            final String uniqueKey = '${normalizedKab}_$normalizedKec';
            _geoJsonLookup[uniqueKey] = feature;
          }
        }
      }

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

  void _onRegionChanged(String? newRegion) {
    if (newRegion == null) return;
    setState(() {
      _selectedRegion = newRegion;
      _selectedDistrictState = null;
      _selectedGrowingSeasonState = null;
      _selectedWeeksState.clear();
    });
    _extractFiltersFromData();
  }

  void _extractFiltersFromData() {
    final fieldsAsync = ref.read(masterFieldsProvider);
    fieldsAsync.whenData((fields) {
      if (!mounted) return;

      _currentSupabaseData = fields;

      // Update Region Options
      final regionsSet = <String>{};
      for (final f in fields) {
        final r = f['region']?.toString() ?? '';
        if (r.isNotEmpty) regionsSet.add(r);
      }
      _regionOptions = [_allRegionsSentinel, ...regionsSet.toList()..sort()];
      _selectedRegion ??= _allRegionsSentinel;

      // Update Growing Seasons
      final seasonsSet = <String>{};
      for (final f in fields) {
        if (_selectedRegion == _allRegionsSentinel || f['region'] == _selectedRegion) {
          final s = f['season']?.toString() ?? '';
          if (s.isNotEmpty) seasonsSet.add(s);
        }
      }
      _availableGrowingSeasons = seasonsSet.toList()..sort();
      if (_selectedGrowingSeasonState != null && !_availableGrowingSeasons.contains(_selectedGrowingSeasonState)) {
        _selectedGrowingSeasonState = null;
      }
      if (_selectedGrowingSeasonState == null && _availableGrowingSeasons.isNotEmpty) {
        _selectedGrowingSeasonState = _availableGrowingSeasons.first;
      }

      _populateAvailableDistricts();
    });
  }

  void _populateAvailableDistricts() {
    final districtsSet = <String>{};
    for (final f in _currentSupabaseData) {
      bool matchRegion = _selectedRegion == _allRegionsSentinel || f['region'] == _selectedRegion;
      bool matchSeason = _selectedGrowingSeasonState == null || f['season'] == _selectedGrowingSeasonState;

      if (matchRegion && matchSeason) {
        final d = f['district_kab']?.toString() ?? '';
        if (d.isNotEmpty) districtsSet.add(d);
      }
    }
    setState(() {
      _availableDistricts = districtsSet.toList()..sort();
      if (_selectedDistrictState != null && !_availableDistricts.contains(_selectedDistrictState)) {
        _selectedDistrictState = null;
      }
    });
    _populateAvailableWeeks();
  }

  void _populateAvailableWeeks() {
    final weeksSet = <String>{};
    for (final f in _currentSupabaseData) {
      bool matchRegion = _selectedRegion == _allRegionsSentinel || f['region'] == _selectedRegion;
      bool matchSeason = _selectedGrowingSeasonState == null || f['season'] == _selectedGrowingSeasonState;
      bool matchDistrict = _selectedDistrictState == null || f['district_kab'] == _selectedDistrictState;

      if (matchRegion && matchSeason && matchDistrict) {
        // Mendapatkan data week dari audit yang sesuai
        String? weekVal;
        if (_selectedWorksheetTitle == 'Vegetative') {
          weekVal = f['audit_vegetative'] != null && f['audit_vegetative'].isNotEmpty 
              ? f['audit_vegetative'][0]['audit_week']?.toString() 
              : null;
        } else if (_selectedWorksheetTitle == 'Generative') {
          final genAudit = f['audit_generative'] != null && f['audit_generative'].isNotEmpty 
              ? f['audit_generative'][0] 
              : null;
          weekVal = genAudit?['audit_week_1']?.toString() ?? 
                    genAudit?['audit_week_2']?.toString() ??
                    genAudit?['audit_week_3']?.toString();
        } else if (_selectedWorksheetTitle == 'Pre Harvest') {
          weekVal = f['audit_pre_harvest'] != null && f['audit_pre_harvest'].isNotEmpty 
              ? f['audit_pre_harvest'][0]['audit_week']?.toString() 
              : null;
        } else if (_selectedWorksheetTitle == 'Harvest') {
          weekVal = f['audit_harvest'] != null && f['audit_harvest'].isNotEmpty 
              ? f['audit_harvest'][0]['audit_week']?.toString() 
              : null;
        }
        
        if (weekVal != null && weekVal.isNotEmpty) weeksSet.add(weekVal);
      }
    }

    setState(() {
      _availableWeeks = weeksSet.toList()
        ..sort((a, b) {
          int? valA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), ''));
          int? valB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), ''));
          if (valA != null && valB != null) return valA.compareTo(valB);
          return a.compareTo(b);
        });
      _selectedWeeksState.removeWhere((w) => !_availableWeeks.contains(w));
    });

    _applyAllFiltersAndBuildMap();
  }

  void _applyAllFiltersAndBuildMap() {
    setState(() => _isLoadingData = true);

    _filteredMapData = _currentSupabaseData.where((f) {
      bool matchRegion = _selectedRegion == _allRegionsSentinel || f['region'] == _selectedRegion;
      bool matchSeason = _selectedGrowingSeasonState == null || f['season'] == _selectedGrowingSeasonState;
      bool matchDistrict = _selectedDistrictState == null || f['district_kab'] == _selectedDistrictState;
      
      String? rowWeek;
      if (_selectedWorksheetTitle == 'Vegetative') {
        rowWeek = f['audit_vegetative'] != null && f['audit_vegetative'].isNotEmpty 
            ? f['audit_vegetative'][0]['audit_week']?.toString() 
            : null;
      } else if (_selectedWorksheetTitle == 'Generative') {
        final genAudit = f['audit_generative'] != null && f['audit_generative'].isNotEmpty 
            ? f['audit_generative'][0] 
            : null;
        rowWeek = genAudit?['audit_week_1']?.toString() ?? 
                  genAudit?['audit_week_2']?.toString() ??
                  genAudit?['audit_week_3']?.toString();
      } else if (_selectedWorksheetTitle == 'Pre Harvest') {
        rowWeek = f['audit_pre_harvest'] != null && f['audit_pre_harvest'].isNotEmpty 
            ? f['audit_pre_harvest'][0]['audit_week']?.toString() 
            : null;
      } else if (_selectedWorksheetTitle == 'Harvest') {
        rowWeek = f['audit_harvest'] != null && f['audit_harvest'].isNotEmpty 
            ? f['audit_harvest'][0]['audit_week']?.toString() 
            : null;
      }

      bool matchWeek = _selectedWeeksState.isEmpty || (rowWeek != null && _selectedWeeksState.contains(rowWeek));

      return matchRegion && matchSeason && matchDistrict && matchWeek;
    }).toList();

    _calculateKecamatanWorkloadAndDesa(_filteredMapData);

    setState(() {
      _currentPolygons = _buildPolygons();
      _isLoadingData = false;
    });
    _triggerMapActionsIfNeeded();
  }

  void _calculateKecamatanWorkloadAndDesa(List<Map<String, dynamic>> dataToProcess) {
    _kecamatanWorkload.clear();
    _desaWorkloadByKecamatan.clear();

    for (final row in dataToProcess) {
      final String kecamatanRaw = row['sub_district_kec']?.toString().trim() ?? '';
      final String desaRaw = row['village_desa']?.toString().trim() ?? '';
      final String districtRaw = row['district_kab']?.toString().trim() ?? '';
      final effectiveArea = _parseDouble(row['effective_area_ha']);

      if (kecamatanRaw.isEmpty || districtRaw.isEmpty) continue;

      final String normalizedKecamatanName = _normalizeName(kecamatanRaw);
      final String normalizedDistrictName = _normalizeName(districtRaw);
      final String uniqueKecamatanKey = '${normalizedDistrictName}_$normalizedKecamatanName';

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
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    return 0.0;
  }

  void _triggerMapActionsIfNeeded() {
    if (mounted && _isMapReady && !_isLoadingGeoJson && !_isLoadingData && !_initialZoomDone) {
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
    normalized = normalized.replaceAll(RegExp(r'KOTA ADMINISTRASI |KABUPATEN |KOTA |KECAMATAN |KEC\. |KAB\. |[\., ]'), '');
    return normalized.trim();
  }

  Color _getKecamatanColor(double workload) {
    int alphaValue = 220;
    if (workload <= 0) return Colors.green.shade100.withAlpha(150);
    if (workload <= 4.9) return Colors.green.shade600.withAlpha(alphaValue);
    if (workload <= 9.9) return Colors.amber.shade700.withAlpha(alphaValue);
    if (workload <= 19.9) return Colors.orange.shade800.withAlpha(alphaValue);
    if (workload <= 29.9) return Colors.deepOrange.shade700.withAlpha(alphaValue);
    if (workload <= 49.9) return Colors.red.shade500.withAlpha(alphaValue);
    return Colors.red.shade900.withAlpha(alphaValue);
  }

  List<Polygon> _buildPolygons() {
    if (_kecamatanWorkload.isEmpty || _geoJsonLookup.isEmpty) return [];
    final List<Polygon> polygons = [];

    for (final entry in _kecamatanWorkload.entries) {
      final String uniqueKey = entry.key;
      final double workload = entry.value;

      var feature = _geoJsonLookup[uniqueKey];
      if (feature == null) {
        final parts = uniqueKey.split('_');
        if (parts.length > 1) {
          final String kecNameOnly = parts[1];
          try {
            feature = _geoJsonLookup.values.firstWhere((f) {
              final props = f['properties'];
              final String gideonKec = _normalizeName(props['NAME_3']?.toString() ?? '');
              return gideonKec == kecNameOnly;
            });
          } catch (e) {
            // Handle error or ignore if feature not found
          }
        }
      }

      if (feature != null) {
        final geometry = feature['geometry'];
        final Color fillColor = _getKecamatanColor(workload);
        final bool isSelectedKecamatan = _selectedKecamatanKey == uniqueKey;

        if (geometry != null && geometry['coordinates'] != null) {
          final type = geometry['type'];
          final coordinates = geometry['coordinates'];
          try {
            List<LatLng> convertCoords(List rawCoords) {
              return rawCoords.map<LatLng>((point) => LatLng(point.last as double, point.first as double)).toList();
            }

            if (type == 'Polygon') {
              final points = convertCoords(coordinates.first as List);
              if (points.isNotEmpty) polygons.add(_createPolygonStyle(points, fillColor, isSelectedKecamatan, uniqueKey));
            } else if (type == 'MultiPolygon') {
              for (final polygonCoords in coordinates) {
                final points = convertCoords(polygonCoords.first as List);
                if (points.isNotEmpty) polygons.add(_createPolygonStyle(points, fillColor, isSelectedKecamatan, uniqueKey));
              }
            }
          } catch (e) {
            // Handle error during coordinate conversion
          }
        }
      }
    }
    return polygons;
  }

  Polygon _createPolygonStyle(List<LatLng> points, Color color, bool isSelected, String label) {
    return Polygon(
      points: points,
      color: color,
      borderColor: isSelected ? AppTheme.accent : AppTheme.primaryDark.withAlpha(178),
      borderStrokeWidth: isSelected ? 2.5 : 0.7,
      label: label,
    );
  }

  void _autoZoomToFilteredArea() {
    if (!mounted || !_isMapReady || _isLoadingGeoJson || _geojsonFeatures == null) return;
    List<LatLng> allPointsInView = [];
    if (_currentPolygons.isNotEmpty) {
      for (final polygon in _currentPolygons) {
        allPointsInView.addAll(polygon.points);
      }
    }
    if (allPointsInView.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(allPointsInView), padding: const EdgeInsets.all(30.0)));
      } catch (e) {
        // Handle error during camera fit
      }
    } else {
      _mapController.move(const LatLng(-2.548926, 118.0148634), 5.0);
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
        pointsToFit.addAll(polygon.points);
      }
    }

    if (pointsToFit.isNotEmpty) {
      try {
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pointsToFit), padding: const EdgeInsets.all(40.0)));
      } catch (e) {
        _mapController.move(pointsToFit.first, 10.0);
      }
    } else {
      _autoZoomToFilteredArea();
    }
  }

  void _handleKecamatanTap(String tappedKecKey) {
    setState(() {
      _selectedKecamatanKey = tappedKecKey;
      _isDetailPanelVisible = true;
      _kecamatanDataPoints.clear();

      for (final row in _filteredMapData) {
        final String normalizedKecName = _normalizeName(row['sub_district']?.toString() ?? '');
        final String normalizedDistName = _normalizeName(row['district_kab']?.toString() ?? '');
        final String uniqueKeyFromRow = '${normalizedDistName}_$normalizedKecName';

        if (uniqueKeyFromRow == tappedKecKey) {
          final lat = _parseDouble(row['latitude']);
          final lng = _parseDouble(row['longitude']);
          if (lat != 0.0 && lng != 0.0) {
            _kecamatanDataPoints.add({
              'lat': lat,
              'lng': lng,
              'area': _parseDouble(row['effective_area']),
              'label': row['field_number']?.toString() ?? 'N/A',
            });
          }
        }
      }
      _currentPolygons = _buildPolygons();
    });
  }

  Widget _buildDetailPanel(ScrollController scrollController) {
    if (_selectedKecamatanKey == null || !_desaWorkloadByKecamatan.containsKey(_selectedKecamatanKey)) {
      return const SizedBox.shrink();
    }
    final desaData = _desaWorkloadByKecamatan[_selectedKecamatanKey!]!;
    final kecamatanNameParts = _selectedKecamatanKey!.split('_');
    String displayName = kecamatanNameParts.length > 1 ? kecamatanNameParts.sublist(1).join(' ') : _selectedKecamatanKey!;
    final displayDistrictName = kecamatanNameParts.first;
    final totalWorkloadKecamatan = _kecamatanWorkload[_selectedKecamatanKey!] ?? 0.0;
    final Color themeColor = _getKecamatanColor(totalWorkloadKecamatan);
    final sortedDesaEntries = desaData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(color: themeColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(10)))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("KECAMATAN", style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 4),
                          Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("Kab/Kota $displayDistrictName", style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() { _selectedKecamatanKey = null; _isDetailPanelVisible = false; }))
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.analytics_outlined, color: themeColor, size: 28)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Area Efektif", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(totalWorkloadKecamatan.toStringAsFixed(2), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                              const SizedBox(width: 4),
                              const Text("Ha", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20.0), child: Text("Detail Desa/Kelurahan (${sortedDesaEntries.length})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark))),
          const SizedBox(height: 10),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: sortedDesaEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedDesaEntries[index];
              final double percent = totalWorkloadKecamatan > 0 ? (entry.value / totalWorkloadKecamatan) : 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)), Text("${entry.value.toStringAsFixed(2)} Ha", style: TextStyle(fontWeight: FontWeight.bold, color: themeColor))]),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percent, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation<Color>(themeColor), minHeight: 6)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRegionSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(20), child: Row(children: [const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 24), const SizedBox(width: 12), const Text('Pilih Region', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark))])),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _regionOptions.length,
                itemBuilder: (context, index) {
                  final region = _regionOptions[index];
                  final isSelected = _selectedRegion == region;
                  return ListTile(
                    leading: Icon(region == _allRegionsSentinel ? Icons.public : Icons.location_on, color: isSelected ? AppTheme.primary : Colors.grey),
                    title: Text(region, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primary : AppTheme.textDark)),
                    onTap: () { Navigator.pop(context); _onRegionChanged(region); },
                  );
                },
              ),
            ),
          ],
        ),
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
          setState(() { _selectedWeeksState = results; _selectedKecamatanKey = null; _isDetailPanelVisible = false; _kecamatanDataPoints.clear(); _initialZoomDone = false; });
          _applyAllFiltersAndBuildMap();
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Row(
            children: [
              _buildModernSelector(
                label: 'Worksheet',
                value: _selectedWorksheetTitle,
                icon: Icons.assignment_outlined,
                onTap: () => _showPremiumSelector(title: "Pilih Worksheet", items: _worksheetTitles, selectedValue: _selectedWorksheetTitle, onSelect: (val) { setState(() => _selectedWorksheetTitle = val); _populateAvailableWeeks(); }),
              ),
              const SizedBox(width: 12),
              _buildModernSelector(
                label: 'Musim Tanam',
                value: _selectedGrowingSeasonState ?? "Pilih Musim",
                icon: Icons.wb_sunny_outlined,
                onTap: () => _showPremiumSelector(title: "Pilih Musim Tanam", items: _availableGrowingSeasons, selectedValue: _selectedGrowingSeasonState, onSelect: (val) { setState(() { _selectedGrowingSeasonState = val; _selectedDistrictState = null; _selectedWeeksState.clear(); }); _populateAvailableDistricts(); }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModernSelector(
                label: 'District',
                value: _selectedDistrictState ?? "Semua District",
                icon: Icons.location_city_outlined,
                onTap: () => _showPremiumSelector(title: "Pilih District", items: _availableDistricts, selectedValue: _selectedDistrictState, onSelect: (val) { setState(() { _selectedDistrictState = val; _selectedWeeksState.clear(); }); _populateAvailableWeeks(); }),
              ),
              const SizedBox(width: 12),
              _buildModernSelector(
                label: 'Minggu Ke-',
                value: _selectedWeeksState.isEmpty ? 'Semua Minggu' : (_selectedWeeksState.length > 2 ? '${_selectedWeeksState.length} Minggu' : _selectedWeeksState.join(', ')),
                icon: Icons.calendar_month_outlined,
                onTap: _availableWeeks.isEmpty ? null : _showMultiSelectWeekDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernSelector({required String label, required String value, required IconData icon, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [Icon(icon, size: 16, color: AppTheme.primary), const SizedBox(width: 8), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark), overflow: TextOverflow.ellipsis)), Icon(Icons.unfold_more_rounded, size: 14, color: Colors.grey.shade400)]),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumSelector({required String title, required List<String> items, required String? selectedValue, required Function(String) onSelect}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const Divider(height: 1),
            Flexible(child: ListView.builder(shrinkWrap: true, itemCount: items.length, itemBuilder: (context, index) { final item = items[index]; final isSelected = item == selectedValue; return ListTile(title: Text(item, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textDark, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primary) : null, onTap: () { Navigator.pop(context); onSelect(item); }); })),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final legendItems = [
      {'color': _getKecamatanColor(0), 'label': '0 Ha'},
      {'color': _getKecamatanColor(4.9), 'label': '> 0-4.9 Ha'},
      {'color': _getKecamatanColor(9.9), 'label': '> 5-9.9 Ha'},
      {'color': _getKecamatanColor(19.9), 'label': '> 10-19.9 Ha'},
      {'color': _getKecamatanColor(29.9), 'label': '> 20-29.9 Ha'},
      {'color': _getKecamatanColor(49.9), 'label': '> 30-49.9 Ha'},
      {'color': _getKecamatanColor(50.0), 'label': '> 50 Ha'},
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withAlpha(220), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Area Efektif (Ha)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
          const SizedBox(height: 5),
          Wrap(spacing: 12.0, runSpacing: 4.0, alignment: WrapAlignment.center, children: legendItems.map((item) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: item['color'] as Color, border: Border.all(color: Colors.black54, width: 0.5), borderRadius: BorderRadius.circular(4))), const SizedBox(width: 4), Text(item['label'] as String, style: const TextStyle(fontSize: 11, color: AppTheme.textMedium))])).toList()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterFieldsAsync = ref.watch(masterFieldsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.go('/admin')),
        title: GestureDetector(
          onTap: _showRegionSelectionBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_selectedRegion == _allRegionsSentinel ? Icons.public : Icons.location_on, color: Colors.white, size: 18), const SizedBox(width: 8), Flexible(child: Text(_selectedRegion ?? 'Semua Region', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)), const Icon(Icons.unfold_more_rounded, color: Colors.white, size: 18)]),
          ),
        ),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark]))),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: () => ref.refresh(masterFieldsProvider))],
      ),
      body: masterFieldsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (fields) {
          if (_currentSupabaseData.isEmpty) {
            _currentSupabaseData = fields;
            Future.microtask(() => _extractFiltersFromData());
          }
          return Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(-2.548926, 118.0148634),
                        initialZoom: 5.0,
                        onMapReady: () { setState(() => _isMapReady = true); _triggerMapActionsIfNeeded(); },
                        onTap: (tapPosition, latLng) {
                          String? tappedKey;
                          for (final p in _currentPolygons.reversed) {
                            if (isPointInPolygon(latLng, p.points)) {
                              tappedKey = p.label;
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
                        TileLayer(urlTemplate: _isStreetView ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png' : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'com.kroscek.app'),
                        if (_currentPolygons.isNotEmpty) PolygonLayer(polygons: _currentPolygons),
                        MarkerLayer(markers: _kecamatanDataPoints.map((p) => Marker(point: LatLng(p['lat'], p['lng']), width: 30, height: 30, child: AnimatedPulseMarker(color: AppTheme.accent))).toList()),
                      ],
                    ),
                    if (_isDetailPanelVisible && _selectedKecamatanKey != null)
                      DraggableScrollableSheet(initialChildSize: 0.35, minChildSize: 0.15, maxChildSize: 0.85, builder: (context, sc) => _buildDetailPanel(sc)),
                    Positioned(
                      top: 10, right: 10,
                      child: Column(children: [
                        FloatingActionButton(heroTag: "zIn", mini: true, backgroundColor: Colors.white, onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 0.5), child: const Icon(Icons.add, color: AppTheme.primaryDark)),
                        const SizedBox(height: 8),
                        FloatingActionButton(heroTag: "zOut", mini: true, backgroundColor: Colors.white, onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 0.5), child: const Icon(Icons.remove, color: AppTheme.primaryDark)),
                        const SizedBox(height: 8),
                        FloatingActionButton(heroTag: "cnt", mini: true, backgroundColor: Colors.white, onPressed: _centerMapOnCurrentFeatures, child: const Icon(Icons.center_focus_strong, color: AppTheme.primaryDark)),
                        const SizedBox(height: 8),
                        FloatingActionButton(heroTag: "lyr", mini: true, backgroundColor: Colors.white, onPressed: () => setState(() => _isStreetView = !_isStreetView), child: Icon(_isStreetView ? Icons.satellite_alt : Icons.map, color: AppTheme.primaryDark)),
                      ]),
                    ),
                    if (_isLegendVisible) Positioned(bottom: 10, left: 10, right: 10, child: _buildLegend()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PremiumMultiSelectWeeks extends StatefulWidget {
  final List<String> availableWeeks;
  final List<String> initialSelectedWeeks;
  final Function(List<String>) onApply;
  const _PremiumMultiSelectWeeks({required this.availableWeeks, required this.initialSelectedWeeks, required this.onApply});
  @override
  State<_PremiumMultiSelectWeeks> createState() => _PremiumMultiSelectWeeksState();
}

class _PremiumMultiSelectWeeksState extends State<_PremiumMultiSelectWeeks> {
  late List<String> _tempSelected;
  @override
  void initState() { super.initState(); _tempSelected = List.from(widget.initialSelectedWeeks); }
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Pilih Minggu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton(onPressed: () => setState(() => _tempSelected.clear()), child: const Text("Reset", style: TextStyle(color: Colors.redAccent)))])),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableWeeks.length,
              itemBuilder: (context, index) {
                final week = widget.availableWeeks[index];
                final isSelected = _tempSelected.contains(week);
                return CheckboxListTile(
                  title: Text(
                    week,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.primary : AppTheme.textDark,
                    ),
                  ),
                  value: isSelected,
                  activeColor: AppTheme.primary,
                  onChanged: (bool? v) {
                    setState(() {
                      if (v == true) {
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
          Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { widget.onApply(_tempSelected); Navigator.pop(context); }, child: const Text("Terapkan Filter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
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
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (context, child) => Stack(alignment: Alignment.center, children: [Container(width: 20 * _controller.value, height: 20 * _controller.value, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(1 - _controller.value))), Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))]));
  }
}

bool isPointInPolygon(LatLng point, List<LatLng> polygonVertices) {
  if (polygonVertices.isEmpty) return false;
  int intersectCount = 0;
  for (int j = 0; j < polygonVertices.length; j++) {
    LatLng vertA = polygonVertices.elementAt(j);
    LatLng vertB = polygonVertices.elementAt((j + 1) % polygonVertices.length);
    if (((vertA.latitude <= point.latitude && point.latitude < vertB.latitude) ||
            (vertB.latitude <= point.latitude && point.latitude < vertA.latitude)) &&
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
