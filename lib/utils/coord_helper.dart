class CoordHelper {
  static ({String wkt, double lat, double lng, int pointCount})?
      kmlPolygonToWkt(String content) {
    final coordinateBlocks = RegExp(
      r'<coordinates[^>]*>(.*?)</coordinates>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(content);

    for (final block in coordinateBlocks) {
      final points = _parseKmlCoordinateBlock(block.group(1) ?? '');
      if (points.length < 3) continue;

      final ring = List<({double lat, double lng})>.from(points);
      if (!_samePoint(ring.first, ring.last)) {
        ring.add(ring.first);
      }

      final wkt = 'POLYGON(('
          '${ring.map((p) => '${_fmt(p.lng)} ${_fmt(p.lat)}').join(', ')}'
          '))';
      final centroid = wktCentroid(wkt);
      if (centroid == null) continue;

      final lat = centroid['lat']!;
      final lng = centroid['lng']!;
      if (!isValidIndonesia(lat, lng)) continue;

      return (
        wkt: wkt,
        lat: lat,
        lng: lng,
        pointCount: _samePoint(points.first, points.last)
            ? points.length - 1
            : points.length,
      );
    }

    return null;
  }

  static ({double lat, double lng})? firstKmlCoordinate(String content) {
    final match = RegExp(
      r'<coordinates[^>]*>\s*([-\d.]+)\s*,\s*([-\d.]+)',
      caseSensitive: false,
    ).firstMatch(content);
    if (match == null) return null;

    final lng = double.tryParse(match.group(1)!);
    final lat = double.tryParse(match.group(2)!);
    if (lat == null || lng == null || !isValidIndonesia(lat, lng)) return null;
    return (lat: lat, lng: lng);
  }

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

    final points = <({double lat, double lng})>[];

    for (final pair in match.group(1)!.split(',')) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final lng = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lng == null || lat == null) continue;
      points.add((lat: lat, lng: lng));
    }

    if (points.length < 3) return null;
    if (_samePoint(points.first, points.last)) {
      points.removeLast();
    }
    if (points.length < 3) return null;

    double signedArea = 0;
    double centroidLng = 0;
    double centroidLat = 0;

    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final cross = current.lng * next.lat - next.lng * current.lat;
      signedArea += cross;
      centroidLng += (current.lng + next.lng) * cross;
      centroidLat += (current.lat + next.lat) * cross;
    }

    if (signedArea.abs() < 0.000000000001) {
      double sumLng = 0, sumLat = 0;
      for (final p in points) {
        sumLng += p.lng;
        sumLat += p.lat;
      }
      return {'lat': sumLat / points.length, 'lng': sumLng / points.length};
    }

    signedArea *= 0.5;
    return {
      'lat': centroidLat / (6 * signedArea),
      'lng': centroidLng / (6 * signedArea),
    };
  }

  static bool isValidIndonesia(double lat, double lng) =>
      lat >= -11.0 && lat <= 6.0 &&
          lng >= 95.0  && lng <= 141.0 &&
          !(lat == 0.0 && lng == 0.0);

  static bool _samePoint(
    ({double lat, double lng}) a,
    ({double lat, double lng}) b,
  ) {
    return (a.lat - b.lat).abs() < 0.0000001 &&
        (a.lng - b.lng).abs() < 0.0000001;
  }

  static List<({double lat, double lng})> _parseKmlCoordinateBlock(
    String block,
  ) {
    final points = <({double lat, double lng})>[];

    for (final token in block.trim().split(RegExp(r'\s+'))) {
      final parts = token.split(',');
      if (parts.length < 2) continue;

      final lng = double.tryParse(parts[0].trim());
      final lat = double.tryParse(parts[1].trim());
      if (lat == null || lng == null || !isValidIndonesia(lat, lng)) continue;
      points.add((lat: lat, lng: lng));
    }

    return points;
  }

  static String _fmt(double value) => value.toStringAsFixed(7);
}
