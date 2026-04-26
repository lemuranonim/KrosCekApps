// lib/providers/profile_rename_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/session_manager.dart';

const _kLastRenameKey = 'profile_last_rename_';
const _kRenameCooldownDays = 14;

class ProfileRenameState {
  final String profileName;
  final String mappingName;
  bool get isSynced => profileName.trim().toLowerCase() == mappingName.trim().toLowerCase();
  final DateTime? lastRenameAt;

  bool get canRename {
    if (lastRenameAt == null) return true;
    return DateTime.now().difference(lastRenameAt!) >= const Duration(days: _kRenameCooldownDays);
  }

  int get cooldownDaysLeft {
    if (lastRenameAt == null) return 0;
    final diff = _kRenameCooldownDays - DateTime.now().difference(lastRenameAt!).inDays;
    return diff > 0 ? diff : 0;
  }

  const ProfileRenameState({
    required this.profileName,
    required this.mappingName,
    this.lastRenameAt,
  });

  ProfileRenameState copyWith({
    String? profileName, String? mappingName, DateTime? lastRenameAt,
  }) {
    return ProfileRenameState(
      profileName: profileName ?? this.profileName,
      mappingName: mappingName ?? this.mappingName,
      lastRenameAt: lastRenameAt ?? this.lastRenameAt,
    );
  }
}

class ProfileRenameNotifier extends AsyncNotifier<ProfileRenameState> {
  final _supabase = Supabase.instance.client;

  @override
  Future<ProfileRenameState> build() async {
    return _loadState();
  }

  Future<ProfileRenameState> _loadState() async {
    final session = await SessionManager.instance.getActiveSession();
    final userId = session?.userId ?? '';
    final profileName = session?.name ?? '';

    String mappingName = profileName;
    try {
      final rows = await _supabase
          .from('master_qa_mapping')
          .select('qa_fi')
          .eq('qa_fi', profileName)
          .limit(1);
      if (rows.isNotEmpty) {
        mappingName = rows[0]['qa_fi']?.toString() ?? profileName;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final tsStr = prefs.getString('$_kLastRenameKey$userId');
    DateTime? lastRenameAt;
    if (tsStr != null) {
      lastRenameAt = DateTime.tryParse(tsStr);
    }

    return ProfileRenameState(
      profileName: profileName,
      mappingName: mappingName,
      lastRenameAt: lastRenameAt,
    );
  }

  Future<void> renameTo(String newName) async {
    final current = state.value; // Ganti .valueOrNull menjadi .value
    if (current == null) return;
    if (!current.canRename) {
      throw Exception('Rename masih dalam cooldown ${current.cooldownDaysLeft} hari lagi.');
    }
    if (newName.trim().isEmpty) {
      throw Exception('Nama baru tidak boleh kosong.');
    }

    state = const AsyncValue.loading();
    try {
      final session = await SessionManager.instance.getActiveSession();
      final userId = session?.userId ?? '';
      final oldName = current.profileName;

      await _supabase
          .from('app_users')
          .update({'name': newName.trim()})
          .eq('id', userId);

      await _supabase
          .from('master_qa_mapping')
          .update({'qa_fi': newName.trim()})
          .eq('qa_fi', oldName);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kLastRenameKey$userId',
        DateTime.now().toIso8601String(),
      );

      await SessionManager.instance.refreshName(userId: userId, newName: newName.trim());
      state = AsyncValue.data(await _loadState());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final profileRenameProvider = AsyncNotifierProvider<ProfileRenameNotifier, ProfileRenameState>(
      () => ProfileRenameNotifier(),
);