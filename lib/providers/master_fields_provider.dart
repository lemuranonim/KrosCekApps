import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/session_manager.dart';
import '../utils/dap_helper.dart';
import '../utils/qa_name_helper.dart';

// ============================================================
// 1. SUPABASE SERVICE
// ============================================================
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// ============================================================
// 2. CURRENT USER PROVIDER
// ============================================================
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final session = await SessionManager.instance.getActiveSession();
  if (session == null) return null;

  return AppUser(
    id: session.userId,
    email: session.email,
    name: session.name,
    role: session.role,
    action: session.action,
  );
});

String? _readVegetativeCorrection(Map<String, dynamic> field) {
  final vegRow = field['audit_vegetative'];
  Object? value;
  if (vegRow is List && vegRow.isNotEmpty) {
    value = vegRow[0]['correction_tagging'];
  } else if (vegRow is Map) {
    value = vegRow['correction_tagging'];
  }

  final auditCorrection = value?.toString().trim();
  if (auditCorrection != null && auditCorrection.isNotEmpty) {
    return auditCorrection;
  }

  final fieldCorrection = field['correction_tagging']?.toString().trim();
  if (fieldCorrection != null && fieldCorrection.isNotEmpty) {
    return fieldCorrection;
  }

  return null;
}

Map<String, dynamic> _withResolvedCorrectionTagging(
  Map<String, dynamic> field,
) {
  final correction = _readVegetativeCorrection(field);
  if (correction == null) return field;
  return {
    ...field,
    'correction_tagging': correction,
  };
}

// ============================================================
// 3. MASTER FIELDS PROVIDER (Data Mentah)
// ============================================================
final masterFieldsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);

  if (kDebugMode) {
    print('--- DEBUG USER ---');
    print('Name: ${user?.name}');
    print('Role: ${user?.role}');
    print('Action: ${user?.action}');
    print('------------------');
  }

  if (user == null) return [];

  final action = user.action.toLowerCase();
  final role = user.role.toUpperCase();
  final userName = user.name.trim().toLowerCase();

  final allFields = (await supabaseService.getMasterFieldsWithAllAudits(
    qaFi: action == 'audit' && role == 'FI' ? user.name.trim() : null,
    qaSpv: action == 'audit' && role == 'SPV' ? user.name.trim() : null,
  ))
      .map(_withResolvedCorrectionTagging)
      .toList();

  if (action == 'all') return allFields;

  if (action == 'audit') {
    if (role == 'FI') {
      return allFields.where((field) {
        return QaNameHelper.fieldHasFi(field, userName);
      }).toList();
    } else if (role == 'SPV') {
      return allFields.where((field) {
        return QaNameHelper.fieldHasSpv(field, userName);
      }).toList();
    }
  }

  return allFields;
});

final masterFieldDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, fieldNumber) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);
  final trimmedFieldNumber = fieldNumber.trim();

  if (user == null || trimmedFieldNumber.isEmpty) return null;

  final detail =
      await supabaseService.getMasterFieldWithAllAudits(trimmedFieldNumber);
  if (detail == null) return null;

  final resolved = _withResolvedCorrectionTagging(detail);
  final action = user.action.toLowerCase();
  final role = user.role.toUpperCase();
  final userName = user.name.trim().toLowerCase();

  if (action == 'all') return resolved;
  if (action == 'audit') {
    if (role == 'FI') {
      return QaNameHelper.fieldHasFi(resolved, userName) ? resolved : null;
    }
    if (role == 'SPV') {
      return QaNameHelper.fieldHasSpv(resolved, userName) ? resolved : null;
    }
  }

  return resolved;
});

class MasterFieldNumbersScope {
  final List<String> fieldNumbers;

  MasterFieldNumbersScope(Iterable<String> fieldNumbers)
      : fieldNumbers = (fieldNumbers
            .map((fieldNumber) => fieldNumber.trim())
            .where((fieldNumber) => fieldNumber.isNotEmpty)
            .toSet()
            .toList()
          ..sort());

  @override
  bool operator ==(Object other) =>
      other is MasterFieldNumbersScope &&
      _listEquals(other.fieldNumbers, fieldNumbers);

  @override
  int get hashCode => Object.hashAll(fieldNumbers);
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

final masterFieldsByFieldNumbersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, MasterFieldNumbersScope>(
        (ref, scope) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);

  if (user == null || scope.fieldNumbers.isEmpty) return [];

