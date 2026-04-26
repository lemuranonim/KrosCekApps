// lib/utils/audit_status_helper.dart
//
// Helper untuk menentukan status audit per fase.
//
// STRUKTUR DATA DARI SUPABASE (hasil getMasterFieldsWithAllAudits):
//   raw['audit_vegetative']  → List<Map> atau null, punya kolom 'date_of_audit'
//   raw['audit_generative']  → List<Map> atau null, punya:
//                               'date_of_audit_1', 'date_of_audit_2', 'date_of_audit_3'
//   raw['audit_pre_harvest'] → List<Map> atau null, punya kolom 'audit_date'
//   raw['audit_harvest']     → List<Map> atau null, punya kolom 'date_of_audit'
//
// ── LOGIKA STATUS ────────────────────────────────────────────────────────
//   Vegetatif   : date_of_audit terisi → Sampun
//   Pre-Harvest : audit_date terisi    → Sampun
//   Harvest     : date_of_audit terisi → Sampun
//
//   Generatif:
//     Semua 3 date terisi  → Sampun
//     1 atau 2 date terisi → Dereng Jangkep
//     Semua kosong         → Dereng Blas
// ─────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

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

  const FieldAuditStatus({
    required this.vegetative,
    required this.generative,
    required this.preHarvest,
    required this.harvest,
    required this.gen1Done,
    required this.gen2Done,
    required this.gen3Done,
  });

  bool get isCompletelyUnaudited =>
      vegetative == SingleAuditStatus.dereng &&
          generative == GenerativeAuditStatus.derengBlas &&
          preHarvest == SingleAuditStatus.dereng &&
          harvest == SingleAuditStatus.dereng;

  bool isActivePhaseDone(int dap) {
    if (dap <= 35) return vegetative == SingleAuditStatus.sampun;
    if (dap <= 65) return generative == GenerativeAuditStatus.sampun;
    if (dap <= 90) return preHarvest == SingleAuditStatus.sampun;
    return harvest == SingleAuditStatus.sampun;
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

  static FieldAuditStatus fromRaw(Map<String, dynamic> raw) {
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

    final doneCount = [gen1Done, gen2Done, gen3Done].where((v) => v).length;
    final GenerativeAuditStatus genStatus;
    if (doneCount == 3) {
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
          '[AuditStatus] $fn | '
              'veg=${vegRow?['date_of_audit']}(${vegStatus.name}) | '
              'gen1=${genRow?['date_of_audit_1']}($gen1Done) '
              'gen2=${genRow?['date_of_audit_2']}($gen2Done) '
              'gen3=${genRow?['date_of_audit_3']}($gen3Done)(${genStatus.name}) | '
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
    );
  }
}