import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:flip_card/flip_card.dart';

import 'weather_model.dart';
import 'weather_service.dart';

class WeatherWidget extends StatefulWidget {
  final String greeting;

  const WeatherWidget({
    super.key,
    required this.greeting,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final WeatherService _weatherService = WeatherService();

  WeatherData _weatherData = WeatherData();
  ForecastData _forecastData = ForecastData.empty();

  Timer? _timer;
  bool _isLoading = true;
  String _errorMessage = '';

  final GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _fetchWeatherData();
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _fetchWeatherData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedWeather =
      await _weatherService.loadCachedWeatherData();
      final cachedForecast = await _weatherService.loadCachedForecastData();

      setState(() {
        _weatherData = cachedWeather;
        _forecastData = cachedForecast;
        if (cachedWeather.lastFetchTime != null) {
          _isLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> _fetchWeatherData() async {
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

      final position = await _weatherService.getCurrentPosition();

      String locationName = _weatherData.locationName;
      if (locationName.isEmpty ||
          _weatherService.hasPositionChangedSignificantly(position)) {
        locationName = await _weatherService.getLocationName(position);
      }

      final weatherData =
      await _weatherService.fetchCurrentWeather(position, locationName);

      final forecastData = await _weatherService.fetchForecast(position);

      setState(() {
        _weatherData = weatherData;
        _forecastData = forecastData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlipCard(
      key: cardKey,
      front: _buildFrontCard(),
      back: _buildBackCard(),
    );
  }

  // ============================================================================
  // FRONT CARD - CURRENT WEATHER
  // ============================================================================

  Widget _buildFrontCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.green.shade50.withAlpha(178),
            Colors.green.shade100.withAlpha(102),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(30),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade100.withAlpha(51),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade100.withAlpha(38),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.all(18),
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage.isNotEmpty
                  ? _buildErrorState()
                  : _buildFrontContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading weather...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade400,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFrontContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Location Badge
        if (_weatherData.locationName.isNotEmpty)
          _buildLocationBadge(),

        // Main Weather Info
        _buildMainWeatherInfo(),
        const SizedBox(height: 16),

        // GDU and CHU Row
        _buildGduChuRow(),
        const SizedBox(height: 12),

        // Weather Details (Humidity, UV, Feels Like)
        _buildWeatherDetailsCard(),
        const SizedBox(height: 12),

        // Growing Condition & Alert
        _buildConditionAndAlert(),
        const SizedBox(height: 12),

        // Last Update Info
        _buildLastUpdateInfo(),
      ],
    );
  }

  Widget _buildLocationBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(15),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _weatherData.locationName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainWeatherInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Weather',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _weatherData.temperature,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _weatherData.weatherCondition,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        ),

        // Weather Icon with Animation
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.green.shade50,
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _weatherData.iconColor.withAlpha(40),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: BoxedIcon(
                  _weatherData.weatherIcon,
                  color: _weatherData.iconColor,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGduChuRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildWeatherInfoChip(
            icon: Icons.thermostat,
            label: 'GDU: ${_weatherData.gdu.toStringAsFixed(1)}',
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 10),
          _buildWeatherInfoChip(
            icon: Icons.wb_sunny,
            label: 'CHU: ${_weatherData.chu.toStringAsFixed(1)}',
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildWeatherDetail(
            icon: WeatherIcons.humidity,
            label: 'Humidity',
            value: '${_weatherData.humidity}%',
            color: Colors.blue.shade600,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.green.shade200,
          ),
          _buildWeatherDetail(
            icon: WeatherIcons.day_sunny,
            label: 'UV Index',
            value: _weatherData.uvIndex.toStringAsFixed(1),
            color: Colors.green.shade800,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.green.shade200,
          ),
          _buildWeatherDetail(
            icon: WeatherIcons.thermometer,
            label: 'Feels Like',
            value: _weatherData.feelsLike,
            color: Colors.purple.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetail({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        BoxedIcon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionAndAlert() {
    return Row(
      children: [
        // Growing Condition
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getConditionColor(_weatherData.growingCondition)
                      .withAlpha(51),
                  _getConditionColor(_weatherData.growingCondition)
                      .withAlpha(25),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getConditionColor(_weatherData.growingCondition),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.eco,
                  size: 16,
                  color: _getConditionColor(_weatherData.growingCondition),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _weatherData.growingCondition,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                      _getConditionColor(_weatherData.growingCondition),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Alert (if exists)
        if (_weatherData.alert != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade100,
                    Colors.red.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.shade400,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _weatherData.alert == 'Frost Risk'
                        ? WeatherIcons.snowflake_cold
                        : WeatherIcons.hot,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _weatherData.alert!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLastUpdateInfo() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.update_rounded,
              size: 12,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              _weatherData.lastFetchTime != null
                  ? 'Updated: ${_weatherService.formatLastUpdateTime(_weatherData.lastFetchTime!)}'
                  : 'Updates every 15 minutes',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // BACK CARD - FORECAST
  // ============================================================================

  Widget _buildBackCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withAlpha(25),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
                Colors.green.shade700),
          ),
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Text(
          _errorMessage,
          style: TextStyle(color: Colors.red[300], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      )
          : _buildBackContent(),
    );
  }

  Widget _buildBackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with Badge
        _buildForecastTitle(),
        const SizedBox(height: 8),

        // Total GDU and CHU Summary
        _buildTotalSummary(),
        const SizedBox(height: 8),

        // GDU Progress Bar
        _buildGduRating(),
        const SizedBox(height: 12),

        // Table header
        _buildTableHeader(),

        // Table rows
        ..._buildTableRows(),

        const SizedBox(height: 8),

        // Info note
        _buildInfoNote(),
      ],
    );
  }

  Widget _buildForecastTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _forecastData.forecastTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.green.shade200.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '3-Day Total',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Icon(
                Icons.thermostat,
                color: Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                'Total GDU',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _forecastData.totalGdu.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.green.shade200,
          ),
          Column(
            children: [
              Icon(
                Icons.wb_sunny,
                color: Colors.amber.shade700,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                'Total CHU',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _forecastData.totalChu.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade200.withAlpha(76),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Day',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.green.shade800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Temp (°C)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.green.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'GDU',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.green.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'CHU',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.green.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTableRows() {
    List<Widget> rows = [];
    final dayLabels = _getDayLabels();

    for (var entry in dayLabels.entries) {
      if (_forecastData.dailyForecasts.containsKey(entry.key)) {
        rows.add(_buildTableRow(entry.key, entry.value));
      }
    }

    return rows;
  }

  Widget _buildTableRow(String key, String label) {
    final forecast = _forecastData.dailyForecasts[key]!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.green.shade100,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,  // Ubah dari 2 ke 3
            child: Row(
              children: [
                // Tambahkan icon cuaca
                BoxedIcon(
                  forecast.icon,
                  size: 16,
                  color: forecast.color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      if (forecast.date.isNotEmpty)
                        Text(
                          forecast.date.split(',')[0],
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              forecast.tempRange,
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                forecast.gdu.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                forecast.chu.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGduRating() {
    final avgDailyGdu = _forecastData.totalGdu / 3;
    String rating;
    Color ratingColor;
    IconData ratingIcon;

    if (avgDailyGdu >= 15) {
      rating = 'Excellent Growing Weather';
      ratingColor = Colors.green.shade700;
      ratingIcon = Icons.local_fire_department;
    } else if (avgDailyGdu >= 10) {
      rating = 'Good Growing Weather';
      ratingColor = Colors.lightGreen.shade600;
      ratingIcon = Icons.wb_sunny;
    } else if (avgDailyGdu >= 5) {
      rating = 'Moderate Growing Weather';
      ratingColor = Colors.orange.shade600;
      ratingIcon = Icons.cloud;
    } else {
      rating = 'Slow Growing Weather';
      ratingColor = Colors.red.shade600;
      ratingIcon = Icons.ac_unit;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ratingColor.withAlpha(51),
            ratingColor.withAlpha(25),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ratingColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(ratingIcon, color: ratingColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating,
                  style: TextStyle(
                    fontSize: 12,
                    color: ratingColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${avgDailyGdu.toStringAsFixed(1)} GDU/day over 3 days',
                  style: TextStyle(
                    fontSize: 10,
                    color: ratingColor.withAlpha(200),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'GDU: Growing Degree Units (Base 10°C)\nCHU: Crop Heat Units for crop development',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Map<String, String> _getDayLabels() {
    return {
      'day1': 'Tomorrow',
      'day2': 'Day 2',
      'day3': 'Day 3',
    };
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Excellent':
        return Colors.green.shade700;
      case 'Good':
        return Colors.lightGreen.shade600;
      case 'Fair':
        return Colors.orange.shade600;
      case 'Poor':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildWeatherInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            color.withAlpha(25),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha(76),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}