  final action = user.action.toLowerCase();
  final role = user.role.toUpperCase();
  final userName = user.name.trim().toLowerCase();

  final fields =
      (await supabaseService.getMasterFieldsByFieldNumbers(scope.fieldNumbers))
          .map(_withResolvedCorrectionTagging)
          .toList();

  if (action == 'all') return fields;

  if (action == 'audit') {
    if (role == 'FI') {
      return fields.where((field) {
        return QaNameHelper.fieldHasFi(field, userName);
      }).toList();
    } else if (role == 'SPV') {
      return fields.where((field) {
        return QaNameHelper.fieldHasSpv(field, userName);
      }).toList();
    }
  }

  return fields;
});

// ============================================================
// 3b. MASTER FIELD MAP PROVIDER (Data Ringan Untuk Peta)
// ============================================================
final activeMasterFieldSeasonsProvider = FutureProvider<List<String>>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getActiveMasterFieldSeasons();
});

final latestActiveMasterFieldSeasonProvider = FutureProvider<String?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.getLatestActiveMasterFieldSeason();
});

class MasterFieldMapScope {
  final String? season;
  final String? region;
  final String? district;
  final bool allSeasons;

  const MasterFieldMapScope({
    this.season,
    this.region,
    this.district,
    this.allSeasons = true,
  });

  const MasterFieldMapScope.all()
      : season = null,
        region = null,
        district = null,
        allSeasons = true;

  @override
  bool operator ==(Object other) =>
      other is MasterFieldMapScope &&
      other.season == season &&
      other.region == region &&
      other.district == district &&
      other.allSeasons == allSeasons;

  @override
  int get hashCode => Object.hash(season, region, district, allSeasons);
}

final activeMasterFieldRegionsProvider =
    FutureProvider.family<List<String>, MasterFieldMapScope>(
        (ref, scope) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final resolvedSeason = scope.allSeasons
      ? null
      : (scope.season?.trim().isNotEmpty == true
          ? scope.season!.trim()
          : await ref.watch(latestActiveMasterFieldSeasonProvider.future));
  final action = user.action.toLowerCase();
  final role = user.role.toUpperCase();

  return supabaseService.getActiveMasterFieldRegions(
    season: resolvedSeason,
    qaFi: action == 'audit' && role == 'FI' ? user.name.trim() : null,
    qaSpv: action == 'audit' && role == 'SPV' ? user.name.trim() : null,
  );
});

final masterFieldMapProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(
    masterFieldMapScopedProvider(const MasterFieldMapScope.all()).future,
  );
});

final masterFieldMapScopedProvider =
    FutureProvider.family<List<Map<String, dynamic>>, MasterFieldMapScope>(
        (ref, scope) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);

  if (user == null) return [];

  final action = user.action.toLowerCase();
  final role = user.role.toUpperCase();
  final userName = user.name.trim().toLowerCase();
  final resolvedSeason = scope.allSeasons
      ? null
      : (scope.season?.trim().isNotEmpty == true
          ? scope.season!.trim()
          : await ref.watch(latestActiveMasterFieldSeasonProvider.future));

  final mapFields = (await supabaseService.getMasterFieldsForMap(
    qaFi: action == 'audit' && role == 'FI' ? user.name.trim() : null,
    qaSpv: action == 'audit' && role == 'SPV' ? user.name.trim() : null,
    season: resolvedSeason,
    region: scope.region,
    district: scope.district,
  ))
      .map(_withResolvedCorrectionTagging)
      .toList();

  if (action == 'all') return mapFields;

  if (action == 'audit') {
    if (role == 'FI') {
      return mapFields.where((field) {
        return QaNameHelper.fieldHasFi(field, userName);
      }).toList();
    } else if (role == 'SPV') {
      return mapFields.where((field) {
        return QaNameHelper.fieldHasSpv(field, userName);
      }).toList();
    }
  }

  return mapFields;
});

