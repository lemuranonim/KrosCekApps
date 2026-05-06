import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'master_fields_provider.dart';
import '../utils/qa_name_helper.dart';

// ============================================================================
// 1. REGIONS — semua region unik dari master fields
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
// 2. DISTRICTS — difilter berdasarkan region yang dipilih
//    Jika selectedRegion null/'All', tampilkan semua district
// ============================================================================
final uniqueDistrictsProvider = Provider.family<List<String>, String?>((ref, selectedRegion) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  return allFields
      .where((field) {
    if (selectedRegion == null || selectedRegion == 'All') return true;
    final region = field['region']?.toString().trim() ?? '';
    return region.toLowerCase() == selectedRegion.toLowerCase();
  })
      .map((e) => e['district_kab']?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

// ============================================================================
// 3. SUB-DISTRICTS (Kecamatan) — difilter berdasarkan region + district
// ============================================================================
class DistrictFilterParams {
  final String? region;
  final String? district;
  const DistrictFilterParams({this.region, this.district});

  @override
  bool operator ==(Object other) =>
      other is DistrictFilterParams && other.region == region && other.district == district;

  @override
  int get hashCode => region.hashCode ^ district.hashCode;
}

final uniqueSubDistrictsProvider = Provider.family<List<String>, DistrictFilterParams>((ref, params) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  return allFields
      .where((field) {
    final region = field['region']?.toString().trim() ?? '';
    final district = field['district_kab']?.toString().trim() ?? '';
    final matchRegion = params.region == null || params.region == 'All' ||
        region.toLowerCase() == params.region!.toLowerCase();
    final matchDistrict = params.district == null || params.district == 'All' ||
        district.toLowerCase() == params.district!.toLowerCase();
    return matchRegion && matchDistrict;
  })
      .map((e) => e['sub_district_kec']?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

// ============================================================================
// 4. VILLAGES — difilter berdasarkan region + district + sub-district
// ============================================================================
class VillageFilterParams {
  final String? region;
  final String? district;
  final String? subDistrict;
  const VillageFilterParams({this.region, this.district, this.subDistrict});

  @override
  bool operator ==(Object other) =>
      other is VillageFilterParams &&
          other.region == region &&
          other.district == district &&
          other.subDistrict == subDistrict;

  @override
  int get hashCode => region.hashCode ^ district.hashCode ^ subDistrict.hashCode;
}

final uniqueVillagesProvider = Provider.family<List<String>, VillageFilterParams>((ref, params) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  return allFields
      .where((field) {
    final region = field['region']?.toString().trim() ?? '';
    final district = field['district_kab']?.toString().trim() ?? '';
    final subDistrict = field['sub_district_kec']?.toString().trim() ?? '';
    final matchRegion = params.region == null || params.region == 'All' ||
        region.toLowerCase() == params.region!.toLowerCase();
    final matchDistrict = params.district == null || params.district == 'All' ||
        district.toLowerCase() == params.district!.toLowerCase();
    final matchSub = params.subDistrict == null || params.subDistrict == 'All' ||
        subDistrict.toLowerCase() == params.subDistrict!.toLowerCase();
    return matchRegion && matchDistrict && matchSub;
  })
      .map((e) => e['village_desa']?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
});

// ============================================================================
// 5. QA SPV — difilter berdasarkan region + district
// ============================================================================
class QAFilterParams {
  final String? region;
  final String? district;
  const QAFilterParams({this.region, this.district});

  @override
  bool operator ==(Object other) =>
      other is QAFilterParams && other.region == region && other.district == district;

  @override
  int get hashCode => region.hashCode ^ district.hashCode;
}

final uniqueQAProvider = Provider.family<List<String>, QAFilterParams>((ref, filterParams) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  final qas = <String>{};

  for (final field in allFields) {
    final region = field['region']?.toString().trim() ?? '';
    final district = field['district_kab']?.toString().trim() ?? '';

    final matchRegion = filterParams.region == null ||
        filterParams.region == 'All' ||
        region.toLowerCase() == filterParams.region!.toLowerCase();
    final matchDistrict = filterParams.district == null ||
        filterParams.district == 'All' ||
        district.toLowerCase() == filterParams.district!.toLowerCase();

    if (matchRegion && matchDistrict) {
      final qaSpv = field['qa_spv']?.toString().trim();
      qas.addAll(QaNameHelper.splitNames(field['qa_fi']));
      qas.addAll(QaNameHelper.splitNames(field['qa_fi_list']));
      if (qaSpv != null && qaSpv.isNotEmpty) qas.add(qaSpv);
    }
  }

  return qas.toList()..sort();
});

// ============================================================================
// 6. QA FI ONLY — untuk filter SPV view (hanya FI, bukan SPV)
// ============================================================================
final uniqueFIProvider = Provider.family<List<String>, QAFilterParams>((ref, filterParams) {
  final allFields = ref.watch(masterFieldsProvider).value ?? [];
  final fis = <String>{};

  for (final field in allFields) {
    final region = field['region']?.toString().trim() ?? '';
    final district = field['district_kab']?.toString().trim() ?? '';

    final matchRegion = filterParams.region == null ||
        filterParams.region == 'All' ||
        region.toLowerCase() == filterParams.region!.toLowerCase();
    final matchDistrict = filterParams.district == null ||
        filterParams.district == 'All' ||
        district.toLowerCase() == filterParams.district!.toLowerCase();

    if (matchRegion && matchDistrict) {
      fis.addAll(QaNameHelper.splitNames(field['qa_fi']));
      fis.addAll(QaNameHelper.splitNames(field['qa_fi_list']));
    }
  }

  return fis.toList()..sort();
});
