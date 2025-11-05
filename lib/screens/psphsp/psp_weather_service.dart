import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_icons/weather_icons.dart';

import 'psp_weather_model.dart';

class PspWeatherService {
  // Cache duration in minutes
  final int _cacheDuration = 10;
  Position? _lastPosition;
  DateTime? _lastFetchTime;

  // Base temperatures for calculations
  final double _baseTemp = 10.0; // Base temperature for GDU (common for corn)
  final double _maxTemp = 30.0; // Maximum temperature cap for GDU

  // ============================================================================
  // HTTP CLIENT CONFIGURATION
  // ============================================================================

  Future<http.Client> getHttpClient() async {
    final HttpClient client = HttpClient()
      ..badCertificateCallback =
      ((X509Certificate cert, String host, int port) => true);
    return IOClient(client);
  }

  // ============================================================================
  // AGRICULTURAL CALCULATIONS
  // ============================================================================

  /// Calculate Growing Degree Units (GDU)
  /// Formula: Average Temperature - Base Temperature (10°C)
  double calculateGDU(double maxTemp, double minTemp) {
    // Cap temperatures to appropriate ranges
    double cappedMax = min(maxTemp, _maxTemp);
    double cappedMin = max(minTemp, _baseTemp);

    // Calculate average temperature from capped values
    double avgTemp = (cappedMax + cappedMin) / 2;

    // Calculate GDU: Average Temperature - Base Temperature
    double gdu = avgTemp - _baseTemp;

    // Ensure GDU is not negative
    return max(gdu, 0.0);
  }

  /// Calculate Crop Heat Units (CHU)
  /// Formula: [1.8(Tmax - 10) + 3.33(Tmin - 4.4)] / 2
  double calculateCHU(double maxTemp, double minTemp) {
    double yMax = 1.8 * (maxTemp - 10.0);
    double yMin = 3.33 * (minTemp - 4.4);

    // Ensure values are not negative
    yMax = max(yMax, 0.0);
    yMin = max(yMin, 0.0);

    double chu = (yMax + yMin) / 2;

    return max(chu, 0.0);
  }

  /// Calculate Growing Condition Rating based on multiple factors
  /// Returns: Excellent, Good, Fair, or Poor
  String calculateGrowingCondition(
      double gdu, double chu, int humidity, double temp) {
    int score = 0;

    // GDU scoring (0-3 points)
    if (gdu >= 15) {
      score += 3;
    } else if (gdu >= 10) {
      score += 2;
    } else if (gdu >= 5) {
      score += 1;
    }

    // Humidity scoring (0-2 points) - optimal range 40-70%
    if (humidity >= 40 && humidity <= 70) {
      score += 2;
    } else if (humidity >= 30 && humidity <= 80) {
      score += 1;
    }

    // Temperature scoring (0-2 points) - optimal range 18-28°C
    if (temp >= 18 && temp <= 28) {
      score += 2;
    } else if (temp >= 15 && temp <= 32) {
      score += 1;
    }

    // Return rating based on total score (0-7)
    if (score >= 6) return 'Excellent';
    if (score >= 4) return 'Good';
    if (score >= 2) return 'Fair';
    return 'Poor';
  }

  /// Check for agricultural alerts (frost risk or heat stress)
  String? checkAgriculturalAlert(double minTemp, double maxTemp) {
    if (minTemp <= 0) {
      return 'Frost Risk';
    } else if (maxTemp >= 35) {
      return 'Heat Stress';
    }
    return null;
  }

  // ============================================================================
  // CACHE MANAGEMENT
  // ============================================================================

  Future<PspWeatherData> loadCachedPspWeatherData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('weather_cache');