final masterFieldCoverageScopedProvider =
    FutureProvider.family<List<Map<String, dynamic>>, MasterFieldMapScope>(
        (ref, scope) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final user = await ref.watch(currentUserProvider.future);

  if (user == null) return [];

  final action = user.action.toLowerCase();
  final role = user.role.toUpperCase();
  final userName = user.name.trim().toLowerCase();
  final resolvedSeason = scope.allSeasons
      ? null
      : (scope.season?.trim().isNotEmpty == true
          ? scope.season!.trim()
          : await ref.watch(latestActiveMasterFieldSeasonProvider.future));

  final fields = (await supabaseService.getMasterFieldsForCoverage(
    qaFi: action == 'audit' && role == 'FI' ? user.name.trim() : null,
    qaSpv: action == 'audit' && role == 'SPV' ? user.name.trim() : null,
    season: resolvedSeason,
    region: scope.region,
    district: scope.district,
  ))
      .map(_withResolvedCorrectionTagging)
      .toList();

  if (action == 'all') return fields;

  if (action == 'audit') {
    if (role == 'FI') {
      return fields.where((field) {
        return QaNameHelper.fieldHasFi(field, userName);
      }).toList();
    } else if (role == 'SPV') {
      return fields.where((field) {
        return QaNameHelper.fieldHasSpv(field, userName);
      }).toList();
    }
  }

  return fields;
});

// ============================================================
// 4. DATA MODEL KHUSUS PETA
// ============================================================
class ParsedFieldData {
  final Map<String, dynamic> raw;
  final double lat;
  final double lng;
  final bool isDefault;
  final bool isCorrected;
  final bool isFromPolygon;
  final int dap;

  /// Raw WKT string dari kolom geometry_wkt, jika ada.
  final String? geometryWkt;

  /// Koordinat polygon yang sudah diparse dari WKT.
  /// Disimpan di sini agar tidak perlu parse ulang di thread utama (UI).
  final List<LatLng>? polygonPoints;
  final LatLngBounds? polygonBounds;

  ParsedFieldData({
    required this.raw,
    required this.lat,
    required this.lng,
    required this.isDefault,
    required this.isCorrected,
    required this.isFromPolygon,
    required this.dap,
    this.geometryWkt,
    this.polygonPoints,
    this.polygonBounds,
  });
}

