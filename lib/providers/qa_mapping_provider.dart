// lib/providers/qa_mapping_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/session_manager.dart';
import '../utils/qa_name_helper.dart';

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
// Model ringan QA Coverage
// ---------------------------------------------------------------------------
class QaMappingItem {
  final int id;
  final String region;
  final String districtKab;
  final String subDistrictKec;
  final String villageDesa;
  final String qaSpv;
  final String qaFi;
  final String fa;
  final double? ha;
  final String status;
  final String approvalStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> raw;

  const QaMappingItem({
    required this.id,
    required this.region,
    required this.districtKab,
    required this.subDistrictKec,
    required this.villageDesa,
    required this.qaSpv,
    required this.qaFi,
    required this.fa,
    required this.ha,
    required this.status,
    required this.approvalStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.raw,
  });

  factory QaMappingItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = _readString(json['status']);
    final isActive = json['is_active'];
    final normalizedStatus = isActive == false
        ? 'inactive'
        : rawStatus.isEmpty
            ? 'active'
            : rawStatus;

    return QaMappingItem(
      id: _readInt(json['id']),
      region: _readString(json['region']),
      districtKab: _readString(json['district_kab']),
      subDistrictKec: _readString(json['sub_district_kec']),
      villageDesa: _readString(json['village_desa']),
      qaSpv: _readString(json['qa_spv']),
      qaFi: _readString(json['qa_fi']),
      fa: _readString(json['fa']),
      ha: _readDouble(json['ha']),
      status: normalizedStatus,
      approvalStatus:
          _readString(json['approval_status'], fallback: 'approved'),
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  bool get isActive => status.toLowerCase() != 'inactive';

  bool matchesSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return [
      region,
      districtKab,
      subDistrictKec,
      villageDesa,
      qaSpv,
      qaFi,
      fa,
      status,
      approvalStatus,
      ha?.toString() ?? '',
    ].any((value) => value.toLowerCase().contains(q));
  }

  bool matchesField(String value, String? filter) {
    if (filter == null || filter.trim().isEmpty) return true;
    return value.trim().toLowerCase() == filter.trim().toLowerCase();
  }

  String get villageKey => _normalizeKey([
        region,
        districtKab,
        subDistrictKec,
        villageDesa,
      ]);

  String get villageFaKey => _normalizeKey([
        districtKab,
        subDistrictKec,
        villageDesa,
        fa,
      ]);

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(raw);

  static String _normalizeKey(List<String> parts) {
    return parts
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .join('|');
  }
}

class QaMappingConflictIndex {
  final Set<int> conflictedIds;

  const QaMappingConflictIndex(this.conflictedIds);

  bool hasConflict(QaMappingItem item) => conflictedIds.contains(item.id);

  int get total => conflictedIds.length;
}

QaMappingConflictIndex buildQaMappingConflictIndex(List<QaMappingItem> items) {
  final villageOwners = <String, Set<String>>{};
  final villageFaOwners = <String, Set<String>>{};

  for (final item in items) {
    final fi = item.qaFi.trim().toLowerCase();
    if (fi.isEmpty) continue;

    if (item.villageKey.isNotEmpty) {
      villageOwners.putIfAbsent(item.villageKey, () => <String>{}).add(fi);
    }
    if (item.villageFaKey.isNotEmpty) {
      villageFaOwners.putIfAbsent(item.villageFaKey, () => <String>{}).add(fi);
    }
  }

  final conflictedIds = <int>{};
  for (final item in items) {
    final villageConflict = item.villageKey.isNotEmpty &&
        (villageOwners[item.villageKey]?.length ?? 0) > 1;
    final villageFaConflict = item.villageFaKey.isNotEmpty &&
        (villageFaOwners[item.villageFaKey]?.length ?? 0) > 1;
    if (villageConflict || villageFaConflict) {
      conflictedIds.add(item.id);
    }
  }

  return QaMappingConflictIndex(conflictedIds);
}

String _readString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

int _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _readDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _readDate(Object? value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return DateTime.tryParse(text);
}

// ---------------------------------------------------------------------------
// 1. Provider Sesi Login Aktif (MENGGANTIKAN currentQaFiNameProvider)
// ---------------------------------------------------------------------------
final currentSessionProvider = FutureProvider<ActiveSession?>((ref) async {
  return await SessionManager.instance.getActiveSession();
});

// ---------------------------------------------------------------------------
// 2. Cascade Wilayah - Menggunakan RPC Supabase get_wilayah_advanced
// ---------------------------------------------------------------------------

