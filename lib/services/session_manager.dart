// lib/services/session_manager.dart
//
// SESSION MANAGER — Hardcore multi-account cache isolation
// ──────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionKeys {
  SessionKeys._();

  static const activeUserId     = '_session_active_user_id';
  static const activeUserEmail  = '_session_active_user_email';
  static const activeUserRole   = '_session_active_user_role';
  static const activeUserName   = '_session_active_user_name';
  static const activeUserAction = '_session_active_user_action';
  static const activeUserRegion = '_session_active_user_region';     // <--- TAMBAHAN
  static const activeUserDistrict = '_session_active_user_district'; // <--- TAMBAHAN

  static String forUser(String uid, String dataKey) => 'u_${uid}_$dataKey';
}

class ActiveSession {
  final String userId;
  final String email;
  final String role;
  final String name;
  final String action;
  final String? region;    // <--- TAMBAHAN
  final String? district;  // <--- TAMBAHAN

  const ActiveSession({
    required this.userId,
    required this.email,
    required this.role,
    required this.name,
    this.action = 'audit',
    this.region,           // <--- TAMBAHAN
    this.district,         // <--- TAMBAHAN
  });

  bool get isRestricted => action == 'audit';

  // [BARU] Fungsi copyWith untuk mempermudah update satu nilai spesifik
  ActiveSession copyWith({
    String? userId,
    String? email,
    String? role,
    String? name,
    String? action,
    String? region,        // <--- TAMBAHAN
    String? district,      // <--- TAMBAHAN
  }) {
    return ActiveSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      action: action ?? this.action,
      region: region ?? this.region,       // <--- TAMBAHAN
      district: district ?? this.district, // <--- TAMBAHAN
    );
  }
}

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  Future<ActiveSession?> getActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(SessionKeys.activeUserId);
    if (uid == null || uid.isEmpty) return null;
    final reg = prefs.getString(SessionKeys.activeUserRegion);
    final dis = prefs.getString(SessionKeys.activeUserDistrict);

    return ActiveSession(
      userId: uid,
      email:  prefs.getString(SessionKeys.activeUserEmail) ?? '',
      role:   prefs.getString(SessionKeys.activeUserRole) ?? 'FI',
      name:   prefs.getString(SessionKeys.activeUserName) ?? '',
      action: prefs.getString(SessionKeys.activeUserAction) ?? 'audit',
      // Tambahkan 2 baris ini di dalam return:
      region:   (reg == null || reg.isEmpty) ? null : reg,
      district: (dis == null || dis.isEmpty) ? null : dis,
    );
  }

  Future<void> saveSession(ActiveSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.activeUserId,     session.userId);
    await prefs.setString(SessionKeys.activeUserEmail,  session.email);
    await prefs.setString(SessionKeys.activeUserRole,   session.role);
    await prefs.setString(SessionKeys.activeUserName,   session.name);
    await prefs.setString(SessionKeys.activeUserAction, session.action);
    await prefs.setString(SessionKeys.activeUserRegion, session.region ?? '');     // <--- TAMBAH INI
    await prefs.setString(SessionKeys.activeUserDistrict, session.district ?? ''); // <--- TAMBAH INI
  }

  // [BARU] Fungsi untuk refresh nama di cache lokal setelah rename berhasil
  Future<void> refreshName({
    required String userId,
    required String newName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentActiveUid = prefs.getString(SessionKeys.activeUserId);

    // Pastikan kita hanya mengupdate jika user yang direname adalah user yang sedang login
    if (currentActiveUid == userId) {
      await prefs.setString(SessionKeys.activeUserName, newName);
    }
  }

  Future<void> nukeStaleSession({
    required String incomingUserId,
    WidgetRef? ref,
    ProviderContainer? container,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastUid = prefs.getString(SessionKeys.activeUserId) ?? '';

    if (lastUid == incomingUserId && lastUid.isNotEmpty) return;

    if (lastUid.isNotEmpty) {
      final allKeys = prefs.getKeys().toList();
      for (final k in allKeys) {
        if (k.startsWith('u_${lastUid}_')) {
          await prefs.remove(k);
        }
      }
    }

    await prefs.remove(SessionKeys.activeUserId);
    await prefs.remove(SessionKeys.activeUserEmail);
    await prefs.remove(SessionKeys.activeUserRole);
    await prefs.remove(SessionKeys.activeUserName);
    await prefs.remove(SessionKeys.activeUserAction);

    const legacyKeys = ['userId', 'userEmail', 'userRole', 'userName', 'userAction', 'isLoggedIn', 'attendanceId'];
    for (final k in legacyKeys) {
      await prefs.remove(k);
    }

    if (ref != null) {
      _invalidateAllProviders(ref);
    } else if (container != null) {
      container.invalidate(_allProvidersSentinel);
    }

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  void _invalidateAllProviders(WidgetRef ref) {
    // Kosongkan sesuai aslinya
  }

  Future<void> clearSessionOnLogout({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? prefs.getString(SessionKeys.activeUserId) ?? '';

    if (uid.isNotEmpty) {
      final allKeys = prefs.getKeys().toList();
      for (final k in allKeys) {
        if (k.startsWith('u_${uid}_')) {
          await prefs.remove(k);
        }
      }
    }

    const sessionKeys = [
      SessionKeys.activeUserId, SessionKeys.activeUserEmail,
      SessionKeys.activeUserRole, SessionKeys.activeUserName,
      SessionKeys.activeUserAction,
      SessionKeys.activeUserRegion,   // <-- Tambah ini
      SessionKeys.activeUserDistrict, // <-- Tambah ini
    ];
    for (final k in sessionKeys) {
      await prefs.remove(k);
    }

    const legacyKeys = ['userId', 'userEmail', 'userRole', 'userName', 'userAction', 'isLoggedIn', 'attendanceId'];
    for (final k in legacyKeys) {
      await prefs.remove(k);
    }

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  Future<void> writeUserData(String uid, String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SessionKeys.forUser(uid, key), value);
  }

  Future<String?> readUserData(String uid, String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SessionKeys.forUser(uid, key));
  }
}

final _allProvidersSentinel = Provider((_) => null);