      if (cachedData != null) {
        final data = json.decode(cachedData);
        final lastFetchTimeStr = data['lastFetchTime'];

        if (lastFetchTimeStr != null) {
          final lastFetchTime = DateTime.parse(lastFetchTimeStr);
          final now = DateTime.now();
          final difference = now.difference(lastFetchTime).inMinutes;

          if (difference < _cacheDuration) {
            return PspWeatherData.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached weather data: $e');
    }

    return PspWeatherData();
  }

  Future<ForecastData> loadCachedForecastData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedForecast = prefs.getString('forecast_cache');

      if (cachedForecast != null) {
        final forecastData = json.decode(cachedForecast);
        final lastFetchTimeStr = forecastData['lastFetchTime'];

        if (lastFetchTimeStr != null) {
          final lastFetchTime = DateTime.parse(lastFetchTimeStr);
          final now = DateTime.now();
          final difference = now.difference(lastFetchTime).inMinutes;

          if (difference < _cacheDuration) {
            return ForecastData.fromJson(forecastData);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cached forecast data: $e');
    }

    return ForecastData.empty();
  }

  Future<void> saveWeatherToCache(PspWeatherData pspWeatherData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataToCache = pspWeatherData.toJson();
      await prefs.setString('weather_cache', json.encode(dataToCache));
    } catch (e) {
      debugPrint('Error saving weather data to cache: $e');
    }
  }

  Future<void> saveForecastToCache(ForecastData forecastData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final forecastToCache = forecastData.toJson();
      await prefs.setString('forecast_cache', json.encode(forecastToCache));
    } catch (e) {
      debugPrint('Error saving forecast data to cache: $e');
    }
  }

  // ============================================================================
  // LOCATION SERVICES
  // ============================================================================

  Future<Position> getCurrentPosition() async {
    final now = DateTime.now();

    // Use cached position if less than 30 minutes old
    if (_lastPosition != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 30) {
      return _lastPosition!;
    }

    _lastPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    _lastFetchTime = now;
    return _lastPosition!;
  }

  bool hasPositionChangedSignificantly(Position newPosition) {
    if (_lastPosition == null) return true;

    // Check if position has changed by more than 1km
    final distanceInMeters = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    return distanceInMeters > 1000;
  }

