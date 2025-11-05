class VegetativeAuditData {
  final String region;
  final String qaSpv;
  final String season;
  final int week;

  // Data Pokok dari Google Sheet
  final double workloadHa;          // Kolom CO
  final double auditedVegHa;        // Kolom CQ
  final double ncFieldSizeHa;       // Kolom CV
  final double ncPlantingDateHa;    // Kolom CU
  final double poiNonValidHa;       // Kolom CY
  final double potentialIsolationHa; // Kolom CW
  // Tambahkan NC Male Split jika diperlukan
  final double ncMaleSplitHa;       // Kolom (misalnya CZ, sesuaikan jika beda)


  VegetativeAuditData({
    required this.region,
    required this.qaSpv,
    required this.season,
    required this.week,
    required this.workloadHa,
    required this.auditedVegHa,
    required this.ncFieldSizeHa,
    required this.ncPlantingDateHa,
    required this.poiNonValidHa,
    required this.potentialIsolationHa,
    required this.ncMaleSplitHa,
  });

  // Kalkulasi Persentase (Calculated Properties)
  double get auditedVegetativePercentage =>
      workloadHa > 0 ? (auditedVegHa / workloadHa) * 100 : 0;

  double get ncFieldSizePercentage =>
      workloadHa > 0 ? (ncFieldSizeHa / workloadHa) * 100 : 0;

  double get ncPlantingDatePercentage =>
      workloadHa > 0 ? (ncPlantingDateHa / workloadHa) * 100 : 0;

  double get poiNonValidPercentage =>
      workloadHa > 0 ? (poiNonValidHa / workloadHa) * 100 : 0;

  double get potentialIsolationPercentage =>
      workloadHa > 0 ? (potentialIsolationHa / workloadHa) * 100 : 0;

  double get ncMaleSplitPercentage =>
      workloadHa > 0 ? (ncMaleSplitHa / workloadHa) * 100 : 0;

  // Factory constructor untuk membuat objek dari baris data sheet (List<String>)
  factory VegetativeAuditData.fromGSheetRow(List<String> row) {
    // Helper untuk parse double dengan aman
    double parseDouble(String value) => double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    int parseInt(String value) => int.tryParse(value) ?? 0;

    // Asumsi urutan kolom di sheet 'Generative'
    // Anda perlu menyesuaikan indeks ini dengan struktur sheet Anda
    const regionIndex = 18; // Contoh, misal kolom B
    const qaSpvIndex = 30; // Contoh, misal kolom F
    const seasonIndex = 1; // Contoh, misal kolom C
    const weekIndex = 28; // Contoh, misal kolom K (Weeks of Vegetative)

    // Sesuaikan indeks kolom ini dengan yang benar
    const workloadHaIndex = 92;  // Kolom CO
    const auditedVegHaIndex = 94; // Kolom CQ
    const ncPlantingDateHaIndex = 98; // Kolom CU
    const ncFieldSizeHaIndex = 99;    // Kolom CV
    const potentialIsolationHaIndex = 100; // Kolom CW
    const poiNonValidHaIndex = 102;   // Kolom CY
    const ncMaleSplitHaIndex = 97; // Kolom CT, seperti di gambar contoh

    return VegetativeAuditData(
      region: row.length > regionIndex ? row[regionIndex] : 'Unknown',
      qaSpv: row.length > qaSpvIndex ? row[qaSpvIndex] : 'Unknown',
      season: row.length > seasonIndex ? row[seasonIndex] : 'Unknown',
      week: row.length > weekIndex ? parseInt(row[weekIndex]) : 0,
      workloadHa: row.length > workloadHaIndex ? parseDouble(row[workloadHaIndex]) : 0.0,
      auditedVegHa: row.length > auditedVegHaIndex ? parseDouble(row[auditedVegHaIndex]) : 0.0,
      ncFieldSizeHa: row.length > ncFieldSizeHaIndex ? parseDouble(row[ncFieldSizeHaIndex]) : 0.0,
      ncPlantingDateHa: row.length > ncPlantingDateHaIndex ? parseDouble(row[ncPlantingDateHaIndex]) : 0.0,
      poiNonValidHa: row.length > poiNonValidHaIndex ? parseDouble(row[poiNonValidHaIndex]) : 0.0,
      potentialIsolationHa: row.length > potentialIsolationHaIndex ? parseDouble(row[potentialIsolationHaIndex]) : 0.0,
      ncMaleSplitHa: row.length > ncMaleSplitHaIndex ? parseDouble(row[ncMaleSplitHaIndex]) : 0.0,
    );
  }
}