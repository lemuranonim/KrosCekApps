import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'generative_detail_screen.dart';
import '../../../utils/formatters.dart';

enum MapViewMode { street, satellite }

class GenerativeMapView extends StatefulWidget {
  final List<List<String>> filteredData;
  final String? selectedRegion;
  final Map<String, int> activityCounts;

  const GenerativeMapView({
    super.key,
    required this.filteredData,
    this.selectedRegion,
    this.activityCounts = const {},
  });

  @override
  State<GenerativeMapView> createState() => _GenerativeMapViewState();
}

class _GenerativeMapViewState extends State<GenerativeMapView>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<Marker> _markers = [];
  bool _isLoading = true;
  bool _showUserLocation = false;
  LatLng? _selectedLocation;
  List<String>? _selectedData;
  LatLng _mapCenter = const LatLng(-7.637017, 112.8272303);
  bool _initialCenterSet = false;
  MapViewMode _currentMapMode = MapViewMode.street;

  int _sampunOnMapCount = 0;
  int _derengJangkepOnMapCount = 0;
  int _derengBlasOnMapCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _processAndLoadMarkers();
      _getCurrentLocation();
    });
  }

  @override
  void didUpdateWidget(GenerativeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filteredData != oldWidget.filteredData) {
      _initialCenterSet = false;
      Future.microtask(_processAndLoadMarkers);
    }
  }

  void _processAndLoadMarkers() {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      // Reset counter setiap kali data diproses ulang
      _sampunOnMapCount = 0;
      _derengJangkepOnMapCount = 0;
      _derengBlasOnMapCount = 0;
    });

    final Map<String, List<List<String>>> groupedData =
    _groupDataByLocation(widget.filteredData);

    List<Marker> newMarkers = [];
    double sumLat = 0;
    double sumLng = 0;
    int validCoordinatesCount = 0;

    groupedData.forEach((coordString, dataList) {
      final parts = coordString.split(',');
      if (parts.length != 2) return;

      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) return;

      final point = LatLng(lat, lng);
      sumLat += lat;
      sumLng += lng;
      validCoordinatesCount++;

      // Hitung status untuk setiap item di lokasi ini
      for (var row in dataList) {
        final status = getGenerativeStatus(
          _getValue(row, 72, "not audited"),
          _getValue(row, 73, "not audited"),
        );
        switch (status) {
          case "Sampun":
            _sampunOnMapCount++;
            break;
          case "Dereng Jangkep":
            _derengJangkepOnMapCount++;
            break;
          case "Dereng Blas":
            _derengBlasOnMapCount++;
            break;
        }
      }

      Marker marker;
      if (dataList.length == 1) {
        marker = _createSingleMarker(point, dataList.first);
      } else {
        marker = _createStackedMarker(point, dataList);
      }
      newMarkers.add(marker);
    });

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        if (validCoordinatesCount > 0) {
          _mapCenter = LatLng(sumLat / validCoordinatesCount, sumLng / validCoordinatesCount);
          if (!_initialCenterSet) {
            _initialCenterSet = true;
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _mapController.moveAndRotate(_mapCenter, 10.0, 0);
              }
            });
          }
        }
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk mengelompokkan data berdasarkan koordinat
  Map<String, List<List<String>>> _groupDataByLocation(List<List<String>> data) {
    final Map<String, List<List<String>>> groupedData = {};
    for (var row in data) {
      final coordinateStr = _getValue(row, 16, '');
      final parts = coordinateStr.split(',');
      if (coordinateStr.isNotEmpty &&
          parts.length == 2 &&
          double.tryParse(parts[0].trim()) != null &&
          double.tryParse(parts[1].trim()) != null) {
        if (groupedData.containsKey(coordinateStr)) {
          groupedData[coordinateStr]!.add(row);
        } else {
          groupedData[coordinateStr] = [row];
        }
      }
    }
    return groupedData;
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

  // Fungsi untuk membuat marker tunggal
  Marker _createSingleMarker(LatLng point, List<String> row) {
    final status = getGenerativeStatus(
      _getValue(row, 72, "not audited"),
      _getValue(row, 73, "not audited"),
    );
    final dap = Formatters.calculateDAP(_getValue(row, 9, ''));

    return Marker(
      width: 40.0,
      height: 40.0,
      point: point,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedLocation = point;
            _selectedData = row;
          });
          _mapController.moveAndRotate(point, _mapController.camera.zoom, 0);
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
  }

  // Fungsi untuk membuat marker tumpuk (stacked)
  Marker _createStackedMarker(LatLng point, List<List<String>> dataList) {
    return Marker(
      width: 45.0,
      height: 45.0,
      point: point,
      child: GestureDetector(
        onTap: () => _showStackedDataSheet(dataList),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple.withAlpha(200),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.layers, color: Colors.white, size: 18),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    '${dataList.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fungsi untuk menampilkan bottom sheet berisi daftar data
  void _showStackedDataSheet(List<List<String>> dataList) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dataList.length} Lahan di Lokasi Ini',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: dataList.length,
                  itemBuilder: (context, index) {
                    final row = dataList[index];
                    final fieldNumber = _getValue(row, 2, "Unknown");
                    final farmerName = _getValue(row, 3, "Unknown");
                    final status = getGenerativeStatus(
                      _getValue(row, 72, "not audited"),
                      _getValue(row, 73, "not audited"),
                    );

                    return ListTile(
                      leading: Icon(
                        getStatusIcon(status),
                        color: getStatusColor(status),
                      ),
                      title: Text(fieldNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(farmerName),
                      onTap: () {
                        Navigator.pop(context); // Tutup bottom sheet
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GenerativeDetailScreen(
                              fieldNumber: fieldNumber,
                              region: widget.selectedRegion ?? 'Unknown Region',
                            ),
                          ),
                        );
                      },
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

  // Panel Statistik yang sudah dioptimalkan
  Widget _buildStatsPanel() {
    final int totalFilteredCount = widget.filteredData.length;
    final int totalOnMap = _sampunOnMapCount + _derengJangkepOnMapCount + _derengBlasOnMapCount;
    final int invalidCoordinatesCount = totalFilteredCount - totalOnMap;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: $totalFilteredCount Lahan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.green.shade800,
              ),
            ),
            const Divider(height: 12),
            _buildStatRow(
              status: "Sampun",
              count: _sampunOnMapCount,
              total: totalOnMap,
            ),
            const SizedBox(height: 4),
            _buildStatRow(
              status: "Dereng Jangkep",
              count: _derengJangkepOnMapCount,
              total: totalOnMap,
            ),
            const SizedBox(height: 4),
            _buildStatRow(
              status: "Dereng Blas",
              count: _derengBlasOnMapCount,
              total: totalOnMap,
            ),
            if (invalidCoordinatesCount > 0) ...[
              const SizedBox(height: 4),
              _buildStatRow(
                status: "Tanpa Koordinat",
                count: invalidCoordinatesCount,
                total: totalOnMap,
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Helper widget untuk membuat baris statistik
  Widget _buildStatRow({
    required String status,
    required int count,
    required int total,
  }) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;
    final isNoCoord = status == "Tanpa Koordinat";

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isNoCoord ? Colors.grey : getStatusColor(status),
            shape: BoxShape.circle,
          ),
          child: isNoCoord ? const Icon(Icons.location_off_outlined, color: Colors.white, size: 8) : null,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$status: $count ${!isNoCoord ? "(${percentage.toStringAsFixed(1)}%)" : ""}',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- Fungsi utilitas spesifik untuk Generative ---
  String getGenerativeStatus(String cekResult, String cekProses) {
    if (cekResult.toLowerCase() == "audited" && cekProses.toLowerCase() == "audited") {
      return "Sampun";
    } else if ((cekResult.toLowerCase() == "audited" && cekProses.toLowerCase() == "not audited") ||
        (cekResult.toLowerCase() == "not audited" && cekProses.toLowerCase() == "audited")) {
      return "Dereng Jangkep";
    } else if (cekResult.toLowerCase() == "not audited" && cekProses.toLowerCase() == "not audited") {
      return "Dereng Blas";
    }
    return "Unknown";
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Sampun": return Colors.green;
      case "Dereng Jangkep": return Colors.orange;
      case "Dereng Blas": return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case "Sampun": return Icons.check_circle;
      case "Dereng Jangkep": return Icons.hourglass_empty;
      case "Dereng Blas": return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  String _getValue(List<String> row, int index, String defaultValue) {
    return (index < row.length) ? row[index] : defaultValue;
  }

  // Memoize DAP calculations to avoid recalculating
  final Map<String, int> _dapCache = {};

  int _calculateDAP(List<String> row) {
    try {
      final plantingDate = _getValue(row, 9, ''); // Get planting date from column 9
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
    final status = getGenerativeStatus(
        _getValue(_selectedData!, 72, "not audited"),
        _getValue(_selectedData!, 73, "not audited")
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
                      'assets/generative.png',
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
                          _getValue(_selectedData!, 3, "Unknown"), // Farmer Name
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
                          label: 'Hybrid',
                          value: _getValue(_selectedData!, 5, "Unknown"),
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
                          value: '${_getValue(_selectedData!, 8, "0")} Ha',
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow(
                          icon: Icons.people,
                          label: 'FA',
                          value: _getValue(_selectedData!, 14, "Unknown"),
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
                      builder: (context) => GenerativeDetailScreen(
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
}