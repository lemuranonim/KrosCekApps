import 'package:intl/intl.dart';

class Formatters {

  // Fungsi untuk menghitung Days After Planting (DAP)
  static int calculateDAP(String plantingDate) {
    if (plantingDate.isEmpty) return 0;
    try {
      // Coba parse sebagai angka (format tanggal Excel)
      final parsedNumber = double.tryParse(plantingDate);
      if (parsedNumber != null) {
        // Tanggal dasar Excel adalah 30 Desember 1899
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateTime.now().difference(date).inDays;
      } else {
        // Coba parse sebagai string tanggal dd/MM/yyyy
        final parsedDate = DateFormat('dd/MM/yyyy').parse(plantingDate);
        return DateTime.now().difference(parsedDate).inDays;
      }
    } catch (e) {
      // Jika terjadi error saat parsing, kembalikan 0
      return 0;
    }
  }

  // Fungsi untuk memformat tanggal tanam menjadi format "dd MMM yyyy"
  static String formatPlantingDate(String dateStr) {
    if (dateStr.isEmpty) return "Unknown";
    try {
      // Coba parse sebagai angka (format tanggal Excel)
      final parsedNumber = double.tryParse(dateStr);
      if (parsedNumber != null) {
        final date = DateTime(1899, 12, 30).add(Duration(days: parsedNumber.toInt()));
        return DateFormat('dd MMM yyyy').format(date);
      }
      // Coba parse sebagai string tanggal dd/MM/yyyy
      final parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      // Jika gagal, kembalikan string aslinya
      return dateStr;
    }
  }
}