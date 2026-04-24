import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'master_fields_provider.dart';

// ============================================================================
// 1. PROVIDER REGION
// ============================================================================
final uniqueRegionsProvider = Provider<List<String>>((ref) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  return allFields
      .map((e) => e['region']?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

// ============================================================================
// 2. PROVIDER DISTRICT (🌟 HANYA Difilter Berdasarkan Region)
// ============================================================================
// Kita hapus DistrictFilterParams dan langsung pakai String? selectedRegion
final uniqueDistrictsProvider = Provider.family<List<String>, String?>((ref, selectedRegion) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  return allFields.where((field) {
    if (selectedRegion == null || selectedRegion == 'All') return true;
    final region = field['region']?.toString().trim().toLowerCase() ?? '';
    return region == selectedRegion.toLowerCase();
  })
      .map((e) => e['district_kab']?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

// ============================================================================
// 3. PROVIDER QA SPV (Difilter berdasarkan Region DAN District)
// ============================================================================
class QAFilterParams {
  final String? region;
  final String? district;

  QAFilterParams({this.region, this.district});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QAFilterParams &&
        other.region == region &&
        other.district == district;
  }

  @override
  int get hashCode => region.hashCode ^ district.hashCode;
}

final uniqueQAProvider = Provider.family<List<String>, QAFilterParams>((ref, filterParams) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  final qas = <String>{};

  for (var field in allFields) {
    final region = field['region']?.toString().trim().toLowerCase() ?? '';
    final district = field['district_kab']?.toString().trim().toLowerCase() ?? '';

    // Cek kecocokan Region dan District
    bool matchRegion = (filterParams.region == null || filterParams.region == 'All' || region == filterParams.region!.toLowerCase());
    bool matchDistrict = (filterParams.district == null || filterParams.district == 'All' || district == filterParams.district!.toLowerCase());

    if (matchRegion && matchDistrict) {
      // Ambil QA dari master_fields (field baru)
      final qaFi = field['qa_fi']?.toString().trim();
      final qaSpv = field['qa_spv']?.toString().trim();
      
      if (qaFi != null && qaFi.isNotEmpty) qas.add(qaFi);
      if (qaSpv != null && qaSpv.isNotEmpty) qas.add(qaSpv);

      // Tetap cek audit untuk data historis jika diperlukan
      final audits = [
        field['audit_vegetative'],
        field['audit_generative'],
        field['audit_pre_harvest'],
        field['audit_harvest'],
      ];

      for (var auditList in audits) {
        if (auditList is List && auditList.isNotEmpty) {
          final audit = auditList[0];
          final spv = audit['qa_spv']?.toString().trim();
          if (spv != null && spv.isNotEmpty) qas.add(spv);
        }
      }
    }
  }

  return qas.toList()..sort();
});