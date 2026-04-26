import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'master_fields_provider.dart';

final preharvestAuditProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, fieldNumber) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.getPreHarvestAudit(fieldNumber);
});