final kabupatenListProvider = FutureProvider<List<WilayahItem>>((ref) async {
  final supabase = Supabase.instance.client;
  const provinceId = '35';

  final response = await supabase.rpc('get_wilayah_advanced', params: {
    'p_level': 2,
    'p_parent_id': provinceId,
    'p_search': null,
    'p_limit': 1000,
    'p_offset': 0,
  });

  final List data = response as List;
  return data
      .map((e) => WilayahItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SelectedKabupatenNotifier extends Notifier<WilayahItem?> {
  @override
  WilayahItem? build() => null;
  void select(WilayahItem? item) => state = item;
}

final selectedKabupatenProvider =
    NotifierProvider<SelectedKabupatenNotifier, WilayahItem?>(
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
  return data
      .map((e) => WilayahItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SelectedKecamatanNotifier extends Notifier<WilayahItem?> {
  @override
  WilayahItem? build() => null;
  void select(WilayahItem? item) => state = item;
}

final selectedKecamatanProvider =
    NotifierProvider<SelectedKecamatanNotifier, WilayahItem?>(
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
    'p_limit': 1000,
    'p_offset': 0,
  });

  final List data = response as List;
  return data
      .map((e) => WilayahItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SelectedDesaNotifier extends Notifier<WilayahItem?> {
  @override
  WilayahItem? build() => null;
  void select(WilayahItem? item) => state = item;
}

final selectedDesaProvider =
    NotifierProvider<SelectedDesaNotifier, WilayahItem?>(
  () => SelectedDesaNotifier(),
);

// ---------------------------------------------------------------------------
// 3. Notifier CRUD master_qa_mapping
// ---------------------------------------------------------------------------
class QaMappingNotifier extends AsyncNotifier<List<QaMappingItem>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<QaMappingItem>> build() => _fetchData();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchData);
  }

  Future<void> addMapping(Map<String, dynamic> newData) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(currentSessionProvider.future);
      final safeData = await _sanitizeWriteData(newData, null, isInsert: true);

      if (session != null && session.isRestricted) {
        safeData['qa_fi'] = session.name;
        safeData.remove('qa_spv');
      }

      try {
        await _supabase.from('master_qa_mapping').insert(safeData);
      } catch (e) {
        throw Exception('Gagal insert master_qa_mapping: $e');
      }
      final currentItems =
          state.whenOrNull(data: (value) => value) ?? const <QaMappingItem>[];
      return currentItems;
    });
  }

  Future<List<QaMappingItem>> _fetchData() async {
    final session = await ref.read(currentSessionProvider.future);
    if (session == null) return [];

    final restrictedName = session.name.trim();

    if (session.isRestricted) {
      if (restrictedName.isEmpty) return [];

      final exactResponse = await _supabase
          .from('master_qa_mapping')
          .select()
          .eq('qa_fi', restrictedName)
          .order('id', ascending: false);
      final exactItems = List<Map<String, dynamic>>.from(exactResponse)
          .map(QaMappingItem.fromJson)
          .toList();
      if (exactItems.isNotEmpty) return exactItems;

      final caseInsensitiveResponse = await _supabase
          .from('master_qa_mapping')
          .select()
          .ilike('qa_fi', _escapeIlike(restrictedName))
          .order('id', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(caseInsensitiveResponse)
          .map(QaMappingItem.fromJson)
          .where(
            (item) => QaNameHelper.containsExactName(item.qaFi, restrictedName),
          )
          .toList();
    }

    final response = await _supabase
        .from('master_qa_mapping')
        .select()
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map(QaMappingItem.fromJson)
        .toList();
  }

  Future<void> updateMapping(int id, Map<String, dynamic> updatedData) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(currentSessionProvider.future);
      final safeData = await _sanitizeWriteData(updatedData, session);
      if (safeData.isEmpty) return _fetchData();

      await _updateByIdWithOptionalColumnFallback(id, safeData, session);
      return _fetchData();
    });
  }

  Future<void> bulkUpdateMappings({
    required List<int> ids,
    required Map<String, dynamic> data,
  }) async {
    if (ids.isEmpty) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(currentSessionProvider.future);
      if (session == null || session.isRestricted) {
        throw Exception('Bulk action hanya tersedia untuk QA SPV/Admin.');
      }

      final safeData = await _sanitizeWriteData(data, session);
      if (safeData.isEmpty) return _fetchData();

      for (final id in ids) {
        await _updateByIdWithOptionalColumnFallback(id, safeData, session);
      }
      return _fetchData();
    });
  }

  Future<void> deactivateMappings({
    required List<int> ids,
    String? reason,
  }) async {
    if (ids.isEmpty) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(currentSessionProvider.future);
      if (session != null && session.isRestricted && ids.length > 1) {
        throw Exception('Bulk action hanya tersedia untuk QA SPV/Admin.');
      }

      for (final id in ids) {
        await _softDeactivateById(id, session, reason: reason);
      }
      return _fetchData();
    });
  }

  Future<void> deleteMapping(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref.read(currentSessionProvider.future);
      await _hardDeleteById(id, session);
      return _fetchData();
    });
  }

  Future<Map<String, dynamic>> _sanitizeWriteData(
    Map<String, dynamic> data,
    ActiveSession? session, {
    bool isInsert = false,
  }) async {
    final allowedForFi = {
      'district_kab',
      'sub_district_kec',
      'village_desa',
      'fa',
      'ha',
    };

    final allowedForAdmin = {
      'region',
      'district_kab',
      'sub_district_kec',
      'village_desa',
      'qa_spv',
      'qa_fi',
      'fa',
      'ha',
      'status',
      'approval_status',
      'change_reason',
      'is_active',
    };

    final allowed = session != null && session.isRestricted
        ? allowedForFi
        : allowedForAdmin;
    final safeData = <String, dynamic>{};

    for (final entry in data.entries) {
      if (!allowed.contains(entry.key)) continue;
      final value = entry.value;
      if (value is String) {
        safeData[entry.key] = value.trim();
      } else {
        safeData[entry.key] = value;
      }
    }

    if (isInsert) {
      safeData.removeWhere((key, value) => value == null);
    }

    return safeData;
  }

  Future<void> _updateById(
    int id,
    Map<String, dynamic> data,
    ActiveSession? session,
  ) async {
    if (session != null && session.isRestricted) {
      await _updateRestrictedOwnedRow(id, data, session.name.trim());
      return;
    }

    await _supabase.from('master_qa_mapping').update(data).eq('id', id);
  }

  Future<void> _updateByIdWithOptionalColumnFallback(
    int id,
    Map<String, dynamic> data,
    ActiveSession? session,
  ) async {
    try {
      await _updateById(id, data, session);
    } catch (_) {
      final retryData = Map<String, dynamic>.from(data)
        ..remove('change_reason')
        ..remove('approval_status')
        ..remove('status')
        ..remove('is_active');
      if (retryData.length == data.length || retryData.isEmpty) rethrow;
      await _updateById(id, retryData, session);
    }
  }

  Future<void> _softDeactivateById(
    int id,
    ActiveSession? session, {
    String? reason,
  }) async {
    final reasonText = reason?.trim();
    final softPayloads = <Map<String, dynamic>>[
      {
        'status': 'inactive',
        'is_active': false,
        if (reasonText != null && reasonText.isNotEmpty)
          'change_reason': reasonText,
      },
      {
        'status': 'inactive',
        if (reasonText != null && reasonText.isNotEmpty)
          'change_reason': reasonText,
      },
      {'status': 'inactive'},
      {'is_active': false},
    ];

    for (final payload in softPayloads) {
      try {
        await _updateById(id, payload, session);
        return;
      } catch (_) {
        // Kolom opsional belum tentu ada di semua deployment.
      }
    }

    await _hardDeleteById(id, session);
  }

  Future<void> _hardDeleteById(int id, ActiveSession? session) async {
    if (session != null && session.isRestricted) {
      final row = await _fetchOwnedRestrictedRow(id, session.name.trim());
      if (row == null) return;
      await _supabase.from('master_qa_mapping').delete().eq('id', id);
      return;
    }

    await _supabase.from('master_qa_mapping').delete().eq('id', id);
  }

  Future<QaMappingItem?> _fetchOwnedRestrictedRow(
      int id, String qaFiName) async {
    if (qaFiName.trim().isEmpty) return null;

    final row = await _supabase
        .from('master_qa_mapping')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;

    final item = QaMappingItem.fromJson(Map<String, dynamic>.from(row));
    if (!QaNameHelper.containsExactName(item.qaFi, qaFiName)) return null;
    return item;
  }

  Future<void> _updateRestrictedOwnedRow(
    int id,
    Map<String, dynamic> data,
    String qaFiName,
  ) async {
    final row = await _fetchOwnedRestrictedRow(id, qaFiName);
    if (row == null) return;
    await _supabase.from('master_qa_mapping').update(data).eq('id', id);
  }
}

final qaMappingProvider =
    AsyncNotifierProvider<QaMappingNotifier, List<QaMappingItem>>(
  () => QaMappingNotifier(),
);

String _escapeIlike(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
