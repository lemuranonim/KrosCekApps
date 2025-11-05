import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

class PspWeatherData {
  final String temperature;
  final String weatherCondition;
  final String windSpeed;
  final String windDirection;
  final IconData weatherIcon;
  final Color iconColor;
  final bool isDay;
  final String locationName;
  final DateTime? lastFetchTime;
  final int weatherCode;
  final double gdu; // Growing Degree Units
  final double chu; // Crop Heat Units
  final int humidity; // Humidity percentage
  final double uvIndex; // UV Index
  final String feelsLike; // Feels like temperature
  final String growingCondition; // Growing condition rating
  final String? alert; // Agricultural alert (frost/heat stress)

  PspWeatherData({
    this.temperature = '--',
    this.weatherCondition = 'Loading...',
    this.windSpeed = '--',
    this.windDirection = '--',
    this.weatherIcon = WeatherIcons.day_sunny,
    this.iconColor = Colors.amber,
    this.isDay = true,
    this.locationName = '',
    this.lastFetchTime,
    this.weatherCode = 0,
    this.gdu = 0.0,
    this.chu = 0.0,
    this.humidity = 0,
    this.uvIndex = 0.0,
    this.feelsLike = '--',
    this.growingCondition = 'Fair',
    this.alert,
  });

  factory PspWeatherData.fromJson(Map<String, dynamic> json) {
    return PspWeatherData(
      temperature: json['temperature'] ?? '--',
      weatherCondition: json['weatherCondition'] ?? 'Loading...',
      windSpeed: json['windSpeed'] ?? '--',
      windDirection: json['windDirection'] ?? '--',
      weatherIcon: _parseIconData(json['icon'] ?? 'day_sunny'),
      iconColor: _parseColor(json['color'] ?? 'amber'),
      isDay: json['isDay'] ?? true,
      locationName: json['locationName'] ?? '',
      lastFetchTime: json['lastFetchTime'] != null
          ? DateTime.parse(json['lastFetchTime'])
          : null,
      weatherCode: json['weatherCode'] ?? 0,
      gdu: json['gdu']?.toDouble() ?? 0.0,
      chu: json['chu']?.toDouble() ?? 0.0,
      humidity: json['humidity'] ?? 0,
      uvIndex: json['uvIndex']?.toDouble() ?? 0.0,
      feelsLike: json['feelsLike'] ?? '--',
      growingCondition: json['growingCondition'] ?? 'Fair',
      alert: json['alert'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'weatherCondition': weatherCondition,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'icon': _getIconName(weatherIcon),
      'color': _getColorName(iconColor),
      'isDay': isDay,
      'locationName': locationName,
      'lastFetchTime': lastFetchTime?.toIso8601String(),
      'weatherCode': weatherCode,
      'gdu': gdu,
      'chu': chu,
      'humidity': humidity,
      'uvIndex': uvIndex,
      'feelsLike': feelsLike,
      'growingCondition': growingCondition,
      'alert': alert,
    };
  }

  static IconData _parseIconData(String iconName) {
    switch (iconName) {
      case 'day_sunny': return WeatherIcons.day_sunny;
      case 'night_clear': return WeatherIcons.night_clear;
      case 'day_cloudy': return WeatherIcons.day_cloudy;
      case 'night_alt_cloudy': return WeatherIcons.night_alt_cloudy;
      case 'rain': return WeatherIcons.rain;
      case 'day_rain': return WeatherIcons.day_rain;
      case 'night_alt_rain': return WeatherIcons.night_alt_rain;
      case 'thunderstorm': return WeatherIcons.thunderstorm;
      default: return WeatherIcons.day_sunny;
    }
  }

  static Color _parseColor(String colorName) {
    switch (colorName) {
      case 'amber': return Colors.amber;
      case 'indigo': return Colors.indigo.shade300;
      case 'blue': return Colors.blue.shade600;
      case 'grey': return Colors.grey.shade600;
      default: return Colors.amber;
    }
  }

  static String _getIconName(IconData icon) {
    if (icon == WeatherIcons.day_sunny) return 'day_sunny';
    if (icon == WeatherIcons.night_clear) return 'night_clear';
    if (icon == WeatherIcons.day_cloudy) return 'day_cloudy';
    if (icon == WeatherIcons.night_alt_cloudy) return 'night_alt_cloudy';
    if (icon == WeatherIcons.rain) return 'rain';
    if (icon == WeatherIcons.day_rain) return 'day_rain';
    if (icon == WeatherIcons.night_alt_rain) return 'night_alt_rain';
    if (icon == WeatherIcons.thunderstorm) return 'thunderstorm';
    return 'day_sunny';
  }

  static String _getColorName(Color color) {
    if (color == Colors.amber) return 'amber';
    if (color == Colors.indigo.shade300) return 'indigo';
    if (color == Colors.blue.shade600) return 'blue';
    if (color == Colors.grey.shade600) return 'grey';
    return 'amber';
  }
}

class ForecastPeriod {
  final String temp;
  final String tempRange;
  final String condition;
  final IconData icon;
  final Color color;
  final double rainAmount;
  final String date;
  final double gdu; // Growing Degree Units for the day
  final double chu; // Crop Heat Units for the day
  final double maxTemp; // For calculations
  final double minTemp; // For calculations

