import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  Future<http.Client> getHttpClient() async {
    final HttpClient client = HttpClient()
      ..badCertificateCallback =
      ((X509Certificate cert, String host, int port) => true);
    return IOClient(client);
  }

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

          // If cache is still valid, use it
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

  Future<Position> getCurrentPosition() async {
    final now = DateTime.now();

    if (_lastPosition != null && _lastFetchTime != null &&
        now.difference(_lastFetchTime!).inMinutes < 30) {
      // Use cached position if it's less than 30 minutes old
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
        newPosition.longitude
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

        String locationName = addressParts.join(', ');

        // If we still don't have a location name, use coordinates
        if (locationName.isEmpty) {
          locationName = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }

        return locationName;
      }
    } catch (e) {
      debugPrint('Error fetching location name with geocoding: $e');
    }

    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  Future<PspWeatherData> fetchCurrentWeather(Position position, String locationName) async {
    http.Client client = await getHttpClient();

    try {
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m&timezone=auto';
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current']['temperature_2m'];
        final weatherCode = data['current']['weather_code'];
        final isDay = data['current']['is_day'] == 1;
        final windSpeed = data['current']['wind_speed_10m'];
        final windDirection = data['current']['wind_direction_10m'];

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
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_sum&forecast_days=8&timezone=auto';

      // debugPrint("Fetching forecast from: $url");

      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // debugPrint("Forecast API response received");
        final data = json.decode(response.body);
        final forecastData = processForecastData(data);
        await saveForecastToCache(forecastData);
        return forecastData;
      } else {
        debugPrint("Forecast API error: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load forecast data: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching forecast: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;  // <-- menggunakan rethrow
    } finally {
      client.close();
    }
  }

  ForecastData processForecastData(Map<String, dynamic> data) {
    try {
      // debugPrint("Processing forecast data: ${json.encode(data)}");

      final dailyDates = List<String>.from(data['daily']['time']);
      final dailyMaxTemps = List<double>.from(data['daily']['temperature_2m_max']);
      final dailyMinTemps = List<double>.from(data['daily']['temperature_2m_min']);
      final dailyWeatherCodes = List<int>.from(data['daily']['weather_code']);
      final dailyPrecipitation = data['daily']['precipitation_sum'] != null
          ? List<double>.from(data['daily']['precipitation_sum'])
          : List<double>.filled(dailyDates.length, 0.0);

      // Format for display - gunakan format yang lebih sederhana jika locale belum diinisialisasi
      DateFormat formatter;
      try {
        formatter = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
      } catch (e) {
        // Fallback ke format sederhana jika locale belum diinisialisasi
        formatter = DateFormat('yyyy-MM-dd');
      }

      Map<String, ForecastPeriod> dailyForecasts = {};

      // Define day labels
      final dayLabels = ['besok', 'lusa', 'hari3'];

      // Process each day (starting from tomorrow)
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
          // Fallback jika format gagal
          formattedDate = dailyDates[i];
        }

        final dayLabel = dayLabels[dayIndex];
        final maxTemp = dailyMaxTemps[i].round();
        final minTemp = dailyMinTemps[i].round();
        final tempRange = "$minTemp → $maxTemp";
        final weatherCode = dailyWeatherCodes[i];
        final precipitation = dailyPrecipitation[i];

        // Round to one decimal place
        final roundedPrecipitation = (precipitation * 10).round() / 10;

        // Assume daytime for weather icon
        final weatherInfo = getWeatherInfo(weatherCode, true);

        dailyForecasts[dayLabel] = ForecastPeriod(
          temp: '${((maxTemp + minTemp) / 2).round()}°C',
          tempRange: '$tempRange°C',
          condition: weatherInfo['condition'] as String,
          icon: weatherInfo['icon'] as IconData,
          color: weatherInfo['color'] as Color,
          rainAmount: roundedPrecipitation,
          date: formattedDate,
        );

        dayIndex++;
      }

      // Debug log
      // debugPrint("Processed forecast data: ${dailyForecasts.length} days");
      dailyForecasts.forEach((key, value) {
        // debugPrint("$key: ${value.condition}, ${value.tempRange}, ${value.rainAmount}");
      });

      return ForecastData(
        dailyForecasts: dailyForecasts,
        lastFetchTime: DateTime.now(),
        forecastTitle: 'Perkiraan Cuaca 3 Hari',
      );
    } catch (e, stackTrace) {
      debugPrint('Error processing forecast data: $e');
      debugPrint('Stack trace: $stackTrace');
      return ForecastData.empty();
    }
  }

