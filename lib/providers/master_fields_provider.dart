import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider((ref) => SupabaseService());

final masterFieldsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  // Panggil fungsi yang baru kita buat agar menarik semua data relasi sekaligus
  return await supabaseService.getMasterFieldsWithAllAudits();
});