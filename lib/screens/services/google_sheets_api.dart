import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

class GoogleSheetsApi {
  final String spreadsheetId;

  late GSheets _gSheets;
  late Spreadsheet _spreadsheet;
  List<List<String>>? lastFetchedData;
  bool isInitialized = false;

  GoogleSheetsApi(this.spreadsheetId);

  Future<bool> init() async {
    if (isInitialized) {
      debugPrint("[GoogleSheetsApi] ✅ Sudah diinisialisasi sebelumnya");
      return true;
    }

    try {
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("[GoogleSheetsApi] 🔄 MEMULAI INISIALISASI");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("[GoogleSheetsApi] 📋 Spreadsheet ID: $spreadsheetId");

      // STEP 1: Load credentials.json
      debugPrint("\n[GoogleSheetsApi] [STEP 1] Memuat credentials.json...");
      String credentials;
      try {
        credentials = await rootBundle.loadString('assets/credentials.json');
        debugPrint("[GoogleSheetsApi] ✅ File credentials.json berhasil dimuat");
        debugPrint("[GoogleSheetsApi]    Ukuran: ${credentials.length} karakter");
      } catch (e) {
        debugPrint("[GoogleSheetsApi] ❌ GAGAL: File tidak ditemukan!");
        debugPrint("[GoogleSheetsApi]    Error: $e");
        return false;
      }

      if (credentials.isEmpty) {
        debugPrint("[GoogleSheetsApi] ❌ GAGAL: credentials.json kosong!");
        return false;
      }

      // STEP 2: Parse JSON
      debugPrint("\n[GoogleSheetsApi] [STEP 2] Parsing JSON...");
      Map<String, dynamic> jsonCredentials;
      try {
        jsonCredentials = jsonDecode(credentials);
        debugPrint("[GoogleSheetsApi] ✅ JSON berhasil di-parse");
      } catch (e) {
        debugPrint("[GoogleSheetsApi] ❌ GAGAL: Format JSON tidak valid!");
        debugPrint("[GoogleSheetsApi]    Error: $e");
        return false;
      }

      // STEP 3: Validasi struktur
      debugPrint("\n[GoogleSheetsApi] [STEP 3] Validasi struktur...");
      final requiredKeys = ['type', 'project_id', 'private_key', 'client_email'];
      final missingKeys = requiredKeys.where((key) => !jsonCredentials.containsKey(key)).toList();

      if (missingKeys.isNotEmpty) {
        debugPrint("[GoogleSheetsApi] ❌ GAGAL: Field hilang: $missingKeys");
        return false;
      }

      debugPrint("[GoogleSheetsApi] ✅ Struktur JSON valid");
      debugPrint("[GoogleSheetsApi]    Service Account: ${jsonCredentials['client_email']}");

      // STEP 4: Buat GSheets object
      debugPrint("\n[GoogleSheetsApi] [STEP 4] Membuat GSheets object...");
      try {
        _gSheets = GSheets(jsonCredentials);
        debugPrint("[GoogleSheetsApi] ✅ GSheets object berhasil dibuat");
      } catch (e) {
        debugPrint("[GoogleSheetsApi] ❌ GAGAL membuat GSheets object!");
        debugPrint("[GoogleSheetsApi]    Error: $e");
        return false;
      }

      // STEP 5: Koneksi ke Spreadsheet
      debugPrint("\n[GoogleSheetsApi] [STEP 5] Koneksi ke spreadsheet...");
      debugPrint("[GoogleSheetsApi]    Timeout: 20 detik");
      debugPrint("[GoogleSheetsApi]    ID: $spreadsheetId");

      try {
        _spreadsheet = await _gSheets.spreadsheet(spreadsheetId).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            debugPrint("[GoogleSheetsApi] ❌ TIMEOUT 20 detik!");
            throw Exception('Timeout: Tidak dapat terhubung ke Google Sheets');
          },
        );

        debugPrint("[GoogleSheetsApi] ✅ BERHASIL terhubung!");

        // Test akses worksheet
        try {
          final testSheet = _spreadsheet.worksheetByTitle('Vegetative');
          if (testSheet != null) {
            debugPrint("[GoogleSheetsApi]    ✅ Worksheet 'Vegetative' ditemukan");
          } else {
            debugPrint("[GoogleSheetsApi]    ⚠️  Worksheet 'Vegetative' tidak ditemukan");
          }
        } catch (e) {
          debugPrint("[GoogleSheetsApi]    ⚠️  Error saat test worksheet: $e");
        }

      } catch (e) {
        debugPrint("[GoogleSheetsApi] ❌ GAGAL koneksi ke spreadsheet!");
        debugPrint("[GoogleSheetsApi]    Error: $e");

        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('403') || errorStr.contains('forbidden')) {
          debugPrint("\n[GoogleSheetsApi] 💡 ERROR 403: PERMISSION DENIED");
          debugPrint("[GoogleSheetsApi] 📌 SOLUSI:");
          debugPrint("[GoogleSheetsApi]    1. Buka: https://docs.google.com/spreadsheets/d/$spreadsheetId");
          debugPrint("[GoogleSheetsApi]    2. Klik 'Share' (pojok kanan atas)");
          debugPrint("[GoogleSheetsApi]    3. Tambahkan email berikut dengan role 'Editor':");
          debugPrint("[GoogleSheetsApi]       ${jsonCredentials['client_email']}");
          debugPrint("[GoogleSheetsApi]    4. Klik 'Send'");
        } else if (errorStr.contains('404') || errorStr.contains('not found')) {
          debugPrint("\n[GoogleSheetsApi] 💡 ERROR 404: SPREADSHEET NOT FOUND");
          debugPrint("[GoogleSheetsApi]    Spreadsheet ID mungkin salah: $spreadsheetId");
        } else if (errorStr.contains('timeout')) {
          debugPrint("\n[GoogleSheetsApi] 💡 ERROR TIMEOUT");
          debugPrint("[GoogleSheetsApi]    Cek koneksi internet Anda");
        }

