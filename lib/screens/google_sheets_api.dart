import 'dart:convert';
import 'package:flutter/foundation.dart';  // Ini diperlukan untuk memeriksa mode debug
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

class GoogleSheetsApi {
  final String spreadsheetId;

  // GSheets instance
  late GSheets _gSheets;
  late Spreadsheet _spreadsheet;
  List<List<String>>? lastFetchedData; // Cache sederhana untuk menyimpan data terakhir

  GoogleSheetsApi(this.spreadsheetId);

  // Fungsi untuk logging aman yang hanya berjalan di debug mode
  void log(String message) {
    if (kDebugMode) {
      print(message);  // Hanya akan dipanggil jika mode debug
    }
  }

  // Inisialisasi GSheets dengan kredensial dari file JSON
  Future<void> init() async {
    final String credentials = await rootBundle.loadString('assets/credentials.json');
    final Map<String, dynamic> jsonCredentials = jsonDecode(credentials);
    final gSheets = GSheets(jsonCredentials);

    // Simpan instance GSheets
    _gSheets = gSheets;
    _spreadsheet = await _gSheets.spreadsheet(spreadsheetId);
  }

  // Metode untuk mengecek apakah baris dengan fieldNumber ada di worksheet
  Future<bool> checkRowExists(String worksheetTitle, String fieldNumber) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Ambil semua baris dari worksheet
    final List<List<String>> rows = await sheet.values.allRows();
    // Periksa apakah ada baris yang memiliki fieldNumber yang sesuai
    for (final row in rows) {
      if (row.isNotEmpty && row[2] == fieldNumber) {
        return true; // Baris ditemukan
      }
    }
    return false; // Baris tidak ditemukan
  }

  // Fungsi untuk mengambil data dari worksheet dengan pagination
  Future<List<List<String>>> getSpreadsheetDataWithPagination(
      String worksheetTitle, int startRow, int limit) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Ambil data mulai dari startRow dengan jumlah baris sebanyak limit
    final rows = await sheet.values.allRows(fromRow: startRow, length: limit);
    if (rows.isNotEmpty) {
      lastFetchedData = rows; // Simpan data terakhir ke cache
    }
    log("Data diambil dari Google Sheets (pagination): $rows");  // Mengganti debugPrint dengan log
    return rows;
  }

  // Fungsi untuk mengambil seluruh data (gunakan hati-hati untuk data besar)
  Future<List<List<String>>> getSpreadsheetData(String worksheetTitle) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }
    final rows = await sheet.values.allRows();
    log("Data diambil dari Google Sheets: $rows");  // Mengganti debugPrint dengan log
    lastFetchedData = rows; // Cache data
    return rows;
  }

  // Fungsi untuk menambahkan baris ke worksheet
  Future<void> addRow(String worksheetTitle, List<String> rowData) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Tambahkan baris baru ke worksheet
    await sheet.values.appendRow(rowData);
  }

  // Fungsi untuk memperbarui baris data dalam worksheet dengan format tanggal yang benar
  Future<void> updateRow(String worksheetTitle, List<String> rowData, String fieldNumber) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    final int rowIndex = await _findRowByFieldNumber(sheet, fieldNumber);

    if (rowIndex == -1) {
      throw Exception('Data tidak ditemukan untuk diperbarui.');
    }

    // Update setiap kolom dengan data baru
    for (int i = 0; i < rowData.length; i++) {
      final value = rowData[i];
      if (_isDate(value)) {
        final date = _parseDate(value);
        rowData[i] = DateFormat('dd/MM/yyyy').format(date);
      }
      await sheet.values.insertValue(rowData[i], row: rowIndex, column: i + 1);
    }
  }

  // Fungsi untuk menemukan row index berdasarkan field number (atau ID unik)
  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber) async {
    final List<List<String>> rows = await sheet.values.allRows();
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) {
        return i + 1; // Index baris di Google Sheets dimulai dari 1
      }
    }
    return -1; // Tidak ditemukan
  }

  // Fungsi untuk memeriksa apakah nilai merupakan tanggal
  bool _isDate(String value) {
    try {
      _parseDate(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fungsi untuk parsing tanggal yang fleksibel
  DateTime _parseDate(String value) {
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(value);
    } catch (e) {
      return DateTime.parse(value);
    }
  }
}
