// lib/providers/qa_mapping_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/session_manager.dart';

// ---------------------------------------------------------------------------
// Model sederhana untuk data wilayah dari API
// ---------------------------------------------------------------------------
class WilayahItem {
  final String id;
  final String name;
  const WilayahItem({required this.id, required this.name});

  factory WilayahItem.fromJson(Map<String, dynamic> json) =>
      WilayahItem(id: json['id'].toString(), name: json['name'] as String);
}

// ---------------------------------------------------------------------------
// 1. Provider Sesi Login Aktif (MENGGANTIKAN currentQaFiNameProvider)
// ---------------------------------------------------------------------------
final currentSessionProvider = FutureProvider<ActiveSession?>((ref) async {
  return await SessionManager.instance.getActiveSession();
});

// ---------------------------------------------------------------------------
// 2. Cascade Wilayah – Menggunakan RPC Supabase get_wilayah_advanced
// ---------------------------------------------------------------------------

final kabupatenListProvider = FutureProvider<List<WilayahItem>>((ref) async {
  final supabase = Supabase.instance.client;
  // Gunakan ID Provinsi Jawa Timur (sesuaikan tipe datanya dengan DB, misal String '35')
  const provinceId = '35';

  final response = await supabase.rpc('get_wilayah_advanced', params: {
    'p_level': 2,
    'p_parent_id': provinceId,
    'p_search': null,
    'p_limit': 1000,
    'p_offset': 0,
  });

  final List data = response as List;
  return data.map((e) => WilayahItem.fromJson(e as Map<String, dynamic>)).toList();
});

class SelectedKabupatenNotifier extends Notifier<WilayahItem?> {
  @override
  WilayahItem? build() => null;
  void select(WilayahItem? item) => state = item;
}

final selectedKabupatenProvider = NotifierProvider<SelectedKabupatenNotifier, WilayahItem?>(
      () => SelectedKabupatenNotifier(),
);

final kecamatanListProvider = FutureProvider<List<WilayahItem>>((ref) async {
  final kab = ref.watch(selectedKabupatenProvider);
  if (kab == null) return [];

  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_wilayah_advanced', params: {
    'p_level': 3,
    'p_parent_id': kab.id,
    'p_search': null,
    'p_limit': 1000,
    'p_offset': 0,
  });

  final List data = response as List;
  return data.map((e) => WilayahItem.fromJson(e as Map<String, dynamic>)).toList();
});

class SelectedKecamatanNotifier extends Notifier<WilayahItem?> {
  @override
  WilayahItem? build() => null;
  void select(WilayahItem? item) => state = item;
}

final selectedKecamatanProvider = NotifierProvider<SelectedKecamatanNotifier, WilayahItem?>(
      () => SelectedKecamatanNotifier(),
);

final desaListProvider = FutureProvider<List<WilayahItem>>((ref) async {
  final kec = ref.watch(selectedKecamatanProvider);
  if (kec == null) return [];

  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_wilayah_advanced', params: {
    'p_level': 4,
    'p_parent_id': kec.id,
    'p_search': null,
    'p_limit': 1000, // Limit yang cukup besar untuk daftar desa
    'p_offset': 0,
  });

  final List data = response as List;
  return data.map((e) => WilayahItem.fromJson(e as Map<String, dynamic>)).toList();
});

class SelectedDesaNotifier extends Notifier<WilayahItem?> {
  @override
  WilayahItem? build() => null;
  void select(WilayahItem? item) => state = item;
}

final selectedDesaProvider = NotifierProvider<SelectedDesaNotifier, WilayahItem?>(
      () => SelectedDesaNotifier(),
);

// ---------------------------------------------------------------------------
// 3. Notifier CRUD master_qa_mapping
// ---------------------------------------------------------------------------
class QaMappingNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> build() => _fetchData();

  // C: CREATE
  Future<void> addMapping(Map<String, dynamic> newData) async {
    state = const AsyncValue.loading();
    try {
      final session = await ref.read(currentSessionProvider.future);

      // Jika user yang login adalah FI (action == audit), paksa nama qa_fi menjadi nama mereka
      if (session != null && session.isRestricted) {
        newData['qa_fi'] = session.name;
      }
      // Jika user adalah SPV/Manager (action == all), biarkan newData['qa_fi'] sesuai input form

      await _supabase.from('master_qa_mapping').insert(newData);
      state = AsyncValue.data(await _fetchData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // R: READ
  Future<List<Map<String, dynamic>>> _fetchData() async {
    final session = await ref.read(currentSessionProvider.future);
    if (session == null) return [];

    // 1. Panggil select() saja dulu tanpa order
    var query = _supabase.from('master_qa_mapping').select();

    // 2. Terapkan filter JIKA user adalah restricted (QA FI)
    if (session.isRestricted) {
      if (session.name.isEmpty) return [];
      query = query.eq('qa_fi', session.name);
    }

    // 3. Terakhir, baru kita panggil order() sebelum await
    final response = await query.order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // U: UPDATE
  Future<void> updateMapping(int id, Map<String, dynamic> updatedData) async {
    state = const AsyncValue.loading();
    try {
      final session = await ref.read(currentSessionProvider.future);

      Map<String, dynamic> safeData;

      if (session != null && session.isRestricted) {
        // Jika FI, batasi field yang bisa diedit
        final allowedFields = {'district_kab', 'sub_district_kec', 'village_desa', 'ha'};
        safeData = Map.fromEntries(
          updatedData.entries.where((e) => allowedFields.contains(e.key)),
        );
      } else {
        // Jika SPV/Manager, izinkan edit field lain termasuk qa_fi, qa_spv, dll
        safeData = Map.of(updatedData);
      }

      await _supabase
          .from('master_qa_mapping')
          .update(safeData)
          .eq('id', id);
      state = AsyncValue.data(await _fetchData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // D: DELETE
  Future<void> deleteMapping(int id) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.from('master_qa_mapping').delete().eq('id', id);
      state = AsyncValue.data(await _fetchData());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final qaMappingProvider = AsyncNotifierProvider<QaMappingNotifier, List<Map<String, dynamic>>>(
      () => QaMappingNotifier(),
);