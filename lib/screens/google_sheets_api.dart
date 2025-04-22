import 'dart:convert';
import 'package:flutter/foundation.dart';  // Ini diperlukan untuk memeriksa mode debug
import 'package:flutter/services.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

class GoogleSheetsApi {
  final String spreadsheetId;

  /// Konversi angka desimal ke format Indonesia (koma sebagai desimal, titik sebagai ribuan)
  String formatDecimalForIndonesia(double value) {
    final formatter = NumberFormat("#,##0.00", "id_ID"); // Format Indonesia
    return formatter.format(value);
  }

  /// Parsing nilai desimal dari teks ke angka (menerima format Indonesia)
  double parseDecimalFromIndonesia(String value) {
    // Ubah format Indonesia (titik untuk ribuan, koma untuk desimal) menjadi format internasional
    final normalizedValue = value.replaceAll('.', '').replaceAll('.', ','); // Normalisasi angka Indonesia ke format internasional (koma) untuk desimal (titik untuk ribuan)
    final double? parsedValue = double.tryParse(normalizedValue);
    if (parsedValue == null) {
      throw Exception("Nilai '$value' bukan angka valid dalam format Indonesia.");
    }
    return parsedValue;
  }

  /// Validasi apakah nilai dalam format desimal Indonesia
  bool isDecimalIndonesia(String value) {
    // Validasi angka dengan titik untuk ribuan dan koma untuk desimal
    return RegExp(r'^\d{1,3}(\.\d{3})*(,\d+)?$').hasMatch(value);
  }


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
  bool isInitialized = false;  // Status inisialisasi

  Future<void> init() async {
    final String credentials = await rootBundle.loadString('assets/credentials.json');
    final Map<String, dynamic> jsonCredentials = jsonDecode(credentials);
    _gSheets = GSheets(jsonCredentials);
    _spreadsheet = await _gSheets.spreadsheet(spreadsheetId);
  }

  Spreadsheet get spreadsheet => _spreadsheet;

