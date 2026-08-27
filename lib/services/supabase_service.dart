import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _supabase;
  final Duration _auditPlanningTimeout;

  SupabaseService({
    SupabaseClient? client,
    Duration auditPlanningTimeout = const Duration(seconds: 45),
  })  : _supabase = client ?? Supabase.instance.client,
        _auditPlanningTimeout = auditPlanningTimeout;

  // Eligibility only: no geometry, crop monitoring or flagging payloads.
  // Keep revised planting dates and PSP passes so weekly targets stay exact.
  static const String _auditPlanningIndexSelect = '''
    field_number,
    season,
    hybrid,
    planting_date_pdn,
    region,
    district_kab,
    sub_district_kec,
    qa_fi,
    qa_spv,
    audit_vegetative(
      rev_planting_date,
      date_of_audit,
      audit_date_user,
      date_of_inspeksi_roguing_1,
      date_of_inspeksi_roguing_2,
      date_of_inspeksi_roguing_3,
      date_of_inspeksi_roguing_4
    ),
    audit_pre_harvest(audit_date),
    audit_harvest(date_of_audit)
  ''';

  static const String _masterFieldMapSelect = '''
    field_number,
    season,
    farmer_name,
    grower,
    hybrid,
    total_area_planted_ha,
    discard_area_ha,
    effective_area_ha,
    planting_date_pdn,
    hamlet_dusun,
    village_desa,
    sub_district_kec,
    district_kab,
    fa,
    field_spv,
    coordinate,
    correction_tagging,
    region,
    area_manager,
    harvested_area_ha,
    harvested_qty_kg,
    previous_crop_data_a_b,
    standing_crops,
    type,
    prov,
    planting_date_rev,
    is_active,
    qa_fi,
    qa_spv,
    planting_ratio,
    planting_space,
    flagging_final,
    target_dt_date,
    season_id,
    geometry_wkt,
    geometry_area_ha,
    geometry_source,
    geometry_updated_at,
    corr_field_size_ha,
    corr_field_size_source,
    corr_field_size_updated_at,
    audit_vegetative(
      date_of_audit,
      rev_planting_date,
      co_detasseling,
      correction_tagging,
      decision,
      action_needed,
      date_of_inspeksi_roguing_1,
      date_of_inspeksi_roguing_2,
      date_of_inspeksi_roguing_3,
      date_of_inspeksi_roguing_4
    ),
    audit_generative(
      date_of_audit_1,
      date_of_audit_2,
      date_of_audit_3,
      date_of_audit_4,
      date_of_audit_5,
      action_needed_1,
      action_needed_2,
      action_needed_3,
      action_needed_4,
      final_decision_3,
      final_decision_5,
      detasseling_assesment_3,
      detasseling_assesment_5
    ),
    audit_pre_harvest(
      audit_date,
      final_decision,
      final_flagging
    ),
    audit_harvest(
      date_of_audit,
      final_flagging,
      status_downgrade,
      downgrade_flagging
    )
  ''';

  // Coverage also reads NC, crop monitoring, flagging and PSP pass observations.
  static const String _masterFieldCoverageSelect = '''
    field_number,
    season,
    farmer_name,
    grower,
    hybrid,
    total_area_planted_ha,
    discard_area_ha,
    effective_area_ha,
    planting_date_pdn,
    hamlet_dusun,
    village_desa,
    sub_district_kec,
    district_kab,
    fa,
    field_spv,
    coordinate,
    correction_tagging,
    region,
    area_manager,
    harvested_area_ha,
    harvested_qty_kg,
    previous_crop_data_a_b,
    standing_crops,
    type,
    prov,
    planting_date_rev,
    is_active,
    qa_fi,
    qa_spv,
    planting_ratio,
    planting_space,
    flagging_final,
    target_dt_date,
    season_id,
    geometry_wkt,
    geometry_area_ha,
    geometry_source,
    geometry_updated_at,
    corr_field_size_ha,
    corr_field_size_source,
    corr_field_size_updated_at,
    audit_vegetative(
      date_of_audit,
      audit_date_user,
      audit_week,
      qa_fi,
      rev_planting_date,
      field_size_by_audit_ha,
      correction_tagging,
      decision,
      action_needed,
      flagging,
      co_detasseling,
      roguing_status,
      lsv_status,
      isolation_problem_by_audit,
      crop_uniformity,
      crop_health,
      date_of_inspeksi_roguing_1,
      date_of_inspeksi_roguing_2,
      date_of_inspeksi_roguing_3,
      date_of_inspeksi_roguing_4,
      audit_lsv_roguing_2,
      audit_lsv_roguing_3,
      audit_lsv_roguing_4,
      crop_health_roguing_1,
      crop_uniformity_roguing_1,
      crop_health_roguing_2,
      crop_uniformity_roguing_2,
      crop_health_roguing_3,
      crop_uniformity_roguing_3,
      crop_health_roguing_4,
      crop_uniformity_roguing_4,
      isolation_audit_roguing_1
    ),
    audit_generative(
      date_of_audit_1,
      week_of_audit_1,
      qa_fi_1,
      roguing_status_1,
      lsv_status_1,
      crop_uniformity_1,
      crop_health_1,
      date_of_audit_2,
      week_of_audit_2,
      qa_fi_2,
      roguing_status_2,
      lsv_status_2,
      crop_uniformity_2,
      crop_health_2,
      date_of_audit_3,
      week_of_audit_3,
      qa_fi_3,
      lsv_status_3,
      crop_uniformity_3,
      crop_health_3,
      date_of_audit_4,
      week_of_audit_4,
      qa_fi_4,
      roguing_status_4,
      lsv_status_4,
      crop_uniformity_4,
      crop_health_4,
      date_of_audit_5,
      week_of_audit_5,
      qa_fi_5,
      lsv_status_5,
      crop_uniformity_5,
      crop_health_5,
      action_needed_1,
      action_needed_2,
      action_needed_3,
      action_needed_4,
      final_decision_3,
      final_decision_5,
      flagging,
      final_flagging_5,
      detasseling_assesment_3,
      detasseling_assesment_5,
      isolation_problem_5,
      submitted_at_5,
      date_of_inspeksi_roguing_5,
      audit_lsv_roguing_5,
      crop_uniformity_roguing_5,
      crop_health_roguing_5,
      isolation_audit_roguing_5,
      flagging_roguing_5,
      date_of_inspeksi_roguing_6,
      audit_lsv_roguing_6,
      crop_uniformity_roguing_6,
      crop_health_roguing_6,
      isolation_audit_roguing_6,
      flagging_roguing_6
    ),
    audit_pre_harvest(
      audit_date,
      audit_week,
      qa_fi,
      final_decision,
      final_flagging,
      male_chopping_rows,
      crop_uniformity,
      crop_health
    ),
    audit_harvest(
      date_of_audit,
      audit_week,
      qa_fi,
      final_flagging,
      status_downgrade,
      downgrade_flagging,
      crop_uniformity,
      crop_health
    )
  ''';

  // ============================================================
  // MASTER FIELDS — Update query untuk tarik semua audit sekaligus
  // ============================================================

  /// Mengambil data ringan untuk peta/list awal.
  ///
  /// Query ini sengaja tidak memakai `*` untuk tabel audit, supaya halaman peta
  /// tidak memuat payload audit lengkap dari semua lahan saat startup.
  Future<List<Map<String, dynamic>>> getMasterFieldsForMap({
    String? qaFi,
    String? qaSpv,
    String? season,
    String? region,
    String? district,
  }) async {
    try {
      final List<Map<String, dynamic>> allData = [];
      const int pageSize = 1000;
      int from = 0;

      while (true) {
        var query = _supabase
            .from('master_fields')
            .select(_masterFieldMapSelect)
            .eq('is_active', true);

        if (qaFi != null && qaFi.trim().isNotEmpty) {
          final fi = qaFi.trim();
          query = query.ilike('qa_fi', '%$fi%');
        }
        if (qaSpv != null && qaSpv.trim().isNotEmpty) {
          final spv = qaSpv.trim();
          query = query.ilike('qa_spv', '%$spv%');
        }
        if (season != null && season.trim().isNotEmpty) {
          query = query.eq('season', season.trim());
        }
        if (region != null && region.trim().isNotEmpty) {
          query = query.eq('region', region.trim());
        }
        if (district != null && district.trim().isNotEmpty) {
          query = query.eq('district_kab', district.trim());
        }

        final response = await query
            .order('field_number', ascending: true)
            .range(from, from + pageSize - 1);

        allData.addAll(List<Map<String, dynamic>>.from(response));

        if (response.length < pageSize) break;
        from += pageSize;
      }

      debugPrint('Total map records fetched: ${allData.length}');
      return allData;
    } catch (e) {
      throw Exception('Gagal mengambil data peta master Supabase: $e');
    }
  }

  /// Mengambil field tertentu saja untuk form batch/mass inspection.
  Future<List<Map<String, dynamic>>> getMasterFieldsByFieldNumbers(
    List<String> fieldNumbers,
  ) async {
    try {
      final normalized = fieldNumbers
          .map((fieldNumber) => fieldNumber.trim())
          .where((fieldNumber) => fieldNumber.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (normalized.isEmpty) return const [];

      final allData = <Map<String, dynamic>>[];
      const chunkSize = 100;

      for (var i = 0; i < normalized.length; i += chunkSize) {
        final end = i + chunkSize > normalized.length
            ? normalized.length
            : i + chunkSize;
        final chunk = normalized.sublist(i, end);

        final response = await _supabase
            .from('master_fields')
            .select(_masterFieldMapSelect)
            .eq('is_active', true)
            .inFilter('field_number', chunk)
            .order('field_number', ascending: true);

        allData.addAll(List<Map<String, dynamic>>.from(response));
      }

      debugPrint('Total selected field records fetched: ${allData.length}');
      return allData;
    } catch (e) {
      throw Exception('Gagal mengambil data field terpilih Supabase: $e');
    }
  }

  Future<String?> getLatestActiveMasterFieldSeason() async {
    try {
      final response = await _supabase
          .from('master_fields')
          .select('season')
          .eq('is_active', true)
          .not('season', 'is', null)
          .neq('season', '')
          .order('season', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;
      final season = response.first['season']?.toString().trim();
      return season == null || season.isEmpty ? null : season;
    } catch (e) {
      debugPrint('Gagal mengambil season terbaru: $e');
      return null;
    }
  }

  Future<List<String>> getActiveMasterFieldSeasons() async {
    try {
      final response = await _supabase.rpc('get_active_master_field_seasons');
      return List<Map<String, dynamic>>.from(response)
          .map((row) => row['season']?.toString().trim() ?? '')
          .where((season) => season.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return _getActiveMasterFieldSeasonsFallback();
    }
  }

  Future<List<String>> _getActiveMasterFieldSeasonsFallback() async {
    try {
      final seasons = <String>{};
      const int pageSize = 1000;
      int from = 0;

      while (true) {
        final response = await _supabase
            .from('master_fields')
            .select('season')
            .eq('is_active', true)
            .not('season', 'is', null)
            .neq('season', '')
            .order('season', ascending: false)
            .range(from, from + pageSize - 1);

        for (final row in response) {
          final season = row['season']?.toString().trim();
          if (season != null && season.isNotEmpty) seasons.add(season);
        }

        if (response.length < pageSize) break;
        from += pageSize;
      }

      final result = seasons.toList()..sort((a, b) => b.compareTo(a));
      return result;
    } catch (e) {
      debugPrint('Gagal mengambil daftar season: $e');
      return const [];
    }
  }

  Future<List<String>> getActiveMasterFieldRegions({
    String? season,
    String? qaFi,
    String? qaSpv,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_active_master_field_regions',
        params: {
          'p_season': season?.trim().isEmpty == true ? null : season,
          'p_qa_fi': qaFi?.trim().isEmpty == true ? null : qaFi,
          'p_qa_spv': qaSpv?.trim().isEmpty == true ? null : qaSpv,
        },
      );
      return List<Map<String, dynamic>>.from(response)
          .map((row) => row['region']?.toString().trim() ?? '')
          .where((region) => region.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return _getActiveMasterFieldRegionsFallback(
        season: season,
        qaFi: qaFi,
        qaSpv: qaSpv,
      );
    }
  }

  Future<List<String>> _getActiveMasterFieldRegionsFallback({
    String? season,
    String? qaFi,
    String? qaSpv,
  }) async {
    try {
      final regions = <String>{};
      const int pageSize = 1000;
      int from = 0;

      while (true) {
        var query = _supabase
            .from('master_fields')
            .select('region')
            .eq('is_active', true)
            .not('region', 'is', null)
            .neq('region', '');

        if (season != null && season.trim().isNotEmpty) {
          query = query.eq('season', season.trim());
        }
        if (qaFi != null && qaFi.trim().isNotEmpty) {
          query = query.ilike('qa_fi', '%${qaFi.trim()}%');
        }
        if (qaSpv != null && qaSpv.trim().isNotEmpty) {
          query = query.ilike('qa_spv', '%${qaSpv.trim()}%');
        }

        final response = await query
            .order('region', ascending: true)
            .range(from, from + pageSize - 1);

        for (final row in response) {
          final region = row['region']?.toString().trim();
          if (region != null && region.isNotEmpty) regions.add(region);
        }

        if (response.length < pageSize) break;
        from += pageSize;
      }

      final result = regions.toList()..sort();
      return result;
    } catch (e) {
      debugPrint('Gagal mengambil daftar region: $e');
      return const [];
    }
  }

  /// Mengambil data ringkas untuk coverage monitoring.
  ///
  /// Coverage butuh status audit dan action flags, tapi tidak perlu semua kolom
  /// audit lengkap untuk setiap field saat layar pertama dibuka.
  Future<List<Map<String, dynamic>>> getMasterFieldsForCoverage({
    String? qaFi,
    String? qaSpv,
    String? season,
    String? region,
    String? district,
  }) async {
    try {
      final List<Map<String, dynamic>> allData = [];
      const int pageSize = 1000;
      int from = 0;

      while (true) {
        var query = _supabase
            .from('master_fields')
            .select(_masterFieldCoverageSelect)
            .eq('is_active', true);

        if (qaFi != null && qaFi.trim().isNotEmpty) {
          final fi = qaFi.trim();
          query = query.ilike('qa_fi', '%$fi%');
        }
        if (qaSpv != null && qaSpv.trim().isNotEmpty) {
          final spv = qaSpv.trim();
          query = query.ilike('qa_spv', '%$spv%');
        }
        if (season != null && season.trim().isNotEmpty) {
          query = query.eq('season', season.trim());
        }
        if (region != null && region.trim().isNotEmpty) {
          query = query.eq('region', region.trim());
        }
        if (district != null && district.trim().isNotEmpty) {
          query = query.eq('district_kab', district.trim());
        }

        final response = await query
            .order('field_number', ascending: true)
            .range(from, from + pageSize - 1);

        allData.addAll(List<Map<String, dynamic>>.from(response));

        if (response.length < pageSize) break;
        from += pageSize;
      }

      debugPrint('Total coverage records fetched: ${allData.length}');
      return allData;
    } catch (e) {
      throw Exception('Gagal mengambil data coverage Supabase: $e');
    }
  }

  /// A small, reusable index for weekly planning, scoped before downloading.
  /// Full coverage rows are fetched separately, only for eligible field numbers.
  Future<List<Map<String, dynamic>>> getAuditPlanningIndex({
    String? qaFi,
    String? qaSpv,
    String? region,
    String? district,
    String? season,
  }) async {
    final timer = Stopwatch()..start();
    final rows = <Map<String, dynamic>>[];
    const pageSize = 1000;
    for (var from = 0;; from += pageSize) {
      final remaining = _auditPlanningTimeRemaining(timer);
      final page = await _auditPlanningQuery(
        _auditPlanningIndexSelect,
        qaFi: qaFi,
        qaSpv: qaSpv,
        region: region,
        district: district,
        season: season,
      )
          .order('field_number', ascending: true)
          .range(from, from + pageSize - 1)
          .timeout(remaining);
      rows.addAll(page);
      if (page.length < pageSize) break;
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAuditPlanningFields(
    List<String> fieldNumbers, {
    String? qaFi,
    String? qaSpv,
    String? region,
    String? district,
    String? season,
  }) async {
    final numbers = fieldNumbers
        .map((number) => number.trim())
        .where((number) => number.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final timer = Stopwatch()..start();
    final rows = <Map<String, dynamic>>[];
    const chunkSize = 100;
    for (var i = 0; i < numbers.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, numbers.length);
      final remaining = _auditPlanningTimeRemaining(timer);
      final page = await _auditPlanningQuery(
        _masterFieldCoverageSelect,
        qaFi: qaFi,
        qaSpv: qaSpv,
        region: region,
        district: district,
        season: season,
      )
          .inFilter('field_number', numbers.sublist(i, end))
          .order('field_number', ascending: true)
          .timeout(remaining);
      rows.addAll(page);
    }
    return rows;
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _auditPlanningQuery(
    String columns, {
    String? qaFi,
    String? qaSpv,
    String? region,
    String? district,
    String? season,
  }) {
    var query =
        _supabase.from('master_fields').select(columns).eq('is_active', true);
    if (qaFi != null && qaFi.trim().isNotEmpty) {
      query = query.ilike('qa_fi', '%${qaFi.trim()}%');
    }
    if (qaSpv != null && qaSpv.trim().isNotEmpty) {
      query = query.ilike('qa_spv', '%${qaSpv.trim()}%');
    }
    if (region != null && region.trim().isNotEmpty) {
      query = query.eq('region', region.trim());
    }
    if (district != null && district.trim().isNotEmpty) {
      query = query.eq('district_kab', district.trim());
    }
    if (season != null && season.trim().isNotEmpty) {
      query = query.eq('season', season.trim());
    }
    return query;
  }

  Duration _auditPlanningTimeRemaining(Stopwatch timer) {
    final remaining = _auditPlanningTimeout - timer.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException(
          'Pengambilan data planning terlalu lama.', _auditPlanningTimeout);
    }
    return remaining;
  }

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
        var query = _supabase.from('master_fields').select('''
            *,
            audit_vegetative(*),
            audit_generative(*),
            audit_pre_harvest(*),
            audit_harvest(*)
          ''').eq('is_active', true);

        if (qaFi != null && qaFi.trim().isNotEmpty) {
          final fi = qaFi.trim();
          query = query.ilike('qa_fi', '%$fi%');
        }
        if (qaSpv != null && qaSpv.trim().isNotEmpty) {
          final spv = qaSpv.trim();
          query = query.ilike('qa_spv', '%$spv%');
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
        debugPrint(
            'audit_vegetative type: ${first['audit_vegetative'].runtimeType}');
        debugPrint(
            'audit_generative type: ${first['audit_generative'].runtimeType}');
        debugPrint(
            'audit_pre_harvest type: ${first['audit_pre_harvest'].runtimeType}');
        debugPrint('audit_harvest type: ${first['audit_harvest'].runtimeType}');
      }
      return allData;
    } catch (e) {
      throw Exception('Gagal mengambil data master Supabase: $e');
    }
  }

  /// Mengambil satu field beserta audit lengkapnya untuk detail sheet/form.
  Future<Map<String, dynamic>?> getMasterFieldWithAllAudits(
    String fieldNumber,
  ) async {
    try {
      final response = await _supabase.from('master_fields').select('''
            *,
            audit_vegetative(*),
            audit_generative(*),
            audit_pre_harvest(*),
            audit_harvest(*)
          ''').eq('field_number', fieldNumber).maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil detail field Supabase: $e');
    }
  }

  Future<void> updateFieldGeometryWkt({
    required String fieldNumber,
    required String geometryWkt,
    String? geometrySource,
    double? geometryAreaHa,
    int? geometryPointCount,
    String? geometryUpdatedBy,
    String? geometryEditNote,
    double? corrFieldSizeHa,
    String? corrFieldSizeSource,
    String? corrFieldSizeUpdatedBy,
    String? corrFieldSizeNote,
  }) async {
    final payload = <String, dynamic>{'geometry_wkt': geometryWkt};
    final hasGeometryMetadata = geometrySource != null ||
        geometryAreaHa != null ||
        geometryPointCount != null ||
        geometryUpdatedBy != null ||
        geometryEditNote != null;
    final hasCorrFieldSize = corrFieldSizeHa != null ||
        corrFieldSizeSource != null ||
        corrFieldSizeUpdatedBy != null ||
        corrFieldSizeNote != null;

    if (hasGeometryMetadata) {
      payload.addAll({
        'geometry_source': geometrySource,
        'geometry_area_ha': geometryAreaHa,
        'geometry_point_count': geometryPointCount,
        'geometry_updated_by': geometryUpdatedBy,
        'geometry_updated_at': DateTime.now().toIso8601String(),
        'geometry_edit_note': geometryEditNote,
      });
    }
    if (hasCorrFieldSize) {
      payload.addAll({
        'corr_field_size_ha': corrFieldSizeHa,
        'corr_field_size_source': corrFieldSizeSource,
        'corr_field_size_updated_by': corrFieldSizeUpdatedBy,
        'corr_field_size_updated_at': DateTime.now().toIso8601String(),
        'corr_field_size_note': corrFieldSizeNote,
      });
    }

    try {
      final updatedRows = await _supabase
          .from('master_fields')
          .update(payload)
          .eq('field_number', fieldNumber)
          .select('field_number');

      if (updatedRows.isEmpty) {
        throw Exception('field_number tidak ditemukan: $fieldNumber');
      }
    } catch (e) {
      if (hasGeometryMetadata || hasCorrFieldSize) {
        try {
          final updatedRows = await _supabase
              .from('master_fields')
              .update({'geometry_wkt': geometryWkt})
              .eq('field_number', fieldNumber)
              .select('field_number');

          if (updatedRows.isEmpty) {
            throw Exception('field_number tidak ditemukan: $fieldNumber');
          }
          return;
        } catch (_) {
          // Keep the original metadata update error below for clearer diagnostics.
        }
      }
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
      return await _supabase
          .from('audit_vegetative')
          .select()
          .eq('field_number', fieldNumber)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit vegetative: $e');
    }
  }

  Future<void> upsertVegetativeAudit(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _saveAuditByFieldNumber(
        tableName: 'audit_vegetative',
        data: data,
        errorContext: 'Gagal menyimpan audit vegetative',
      );
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
      _applyDetasselingDateDefaults(data, checkpoint);
      // Tambahkan timestamp submission untuk checkpoint tsb
      data['submitted_at_$checkpoint'] = DateTime.now().toIso8601String();

      await _saveAuditByFieldNumber(
        tableName: 'audit_generative',
        data: data,
        errorContext: 'Gagal menyimpan audit generative-$checkpoint',
      );
    } catch (e) {
      throw Exception('Gagal menyimpan audit generative-$checkpoint: $e');
    }
  }

  void _applyDetasselingDateDefaults(
    Map<String, dynamic> data,
    int checkpoint,
  ) {
    final auditDateKey = 'date_of_audit_$checkpoint';
    final auditDate = data[auditDateKey];
    if (auditDate == null || auditDate.toString().trim().isEmpty) return;

    data.putIfAbsent('actual_dt_date_$checkpoint', () => auditDate);
    data.putIfAbsent('audit_fi_date_$checkpoint', () => auditDate);

    final helper = data['audit_helper_$checkpoint']?.toString().trim() ?? '';
    data.putIfAbsent(
      'audit_helper_date_$checkpoint',
      () => helper.isEmpty ? null : auditDate,
    );
  }

  // Backward compatibility atau jika masih butuh function spesifik
  Future<void> upsertGenerative1Audit(Map<String, dynamic> data) async =>
      upsertGenerativeCheckpoint(
          fieldNumber: data['field_number'], checkpoint: 1, data: data);

  Future<void> upsertGenerative2Audit(Map<String, dynamic> data) async =>
      upsertGenerativeCheckpoint(
          fieldNumber: data['field_number'], checkpoint: 2, data: data);

  Future<void> upsertGenerative3Audit(Map<String, dynamic> data) async =>
      upsertGenerativeCheckpoint(
          fieldNumber: data['field_number'], checkpoint: 3, data: data);

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
              data: record);
        } else {
          final tableName = _phaseToTable(phase);
          record['updated_at'] = DateTime.now().toIso8601String();
          record['is_mass_submit'] = true;
          await _saveAuditByFieldNumber(
            tableName: tableName,
            data: record,
            errorContext: 'Gagal bulk upsert $phase',
          );
        }
      }
    } catch (e) {
      throw Exception('Gagal bulk upsert $phase: $e');
    }
  }

  String _phaseToTable(String phase) {
    switch (phase) {
      case 'vegetative':
        return 'audit_vegetative';
      case 'generative':
        return 'audit_generative';
      case 'pre_harvest':
        return 'audit_pre_harvest';
      case 'harvest':
        return 'audit_harvest';
      default:
        throw Exception('Unknown phase: $phase');
    }
  }

  Future<void> _saveAuditByFieldNumber({
    required String tableName,
    required Map<String, dynamic> data,
    required String errorContext,
  }) async {
    final fieldNumber = data['field_number']?.toString().trim();
    if (fieldNumber == null || fieldNumber.isEmpty) {
      throw Exception('$errorContext: field_number kosong');
    }

    final payload = Map<String, dynamic>.from(data);
    final droppedColumns = <String>{};
    var useManualFallback = false;

    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        if (useManualFallback) {
          await _manualSaveAuditByFieldNumber(tableName, payload, fieldNumber);
        } else {
          await _supabase
              .from(tableName)
              .upsert(payload, onConflict: 'field_number');
        }

        if (kDebugMode && droppedColumns.isNotEmpty) {
          debugPrint(
            '$tableName saved without unsupported columns: '
            '${droppedColumns.join(', ')}',
          );
        }
        return;
      } catch (e) {
        final missingColumns = _missingPayloadColumnsFromError(
          e,
          payload.keys.toSet(),
        );

        if (missingColumns.isNotEmpty) {
          var removedAny = false;
          for (final column in missingColumns) {
            if (column == 'field_number') continue;
            removedAny = payload.remove(column) != null || removedAny;
            droppedColumns.add(column);
          }
          if (removedAny) continue;
        }

        if (!useManualFallback && _isMissingOnConflictConstraint(e)) {
          useManualFallback = true;
          continue;
        }

        throw Exception('$errorContext: $e');
      }
    }

    throw Exception(
      '$errorContext: gagal menyimpan setelah retry fallback schema',
    );
  }

  Future<void> _manualSaveAuditByFieldNumber(
    String tableName,
    Map<String, dynamic> payload,
    String fieldNumber,
  ) async {
    final existing = await _supabase
        .from(tableName)
        .select('field_number')
        .eq('field_number', fieldNumber)
        .limit(1)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from(tableName).insert(payload);
    } else {
      await _supabase
          .from(tableName)
          .update(payload)
          .eq('field_number', fieldNumber);
    }
  }

  Set<String> _missingPayloadColumnsFromError(
    Object error,
    Set<String> payloadColumns,
  ) {
    final text = error.toString();
    final missing = <String>{};
    final patterns = <RegExp>[
      RegExp(r"Could not find the '([^']+)' column"),
      RegExp(
          r'column [A-Za-z_][A-Za-z0-9_]*\.([A-Za-z_][A-Za-z0-9_]*) does not exist'),
      RegExp(r'column "([^"]+)" does not exist'),
      RegExp(r'column ([A-Za-z_][A-Za-z0-9_]*) does not exist'),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final column = match.group(1);
        if (column != null && payloadColumns.contains(column)) {
          missing.add(column);
        }
      }
    }
    return missing;
  }

  bool _isMissingOnConflictConstraint(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('42p10') ||
        text.contains('no unique or exclusion constraint') ||
        text.contains('there is no unique or exclusion constraint matching');
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
      final activeUserId = _supabase.auth.currentUser?.id ?? userId;
      await _supabase.from('attendance_activity').insert({
        'attendance_id': attendanceId,
        'user_id': activeUserId,
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
  Future<List<Map<String, dynamic>>> getTodayActivities(
      String attendanceId) async {
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
      return await _supabase
          .from('audit_pre_harvest')
          .select()
          .eq('field_number', fieldNumber)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit pre-harvest: $e');
    }
  }

  Future<void> upsertPreHarvestAudit(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _saveAuditByFieldNumber(
        tableName: 'audit_pre_harvest',
        data: data,
        errorContext: 'Gagal menyimpan audit pre-harvest',
      );
    } catch (e) {
      throw Exception('Gagal menyimpan audit pre-harvest: $e');
    }
  }

  // ==========================================
  // FUNGSI UNTUK AUDIT HARVEST
  // ==========================================
  Future<Map<String, dynamic>?> getHarvestAudit(String fieldNumber) async {
    try {
      return await _supabase
          .from('audit_harvest')
          .select()
          .eq('field_number', fieldNumber)
          .maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit harvest: $e');
    }
  }

  Future<void> upsertHarvestAudit(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toIso8601String();
      await _saveAuditByFieldNumber(
        tableName: 'audit_harvest',
        data: data,
        errorContext: 'Gagal menyimpan audit harvest',
      );
    } catch (e) {
      throw Exception('Gagal menyimpan audit harvest: $e');
    }
  }
}
