import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // MASTER FIELDS — Update query untuk tarik semua audit sekaligus
  // ============================================================

  /// Mengambil data master fields beserta semua data audit terkait.
  /// Generative sekarang menggunakan 1 tabel (audit_generative).
  Future<List<Map<String, dynamic>>> getMasterFieldsWithAllAudits({
    String? qaFi,
    String? qaSpv,
  }) async {
    try {
      final List<Map<String, dynamic>> allData = [];
      const int pageSize = 1000;
      int from = 0;

      while (true) {
        var query = _supabase
            .from('master_fields')
            .select('''
            *,
            audit_vegetative(*),
            audit_generative(*),
            audit_pre_harvest(*),
            audit_harvest(*)
          ''')
            .eq('is_active', true);

        if (qaFi != null && qaFi.trim().isNotEmpty) {
          final fi = qaFi.trim();
          query = query.or('qa_fi.ilike.$fi,qa_fi_list.ilike.*$fi*');
        }
        if (qaSpv != null && qaSpv.trim().isNotEmpty) {
          query = query.ilike('qa_spv', qaSpv.trim());
        }

        final response = await query
            .order('field_number', ascending: true)
            .range(from, from + pageSize - 1);

        allData.addAll(List<Map<String, dynamic>>.from(response));

        if (response.length < pageSize) break;
        from += pageSize;
      }

      debugPrint('Total active records fetched: ${allData.length}');
      if (allData.isNotEmpty) {
        // Debug: cek struktur data pertama
        final first = allData.first;
        debugPrint('Sample field_number: ${first['field_number']}');
        debugPrint('Sample effective_area_ha: ${first['effective_area_ha']}');
        debugPrint('Sample qa_fi: ${first['qa_fi']}');
        debugPrint('Sample planting_date_pdn: ${first['planting_date_pdn']}');
        debugPrint('audit_vegetative type: ${first['audit_vegetative'].runtimeType}');
        debugPrint('audit_generative type: ${first['audit_generative'].runtimeType}');
        debugPrint('audit_pre_harvest type: ${first['audit_pre_harvest'].runtimeType}');
        debugPrint('audit_harvest type: ${first['audit_harvest'].runtimeType}');
      }
      return allData;
    } catch (e) {
      throw Exception('Gagal mengambil data master Supabase: $e');
    }
  }

  Future<void> updateFieldGeometryWkt({
    required String fieldNumber,
    required String geometryWkt,
  }) async {
    try {
      await _supabase
          .from('master_fields')
          .update({'geometry_wkt': geometryWkt})
          .eq('field_number', fieldNumber);
    } catch (e) {
      throw Exception('Gagal menyimpan polygon lahan: $e');
    }
  }

  Future<void> updateFieldCorrectionTagging({
    required String fieldNumber,
    required String correctionTagging,
  }) async {
    final now = DateTime.now().toIso8601String();

    try {
      final updatedAuditRows = await _supabase
          .from('audit_vegetative')
          .update({
            'correction_tagging': correctionTagging,
            'updated_at': now,
          })
          .eq('field_number', fieldNumber)
          .select('field_number');

      if (updatedAuditRows.isNotEmpty) return;

      try {
        final updatedMasterRows = await _supabase
            .from('master_fields')
            .update({'correction_tagging': correctionTagging})
            .eq('field_number', fieldNumber)
            .select('field_number');

        if (updatedMasterRows.isNotEmpty) return;
      } catch (_) {
        // Some deployments keep correction_tagging only in audit_vegetative.
      }

      await _supabase.from('audit_vegetative').upsert({
        'field_number': fieldNumber,
        'correction_tagging': correctionTagging,
        'updated_at': now,
      }, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan correction tagging: $e');
    }
  }

  // ==========================================
  // FUNGSI UNTUK AUDIT VEGETATIVE
  // ==========================================
  Future<Map<String, dynamic>?> getVegetativeAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_vegetative').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit vegetative: $e');
    }
  }

  Future<void> upsertVegetativeAudit(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('audit_vegetative').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit vegetative: $e');
    }
  }

  // ============================================================
  // GENERATIVE — 1 Tabel untuk 3 Checkpoint
  // ============================================================

  Future<Map<String, dynamic>?> getGenerativeAudit(String fieldNumber) async {
    try {
      return await _supabase
          .from('audit_generative')
          .select()
          .eq('field_number', fieldNumber)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit generative: $e');
    }
  }

  /// Upsert data untuk checkpoint tertentu (1, 2, atau 3)
  Future<void> upsertGenerativeCheckpoint({
    required String fieldNumber,
    required int checkpoint,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Pastikan field_number ada di data
      data['field_number'] = fieldNumber;
      // Tambahkan timestamp submission untuk checkpoint tsb
      data['submitted_at_$checkpoint'] = DateTime.now().toIso8601String();

      await _supabase
          .from('audit_generative')
          .upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit generative-$checkpoint: $e');
    }
  }

  // Backward compatibility atau jika masih butuh function spesifik
  Future<void> upsertGenerative1Audit(Map<String, dynamic> data) async =>
      upsertGenerativeCheckpoint(fieldNumber: data['field_number'], checkpoint: 1, data: data);

  Future<void> upsertGenerative2Audit(Map<String, dynamic> data) async =>
      upsertGenerativeCheckpoint(fieldNumber: data['field_number'], checkpoint: 2, data: data);

  Future<void> upsertGenerative3Audit(Map<String, dynamic> data) async =>
      upsertGenerativeCheckpoint(fieldNumber: data['field_number'], checkpoint: 3, data: data);

  // ============================================================
  // MASS INSPECTION — Bulk upsert
  // ============================================================

  /// Menerima list of records, upsert satu-per-satu ke tabel yang sesuai.
  /// phase: 'vegetative' | 'generative_1' | 'generative_2' | 'generative_3'
  ///        | 'pre_harvest' | 'harvest'
  Future<void> bulkUpsertInspection({
    required String phase,
    required List<Map<String, dynamic>> records,
  }) async {
    try {
      for (final record in records) {
        if (phase.startsWith('generative_')) {
          final checkpoint = int.parse(phase.split('_')[1]);
          record['is_mass_submit_$checkpoint'] = true;
          await upsertGenerativeCheckpoint(
              fieldNumber: record['field_number'],
              checkpoint: checkpoint,
              data: record
          );
        } else {
          final tableName = _phaseToTable(phase);
          record['updated_at'] = DateTime.now().toIso8601String();
          record['is_mass_submit'] = true;
          await _supabase
              .from(tableName)
              .upsert(record, onConflict: 'field_number');
        }
      }
    } catch (e) {
      throw Exception('Gagal bulk upsert $phase: $e');
    }
  }

  String _phaseToTable(String phase) {
    switch (phase) {
      case 'vegetative': return 'audit_vegetative';
      case 'generative': return 'audit_generative';
      case 'pre_harvest': return 'audit_pre_harvest';
      case 'harvest': return 'audit_harvest';
      default: throw Exception('Unknown phase: $phase');
    }
  }

  // ============================================================
  // ATTENDANCE — Header & Activity
  // ============================================================

  Future<Map<String, dynamic>?> getTodayAttendance(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      return await _supabase
          .from('attendance_header')
          .select()
          .eq('user_id', userId)
          .eq('attendance_date', today)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data absensi: $e');
    }
  }

  Future<String> checkIn({
    required String userId,
    required double lat,
    required double lng,
    String? photoUrl,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final result = await _supabase
          .from('attendance_header')
          .upsert({
        'user_id': userId,
        'attendance_date': today,
        'check_in_time': DateTime.now().toIso8601String(),
        'check_in_lat': lat,
        'check_in_lng': lng,
        'check_in_photo': photoUrl,
        'status': 'open',
      }, onConflict: 'user_id,attendance_date')
          .select('attendance_id')
          .single();
      return result['attendance_id'];
    } catch (e) {
      throw Exception('Gagal check-in: $e');
    }
  }

  Future<void> checkOut({
    required String userId,
    required double lat,
    required double lng,
    String? notes,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _supabase
          .from('attendance_header')
          .update({
        'check_out_time': DateTime.now().toIso8601String(),
        'check_out_lat': lat,
        'check_out_lng': lng,
        'notes': notes,
        'status': 'closed',
      })
          .eq('user_id', userId)
          .eq('attendance_date', today);
    } catch (e) {
      throw Exception('Gagal check-out: $e');
    }
  }

  Future<void> logActivity({
    required String attendanceId,
    required String userId,
    required String fieldNumber,
    required String phase,
    required String actionType,
    required double lat,
    required double lng,
    String? referenceInspectionId,
  }) async {
    try {
      await _supabase.from('attendance_activity').insert({
        'attendance_id': attendanceId,
        'user_id': userId,
        'field_number': fieldNumber,
        'phase': phase,
        'action_type': actionType,
        'action_time': DateTime.now().toIso8601String(),
        'lat': lat,
        'lng': lng,
        'reference_inspection_id': referenceInspectionId,
      });
    } catch (e) {
      debugPrint('Warning: Gagal log activity: $e');
    }
  }

  // [BARU DITAMBAHKAN] Fungsi untuk mengambil data aktivitas hari ini
  Future<List<Map<String, dynamic>>> getTodayActivities(String attendanceId) async {
    try {
      final response = await _supabase
          .from('attendance_activity')
          .select()
          .eq('attendance_id', attendanceId)
          .order('action_time', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getTodayActivities: $e');
      throw Exception('Gagal mengambil data aktivitas hari ini: $e');
    }
  }

  // ==========================================
  // FUNGSI UNTUK AUDIT PRE-HARVEST
  // ==========================================
  Future<Map<String, dynamic>?> getPreHarvestAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_pre_harvest').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit pre-harvest: $e');
    }
  }

  Future<void> upsertPreHarvestAudit(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('audit_pre_harvest').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit pre-harvest: $e');
    }
  }

  // ==========================================
  // FUNGSI UNTUK AUDIT HARVEST
  // ==========================================
  Future<Map<String, dynamic>?> getHarvestAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_harvest').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit harvest: $e');
    }
  }

  Future<void> upsertHarvestAudit(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('audit_harvest').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit harvest: $e');
    }
  }
}
