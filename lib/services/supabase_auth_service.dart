// lib/services/supabase_auth_service.dart
//
// Auth Service — Supabase (menggantikan Firebase Auth)
// ─────────────────────────────────────────────────────
// Mengelola:
//   • Sign in / sign out via Supabase Auth
//   • Fetch profil user dari tabel app_users
//   • Simpan sesi ke SharedPreferences
// ─────────────────────────────────────────────────────

// ignore_for_file: avoid_print

import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_manager.dart';

// ─── Model ───────────────────────────────────────────
class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String action;
  final String? region;    // <--- TAMBAHAN
  final String? district;  // <--- TAMBAHAN

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.action,
    this.region,           // <--- TAMBAHAN
    this.district,         // <--- TAMBAHAN
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id       : map['id']?.toString() ?? '',
      email    : map['email']?.toString() ?? '',
      name     : map['name']?.toString() ?? '',
      role     : map['role']?.toString() ?? 'FI',
      action   : map['action']?.toString() ?? 'audit',
      region   : map['region']?.toString(),        // <--- BACA DARI DATABASE
      district : map['district_kab']?.toString(),  // <--- BACA DARI DATABASE
    );
  }
}

// ─── Service ─────────────────────────────────────────
class SupabaseAuthService {
  final _supabase = Supabase.instance.client;

  // ── Sign In ──────────────────────────────────────
  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final res = await _supabase.auth.signInWithPassword(
        email   : email,
        password: password,
      );
      if (res.user == null) return null;
      return await _fetchAndSaveProfile(res.user!.id, email);
    } on AuthException catch (e) {
      // TAMPILKAN ERROR AUTHENTICATION
      print('=== ERROR LOGIN SUPABASE ===: ${e.message}');
      return null;
    } catch (e) {
      print('=== ERROR UMUM LOGIN ===: $e');
      return null;
    }
  }

  // ── Sign Out ─────────────────────────────────────
  // Delegate ke SessionManager agar nuke namespace-aware (tidak prefs.clear() semua)
  Future<void> signOut({String? userId}) async {
    await SessionManager.instance.clearSessionOnLogout(userId: userId);
  }

  // ── Reset Password ───────────────────────────────
  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Current Session (untuk auto-login) ──────────
  User? get currentUser => _supabase.auth.currentUser;

  Future<AppUser?> restoreSession() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await _fetchAndSaveProfile(user.id, user.email ?? '');
  }

  // ── Internal: fetch profil dari app_users ────────
  Future<AppUser?> _fetchAndSaveProfile(String uid, String email) async {
    try {
      final data = await _supabase
          .from('app_users')
          .select('id, email, name, role, action, is_active')
          .eq('id', uid)
          .maybeSingle();

      if (data == null) {
        print('=== ERROR: USER ADA DI AUTH TAPI TIDAK ADA DI TABEL APP_USERS ===');
        return null;
      }

      // Cek is_active — tolak login jika akun dinonaktifkan
      if (data['is_active'] == false) {
        print('=== ERROR: AKUN TIDAK AKTIF (is_active = false) ===');
        await _supabase.auth.signOut();
        return null;
      }

      final appUser = AppUser.fromMap(data);
      await _saveToPrefs(appUser);
      return appUser;
    } catch (e) {
      // TAMPILKAN ERROR DATABASE
      print('=== ERROR BACA TABEL APP_USERS ===: $e');
      return null;
    }
  }

  // ── Simpan ke SharedPreferences via SessionManager ──
  // Single source of truth: semua write lewat SessionManager
  // agar key selalu konsisten dan bisa di-nuke dengan benar saat logout.
  Future<void> _saveToPrefs(AppUser user) async {
    await SessionManager.instance.saveSession(
      ActiveSession(
        userId: user.id,
        email:  user.email,
        name:   user.name,
        role:   user.role,
        action: user.action,
        region: user.region,     // <--- TAMBAHAN: Lempar ke Session
        district: user.district, // <--- TAMBAHAN: Lempar ke Session
      ),
    );
  }

  // ── Baca sesi lokal tanpa hit DB ─────────────────
  // Membaca dari SessionManager keys (bukan legacy keys)
  static Future<Map<String, String?>> loadLocalSession() async {
    final session = await SessionManager.instance.getActiveSession();
    if (session == null) return {};
    return {
      'userId'    : session.userId,
      'userEmail' : session.email,
      'userName'  : session.name,
      'userRole'  : session.role,
      'userAction': session.action,
    };
  }
}