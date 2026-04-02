import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. MENGAMBIL DATA MASTER + SEMUA AUDIT SEKALIGUS (SUDAH DIPERBARUI)
  Future<List<Map<String, dynamic>>> getMasterFieldsWithAllAudits() async {
    try {
      final response = await _supabase
          .from('master_fields')
      // KITA TAMBAHKAN audit_generative(*) DI SINI
          .select('*, audit_vegetative(*), audit_generative(*), audit_pre_harvest(*), audit_harvest(*)')
          .order('field_number', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data master Supabase: $e');
    }
  }

  // ==========================================
  // 2. FUNGSI UNTUK AUDIT VEGETATIVE (TETAP SAMA)
  // ==========================================
  Future<Map<String, dynamic>?> getVegetativeAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_vegetative').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit vegetative: $e');
    }
  }

  Future<void> upsertVegetativeAudit(Map<String, dynamic> data) async {
    try {
      await _supabase.from('audit_vegetative').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit vegetative: $e');
    }
  }

  // ==========================================
  // 3. FUNGSI UNTUK AUDIT GENERATIVE (BARU) 🌟
  // ==========================================
  Future<Map<String, dynamic>?> getGenerativeAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_generative').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit generative: $e');
    }
  }

  Future<void> upsertGenerativeAudit(Map<String, dynamic> data) async {
    try {
      await _supabase.from('audit_generative').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit generative: $e');
    }
  }

  // ==========================================
  // 4. FUNGSI UNTUK AUDIT PRE-HARVEST (TETAP SAMA)
  // ==========================================
  Future<Map<String, dynamic>?> getPreHarvestAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_pre_harvest').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit pre-harvest: $e');
    }
  }

  Future<void> upsertPreHarvestAudit(Map<String, dynamic> data) async {
    try {
      await _supabase.from('audit_pre_harvest').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit pre-harvest: $e');
    }
  }

  // ==========================================
  // 5. FUNGSI UNTUK AUDIT HARVEST (TETAP SAMA)
  // ==========================================
  Future<Map<String, dynamic>?> getHarvestAudit(String fieldNumber) async {
    try {
      return await _supabase.from('audit_harvest').select().eq('field_number', fieldNumber).maybeSingle();
    } catch (e) {
      throw Exception('Gagal mengambil data audit harvest: $e');
    }
  }

  Future<void> upsertHarvestAudit(Map<String, dynamic> data) async {
    try {
      await _supabase.from('audit_harvest').upsert(data, onConflict: 'field_number');
    } catch (e) {
      throw Exception('Gagal menyimpan audit harvest: $e');
    }
  }
}