// Helper method to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Map<String, dynamic> getWeatherInfo(int weatherCode, bool isDay) {
    IconData icon;
    String condition;
    Color color;

    switch (weatherCode) {
      case 0:
        condition = isDay ? 'Cerah' : 'Cerah Malam';
        icon = isDay ? WeatherIcons.day_sunny : WeatherIcons.night_clear;
        color = isDay ? Colors.amber : Colors.indigo.shade300;
        break;

      case 1:
        condition = isDay ? 'Sebagian Cerah' : 'Sebagian Cerah Malam';
        icon = isDay ? WeatherIcons.day_sunny_overcast : WeatherIcons.night_partly_cloudy;
        color = isDay ? Colors.amber.shade600 : Colors.indigo.shade300;
        break;

      case 2:
        condition = 'Berawan Sebagian';
        icon = isDay ? WeatherIcons.day_cloudy : WeatherIcons.night_alt_partly_cloudy;
        color = isDay ? Colors.amber.shade700 : Colors.blueGrey.shade400;
        break;

      case 3:
        condition = 'Berawan';
        icon = WeatherIcons.cloudy;
        color = Colors.grey.shade600;
        break;

      case 45:
      case 48:
        condition = 'Berkabut';
        icon = isDay ? WeatherIcons.day_fog : WeatherIcons.night_fog;
        color = Colors.blueGrey.shade300;
        break;

      case 51:
        condition = 'Gerimis Ringan';
        icon = isDay ? WeatherIcons.day_sprinkle : WeatherIcons.night_alt_sprinkle;
        color = Colors.blue.shade300;
        break;

      case 53:
        condition = 'Gerimis Sedang';
        icon = WeatherIcons.sprinkle;
        color = Colors.blue.shade400;
        break;

      case 55:
        condition = 'Gerimis Lebat';
        icon = WeatherIcons.raindrops;
        color = Colors.blue.shade500;
        break;

      case 56:
      case 57:
        condition = 'Gerimis Beku';
        icon = WeatherIcons.sleet;
        color = Colors.lightBlue.shade200;
        break;

      case 61:
        condition = 'Hujan Ringan';
        icon = isDay ? WeatherIcons.day_rain : WeatherIcons.night_alt_rain;
        color = Colors.blue.shade600;
        break;

      case 63:
        condition = 'Hujan Sedang';
        icon = WeatherIcons.rain;
        color = Colors.blue.shade700;
        break;

      case 65:
        condition = 'Hujan Lebat';
        icon = WeatherIcons.rain_wind;
        color = Colors.blue.shade800;
        break;

      case 66:
      case 67:
        condition = 'Hujan Beku';
        icon = WeatherIcons.rain_mix;
        color = Colors.lightBlue.shade200;
        break;

      case 71:
      case 73:
      case 75:
      case 77:
        condition = 'Bersalju';
        icon = isDay ? WeatherIcons.day_snow : WeatherIcons.night_alt_snow;
        color = Colors.lightBlue.shade100;
        break;

      case 80:
      case 81:
      case 82:
        condition = 'Hujan Lokal';
        icon = isDay ? WeatherIcons.day_showers : WeatherIcons.night_alt_showers;
        color = Colors.blue.shade500;
        break;

      case 85:
      case 86:
        condition = 'Salju Lokal';
        icon = isDay ? WeatherIcons.day_snow : WeatherIcons.night_alt_snow;
        color = Colors.lightBlue.shade100;
        break;

      case 95:
        condition = 'Badai Petir';
        icon = isDay ? WeatherIcons.day_thunderstorm : WeatherIcons.night_alt_thunderstorm;
        color = Colors.deepPurple.shade300;
        break;

      case 96:
      case 99:
        condition = 'Badai Petir & Hujan Es';
        icon = isDay ? WeatherIcons.day_storm_showers : WeatherIcons.night_alt_storm_showers;
        color = Colors.deepPurple.shade400;
        break;

      default:
        condition = 'Tidak Diketahui';
        icon = WeatherIcons.na;
        color = Colors.grey;
    }

    return {
      'condition': condition,
      'icon': icon,
      'color': color,
    };
  }

  String getWindDirectionText(double degrees) {
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

  String formatLastUpdateTime(DateTime time) {
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