// ============================================================
// 5. FUNGSI TOP-LEVEL UNTUK ISOLATE
// (Syarat Isolate: fungsi harus di luar class atau berupa static)
// ============================================================
List<ParsedFieldData> _parseMapFieldsInIsolate(
    List<Map<String, dynamic>> rawFields) {
  // ── Helper: validasi koordinat wilayah Indonesia ──────────
  bool isValidIndonesiaCoord(double lat, double lng) {
    return lat >= -11.0 &&
        lat <= 6.0 &&
        lng >= 95.0 &&
        lng <= 141.0 &&
        !(lat == 0.0 && lng == 0.0);
  }

  // ── Helper: parse WKT POLYGON → List<LatLng> ──────────────
  List<LatLng> parseWktToLatLngs(String wkt) {
    final match = RegExp(
      r'POLYGON\s*\(\((.+?)\)\)',
      caseSensitive: false,
    ).firstMatch(wkt);
    if (match == null) return [];

    final result = <LatLng>[];
    for (final pair in match.group(1)!.split(',')) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final lng = double.tryParse(parts[0]);
      final lat = double.tryParse(parts[1]);
      if (lat != null && lng != null) {
        result.add(LatLng(lat, lng));
      }
    }
    return result;
  }

  List<LatLng> openPolygonRing(List<LatLng> points) {
    if (points.length < 2) return List<LatLng>.from(points);
    final result = List<LatLng>.from(points);
    final first = result.first;
    final last = result.last;
    if ((first.latitude - last.latitude).abs() < 0.0000001 &&
        (first.longitude - last.longitude).abs() < 0.0000001) {
      result.removeLast();
    }
    return result;
  }

  LatLng? polygonCentroid(List<LatLng> points) {
    final ring = openPolygonRing(points);
    if (ring.length < 3) return null;

    double signedArea = 0;
    double centroidLng = 0;
    double centroidLat = 0;

    for (var i = 0; i < ring.length; i++) {
      final current = ring[i];
      final next = ring[(i + 1) % ring.length];
      final cross =
          current.longitude * next.latitude - next.longitude * current.latitude;
      signedArea += cross;
      centroidLng += (current.longitude + next.longitude) * cross;
      centroidLat += (current.latitude + next.latitude) * cross;
    }

    if (signedArea.abs() < 0.000000000001) {
      double sumLng = 0;
      double sumLat = 0;
      for (final p in ring) {
        sumLng += p.longitude;
        sumLat += p.latitude;
      }
      return LatLng(sumLat / ring.length, sumLng / ring.length);
    }

    signedArea *= 0.5;
    return LatLng(
      centroidLat / (6 * signedArea),
      centroidLng / (6 * signedArea),
    );
  }

  // ── Helper: parse centroid dari WKT POLYGON ───────────────
  Map<String, double>? parseWktCentroid(String? wkt) {
    if (wkt == null || wkt.trim().isEmpty) return null;
    final centroid = polygonCentroid(parseWktToLatLngs(wkt));
    if (centroid == null) return null;
    return {'lat': centroid.latitude, 'lng': centroid.longitude};
  }

  ({double lat, double lng})? parseValidCoordinate(String? raw) {
    if (raw == null || raw.trim().isEmpty || !raw.contains(',')) return null;
    final parts = raw.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (!isValidIndonesiaCoord(lat, lng)) return null;
    return (lat: lat, lng: lng);
  }
  // ─────────────────────────────────────────────────────────

  return rawFields.map((f) {
    final normalizedRaw = _withResolvedCorrectionTagging(f);
    final correctionCoord = _readVegetativeCorrection(normalizedRaw);
    final geometryWkt = f['geometry_wkt']?.toString();
    final rawCoord = f['coordinate']?.toString();

    // Parse Polygon Points
    List<LatLng>? parsedPolygon;
    if (geometryWkt != null && geometryWkt.isNotEmpty) {
      parsedPolygon = parseWktToLatLngs(geometryWkt);
    }

    // Inisialisasi langsung non-nullable dengan nilai default (PRIORITAS 4).
    double finalLat = -7.637017;
    double finalLng = 112.8272303;
    bool isDef = true;
    bool isCorrected = false;
    bool isFromPolygon = false;

    // ── PRIORITAS 1: centroid polygon WKT ──────────
    final centroid = parseWktCentroid(geometryWkt);
    if (centroid != null) {
      final wlat = centroid['lat']!;
      final wlng = centroid['lng']!;
      if (isValidIndonesiaCoord(wlat, wlng)) {
        finalLat = wlat;
        finalLng = wlng;
        isFromPolygon = true;
        isDef = false;
      }
    }

    // ── PRIORITAS 2: correction_tagging ──
    final correction = parseValidCoordinate(correctionCoord);
    if (correction != null) {
      isCorrected = true;
      if (!isFromPolygon) {
        finalLat = correction.lat;
        finalLng = correction.lng;
        isDef = false;
      }
    }

    // ── PRIORITAS 3: coordinate ────────────
    final coordinate = parseValidCoordinate(rawCoord);
    if (!isCorrected && !isFromPolygon && coordinate != null) {
      finalLat = coordinate.lat;
      finalLng = coordinate.lng;
      isDef = false;
    }

    final validPolygon = (parsedPolygon != null && parsedPolygon.length >= 3)
        ? parsedPolygon
        : null;

    return ParsedFieldData(
      raw: normalizedRaw,
      lat: finalLat,
      lng: finalLng,
      isDefault: isDef,
      isCorrected: isCorrected,
      isFromPolygon: isFromPolygon,
      dap: DapHelper.calculateFieldDAP(normalizedRaw),
      geometryWkt: geometryWkt,
      polygonPoints: validPolygon,
      polygonBounds:
          validPolygon == null ? null : LatLngBounds.fromPoints(validPolygon),
    );
  }).toList();
}

// ============================================================
// 6. PROVIDER PETA (Menjalankan Isolate)
// ============================================================
final parsedMapFieldsProvider =
    FutureProvider<List<ParsedFieldData>>((ref) async {
  final rawFields = await ref.watch(masterFieldsProvider.future);

  if (rawFields.isEmpty) return [];

  // Lemparkan tugas parsing yang berat ke thread terpisah menggunakan compute
  return await compute(_parseMapFieldsInIsolate, rawFields);
});

final parsedMasterFieldMapProvider =
    FutureProvider<List<ParsedFieldData>>((ref) async {
  final rawFields = await ref.watch(masterFieldMapProvider.future);

  if (rawFields.isEmpty) return [];

  return await compute(_parseMapFieldsInIsolate, rawFields);
});

final parsedMasterFieldMapScopedProvider =
    FutureProvider.family<List<ParsedFieldData>, MasterFieldMapScope>(
        (ref, scope) async {
  final rawFields = await ref.watch(masterFieldMapScopedProvider(scope).future);

  if (rawFields.isEmpty) return [];

  return await compute(_parseMapFieldsInIsolate, rawFields);
});
