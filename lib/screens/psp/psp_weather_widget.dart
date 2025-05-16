import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

class PspWeatherWidget extends StatefulWidget {
  final String greeting;

  const PspWeatherWidget({
    super.key,
    required this.greeting,
  });

  @override
  State<PspWeatherWidget> createState() => _PspWeatherWidgetState();
}

class _PspWeatherWidgetState extends State<PspWeatherWidget> {
  String _temperature = '--';
  String _weatherCondition = 'Loading...';
  String _windSpeed = '--';
  String _windDirection = '--';
  IconData _weatherIcon = WeatherIcons.day_sunny;
  Color _iconColor = Colors.amber;
  Timer? _timer;
  bool _isLoading = true;
  String _errorMessage = '';
  String _locationName = '';
  bool _isDay = true;
  DateTime? _lastFetchTime;
  Position? _lastPosition;

  // Cache duration in minutes
  final int _cacheDuration = 10;

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
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('weather_cache');

      if (cachedData != null) {
        final data = json.decode(cachedData);
        final lastFetchTimeStr = data['lastFetchTime'];

        if (lastFetchTimeStr != null) {
          _lastFetchTime = DateTime.parse(lastFetchTimeStr);
          final now = DateTime.now();
          final difference = now.difference(_lastFetchTime!).inMinutes;

          // If cache is still valid, use it
          if (difference < _cacheDuration) {
            setState(() {
              _temperature = data['temperature'] ?? '--';
              _weatherCondition = data['weatherCondition'] ?? 'Loading...';
              _windSpeed = data['windSpeed'] ?? '--';
              _windDirection = data['windDirection'] ?? '--';
              _locationName = data['locationName'] ?? '';
              _isDay = data['isDay'] ?? true;
              _updateWeatherInfo(data['weatherCode'] ?? 0);
              _isLoading = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      // If there's an error loading cache, continue to fetch fresh data
      debugPrint('Error loading cached weather data: $e');
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> weatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataToCache = {
        'temperature': _temperature,
        'weatherCondition': _weatherCondition,
        'windSpeed': _windSpeed,
        'windDirection': _windDirection,
        'locationName': _locationName,
        'isDay': _isDay,
        'weatherCode': weatherData['current']['weather_code'],
        'lastFetchTime': DateTime.now().toIso8601String(),
      };

      await prefs.setString('weather_cache', json.encode(dataToCache));
    } catch (e) {
      debugPrint('Error saving weather data to cache: $e');
    }
  }

  Future<http.Client> getHttpClient() async {
    final HttpClient client = HttpClient()
      ..badCertificateCallback =
      ((X509Certificate cert, String host, int port) => true);
    return IOClient(client);
  }

  Future<void> _fetchWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    http.Client? client;

    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
        if (status.isDenied) {
          throw Exception('Location permission denied');
        }
      }

      // Check if we need to get a new position or can use the cached one
      Position position;
      final now = DateTime.now();

      if (_lastPosition != null && _lastFetchTime != null &&
          now.difference(_lastFetchTime!).inMinutes < 30) {
        // Use cached position if it's less than 30 minutes old
        position = _lastPosition!;
      } else {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        _lastPosition = position;
        _lastFetchTime = now;
      }

      // Only fetch location name if it's empty or position has changed significantly
      if (_locationName.isEmpty || _hasPositionChangedSignificantly(position)) {
        await _fetchLocationNameWithGeocoding(position);
      }

      client = await getHttpClient();

      // Fetch weather data
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m&timezone=auto';
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current']['temperature_2m'];
        final weatherCode = data['current']['weather_code'];
        final isDay = data['current']['is_day'] == 1;
        final windSpeed = data['current']['wind_speed_10m'];
        final windDirection = data['current']['wind_direction_10m'];

        setState(() {
          _temperature = '${temp.round()}°C';
          _isDay = isDay;
          _windSpeed = '$windSpeed km/h';
          _windDirection = _getWindDirectionText(windDirection.toDouble());
          _updateWeatherInfo(weatherCode);
          _isLoading = false;
        });

        // Save to cache
        await _saveToCache(data);
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    } finally {
      client?.close();
    }
  }

  bool _hasPositionChangedSignificantly(Position newPosition) {
    if (_lastPosition == null) return true;

    // Check if position has changed by more than 1km
    final distanceInMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude
    );

