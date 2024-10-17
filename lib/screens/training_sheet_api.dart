import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';

class TrainingSheetApi {
  final String spreadsheetId;

  // GSheets instance
  late GSheets _gSheets;
  late Spreadsheet _spreadsheet;

  TrainingSheetApi(this.spreadsheetId);

  // Inisialisasi GSheets khusus untuk worksheet Training
  Future<void> init() async {
    final String credentials = await rootBundle.loadString('assets/credentials.json');
    final Map<String, dynamic> jsonCredentials = jsonDecode(credentials);
    final gSheets = GSheets(jsonCredentials);

    // Simpan instance GSheets
    _gSheets = gSheets;

    // Muat spreadsheet berdasarkan ID
    _spreadsheet = await _gSheets.spreadsheet(spreadsheetId);
  }

  // Fungsi untuk mengambil data dari worksheet Training
  Future<List<List<String>>> getTrainingData() async {
    try {
      final Worksheet? sheet = _spreadsheet.worksheetByTitle('Training');

      if (sheet == null) {
        throw 'Worksheet Training tidak ditemukan';
      }

      final List<List<String>> data = await sheet.values.allRows();
      return data;
    } catch (e) {
      print('Error mendapatkan data dari Training: $e');
      return [];
    }
  }

  // Fungsi untuk menambahkan baris baru dengan nomor otomatis ke worksheet Training
  Future<void> addTrainingRow(List<String> rowData) async {
    try {
      final Worksheet? sheet = _spreadsheet.worksheetByTitle('Training');

      if (sheet == null) {
        throw 'Worksheet Training tidak ditemukan';
      }

      // Hitung jumlah baris yang ada, mulai dari baris 105 jika kurang dari 105
      final int nextRow = (sheet.rowCount < 105) ? 105 : sheet.rowCount + 1;

      // Tambahkan nomor urut otomatis di depan baris data
      final List<String> newRowData = [nextRow.toString()] + rowData;

      // Tambahkan baris baru ke worksheet Training
      await sheet.values.appendRow(newRowData);
    } catch (e) {
      print('Error menambahkan data ke Training: $e');
      rethrow;
    }
  }
}
