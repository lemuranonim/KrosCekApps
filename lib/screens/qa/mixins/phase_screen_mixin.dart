import 'package:flutter/material.dart';
import '../../services/config_manager.dart';
import '../../services/google_sheets_api.dart';

/// Mixin untuk memastikan ConfigManager terinisialisasi di semua phase screen
mixin PhaseScreenInitializationMixin<T extends StatefulWidget> on State<T> {
  late GoogleSheetsApi googleSheetsApi;
  bool isInitializing = true;
  String? initializationError;

  String get spreadsheetIdFromWidget;
  String? get regionFromWidget;

  /// Method yang HARUS dipanggil dari initState screen
  Future<void> initializePhaseScreen() async {
    setState(() {
      isInitializing = true;
      initializationError = null;
    });

    try {
      debugPrint("\n🔄 Initializing Phase Screen...");
      debugPrint("   Region: $regionFromWidget");
      debugPrint("   Spreadsheet ID from widget: $spreadsheetIdFromWidget");

      // ✅ STEP 1: Ensure ConfigManager is loaded
      if (ConfigManager.regions.isEmpty) {
        debugPrint("⚠️ ConfigManager belum terinisialisasi, loading now...");
        await ConfigManager.loadConfig().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Timeout loading ConfigManager');
          },
        );
        debugPrint("✅ ConfigManager loaded successfully");
      } else {
        debugPrint("✅ ConfigManager already initialized");
        debugPrint("   Available regions: ${ConfigManager.regions.keys.join(', ')}");
      }

      // ✅ STEP 2: Get spreadsheet ID
      String? spreadsheetId = spreadsheetIdFromWidget.isNotEmpty
          ? spreadsheetIdFromWidget
          : null;

      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        debugPrint("⚠️ Spreadsheet ID from widget is empty, getting from ConfigManager...");
        spreadsheetId = ConfigManager.getSpreadsheetId(regionFromWidget ?? "Default Region");

        if (spreadsheetId == null || spreadsheetId.isEmpty) {
          throw Exception(
              "Spreadsheet ID tidak ditemukan untuk region '$regionFromWidget'\n"
                  "Available regions: ${ConfigManager.regions.keys.join(', ')}"
          );
        }
      }

      debugPrint("✅ Using Spreadsheet ID: $spreadsheetId");

      // ✅ STEP 3: Initialize GoogleSheetsApi
      googleSheetsApi = GoogleSheetsApi(spreadsheetId);

      setState(() {
        isInitializing = false;
      });

      debugPrint("🎉 Phase Screen initialization completed successfully!\n");

    } catch (e, stackTrace) {
      debugPrint("❌ Error initializing Phase Screen: $e");
      debugPrint("Stack trace: $stackTrace");

      setState(() {
        isInitializing = false;
        initializationError = e.toString();
      });
    }
  }

  /// Widget untuk menampilkan loading state
  Widget buildInitializingWidget() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade700,
              Colors.green.shade800,
              Colors.green.shade900,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Memuat data...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mohon tunggu sebentar',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget untuk menampilkan error state
  Widget buildErrorWidget() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade700,
              Colors.red.shade800,
              Colors.red.shade900,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  'Gagal Memuat Data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    initializationError ?? 'Unknown error',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        initializePhaseScreen();
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade700,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: Icon(Icons.arrow_back),
                      label: Text('Kembali'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}