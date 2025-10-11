import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'psp_vegetative_detail_screen.dart';

enum MapViewMode {
  street,
  satellite
}

class PspVegetativeMapView extends StatefulWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Map<String, int> activityCounts;

  const PspVegetativeMapView({
    super.key,
    required this.filteredData,
    this.selectedRegion,
    this.activityCounts = const {},
  });

  @override
  State<PspVegetativeMapView> createState() => _PspVegetativeMapViewState();
}

class _PspVegetativeMapViewState extends State<PspVegetativeMapView> with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<Marker> _markers = [];
  bool _isLoading = true;
  bool _showUserLocation = false;
  LatLng? _selectedLocation;
  List<String>? _selectedData;
  LatLng _mapCenter = const LatLng(-7.637017, 112.8272303); // Default to central Java
  bool _initialCenterSet = false;
  MapViewMode _currentMapMode = MapViewMode.street;

  // Cache for marker data to avoid recalculation
  final Map<String, Marker> _markerCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to avoid blocking the UI during initialization
    Future.microtask(() {
      _loadMarkers();
      _getCurrentLocation();
    });
  }

  @override
  void didUpdateWidget(PspVegetativeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filteredData != oldWidget.filteredData) {
      // Reset the initial center flag when data changes
      _initialCenterSet = false;
      // Use compute for heavy processing
      Future.microtask(_loadMarkers);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _showUserLocation = true;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _loadMarkers() {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    // Process markers in batches to avoid UI freezes
    _processMarkersInBatches(widget.filteredData);
  }

  void _processMarkersInBatches(List<List<String>> data) {
    // Adjust batch size based on data size
    int batchSize = data.length <= 500 ? data.length : 200;

    List<Marker> markers = [];
    double sumLat = 0;
    double sumLng = 0;
    int validCoordinates = 0;
    int sampunCount = 0;
    int derengJangkepCount = 0;
    int derengBlasCount = 0;

    // Calculate total counts upfront
    for (var row in data) {
      final coordinateStr = _getValue(row, 20, '');
      if (coordinateStr.isNotEmpty) {
        final status = getPspVegetativeStatus(
            _getValue(row, 83, "not audited"),
            _getValue(row, 85, "not audited"),
            _getValue(row, 87, "not audited"),
            _getValue(row, 89, "not audited")
        );

        if (status == "Sampun") {
          sampunCount++;
        } else if (status == "Dereng Jangkep") {
          derengJangkepCount++;
        } else if (status == "Dereng Blas") {
          derengBlasCount++;
        }
      }
    }

    // Update cached counts immediately
    _cachedSampunCount = sampunCount;
    _cachedDerengJangkepCount = derengJangkepCount;
    _cachedDerengBlasCount = derengBlasCount;
    _lastFilteredData = data;

    // Process first batch immediately
    int endIndex = data.length < batchSize ? data.length : batchSize;

    for (int i = 0; i < endIndex; i++) {
      final marker = _createMarkerFromRow(data[i]);
      if (marker != null) {
        markers.add(marker);
        sumLat += marker.point.latitude;
        sumLng += marker.point.longitude;
        validCoordinates++;
      }
    }

    // Update UI with first batch
    if (mounted) {
      setState(() {
        _markers = markers;
        _isLoading = endIndex < data.length; // Still loading if more data to process

        // Update map center if we have valid coordinates
        if (validCoordinates > 0) {
          _mapCenter = LatLng(sumLat / validCoordinates, sumLng / validCoordinates);

          // Center the map on markers if this is the first load
          if (!_initialCenterSet) {
            _initialCenterSet = true;
            // Use a slight delay to ensure the map is ready
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _mapController.moveAndRotate(_mapCenter, 10.0, 0);
              }
            });
          }
        }
      });
    }

    // Process remaining batches asynchronously
    if (endIndex < data.length) {
      Future.microtask(() {
        _processRemainingBatches(data, endIndex, batchSize, markers, sumLat, sumLng, validCoordinates);
      });
    }
  }

  void _processRemainingBatches(
      List<List<String>> data,
      int startIndex,
      int batchSize,
      List<Marker> markers,
      double sumLat,
      double sumLng,
      int validCoordinates
      ) {
    int endIndex = startIndex + batchSize;
    if (endIndex > data.length) endIndex = data.length;

    for (int i = startIndex; i < endIndex; i++) {
      final marker = _createMarkerFromRow(data[i]);
      if (marker != null) {
        markers.add(marker);
        sumLat += marker.point.latitude;
        sumLng += marker.point.longitude;
        validCoordinates++;
      }
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _isLoading = endIndex < data.length;

        if (validCoordinates > 0) {
          _mapCenter = LatLng(sumLat / validCoordinates, sumLng / validCoordinates);

          // If this is the first complete batch and we have a lot of markers,
          // make sure the map is centered on them
          if (markers.length > 10 && !_initialCenterSet) {
            _initialCenterSet = true;
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _mapController.moveAndRotate(_mapCenter, 10.0, 0);
              }
            });
          }
        }
      });
    }

    // Continue with next batch if needed
    if (endIndex < data.length) {
      Future.microtask(() {
        _processRemainingBatches(data, endIndex, batchSize, markers, sumLat, sumLng, validCoordinates);
      });
    }
  }

  Marker? _createMarkerFromRow(List<String> row) {
    try {
      // Get coordinates from column R (index 17)
      final coordinateStr = _getValue(row, 20, '');
      if (coordinateStr.isEmpty) return null;

      // Check if we already have this marker in cache
      if (_markerCache.containsKey(coordinateStr)) {
        return _markerCache[coordinateStr];
      }

      // Parse coordinates (assuming format like "latitude,longitude")
      final parts = coordinateStr.split(',');
      if (parts.length != 2) return null;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat == null || lng == null) return null;

      final status = getPspVegetativeStatus(
        _getValue(row, 83, "not audited"),
        _getValue(row, 85, "not audited"),
        _getValue(row, 87, "not audited"),
        _getValue(row, 89, "not audited"),
      );
      final dap = _calculateDAP(row);

      final marker = Marker(
        width: 40.0,
        height: 40.0,
        point: LatLng(lat, lng),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedLocation = LatLng(lat, lng);
              _selectedData = row;
            });
            _mapController.moveAndRotate(LatLng(lat, lng), _mapController.camera.zoom, 0);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: getStatusColor(status).withAlpha(178),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$dap',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
      );

      // Cache the marker
      _markerCache[coordinateStr] = marker;

      return marker;
    } catch (e) {
      // Skip invalid coordinates
      return null;
    }
  }

  String _getValue(List<String> row, int index, String defaultValue) {
    if (index < row.length) {
      return row[index];
    }
    return defaultValue;
  }

  // Memoize DAP calculations to avoid recalculating
  final Map<String, int> _dapCache = {};

  int _calculateDAP(List<String> row) {
    try {
      final plantingDate = _getValue(row, 11, ''); // Get planting date from column 9
      if (plantingDate.isEmpty) return 0;

      // Check cache first
      if (_dapCache.containsKey(plantingDate)) {
        return _dapCache[plantingDate]!;
      }

      int dap = 0;
      // Try to parse as Excel date number
      final parsedNumber = double.tryParse(plantingDate);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        final today = DateTime.now();
        dap = today.difference(date).inDays;
      } else {
        // Try to parse as formatted date
        final parsedDate = DateTime.parse(plantingDate.split('/').reversed.join('-'));
        final today = DateTime.now();
        dap = today.difference(parsedDate).inDays;
      }

      // Cache the result
      _dapCache[plantingDate] = dap;
      return dap;
    } catch (e) {
      return 0;
    }
  }

  String getPspVegetativeStatus(
      String cekResult, String cekProses, String cekCF, String cekCH) {
    // Count how many columns are "audited"
    int auditedCount = 0;

    if (cekResult.toLowerCase() == "audited") auditedCount++;
    if (cekProses.toLowerCase() == "audited") auditedCount++;
    if (cekCF.toLowerCase() == "audited") auditedCount++;
    if (cekCH.toLowerCase() == "audited") auditedCount++;

    // Determine status based on count
    if (auditedCount == 4) {
      return "Sampun";
    } else if (auditedCount > 0) {
      return "Dereng Jangkep";
    } else {
      return "Dereng Blas";
    }
  }

  // Get color based on status
  Color getStatusColor(String status) {
    switch (status) {
      case "Sampun":
        return Colors.green;
      case "Dereng Jangkep":
        return Colors.orange;
      case "Dereng Blas":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get gradient colors based on status
  List<Color> getStatusGradient(String status) {
    switch (status) {
      case "Sampun":
        return [Colors.green.shade400, Colors.green.shade600];
      case "Dereng Jangkep":
        return [Colors.orange.shade400, Colors.orange.shade600];
      case "Dereng Blas":
        return [Colors.red.shade400, Colors.red.shade600];
      default:
        return [Colors.grey.shade400, Colors.grey.shade600];
    }
  }

  // Get icon based on status
  IconData getStatusIcon(String status) {
    switch (status) {
      case "Sampun":
        return Icons.check_circle;
      case "Dereng Jangkep":
        return Icons.hourglass_empty;
      case "Dereng Blas":
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  // Get the appropriate tile layer based on the current map mode
  TileLayer _getTileLayer() {
    switch (_currentMapMode) {
      case MapViewMode.street:
        return TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.kroscek',
          tileProvider: NetworkTileProvider(),
        );
      case MapViewMode.satellite:
        return TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.kroscek',
          tileProvider: NetworkTileProvider(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 10.0,
            maxZoom: 18.0,
            minZoom: 5.0,
            onTap: (_, __) {
              setState(() {
                _selectedLocation = null;
                _selectedData = null;
              });
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              // When map is ready, center on markers if we have them
              if (_markers.isNotEmpty && !_initialCenterSet) {
                _initialCenterSet = true;
                _mapController.moveAndRotate(_mapCenter, 10.0, 0);
              }
            },
          ),
          children: [
            _getTileLayer(),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(40, 40),
                markers: _markers,
                builder: (context, markers) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.blue.withAlpha(178),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                // Add these options for better performance
                disableClusteringAtZoom: 16,
                animationsOptions: const AnimationsOptions(
                  zoom: Duration(milliseconds: 200),
                  spiderfy: Duration(milliseconds: 300),
                ),
              ),
            ),
            // User location marker
            if (_showUserLocation && _currentPosition != null)
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

        // Loading indicator
        if (_isLoading)
          Positioned(
            bottom: 16,
            left: 16,
            child: Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading ${_markers.length}/${widget.filteredData.length} fields...',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Map type selector
        Positioned(
          top: 16,
          left: 16,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapTypeButton(
                    icon: Icons.map,
                    label: 'Street',
                    mode: MapViewMode.street,
                  ),
                  _buildMapTypeButton(
                    icon: Icons.satellite,
                    label: 'Satellite',
                    mode: MapViewMode.satellite,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Map controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: "zoomIn",
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade800,
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.moveAndRotate(
                    _mapController.camera.center,
                    currentZoom + 1,
                    0,
                  );
                },
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: "zoomOut",
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade800,
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.moveAndRotate(
                    _mapController.camera.center,
                    currentZoom - 1,
                    0,
                  );
                },
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: "myLocation",
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
                onPressed: () async {
                  await _getCurrentLocation();
                  if (_currentPosition != null) {
                    _mapController.moveAndRotate(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      15,
                      0,
                    );
                  }
                },
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: "centerMarkers",
                mini: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade800,
                onPressed: () {
                  if (_markers.isNotEmpty) {
                    _mapController.moveAndRotate(_mapCenter, 10.0, 0);
                  }
                },
                child: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
        ),

        // Info panel when a marker is selected
        if (_selectedLocation != null && _selectedData != null)
          _buildInfoPanel(),

        // Stats panel
        Positioned(
          top: 16,
          right: 16,
          child: _buildStatsPanel(),
        ),
      ],
    );
  }

  Widget _buildMapTypeButton({
    required IconData icon,
    required String label,
    required MapViewMode mode,
  }) {
    final isSelected = _currentMapMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _currentMapMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: Colors.green.shade300, width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.green.shade700 : Colors.black54,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green.shade700 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    final status = getPspVegetativeStatus(
      _getValue(_selectedData!, 83, "not audited"),
      _getValue(_selectedData!, 85, "not audited"),
      _getValue(_selectedData!, 87, "not audited"),
      _getValue(_selectedData!, 89, "not audited")
    );
    final fieldNumber = _getValue(_selectedData!, 2, "Unknown");
    final activityCount = widget.activityCounts[fieldNumber] ?? 0;
    final statusColor = getStatusColor(status);
    final statusGradient = getStatusGradient(status);

    return Positioned(
      bottom: 16,
      left: 16,
      right: 80,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: statusColor,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status and Activity Count moved above the image and field number
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: statusGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getStatusIcon(status),
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Activity Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: activityCount == 0
                            ? [Colors.red.shade50, Colors.red.shade100]
                            : (activityCount < 3
                            ? [Colors.orange.shade50, Colors.orange.shade100]
                            : [Colors.green.shade50, Colors.green.shade100]),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: activityCount == 0
                              ? Colors.red.withAlpha(25)
                              : (activityCount < 3 ? Colors.orange.withAlpha(25) : Colors.green.withAlpha(25)),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: activityCount == 0
                            ? Colors.red.shade200
                            : (activityCount < 3 ? Colors.orange.shade200 : Colors.green.shade200),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activityCount == 0
                              ? Icons.history_toggle_off
                              : (activityCount < 3 ? Icons.history : Icons.history_edu),
                          color: activityCount == 0
                              ? Colors.red.shade700
                              : (activityCount < 3 ? Colors.orange.shade700 : Colors.green.shade700),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          activityCount == 0
                              ? 'Not Visited'
                              : (activityCount == 1
                              ? 'Visited 1 kali'
                              : 'Visited $activityCount kali'),
                          style: TextStyle(
                            color: activityCount == 0
                                ? Colors.red.shade700
                                : (activityCount < 3 ? Colors.orange.shade700 : Colors.green.shade700),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/vegetative.png',
                      height: 30,
                      width: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fieldNumber, // Field Number
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _getValue(_selectedData!, 4, "Unknown"), // Farmer Name
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.grass,
                          label: 'PS Code',
                          value: _getValue(_selectedData!, 6, "Unknown"),
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: 'DAP',
                          value: '${_calculateDAP(_selectedData!)} days',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          icon: Icons.crop,
                          label: 'Area',
                          value: '${_getValue(_selectedData!, 9, "0")} Ha',
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          icon: Icons.people,
                          label: 'FA',
                          value: _getValue(_selectedData!, 19, "Unknown"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PspVegetativeDetailScreen(
                        fieldNumber: fieldNumber,
                        region: widget.selectedRegion ?? 'Unknown Region',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: getStatusColor(status), // Set color based on status
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility, size: 16),
                    Text(' View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cache for status counts
  List<List<String>>? _lastFilteredData;
  int _cachedSampunCount = 0;
  int _cachedDerengJangkepCount = 0;
  int _cachedDerengBlasCount = 0;

  Widget _buildStatsPanel() {
    // Use cached values if the data hasn't changed
    if (_lastFilteredData != widget.filteredData) {
      _updateStatusCounts();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: ${_cachedSampunCount + _cachedDerengJangkepCount + _cachedDerengBlasCount} Lahan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 4),
            _buildStatusIndicator(
              count: _cachedSampunCount,
              color: Colors.green,
            ),
            const SizedBox(height: 4),
            _buildStatusIndicator(
              count: _cachedDerengJangkepCount,
              color: Colors.orange,
            ),
            const SizedBox(height: 4),
            _buildStatusIndicator(
              count: _cachedDerengBlasCount,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatusCounts() {
    int sampunCount = 0;
    int derengJangkepCount = 0;
    int derengBlasCount = 0;

    for (var row in widget.filteredData) {
      final status = getPspVegetativeStatus(
          _getValue(row, 83, "not audited"),
          _getValue(row, 85, "not audited"),
          _getValue(row, 87, "not audited"),
          _getValue(row, 89, "not audited")
      );

      if (status == "Sampun") {
        sampunCount++;
      } else if (status == "Dereng Jangkep") {
        derengJangkepCount++;
      } else if (status == "Dereng Blas") {
        derengBlasCount++;
      }
    }

    setState(() {
      _cachedSampunCount = sampunCount;
      _cachedDerengJangkepCount = derengJangkepCount;
      _cachedDerengBlasCount = derengBlasCount;
      _lastFilteredData = widget.filteredData;
    });
  }

  Widget _buildStatusIndicator({
    required int count,
    required Color color,
    bool isTotal = false,
  }) {
    final totalCount = _cachedSampunCount + _cachedDerengJangkepCount + _cachedDerengBlasCount;
    final percentage = totalCount > 0 ? (count / totalCount * 100).toStringAsFixed(1) : '0.0';

    IconData statusIcon;
    if (color == Colors.green) {
      statusIcon = Icons.check_circle; // Sampun
    } else if (color == Colors.orange) {
      statusIcon = Icons.hourglass_empty; // Dereng Jangkep
    } else if (color == Colors.red) {
      statusIcon = Icons.cancel; // Dereng Blas
    } else {
      statusIcon = Icons.grading_rounded; // Default icon
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(statusIcon, size: 14, color: color),
        const Spacer(),
        Text(
          ': $count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.black : color.withAlpha(204),
          ),
        ),
        if (!isTotal) ...[
          const SizedBox(width: 6),
          Text(
            '($percentage%)',
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.green.shade700),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _markerCache.clear();
    _dapCache.clear();
    super.dispose();
  }
}