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

  // Fungsi untuk mengambil seluruh data dari worksheet (Gunakan ini untuk log_service.dart dan kebutuhan lainnya)
  Future<List<List<String>>> getSpreadsheetData(String worksheetTitle) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }
    final rows = await sheet.values.allRows();
    log("Data diambil dari worksheet $worksheetTitle: $rows");  // Mengganti debugPrint dengan log
    lastFetchedData = rows; // Cache data
    return rows;
  }

  // Fungsi untuk menambahkan baris ke worksheet
  Future<void> appendRowToSheet(String worksheetTitle, List<String> rowData) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Tambahkan baris baru ke worksheet
    await sheet.values.appendRow(rowData);
    log("Baris ditambahkan ke worksheet $worksheetTitle: $rowData");
  }

  // Fungsi untuk menambahkan baris ke worksheet (Fungsi yang kamu sebutkan)
  Future<void> addRow(String worksheetTitle, List<String> rowData) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Tambahkan baris baru ke worksheet
    await sheet.values.appendRow(rowData);
    log("Baris berhasil ditambahkan ke worksheet $worksheetTitle: $rowData");
  }

  // Fungsi untuk mengecek apakah baris dengan fieldNumber ada di worksheet
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

    // Normalisasi data
    final formattedRowData = rowData.map((value) {
      if (_isNumberWithCommas(value)) {
        return value;
      } else if (_isDate(value)) {
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

    // Perbarui seluruh baris dengan satu panggilan API
    await sheet.values.insertRow(rowIndex, formattedRowData);
    log("Baris diperbarui pada worksheet $worksheetTitle: $formattedRowData");
  }

  Future<void> batchUpdateRows(String worksheetTitle, List<List<String>> rowsData) async {
    final Worksheet? sheet = _spreadsheet.worksheetByTitle(worksheetTitle);
    if (sheet == null) {
      throw Exception('Worksheet tidak ditemukan: $worksheetTitle');
    }

    // Proses setiap baris
    for (final rowData in rowsData) {
      final String fieldNumber = rowData[2]; // Asumsikan fieldNumber di kolom ke-3
      final int rowIndex = await _findRowByFieldNumber(sheet, fieldNumber);

      if (rowIndex == -1) {
        log("Baris dengan fieldNumber $fieldNumber tidak ditemukan. Melewati baris ini.");
        continue; // Lewati jika baris tidak ditemukan
      }

      // Format tanggal di setiap baris
      final formattedRowData = rowData.map((value) {
        if (_isDate(value)) {
          final date = _parseDate(value);
          return DateFormat('dd/MM/yyyy').format(date);
        }
        return value;
      }).toList();

      // Perbarui baris dalam batch
      await sheet.values.insertRow(rowIndex, formattedRowData);
      log("Baris diperbarui pada rowIndex $rowIndex: $formattedRowData");
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

  // Fungsi untuk memeriksa apakah nilai merupakan angka desimal
  bool _isDecimal(String value) {
    return RegExp(r'^[0-9]+([.,][0-9]+)?\$').hasMatch(value);
  }

  // Fungsi untuk format angka desimal tanpa pembulatan
  String _formatDecimal(String value) {
    if (value.contains(',')) {
      value = value.replaceAll(',', '.');
    }
    double? number = double.tryParse(value);
    if (number != null) {
      return number.toString(); // Kembalikan nilai tanpa pembulatan
    }
    return value;
  }

  String _normalizeText(String value) {
    // Gabungkan normalisasi simbol tanpa menghapus simbol
    return _normalizeSymbols(value)
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
    // Ubah koma (,) menjadi titik (.) untuk validasi
    final normalizedValue = value.replaceAll(',', ',');
    return double.tryParse(normalizedValue) != null;
  }

  String _normalizeNumber(String value) {
    // Ubah koma (,) menjadi titik (.)
    final normalizedValue = value.replaceAll(',', ',');

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
    final parts = value.split(':');
    if (parts.length == 2) {
      return '${parts[0].trim()}:${parts[1].trim()}'; // Gabungkan tanpa spasi
    }
    return value; // Jika bukan rasio, kembalikan nilai asli
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