  ForecastPeriod({
    this.temp = '--',
    this.tempRange = '-- → --',
    this.condition = 'Loading...',
    this.icon = WeatherIcons.day_sunny,
    this.color = Colors.amber,
    this.rainAmount = 0.0,
    this.date = '',
    this.gdu = 0.0,
    this.chu = 0.0,
    this.maxTemp = 0.0,
    this.minTemp = 0.0,
  });

  factory ForecastPeriod.fromJson(Map<String, dynamic>? data) {
    if (data == null) {
      return ForecastPeriod();
    }
    return ForecastPeriod(
      temp: data['temp'] ?? '--',
      tempRange: data['tempRange'] ?? '-- → --',
      condition: data['condition'] ?? 'Loading...',
      icon: PspWeatherData._parseIconData(data['icon'] ?? 'day_sunny'),
      color: PspWeatherData._parseColor(data['color'] ?? 'amber'),
      rainAmount: data['rainAmount']?.toDouble() ?? 0.0,
      date: data['date'] ?? '',
      gdu: data['gdu']?.toDouble() ?? 0.0,
      chu: data['chu']?.toDouble() ?? 0.0,
      maxTemp: data['maxTemp']?.toDouble() ?? 0.0,
      minTemp: data['minTemp']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp': temp,
      'tempRange': tempRange,
      'condition': condition,
      'icon': PspWeatherData._getIconName(icon),
      'color': PspWeatherData._getColorName(color),
      'rainAmount': rainAmount,
      'date': date,
      'gdu': gdu,
      'chu': chu,
      'maxTemp': maxTemp,
      'minTemp': minTemp,
    };
  }
}

class ForecastData {
  final Map<String, ForecastPeriod> dailyForecasts;
  final DateTime? lastFetchTime;
  final String forecastTitle;
  final double totalGdu; // Accumulated GDU
  final double totalChu; // Accumulated CHU

  ForecastData({
    required this.dailyForecasts,
    this.lastFetchTime,
    this.forecastTitle = 'Weather Forecast',
    this.totalGdu = 0.0,
    this.totalChu = 0.0,
  });

  factory ForecastData.empty() {
    return ForecastData(
      dailyForecasts: {
        'day1': ForecastPeriod(),
        'day2': ForecastPeriod(),
        'day3': ForecastPeriod(),
      },
    );
  }

  factory ForecastData.fromJson(Map<String, dynamic> json) {
    Map<String, ForecastPeriod> dailyForecasts = {};

    if (json['dailyForecasts'] != null) {
      (json['dailyForecasts'] as Map<String, dynamic>).forEach((key, value) {
        dailyForecasts[key] = ForecastPeriod.fromJson(value);
      });
    } else {
      dailyForecasts = {
        'day1': ForecastPeriod(),
        'day2': ForecastPeriod(),
        'day3': ForecastPeriod(),
      };
    }

    return ForecastData(
      dailyForecasts: dailyForecasts,
      lastFetchTime: json['lastFetchTime'] != null
          ? DateTime.parse(json['lastFetchTime'])
          : null,
      forecastTitle: json['forecastTitle'] ?? 'Weather Forecast',
      totalGdu: json['totalGdu']?.toDouble() ?? 0.0,
      totalChu: json['totalChu']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyForecasts': dailyForecasts.map((key, value) => MapEntry(key, value.toJson())),
      'lastFetchTime': lastFetchTime?.toIso8601String(),
      'forecastTitle': forecastTitle,
      'totalGdu': totalGdu,
      'totalChu': totalChu,
    };
  }
}