        return false;
      }

      isInitialized = true;
      debugPrint("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("[GoogleSheetsApi] 🎉 INISIALISASI BERHASIL!");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
      return true;

    } catch (e, stackTrace) {
      debugPrint("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("[GoogleSheetsApi] ❌ INISIALISASI GAGAL TOTAL!");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      debugPrint("[GoogleSheetsApi] Error: $e");
      debugPrint("[GoogleSheetsApi] Stack trace: $stackTrace");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
      isInitialized = false;
      return false;
    }
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      throw Exception(
          'GoogleSheetsApi belum diinisialisasi. Panggil init() terlebih dahulu.'
      );
    }
  }

  Spreadsheet get spreadsheet {
    _ensureInitialized();
    return _spreadsheet;
  }

  Future<List<List<String>>> getSpreadsheetData(String worksheetTitle) async {
    _ensureInitialized();

    debugPrint("[GoogleSheetsApi] 📥 Mengambil data dari: $worksheetTitle");
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      debugPrint("[GoogleSheetsApi] ❌ Worksheet '$worksheetTitle' tidak ditemukan!");
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    final rows = await sheet.values.allRows();
    debugPrint("[GoogleSheetsApi] ✅ Data diambil: ${rows.length} baris");
    lastFetchedData = rows;
    return rows;
  }

  Future<List<List<String>>> getSpreadsheetDataWithPagination(
      String worksheetTitle, int startRow, int limit) async {
    _ensureInitialized();

    debugPrint("[GoogleSheetsApi] 📥 Pagination: $worksheetTitle [row $startRow, limit $limit]");
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    final rows = await sheet.values.allRows(fromRow: startRow, length: limit);
    if (rows.isNotEmpty) {
      lastFetchedData = rows;
    }
    debugPrint("[GoogleSheetsApi] ✅ Data diambil: ${rows.length} baris");
    return rows;
  }

  Future<List<String>> fetchFIByRegion(String worksheetTitle, String region) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    final rows = await sheet.values.allRows();
    List<String> fiList = [];
    for (var row in rows) {
      if (row.isNotEmpty && row[0] == region) {
        fiList.add(row[1]);
      }
    }

    return fiList;
  }

  Future<void> appendRowToSheet(String worksheetTitle, List<String> rowData) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    await sheet.values.appendRow(rowData);
    debugPrint("[GoogleSheetsApi] Baris ditambahkan ke $worksheetTitle");
  }

  Future<void> addRow(String worksheetTitle, List<String> rowData) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    await sheet.values.appendRow(rowData);
    debugPrint("[GoogleSheetsApi] Baris berhasil ditambahkan");
  }

  Future<bool> checkRowExists(String worksheetTitle, String fieldNumber) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    final List<List<String>> rows = await sheet.values.allRows();
    for (final row in rows) {
      if (row.isNotEmpty && row[2] == fieldNumber) {
        return true;
      }
    }
    return false;
  }

  Future<void> updateRow(String worksheetTitle, List<String> rowData, String fieldNumber) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) throw Exception('Worksheet tidak ditemukan: $worksheetTitle');

    final int rowIndex = await _findRowByFieldNumber(sheet, fieldNumber);
    if (rowIndex == -1) throw Exception('Data tidak ditemukan untuk diperbarui.');

    final formattedRowData = rowData.map((value) {
      if (_isNumberWithCommas(value)) {
        return value;
      } else if (_isDate(value)) {
        final date = _parseDate(value);
        return DateFormat('dd/MM/yyyy').format(date);
      } else if (_isDecimal(value)) {
        return _formatDecimal(value);
      } else if (_isNumber(value)) {
        return _normalizeNumber(value);
      } else if (_containsRatio(value)) {
        return _normalizeRatio(value);
      } else {
        return _normalizeText(value);
      }
    }).toList();

    await sheet.values.insertRow(rowIndex, formattedRowData, fromColumn: 1);
    debugPrint("[GoogleSheetsApi] Baris diperbarui");
  }

  Future<void> batchUpdateRows(String worksheetTitle, List<List<String>> rowsData) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    for (final rowData in rowsData) {
      final String fieldNumber = rowData[2];
      final int rowIndex = await _findRowByFieldNumber(sheet, fieldNumber);

      if (rowIndex == -1) {
        debugPrint("[GoogleSheetsApi] Baris $fieldNumber tidak ditemukan");
        continue;
      }

      await sheet.values.insertRow(rowIndex, rowData);
    }
  }

  Future<void> updateSpecificCells(String worksheetTitle, int rowIndex, Map<int, String> updates) async {
    _ensureInitialized();

    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    for (var entry in updates.entries) {
      final int columnIndex = entry.key;
      final String value = entry.value;
      await sheet.values.insertValue(value, column: columnIndex, row: rowIndex);
    }
  }

  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber) async {
    final List<List<String>> rows = await sheet.values.allRows();
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) {
        return i + 1;
      }
    }
    return -1;
  }

  // Helper methods tetap sama
  bool _isDecimal(String value) {
    return RegExp(r'^\d{1,3}(\.\d{3})*(,\d+)?$').hasMatch(value) ||
        RegExp(r'^\d+([.,]\d+)?$').hasMatch(value);
  }

  String _formatDecimal(String value) {
    if (value.contains(',')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (value.contains('.')) {
      value = value.replaceAll(',', '').replaceAll(',', '.');
    }

    double? number = double.tryParse(value);
    if (number != null) {
      return number.toString();
    }
    return value;
  }

  String _normalizeText(String value) {
    return _normalizeSymbols(value)
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  String _normalizeSymbols(String value) {
    return value.trim();
  }

  bool _isNumber(String value) {
    final normalizedValue = value.replaceAll(',', '.');
    return double.tryParse(normalizedValue.replaceAll(',', '.')) != null;
  }

  String _normalizeNumber(String value) {
    final normalizedValue = value.replaceAll('.', '').replaceAll(',', '.');
    final doubleValue = double.tryParse(normalizedValue);

    if (doubleValue != null) {
      return doubleValue.toStringAsFixed(2).replaceAll(',', '.');
    }

    return value;
  }

  bool _isNumberWithCommas(String value) {
    return RegExp(r'^\d+(,\d+)*$').hasMatch(value);
  }

  bool _containsRatio(String value) {
    return value.contains(':');
  }

  String _normalizeRatio(String value) {
    final parts = value.split(':');
    if (parts.length == 2) {
      return '${parts[0].trim()}:${parts[1].trim()}';
    }
    return value;
  }

  bool _isDate(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  DateTime _parseDate(String value) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(value);
    } catch (e) {
      return DateTime.parse(value);
    }
  }

  /// Konversi angka desimal ke format Indonesia (koma sebagai desimal, titik sebagai ribuan)
  String formatDecimalForIndonesia(double value) {
    final formatter = NumberFormat("#,##0.00", "id_ID");
    return formatter.format(value);
  }

  /// Parsing nilai desimal dari teks ke angka (menerima format Indonesia)
  double parseDecimalFromIndonesia(String value) {
    final normalizedValue = value.replaceAll('.', '').replaceAll(',', '.');
    final double? parsedValue = double.tryParse(normalizedValue);
    if (parsedValue == null) {
      throw Exception("Nilai '$value' bukan angka valid dalam format Indonesia.");
    }
    return parsedValue;
  }

  /// Validasi apakah nilai dalam format desimal Indonesia
  bool isDecimalIndonesia(String value) {
    return RegExp(r'^\d{1,3}(\.\d{3})*(,\d+)?$').hasMatch(value);
  }
}