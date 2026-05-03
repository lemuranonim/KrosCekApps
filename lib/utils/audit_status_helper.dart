// lib/utils/audit_status_helper.dart
//
// Helper untuk menentukan status audit per fase.
//
// STRUKTUR DATA DARI SUPABASE (hasil getMasterFieldsWithAllAudits):
//   raw['audit_vegetative']  → List<Map> atau null, punya kolom 'date_of_audit'
//   raw['audit_generative']  → List<Map> atau null, punya:
//                               'date_of_audit_1' s/d 'date_of_audit_5'
//   raw['audit_pre_harvest'] → List<Map> atau null, punya kolom 'audit_date'
//   raw['audit_harvest']     → List<Map> atau null, punya kolom 'date_of_audit'
//
// ── LOGIKA STATUS ────────────────────────────────────────────────────────
//   Vegetatif   : date_of_audit terisi → Sampun
//   Pre-Harvest : audit_date terisi    → Sampun
//   Harvest     : date_of_audit terisi → Sampun
//
//   Generatif:
//     Semua CP terisi      → Sampun (FC: 3 CP, SC: 5 CP)
//     Sebagian terisi      → Dereng Jangkep
//     Semua kosong         → Dereng Blas
// ─────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'active_phase_filter.dart';
import 'dap_helper.dart';

enum SingleAuditStatus { sampun, dereng }

enum GenerativeAuditStatus { sampun, derengJangkep, derengBlas }

class FieldAuditStatus {
  final SingleAuditStatus vegetative;
  final GenerativeAuditStatus generative;
  final SingleAuditStatus preHarvest;
  final SingleAuditStatus harvest;
  final bool gen1Done;
  final bool gen2Done;
  final bool gen3Done;
  final bool gen4Done;
  final bool gen5Done;
  final bool isSweetCorn;

  const FieldAuditStatus({
    required this.vegetative,
    required this.generative,
    required this.preHarvest,
    required this.harvest,
    required this.gen1Done,
    required this.gen2Done,
    required this.gen3Done,
    required this.gen4Done,
    required this.gen5Done,
    this.isSweetCorn = false,
  });

  bool get isCompletelyUnaudited =>
      vegetative == SingleAuditStatus.dereng &&
          generative == GenerativeAuditStatus.derengBlas &&
          preHarvest == SingleAuditStatus.dereng &&
          harvest == SingleAuditStatus.dereng;

  bool isActivePhaseDone(int dap) {
    final hybrid = isSweetCorn ? 'AX01' : null;
    final phase = DapHelper.getActivePhaseView(dap, hybrid: hybrid);
    return isAuditDoneFor(phase, dap);
  }

  /// Menentukan apakah audit sudah selesai untuk fase tertentu pada DAP tertentu.
  /// Sangat berguna untuk logika "Time Traveller" agar status Sampun/Dereng
  /// menyesuaikan dengan sub-fase (terutama di Generatif).
  bool isAuditDoneFor(ActivePhaseView phase, int dap) {
    switch (phase) {
      case ActivePhaseView.vegetative:
        return vegetative == SingleAuditStatus.sampun;
      case ActivePhaseView.generative:
        return _isGenerativeAuditDoneForDap(dap);
      case ActivePhaseView.preHarvest:
        return preHarvest == SingleAuditStatus.sampun;
      case ActivePhaseView.harvest:
        return harvest == SingleAuditStatus.sampun;
      case ActivePhaseView.auto:
        return isActivePhaseDone(dap);
    }
  }

  bool _isGenerativeAuditDoneForDap(int dap) {
    final hybrid = isSweetCorn ? 'AX01' : null;
    final phaseKey = DapHelper.getRecommendedPhase(dap, hybrid: hybrid);

    switch (phaseKey) {
      case 'generative_1':
        return gen1Done;
      case 'generative_2':
        return gen2Done;
      case 'generative_3':
        return gen3Done;
      case 'generative_4':
        return isSweetCorn ? gen4Done : generative == GenerativeAuditStatus.sampun;
      case 'generative_5':
        return isSweetCorn ? gen5Done : generative == GenerativeAuditStatus.sampun;
      default:
        return generative == GenerativeAuditStatus.sampun;
    }
  }
}

