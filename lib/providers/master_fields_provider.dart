import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/session_manager.dart';
import '../utils/dap_helper.dart';

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
    id    : session.userId,
    email : session.email,
    name  : session.name,
    role  : session.role,
    action: session.action,
  );
});

// ============================================================
// 3. MASTER FIELDS PROVIDER (Data Mentah)
// ============================================================
final masterFieldsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
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

  final allFields = await supabaseService.getMasterFieldsWithAllAudits();

  final action   = user.action.toLowerCase();
  final role     = user.role.toUpperCase();
  final userName = user.name.trim().toLowerCase();

  if (action == 'all') return allFields;

  if (action == 'audit') {
    if (role == 'FI') {
      return allFields.where((field) {
        final qaFi = field['qa_fi']?.toString().trim().toLowerCase() ?? '';
        return qaFi == userName;
      }).toList();
    } else if (role == 'SPV') {
      return allFields.where((field) {
        final qaSpv = field['qa_spv']?.toString().trim().toLowerCase() ?? '';
        return qaSpv == userName;
      }).toList();
    }
  }

  return allFields;
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
  /// Digunakan untuk menggambar polygon overlay di map screen.
  /// Null jika lahan belum memiliki data polygon.
  final String? geometryWkt;

  ParsedFieldData({
    required this.raw,
    required this.lat,
    required this.lng,
    required this.isDefault,
    required this.isCorrected,
    required this.isFromPolygon,
    required this.dap,
    this.geometryWkt,
  });
}

// ============================================================
// 5. FUNGSI TOP-LEVEL UNTUK ISOLATE
// (Syarat Isolate: fungsi harus di luar class atau berupa static)
// ============================================================
List<ParsedFieldData> _parseMapFieldsInIsolate(List<Map<String, dynamic>> rawFields) {

  // ── Helper: validasi koordinat wilayah Indonesia ──────────
  bool isValidIndonesiaCoord(double lat, double lng) {
    return lat >= -11.0 && lat <= 6.0 &&
        lng >= 95.0  && lng <= 141.0 &&
        !(lat == 0.0 && lng == 0.0);
  }

  // ── Helper: parse centroid dari WKT POLYGON ───────────────
  // Format WKT: POLYGON((lng lat, lng lat, ...))
  // Urutan: X (lng) dulu, baru Y (lat) — berbeda dengan LatLng!
  Map<String, double>? parseWktCentroid(String? wkt) {
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
    if (count == 0) return null;
    return {'lat': sumLat / count, 'lng': sumLng / count};
  }
  // ─────────────────────────────────────────────────────────

  return rawFields.map((f) {
    final correctionCoord = f['correction_tagging']?.toString();
    final geometryWkt     = f['geometry_wkt']?.toString();
    final rawCoord        = f['coordinate']?.toString();

    // Inisialisasi langsung non-nullable dengan nilai default (PRIORITAS 4).
    // Tiap prioritas yang berhasil akan override + set isDef = false.
    // Pendekatan ini menghindari nullable, !, dan ?? sekaligus.
    double finalLat    = -7.637017;
    double finalLng    = 112.8272303;
    bool isDef         = true;
    bool isCorrected   = false;
    bool isFromPolygon = false;

    // ── PRIORITAS 1: correction_tagging (koreksi manual QA) ──
    if (correctionCoord != null &&
        correctionCoord.trim().isNotEmpty &&
        correctionCoord.contains(',')) {
      final cp   = correctionCoord.split(',');
      final clat = double.tryParse(cp[0].trim());
      final clng = double.tryParse(cp[1].trim());
      if (clat != null && clng != null &&
          isValidIndonesiaCoord(clat, clng)) {
        finalLat    = clat;
        finalLng    = clng;
        isCorrected = true;
        isDef       = false;
      }
    }

    // ── PRIORITAS 2: geometry_wkt → centroid polygon ──────────
    if (!isCorrected) {
      final centroid = parseWktCentroid(geometryWkt);
      if (centroid != null) {
        final wlat = centroid['lat']!;
        final wlng = centroid['lng']!;
        if (isValidIndonesiaCoord(wlat, wlng)) {
          finalLat      = wlat;
          finalLng      = wlng;
          isFromPolygon = true;
          isDef         = false;
        }
      }
    }

    // ── PRIORITAS 3: coordinate (titik point lama) ────────────
    if (!isCorrected && !isFromPolygon) {
      if (rawCoord != null &&
          rawCoord.trim().isNotEmpty &&
          rawCoord.contains(',')) {
        final p   = rawCoord.split(',');
        final lat = double.tryParse(p[0].trim());
        final lng = double.tryParse(p[1].trim());
        if (lat != null && lng != null &&
            isValidIndonesiaCoord(lat, lng)) {
          finalLat = lat;
          finalLng = lng;
          isDef    = false;
        }
      }
    }

    // ── PRIORITAS 4: sudah ter-handle oleh nilai inisialisasi ─
    // isDef tetap true jika tidak ada prioritas di atas yang berhasil.

    // ── Hitung DAP ────────────────────────────────────────────
    // Cek rev_planting_date dari audit_vegetative dulu,
    // baru fallback ke planting_date_pdn
    String? finalPlantingDate;
    final vegRow = f['audit_vegetative'];
    if (vegRow != null) {
      if (vegRow is List && vegRow.isNotEmpty) {
        finalPlantingDate = vegRow[0]['rev_planting_date']?.toString();
      } else if (vegRow is Map) {
        finalPlantingDate = vegRow['rev_planting_date']?.toString();
      }
    }
    if (finalPlantingDate == null || finalPlantingDate.trim().isEmpty) {
      finalPlantingDate = f['planting_date_pdn']?.toString();
    }

    return ParsedFieldData(
      raw          : f,
      lat          : finalLat,
      lng          : finalLng,
      isDefault    : isDef,
      isCorrected  : isCorrected,
      isFromPolygon: isFromPolygon,
      dap          : DapHelper.calculateDAP(finalPlantingDate),
      geometryWkt  : geometryWkt,  // simpan raw WKT untuk polygon overlay
    );
  }).toList();
}

// ============================================================
// 6. PROVIDER PETA (Menjalankan Isolate)
// ============================================================
final parsedMapFieldsProvider = FutureProvider<List<ParsedFieldData>>((ref) async {
  final rawFields = await ref.watch(masterFieldsProvider.future);

  if (rawFields.isEmpty) return [];

  // Lemparkan tugas parsing yang berat ke thread terpisah menggunakan compute
  return await compute(_parseMapFieldsInIsolate, rawFields);
});