  // Fungsi untuk mengambil seluruh data dari worksheet (Gunakan ini untuk log_service.dart dan kebutuhan lainnya)
  Future<List<List<String>>> getSpreadsheetData(String worksheetTitle) async {
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }
    final rows = await sheet.values.allRows();
    log("Data diambil dari worksheet $worksheetTitle: $rows");  // Mengganti debugPrint dengan log
    lastFetchedData = rows; // Cache data
    return rows;
  }

  Future<List<String>> fetchFIByRegion(String worksheetTitle, String region) async {
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Ambil semua data dari worksheet
    final rows = await sheet.values.allRows();

    // Filter berdasarkan Region
    List<String> fiList = [];
    for (var row in rows) {
      if (row.isNotEmpty && row[0] == region) { // Kolom 0 untuk Region, kolom 1 untuk FI
        fiList.add(row[1]); // Tambahkan FI ke daftar
      }
    }

    return fiList; // Kembalikan daftar FI
  }

  // Fungsi untuk menambahkan baris ke worksheet
  Future<void> appendRowToSheet(String worksheetTitle, List<String> rowData) async {
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Tambahkan baris baru ke worksheet
    await sheet.values.appendRow(rowData);
    log("Baris ditambahkan ke worksheet $worksheetTitle: $rowData");
  }

  // Fungsi untuk menambahkan baris ke worksheet (Fungsi yang kamu sebutkan)
  Future<void> addRow(String worksheetTitle, List<String> rowData) async {
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Tambahkan baris baru ke worksheet
    await sheet.values.appendRow(rowData);
    log("Baris berhasil ditambahkan ke worksheet $worksheetTitle: $rowData");
  }

  // Fungsi untuk mengecek apakah baris dengan fieldNumber ada di worksheet
  Future<bool> checkRowExists(String worksheetTitle, String fieldNumber) async {
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
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
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Ambil data mulai dari startRow dengan jumlah baris sebanyak limit
    final rows = await sheet.values.allRows(fromRow: startRow, length: limit); // Ambil data dengan pagination
    if (rows.isNotEmpty) { // Jika data tidak kosong
      lastFetchedData = rows; // Simpan data terakhir ke cache
    }
    log("Data diambil dari Google Sheets (pagination): $rows");  // Mengganti debugPrint dengan log
    return rows;
  }

  // Fungsi untuk memperbarui baris data dalam worksheet dengan format tanggal yang benar
  Future<void> updateRow(String worksheetTitle, List<String> rowData, String fieldNumber) async {
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) throw Exception('Worksheet tidak ditemukan: $worksheetTitle');

    final int rowIndex = await _findRowByFieldNumber(sheet, fieldNumber);
    if (rowIndex == -1) throw Exception('Data tidak ditemukan untuk diperbarui.');

    // Normalisasi data
    final formattedRowData = rowData.map((value) {
      if (_isNumberWithCommas(value)) {
        return value;
      } else if (_isDate(value)) { // Jika nilai merupakan tanggal
        final date = _parseDate(value);
        return DateFormat('dd/MM/yyyy').format(date); // Format tanggal
      } else if (_isDecimal(value)) {
        return _formatDecimal(value); // Tangani angka desimal
      } else if (_isNumber(value)) {
        return _normalizeNumber(value); // Format angka (mendukung koma dan titik)
      } else if (_containsRatio(value)) {
        return _normalizeRatio(value); // Tangani rasio tanpa spasi
      } else {
        return _normalizeText(value); // Normalisasi teks (simbol diperbolehkan)
      }
    }).toList();

    // Perbarui data di baris yang ditentukan
    await sheet.values.insertRow(rowIndex, rowData, fromColumn: 1);

    log("Baris diperbarui pada worksheet $worksheetTitle: $formattedRowData");
  }

  Future<void> batchUpdateRows(String worksheetTitle, List<List<String>> rowsData) async { // Batch update baris
    final Worksheet? sheet = spreadsheet.worksheetByTitle(worksheetTitle); // Ambil worksheet
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle'); // Jika worksheet tidak ditemukan, lempar exception
    }

    // Proses setiap baris
    for (final rowData in rowsData) {
      final String fieldNumber = rowData[2]; // Asumsikan fieldNumber di kolom ke-3
      final int rowIndex = await _findRowByFieldNumber(sheet, fieldNumber); // Cari baris berdasarkan fieldNumber

      if (rowIndex == -1) { // Periksa apakah baris ditemukan
        log("Baris dengan fieldNumber $fieldNumber tidak ditemukan. Melewati baris ini."); // Log jika baris tidak ditemukan
        continue; // Lewati jika baris tidak ditemukan
      }

      // Format tanggal di setiap baris
      final formattedRowData = rowData.map((value) { // Iterasi setiap nilai dalam baris
        if (_isDate(value)) { // Jika nilai merupakan tanggal
          final date = _parseDate(value); // Parse tanggal
          return DateFormat('dd/MM/yyyy').format(date);
        }
        return value;
      }).toList();

      // Perbarui baris dalam batch
      await sheet.values.insertRow(rowIndex, rowData); // Perbarui baris
      log("Baris diperbarui pada rowIndex $rowIndex: $formattedRowData");
    }
  }

  // Fungsi untuk menemukan row index berdasarkan field number (atau ID unik)
  Future<int> _findRowByFieldNumber(Worksheet sheet, String fieldNumber) async { // Mencari baris berdasarkan fieldNumber

    final List<List<String>> rows = await sheet.values.allRows(); // Ambil semua baris
    for (int i = 0; i < rows.length; i++) { // Iterasi setiap baris
      if (rows[i].isNotEmpty && rows[i][2] == fieldNumber) { // Kolom ke-3 untuk fieldNumber
        return i + 1; // Index baris di Google Sheets dimulai dari 1
      }
    }
    return -1; // Tidak ditemukan
  }

  // Fungsi untuk memeriksa apakah nilai merupakan angka desimal
  bool _isDecimal(String value) {
    return RegExp(r'^[0-9]+([.,][0-9]+)?\$').hasMatch(value); // Contoh: 123.45 atau 123,45
  }

  // Fungsi untuk format angka desimal tanpa pembulatan
  String _formatDecimal(String value) {
    if (value.contains('.')) {  // Jika mengandung titik (.)
      value = value.replaceAll('.', ','); // Ubah titik (.) menjadi koma (,)
    }
    double? number = double.tryParse(value);
    if (number != null) { // Jika berhasil di-parse
      return number.toString(); // Kembalikan nilai tanpa pembulatan
    }
    return value; // Kembalikan nilai asli jika gagal
  }

  String _normalizeText(String value) {
    // Gabungkan normalisasi simbol tanpa menghapus simbol
    return _normalizeSymbols(value) // Normalisasi simbol
        .replaceAll(RegExp(r'\s+'), ' ') // Ganti spasi ganda dengan spasi tunggal
        .split(' ') // Pisah menjadi kata
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '') // Kapitalisasi awal setiap kata
        .join(' '); // Gabungkan kembali teks
  }

  String _normalizeSymbols(String value) {
    // Tidak menghapus simbol, hanya membersihkan spasi di sekitar teks
    return value.trim(); // Hapus spasi ekstra di awal dan akhir
  }

  bool _isNumber(String value) {
    // Ubah titik (.) menjadi koma (,) untuk validasi
    final normalizedValue = value.replaceAll('.', ','); // Normalisasi angka

    // Coba parse angka dengan format yang sudah diubah
    return double.tryParse(normalizedValue.replaceAll(',', ',')) != null; // Coba parse sebagai double
  }


  String _normalizeNumber(String value) {
    // Ubah titik (.) menjadi koma (,)
    final normalizedValue = value.replaceAll('.', ','); // Normalisasi angka

    // Parse sebagai double
    final doubleValue = double.tryParse(normalizedValue);

    if (doubleValue != null) {
      // Format ulang angka (dapat mengembalikan dengan koma jika dibutuhkan)
      return doubleValue.toStringAsFixed(2).replaceAll('.', ','); // Kembali ke format dengan koma
    }

    // Jika gagal, kembalikan nilai asli
    return value;
  }

  bool _isNumberWithCommas(String value) {
    return RegExp(r'^\d+(,\d+)*$').hasMatch(value); // Contoh: 1,1,1 atau 123,456
  }

  bool _containsRatio(String value) {
    return value.contains(':'); // Periksa apakah mengandung simbol `:`
  }

  String _normalizeRatio(String value) {
    // Pastikan format tanpa spasi di sekitar simbol `:`
    final parts = value.split(':'); // Pisahkan rasio
    if (parts.length == 2) { // Jika terdiri dari dua bagian
      return '${parts[0].trim()}:${parts[1].trim()}'; // Gabungkan tanpa spasi
    }
    return value; // Jika bukan rasio, kembalikan nilai asli
  }


  // Fungsi untuk memeriksa apakah nilai merupakan tanggal
  bool _isDate(String value) {
    try { // Coba parse tanggal
      DateTime.parse(value); // Coba parse tanggal
      return true; // Jika berhasil, kembalikan true
    } catch (e) { // Jika gagal
      return false; // Jika gagal, kembalikan false
    }
  }

  // Fungsi untuk parsing tanggal yang fleksibel
  DateTime _parseDate(String value) { // Parsing tanggal yang fleksibel
    try { // Coba parse dengan format tanggal yang berbeda
      return DateFormat('dd/MM/yyyy').parseStrict(value); // Coba format tanggal ini
    } catch (e) { // Jika gagal, coba format lain
      return DateTime.parse(value); // Coba format tanggal default
    }
  }
}
