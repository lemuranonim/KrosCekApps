import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';

class PspTrainingSheetApi {
  late String spreadsheetId;
  late GSheets _gSheets;
  late Spreadsheet _spreadsheet;

  PspTrainingSheetApi(this.spreadsheetId);

  Future<void> updateSpreadsheet(String newId) async {
    spreadsheetId = newId; // Perbarui ID spreadsheet
    await init(); // Re-inisialisasi koneksi dengan ID baru
  }

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

      // Ambil semua data yang sudah terisi di kolom pertama (No)
      final List<String> numbers = await sheet.values.column(1);

      // Hitung nomor berikutnya (nomor dimulai dari baris kedua)
      int nextRowNumber = 1; // Default jika kosong
      if (numbers.length > 1) { // Abaikan baris header
        nextRowNumber = int.tryParse(numbers.last) ?? 1;
        nextRowNumber++; // Tambahkan 1 ke nomor terakhir
      }

      // Gabungkan nomor dengan data lainnya
      final List<String> newRowData = [nextRowNumber.toString()] + rowData;

      // Tambahkan baris baru ke worksheet
      await sheet.values.appendRow(newRowData);
    } catch (e) {
      rethrow;
    }
  }
}
