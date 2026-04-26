// lib/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefKey = 'theme_preference';

// Menggunakan NotifierProvider standar Riverpod 2.0+
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Memuat preferensi tema di latar belakang tanpa memblokir UI
    _loadTheme();
    return ThemeMode.light; // Nilai default awal (High Readability)
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefKey);

    if (savedTheme == 'light') {
      state = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, mode.name);
  }

  Future<void> switchTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await toggleTheme(newMode);
  }
}