  Future<String> getLocationName(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> addressParts = [];

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        } else if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty) {
          addressParts.add(place.subAdministrativeArea!);
        }

        if (addressParts.isEmpty &&
            place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }

        String locationName = addressParts.join(', ');

        if (locationName.isEmpty) {
          locationName =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }

        return locationName;
      }
    } catch (e) {
      debugPrint('Error fetching location name with geocoding: $e');
    }

    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  // ============================================================================
  // WEATHER DATA FETCHING
  // ============================================================================

  Future<PspWeatherData> fetchCurrentWeather(
      Position position, String locationName) async {
    http.Client client = await getHttpClient();

    try {
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,wind_direction_10m,uv_index&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto';
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract current weather data
        final temp = data['current']['temperature_2m'];
        final humidity = data['current']['relative_humidity_2m'];
        final feelsLike = data['current']['apparent_temperature'];
        final uvIndex = data['current']['uv_index'] ?? 0.0;
        final weatherCode = data['current']['weather_code'];
        final isDay = data['current']['is_day'] == 1;
        final windSpeed = data['current']['wind_speed_10m'];
        final windDirection = data['current']['wind_direction_10m'];

        // Get today's max and min for GDU/CHU calculation
        final maxTemp = data['daily']['temperature_2m_max'][0];
        final minTemp = data['daily']['temperature_2m_min'][0];

        // Calculate agricultural metrics
        final gdu = calculateGDU(maxTemp.toDouble(), minTemp.toDouble());
        final chu = calculateCHU(maxTemp.toDouble(), minTemp.toDouble());
        final growingCondition = calculateGrowingCondition(
          gdu,
          chu,
          humidity,
          temp.toDouble(),
        );
        final alert =
        checkAgriculturalAlert(minTemp.toDouble(), maxTemp.toDouble());

        // Get weather info (icon, color, condition)
        final weatherInfo = getWeatherInfo(weatherCode, isDay);

        final pspWeatherData = PspWeatherData(
          temperature: '${temp.round()}°C',
          weatherCondition: weatherInfo['condition'] as String,
          weatherIcon: weatherInfo['icon'] as IconData,
          iconColor: weatherInfo['color'] as Color,
          windSpeed: '$windSpeed km/h',
          windDirection: getWindDirectionText(windDirection.toDouble()),
          isDay: isDay,
          locationName: locationName,
          lastFetchTime: DateTime.now(),
          weatherCode: weatherCode,
          gdu: gdu,
          chu: chu,
          humidity: humidity,
          uvIndex: uvIndex.toDouble(),
          feelsLike: '${feelsLike.round()}°C',
          growingCondition: growingCondition,
          alert: alert,
        );

        await saveWeatherToCache(pspWeatherData);
        return pspWeatherData;
      } else {
        throw Exception('Failed to load current weather data');
      }
    } finally {
      client.close();
    }
  }

  Future<ForecastData> fetchForecast(Position position) async {
    http.Client client = await getHttpClient();

    try {
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_sum&forecast_days=8&timezone=auto';

      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final forecastData = processForecastData(data);
        await saveForecastToCache(forecastData);
        return forecastData;
      } else {
        debugPrint(
            "Forecast API error: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load forecast data: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching forecast: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    } finally {
      client.close();
    }
  }

  // ============================================================================
  // DATA PROCESSING
  // ============================================================================

  ForecastData processForecastData(Map<String, dynamic> data) {
    try {
      final dailyDates = List<String>.from(data['daily']['time']);
      final dailyMaxTemps =
      List<double>.from(data['daily']['temperature_2m_max']);
      final dailyMinTemps =
      List<double>.from(data['daily']['temperature_2m_min']);
      final dailyWeatherCodes = List<int>.from(data['daily']['weather_code']);
      final dailyPrecipitation = data['daily']['precipitation_sum'] != null
          ? List<double>.from(data['daily']['precipitation_sum'])
          : List<double>.filled(dailyDates.length, 0.0);

      // Date formatter
      DateFormat formatter;
      try {
        formatter = DateFormat('EEEE, d MMMM yyyy', 'en_US');
      } catch (e) {
        formatter = DateFormat('yyyy-MM-dd');
      }

      Map<String, ForecastPeriod> dailyForecasts = {};
      final dayLabels = ['day1', 'day2', 'day3'];

      double totalGdu = 0.0;
      double totalChu = 0.0;

      int dayIndex = 0;
      for (int i = 0; i < dailyDates.length && dayIndex < dayLabels.length; i++) {
        final date = DateTime.parse(dailyDates[i]);

        // Skip today
        if (i == 0 && _isSameDay(date, DateTime.now())) {
          continue;
        }

        String formattedDate;
        try {
          formattedDate = formatter.format(date);
        } catch (e) {
          formattedDate = dailyDates[i];
        }

        final dayLabel = dayLabels[dayIndex];
        final maxTemp = dailyMaxTemps[i];
        final minTemp = dailyMinTemps[i];
        final tempRange = "${minTemp.round()} → ${maxTemp.round()}";
        final weatherCode = dailyWeatherCodes[i];
        final precipitation = dailyPrecipitation[i];

        // Calculate GDU and CHU for this day
        final gdu = calculateGDU(maxTemp, minTemp);
        final chu = calculateCHU(maxTemp, minTemp);

        totalGdu += gdu;
        totalChu += chu;

        final roundedPrecipitation = (precipitation * 10).round() / 10;
        final weatherInfo = getWeatherInfo(weatherCode, true);

        dailyForecasts[dayLabel] = ForecastPeriod(
          temp: '${((maxTemp + minTemp) / 2).round()}°C',
          tempRange: '$tempRange°C',
          condition: weatherInfo['condition'] as String,
          icon: weatherInfo['icon'] as IconData,
          color: weatherInfo['color'] as Color,
          rainAmount: roundedPrecipitation,
          date: formattedDate,
          gdu: gdu,
          chu: chu,
          maxTemp: maxTemp,
          minTemp: minTemp,
        );

        dayIndex++;
      }

      return ForecastData(
        dailyForecasts: dailyForecasts,
        lastFetchTime: DateTime.now(),
        forecastTitle: 'Heat Unit Accumulation',
        totalGdu: totalGdu,
        totalChu: totalChu,
      );
    } catch (e, stackTrace) {
      debugPrint('Error processing forecast data: $e');
      debugPrint('Stack trace: $stackTrace');
      return ForecastData.empty();
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // ============================================================================
  // WEATHER CONDITION MAPPING
  // ============================================================================

  Map<String, dynamic> getWeatherInfo(int weatherCode, bool isDay) {
    IconData icon;
    String condition;
    Color color;

    switch (weatherCode) {
      case 0:
        condition = isDay ? 'Clear' : 'Clear Night';
        icon = isDay ? WeatherIcons.day_sunny : WeatherIcons.night_clear;
        color = isDay ? Colors.amber : Colors.indigo.shade300;
        break;

      case 1:
        condition = isDay ? 'Mainly Clear' : 'Mainly Clear Night';
        icon = isDay
            ? WeatherIcons.day_sunny_overcast
            : WeatherIcons.night_partly_cloudy;
        color = isDay ? Colors.amber.shade600 : Colors.indigo.shade300;
        break;

      case 2:
        condition = 'Partly Cloudy';
        icon = isDay
            ? WeatherIcons.day_cloudy
            : WeatherIcons.night_alt_partly_cloudy;
        color = isDay ? Colors.amber.shade700 : Colors.blueGrey.shade400;
        break;

      case 3:
        condition = 'Cloudy';
        icon = WeatherIcons.cloudy;
        color = Colors.grey.shade600;
        break;

      case 45:
      case 48:
        condition = 'Foggy';
        icon = isDay ? WeatherIcons.day_fog : WeatherIcons.night_fog;
        color = Colors.blueGrey.shade300;
        break;

      case 51:
        condition = 'Light Drizzle';
        icon =
        isDay ? WeatherIcons.day_sprinkle : WeatherIcons.night_alt_sprinkle;
        color = Colors.blue.shade300;
        break;

      case 53:
        condition = 'Moderate Drizzle';
        icon = WeatherIcons.sprinkle;
        color = Colors.blue.shade400;
        break;

      case 55:
        condition = 'Dense Drizzle';
        icon = WeatherIcons.raindrops;
        color = Colors.blue.shade500;
        break;

      case 56:
      case 57:
        condition = 'Freezing Drizzle';
        icon = WeatherIcons.sleet;
        color = Colors.lightBlue.shade200;
        break;

      case 61:
        condition = 'Light Rain';
        icon = isDay ? WeatherIcons.day_rain : WeatherIcons.night_alt_rain;
        color = Colors.blue.shade600;
        break;

      case 63:
        condition = 'Moderate Rain';
        icon = WeatherIcons.rain;
        color = Colors.blue.shade700;
        break;

      case 65:
        condition = 'Heavy Rain';
        icon = WeatherIcons.rain_wind;
        color = Colors.blue.shade800;
        break;

      case 66:
      case 67:
        condition = 'Freezing Rain';
        icon = WeatherIcons.rain_mix;
        color = Colors.lightBlue.shade200;
        break;

      case 71:
      case 73:
      case 75:
      case 77:
        condition = 'Snow';
        icon = isDay ? WeatherIcons.day_snow : WeatherIcons.night_alt_snow;
        color = Colors.lightBlue.shade100;
        break;

      case 80:
      case 81:
      case 82:
        condition = 'Rain Showers';
        icon = isDay ? WeatherIcons.day_showers : WeatherIcons.night_alt_showers;
        color = Colors.blue.shade500;
        break;

      case 85:
      case 86:
        condition = 'Snow Showers';
        icon = isDay ? WeatherIcons.day_snow : WeatherIcons.night_alt_snow;
        color = Colors.lightBlue.shade100;
        break;

      case 95:
        condition = 'Thunderstorm';
        icon = isDay
            ? WeatherIcons.day_thunderstorm
            : WeatherIcons.night_alt_thunderstorm;
        color = Colors.deepPurple.shade300;
        break;

      case 96:
      case 99:
        condition = 'Thunderstorm with Hail';
        icon = isDay
            ? WeatherIcons.day_storm_showers
            : WeatherIcons.night_alt_storm_showers;
        color = Colors.deepPurple.shade400;
        break;

      default:
        condition = 'Unknown';
        icon = WeatherIcons.na;
        color = Colors.grey;
    }

    return {
      'condition': condition,
      'icon': icon,
      'color': color,
    };
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  String getWindDirectionText(double degrees) {
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW'
    ];
    int index = ((degrees + 11.25) % 360 / 22.5).floor();
    return directions[index];
  }

  String formatLastUpdateTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}