    return distanceInMeters > 1000;
  }

  Future<void> _fetchLocationNameWithGeocoding(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          // Format the address based on available components
          List<String> addressParts = [];

          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            addressParts.add(place.subLocality!);
          } else if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }

          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          }

          if (addressParts.isEmpty && place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }

          _locationName = addressParts.join(', ');

          // If we still don't have a location name, use coordinates
          if (_locationName.isEmpty) {
            _locationName = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching location name with geocoding: $e');
      // Don't throw here, just log the error and continue
    }
  }

  String _getWindDirectionText(double degrees) {
    const directions = [
      'U',
      'UTL',
      'TL',
      'TTL',
      'T',
      'TTG',
      'TG',
      'UTG',
      'S',
      'SBD',
      'BD',
      'BBD',
      'B',
      'BBL',
      'BL',
      'SBL'
    ];
    int index = ((degrees + 11.25) % 360 / 22.5).floor();
    return directions[index];
  }

  void _updateWeatherInfo(int weatherCode) {
    bool isNight = !_isDay || widget.greeting == 'Sugêng Ndalu!';

    switch (weatherCode) {
      case 0:
        _weatherCondition = isNight ? 'Cerah Malam' : 'Cerah';
        _weatherIcon =
        isNight ? WeatherIcons.night_clear : WeatherIcons.day_sunny;
        _iconColor = isNight ? Colors.indigo.shade300 : Colors.amber;
        break;

      case 1:
        _weatherCondition = isNight ? 'Sebagian Cerah Malam' : 'Sebagian Cerah';
        _weatherIcon = isNight
            ? WeatherIcons.night_partly_cloudy
            : WeatherIcons.day_sunny_overcast;
        _iconColor = isNight ? Colors.indigo.shade300 : Colors.amber.shade600;
        break;

      case 2:
        _weatherCondition = 'Berawan Sebagian';
        _weatherIcon = isNight
            ? WeatherIcons.night_alt_partly_cloudy
            : WeatherIcons.day_cloudy;
        _iconColor = isNight ? Colors.blueGrey.shade400 : Colors.amber.shade700;
        break;

      case 3:
        _weatherCondition = 'Berawan';
        _weatherIcon = WeatherIcons.cloudy;
        _iconColor = Colors.grey.shade600;
        break;

      case 45:
      case 48:
        _weatherCondition = 'Berkabut';
        _weatherIcon = isNight ? WeatherIcons.night_fog : WeatherIcons.day_fog;
        _iconColor = Colors.blueGrey.shade300;
        break;

      case 51:
        _weatherCondition = 'Gerimis Ringan';
        _weatherIcon = isNight
            ? WeatherIcons.night_alt_sprinkle
            : WeatherIcons.day_sprinkle;
        _iconColor = Colors.blue.shade300;
        break;

      case 53:
        _weatherCondition = 'Gerimis Sedang';
        _weatherIcon = WeatherIcons.sprinkle;
        _iconColor = Colors.blue.shade400;
        break;

      case 55:
        _weatherCondition = 'Gerimis Lebat';
        _weatherIcon = WeatherIcons.raindrops;
        _iconColor = Colors.blue.shade500;
        break;

      case 56:
      case 57:
        _weatherCondition = 'Gerimis Beku';
        _weatherIcon = WeatherIcons.sleet;
        _iconColor = Colors.lightBlue.shade200;
        break;

      case 61:
        _weatherCondition = 'Hujan Ringan';
        _weatherIcon =
        isNight ? WeatherIcons.night_alt_rain : WeatherIcons.day_rain;
        _iconColor = Colors.blue.shade600;
        break;

      case 63:
        _weatherCondition = 'Hujan Sedang';
        _weatherIcon = WeatherIcons.rain;
        _iconColor = Colors.blue.shade700;
        break;

      case 65:
        _weatherCondition = 'Hujan Lebat';
        _weatherIcon = WeatherIcons.rain_wind;
        _iconColor = Colors.blue.shade800;
        break;

      case 66:
      case 67:
        _weatherCondition = 'Hujan Beku';
        _weatherIcon = WeatherIcons.rain_mix;
        _iconColor = Colors.lightBlue.shade200;
        break;

      case 71:
      case 73:
      case 75:
      case 77:
        _weatherCondition = 'Bersalju';
        _weatherIcon =
        isNight ? WeatherIcons.night_alt_snow : WeatherIcons.day_snow;
        _iconColor = Colors.lightBlue.shade100;
        break;

      case 80:
      case 81:
      case 82:
        _weatherCondition = 'Hujan Lokal';
        _weatherIcon =
        isNight ? WeatherIcons.night_alt_showers : WeatherIcons.day_showers;
        _iconColor = Colors.blue.shade500;
        break;

      case 85:
      case 86:
        _weatherCondition = 'Salju Lokal';
        _weatherIcon =
        isNight ? WeatherIcons.night_alt_snow : WeatherIcons.day_snow;
        _iconColor = Colors.lightBlue.shade100;
        break;

      case 95:
        _weatherCondition = 'Badai Petir';
        _weatherIcon = isNight
            ? WeatherIcons.night_alt_thunderstorm
            : WeatherIcons.day_thunderstorm;
        _iconColor = Colors.deepPurple.shade300;
        break;

      case 96:
      case 99:
        _weatherCondition = 'Badai Petir & Hujan Es';
        _weatherIcon = isNight
            ? WeatherIcons.night_alt_storm_showers
            : WeatherIcons.day_storm_showers;
        _iconColor = Colors.deepPurple.shade400;
        break;

      default:
        _weatherCondition = 'Tidak Diketahui';
        _weatherIcon = WeatherIcons.na;
        _iconColor = Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade50,
            Colors.red.shade100,
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
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.redAccent.shade700),
          ),
        ),
      )
          : _errorMessage.isNotEmpty
          ? Center(
        child: Text(
          _errorMessage,
          style: TextStyle(color: Colors.redAccent[400], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location display at the top
          if (_locationName.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha(15),
                    blurRadius: 4,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.redAccent.shade700,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _locationName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuaca Saat Ini',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.redAccent.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _temperature,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _weatherCondition,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(25),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: BoxedIcon(
                  _weatherIcon,
                  color: _iconColor,
                  size: 32,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(15),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BoxedIcon(
                      WeatherIcons.strong_wind,
                      size: 16,
                      color: Colors.redAccent.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _windSpeed,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withAlpha(15),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BoxedIcon(
                      WeatherIcons.wind_direction,
                      size: 16,
                      color: Colors.redAccent.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _windDirection,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _lastFetchTime != null
                  ? 'Diperbarui: ${_formatLastUpdateTime(_lastFetchTime!)}'
                  : 'Pembaruan setiap 15 menit',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.green.shade700.withAlpha(178),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return '${difference.inDays} hari yang lalu';
    }
  }
}