class AuditStatusHelper {
  static bool _hasDate(dynamic val) {
    if (val == null) return false;
    return val.toString().trim().isNotEmpty;
  }

  // Ekstrak row pertama dari nested join Supabase (List<Map> atau Map)
  static Map<String, dynamic>? _firstRow(Map<String, dynamic> raw, String tableKey) {
    final v = raw[tableKey];
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is List) {
      if (v.isEmpty) return null;
      final first = v[0];
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  static bool _checkIsSweetCorn(String? hybrid) {
    final h = hybrid?.toUpperCase().trim() ?? '';
    return ['AX01', 'AX02', 'AX03', 'AX04'].contains(h);
  }

  static FieldAuditStatus fromRaw(Map<String, dynamic> raw) {
    final String? hybrid = raw['hybrid']?.toString();
    final bool isSc = _checkIsSweetCorn(hybrid);

    // ── 1. Vegetatif ──────────────────────────────────────
    final vegRow = _firstRow(raw, 'audit_vegetative');
    final vegStatus = _hasDate(vegRow?['date_of_audit'])
        ? SingleAuditStatus.sampun
        : SingleAuditStatus.dereng;

    // ── 2. Generatif ──────────────────────────────────────
    final genRow = _firstRow(raw, 'audit_generative');
    final gen1Done = _hasDate(genRow?['date_of_audit_1']);
    final gen2Done = _hasDate(genRow?['date_of_audit_2']);
    final gen3Done = _hasDate(genRow?['date_of_audit_3']);
    final gen4Done = _hasDate(genRow?['date_of_audit_4']);
    final gen5Done = _hasDate(genRow?['date_of_audit_5']);

    final List<bool> relevantCps = isSc 
        ? [gen1Done, gen2Done, gen3Done, gen4Done, gen5Done]
        : [gen1Done, gen2Done, gen3Done];

    final doneCount = relevantCps.where((v) => v).length;
    final totalNeeded = relevantCps.length;

    final GenerativeAuditStatus genStatus;
    if (doneCount == totalNeeded) {
      genStatus = GenerativeAuditStatus.sampun;
    } else if (doneCount > 0) {
      genStatus = GenerativeAuditStatus.derengJangkep;
    } else {
      genStatus = GenerativeAuditStatus.derengBlas;
    }

    // ── 3. Pre-Harvest ────────────────────────────────────
    final prhRow = _firstRow(raw, 'audit_pre_harvest');
    final prhStatus = _hasDate(prhRow?['audit_date'])
        ? SingleAuditStatus.sampun
        : SingleAuditStatus.dereng;

    // ── 4. Harvest ────────────────────────────────────────
    final hvRow = _firstRow(raw, 'audit_harvest');
    final hvStatus = _hasDate(hvRow?['date_of_audit'])
        ? SingleAuditStatus.sampun
        : SingleAuditStatus.dereng;

    if (kDebugMode) {
      final fn = raw['field_number'] ?? '?';
      if (vegRow != null || genRow != null || prhRow != null || hvRow != null) {
        debugPrint(
          '[AuditStatus] $fn (SC=$isSc) | '
              'veg=${vegRow?['date_of_audit']}(${vegStatus.name}) | '
              'genStatus=${genStatus.name} | '
              'gen1=$gen1Done gen2=$gen2Done gen3=$gen3Done '
              'gen4=$gen4Done gen5=$gen5Done | '
              'prh=${prhRow?['audit_date']}(${prhStatus.name}) | '
              'hv=${hvRow?['date_of_audit']}(${hvStatus.name})',
        );
      }
    }

    return FieldAuditStatus(
      vegetative: vegStatus,
      generative: genStatus,
      preHarvest: prhStatus,
      harvest: hvStatus,
      gen1Done: gen1Done,
      gen2Done: gen2Done,
      gen3Done: gen3Done,
      gen4Done: gen4Done,
      gen5Done: gen5Done,
      isSweetCorn: isSc,
    );
  }
}
