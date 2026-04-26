import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/session_manager.dart';
import '../utils/dap_helper.dart'; // PASTIKAN IMPORT INI SESUAI

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
  final int dap;

  ParsedFieldData({
    required this.raw,
    required this.lat,
    required this.lng,
    required this.isDefault,
    required this.isCorrected,
    required this.dap,
  });
}

// ============================================================
// 5. FUNGSI TOP-LEVEL UNTUK ISOLATE
// (Syarat Isolate: fungsi harus diluar class atau berupa static)
// ============================================================
List<ParsedFieldData> _parseMapFieldsInIsolate(List<Map<String, dynamic>> rawFields) {
  // Fungsi bantuan kecil di dalam Isolate
  bool isValidIndonesiaCoord(double lat, double lng) {
    return lat >= -11.0 && lat <= 6.0 &&
        lng >= 95.0  && lng <= 141.0 &&
        !(lat == 0.0 && lng == 0.0);
  }

  return rawFields.map((f) {
    final correctionCoord = f['correction_tagging']?.toString();
    final rawCoord = f['coordinate']?.toString();

    double? finalLat;
    double? finalLng;
    bool isCorrected = false;
    bool isDef = false;

    // 1. Cek koordinat koreksi
    if (correctionCoord != null && correctionCoord.trim().isNotEmpty && correctionCoord.contains(',')) {
      final cp = correctionCoord.split(',');
      final clat = double.tryParse(cp[0].trim());
      final clng = double.tryParse(cp[1].trim());
      if (clat != null && clng != null && isValidIndonesiaCoord(clat, clng)) {
        finalLat = clat;
        finalLng = clng;
        isCorrected = true;
      }
    }

    // 2. Jika tidak ada koreksi, cek koordinat default
    if (finalLat == null || finalLng == null) {
      if (rawCoord == null || rawCoord.trim().isEmpty || !rawCoord.contains(',')) {
        finalLat = -7.637017;
        finalLng = 112.8272303;
        isDef = true;
      } else {
        final p = rawCoord.split(',');
        final lat = double.tryParse(p[0].trim());
        final lng = double.tryParse(p[1].trim());
        if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
          finalLat = -7.637017;
          finalLng = 112.8272303;
          isDef = true;
        } else {
          finalLat = lat;
          finalLng = lng;
        }
      }
    }

    // 3. Hitung DAP (Cek rev_planting_date dari audit_vegetative dulu, baru fallback ke planting_date_pdn)
    String? finalPlantingDate;
    final vegRow = f['audit_vegetative'];

    // Ekstrak data dari relasi Supabase (bisa berupa List atau Map)
    if (vegRow != null) {
      if (vegRow is List && vegRow.isNotEmpty) {
        finalPlantingDate = vegRow[0]['rev_planting_date']?.toString();
      } else if (vegRow is Map) {
        finalPlantingDate = vegRow['rev_planting_date']?.toString();
      }
    }

    // Jika tidak ada rev_planting_date atau kosong, pakai planting_date_pdn bawaan
    if (finalPlantingDate == null || finalPlantingDate.trim().isEmpty) {
      finalPlantingDate = f['planting_date_pdn']?.toString();
    }

    final dap = DapHelper.calculateDAP(finalPlantingDate);

    return ParsedFieldData(
      raw: f,
      lat: finalLat,
      lng: finalLng,
      isDefault: isDef,
      isCorrected: isCorrected,
      dap: dap,
    );
  }).toList();
}

// ============================================================
// 6. PROVIDER PETA (Menjalankan Isolate)
// ============================================================
final parsedMapFieldsProvider = FutureProvider<List<ParsedFieldData>>((ref) async {
  // Tunggu data mentah dari provider utama
  final rawFields = await ref.watch(masterFieldsProvider.future);

  if (rawFields.isEmpty) return [];

  // Lemparkan tugas parsing yang berat ke thread terpisah menggunakan compute
  return await compute(_parseMapFieldsInIsolate, rawFields);
});