import 'google_sheets_api.dart';  // Impor GoogleSheetsApi untuk menyimpan dan mengambil data dari Google Sheets

class LogService {
  final String spreadsheetId = '1cMW79EwaOa-Xqe_7xf89_VPiak1uvp_f54GHfNR7WyA';  // ID dari Google Spreadsheet

  // Fungsi untuk mencatat aktivitas pengguna
  Future<void> logActivity({
    required String userName,     // Nama pengguna yang melakukan aktivitas
    required String logActivity,  // Deskripsi aktivitas yang dilakukan
  }) async {
    // Dapatkan timestamp saat aktivitas terjadi
    final String timestamp = DateTime.now().toIso8601String();

    // Buat log entry dengan format: [TimeStamp, UserName, LogActivity]
    final logEntry = [timestamp, userName, logActivity];

    try {
      // Inisialisasi Google Sheets API
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();

      // Simpan log ke sheet 'History'
      await gSheetsApi.appendRowToSheet('History', logEntry);
    // ignore: empty_catches
    } catch (e) {
    }
  }

  // Fungsi untuk mengambil log aktivitas berdasarkan userName
  Future<List<List<String>>> getUserLogs(String userName) async {
    try {
      // Inisialisasi Google Sheets API
      final gSheetsApi = GoogleSheetsApi(spreadsheetId);
      await gSheetsApi.init();

      // Ambil semua data log dari sheet 'History'
      final logs = await gSheetsApi.getSpreadsheetData('History');

      // Filter log untuk hanya menampilkan aktivitas berdasarkan userName
      return logs.where((log) => log[1] == userName).toList();  // Kolom ke-2 adalah userName
    } catch (e) {
      return [];
    }
  }
}
