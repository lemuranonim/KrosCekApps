class CoordHelper {
  /// Parse centroid dari WKT POLYGON.
  /// Format WKT: POLYGON((lng lat, lng lat, ...))
  /// Perhatian: urutan WKT adalah X(lng) dulu, baru Y(lat)
  static Map<String, double>? wktCentroid(String? wkt) {
    if (wkt == null || wkt.trim().isEmpty) return null;

    final match = RegExp(
      r'POLYGON\s*\(\((.+?)\)\)',
      caseSensitive: false,
    ).firstMatch(wkt);
    if (match == null) return null;

    final pairs = match.group(1)!.split(',');
    double sumLng = 0, sumLat = 0;
    int count = 0;

    for (final pair in pairs) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final lng = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lng == null || lat == null) continue;
      sumLng += lng;
      sumLat += lat;
      count++;
    }

    // Polygon WKT menutup kembali ke titik pertama,
    // bisa dikurangi 1 tapi rata-rata tetap sama nilainya
    if (count == 0) return null;
    return {'lat': sumLat / count, 'lng': sumLng / count};
  }

  static bool isValidIndonesia(double lat, double lng) =>
      lat >= -11.0 && lat <= 6.0 &&
          lng >= 95.0  && lng <= 141.0 &&
          !(lat == 0.0 && lng == 0.0);
}