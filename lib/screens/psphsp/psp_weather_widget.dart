// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:weather_icons/weather_icons.dart';

import 'psp_weather_model.dart';
import 'psp_weather_service.dart';

class PspWeatherWidget extends StatefulWidget {
  final String greeting;

  const PspWeatherWidget({
    super.key,
    required this.greeting,
  });

  @override
  State<PspWeatherWidget> createState() => _PspWeatherWidgetState();
}

class _PspWeatherWidgetState extends State<PspWeatherWidget> with SingleTickerProviderStateMixin {
  final PspWeatherService _pspWeatherService = PspWeatherService();

  PspWeatherData _pspWeatherData = PspWeatherData();
  ForecastData _forecastData = ForecastData.empty();

  Timer? _timer;
  bool _isLoading = true;
  String _errorMessage = '';

  // --- Animation Controller ---
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  // --- Colors ---
  final Color _glassBorder = Colors.white.withOpacity(0.3);
  final Color _accentCyan = const Color(0xFF00E5FF);
  final Color _accentGreen = const Color(0xFF00E676);
  final Color _accentAmber = const Color(0xFFFFC400);

  @override
  void initState() {
    super.initState();

    // Setup Animasi Native
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _loadCachedData();
    _fetchPspWeatherData();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _fetchPspWeatherData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    _isFront = !_isFront;
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedWeather = await _pspWeatherService.loadCachedPspWeatherData();
      final cachedForecast = await _pspWeatherService.loadCachedForecastData();

      if (mounted) {
        setState(() {
          _pspWeatherData = cachedWeather;
          _forecastData = cachedForecast;
          if (cachedWeather.lastFetchTime != null) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> _fetchPspWeatherData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
        if (status.isDenied) {
          throw Exception('Location permission denied');
        }
      }

      final position = await _pspWeatherService.getCurrentPosition();
      String locationName = _pspWeatherData.locationName;
      if (locationName.isEmpty ||
          _pspWeatherService.hasPositionChangedSignificantly(position)) {
        locationName = await _pspWeatherService.getLocationName(position);
      }

      final pspWeatherData = await _pspWeatherService.fetchCurrentWeather(position, locationName);
      final forecastData = await _pspWeatherService.fetchForecast(position);

      if (mounted) {
        setState(() {
          _pspWeatherData = pspWeatherData;
          _forecastData = forecastData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Check connection/location';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: _toggleCard,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * math.pi;

            // Menjaga value agar tidak persis 90 derajat (pi/2) untuk menghindari singularity matrix
            // Walaupun jarang terjadi dengan animation controller, ini safety guard.
            final safeAngle = (angle == math.pi / 2) ? angle + 0.001 : angle;

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(safeAngle);

            final isFrontVisible = angle < (math.pi / 2);

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: isFrontVisible
                  ? _buildCardContainer(child: _buildFrontContent())
                  : Transform(
                transform: Matrix4.identity()..rotateX(math.pi),
                alignment: Alignment.center,
                child: _buildCardContainer(child: _buildBackContent()),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    final bool isNight = widget.greeting.contains('Night') || widget.greeting.contains('Evening');
    final List<Color> gradientColors = isNight
        ? [const Color(0xFF1A237E), const Color(0xFF4A148C)]
        : [const Color(0xFF448AFF), const Color(0xFF7C4DFF)];

    return Container(
      constraints: const BoxConstraints(minHeight: 220), // Sedikit dinaikkan minHeight-nya
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Background Orbs
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_accentCyan.withOpacity(0.3), _accentCyan.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
            // Glass Layer
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: _glassBorder, width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                  stops: const [0.1, 0.9],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: _isLoading
                      ? _buildLoadingState()
                      : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FRONT CONTENT ---
  Widget _buildFrontContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Location Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: _accentCyan),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _pspWeatherData.locationName.isEmpty ? "Locating..." : _pspWeatherData.locationName,
                          style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(widget.greeting, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 12, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(width: 4),
                  Text("Now", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 20),
        // Main Temp
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pspWeatherData.temperature.replaceAll('°C', ''),
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: Colors.white, height: 1.0, letterSpacing: -2),
                ),
                Row(
                  children: [
                    Text("°C", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: _accentCyan)),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 15, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 8),
                    Text(_pspWeatherData.weatherCondition, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                  ],
                )
              ],
            ),
            const Spacer(),
            // Icon
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 30, spreadRadius: 1)],
              ),
              child: BoxedIcon(_pspWeatherData.weatherIcon, color: Colors.white, size: 60),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Stats Grid
        Row(
          children: [
            Expanded(child: _buildAgriMetricCard(label: "GDU Accum.", value: _pspWeatherData.gdu.toStringAsFixed(1), unit: "Heat Units", icon: WeatherIcons.thermometer, color: _accentGreen)),
            const SizedBox(width: 12),
            Expanded(child: _buildAgriMetricCard(label: "CHU Daily", value: _pspWeatherData.chu.toStringAsFixed(1), unit: "Crop Units", icon: WeatherIcons.day_sunny, color: _accentAmber)),
          ],
        ),
        const SizedBox(height: 12),
        // Details
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(WeatherIcons.humidity, "${_pspWeatherData.humidity}%", "Humidity"),
              _buildDetailItem(WeatherIcons.strong_wind, _pspWeatherData.feelsLike, "Feels Like"),
              _buildDetailItem(WeatherIcons.day_sunny, _pspWeatherData.uvIndex.toStringAsFixed(1), "UV Index"),
            ],
          ),
        ),
      ],
    );
  }

  // --- BACK CONTENT (FIXED: Menggunakan Column, bukan Expanded) ---
  Widget _buildBackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Agar tinggi menyesuaikan konten
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: _accentCyan),
                const SizedBox(width: 8),
                const Text("3-Day Forecast", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 4),
        Text("Planning for ${_forecastData.totalGdu.toStringAsFixed(0)} total GDU", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 20),

        // Forecast List - MENGGUNAKAN COLUMN BIASA
        // Ini mencegah error layout 'unbounded height' yang terjadi saat rotasi
        _isLoading
            ? _buildLoadingState()
            : Column(
          children: _buildModernForecastRows(),
        ),

        // Summary Footer
        const SizedBox(height: 12), // Spacer manual karena tidak pakai Expanded
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _accentGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: _accentGreen.withOpacity(0.5))),
          child: Row(
            children: [
              Icon(Icons.eco_rounded, color: _accentGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_pspWeatherData.growingCondition.isNotEmpty ? "Condition: ${_pspWeatherData.growingCondition}" : "Good Growing Conditions", style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        )
      ],
    );
  }

  List<Widget> _buildModernForecastRows() {
    List<Widget> rows = [];
    final dayLabels = {'day1': 'Tomorrow', 'day2': 'Day 2', 'day3': 'Day 3'};
    for (var entry in dayLabels.entries) {
      if (_forecastData.dailyForecasts.containsKey(entry.key)) {
        rows.add(_buildForecastRowItem(entry.key, entry.value));
        if (entry.key != 'day3') rows.add(const SizedBox(height: 10)); // Spacing antar item
      }
    }
    return rows;
  }

  Widget _buildForecastRowItem(String key, String label) {
    final forecast = _forecastData.dailyForecasts[key]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(
        children: [
          Column(
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              BoxedIcon(forecast.icon, color: Colors.white.withOpacity(0.9), size: 18),
            ],
          ),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Temp", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                Text(forecast.tempRange, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [Icon(Icons.thermostat, size: 10, color: _accentGreen), const SizedBox(width: 2), Text("${forecast.gdu.toStringAsFixed(0)} GDU", style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 12))]),
              const SizedBox(height: 4),
              Row(children: [Icon(Icons.wb_sunny_rounded, size: 10, color: _accentAmber), const SizedBox(width: 2), Text("${forecast.chu.toStringAsFixed(0)} CHU", style: TextStyle(color: _accentAmber, fontWeight: FontWeight.bold, fontSize: 12))]),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAgriMetricCard({required String label, required String value, required String unit, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 14), const SizedBox(width: 6), Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _accentCyan, strokeWidth: 2),
          const SizedBox(height: 16),
          Text("Analyzing Weather Data...", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12))
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: Colors.white.withOpacity(0.5), size: 40),
          const SizedBox(height: 12),
          Text(_errorMessage, style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _fetchPspWeatherData,
            style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
            child: const Text("Retry", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}