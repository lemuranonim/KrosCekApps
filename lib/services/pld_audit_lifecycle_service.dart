import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pld_audit_lifecycle.dart';

class PldAuditLifecycleService {
  PldAuditLifecycleService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<PldAuditLifecycleBundle> getFieldLifecycle(String fieldNumber) async {
    final response = await _client.rpc(
      'get_field_pld_audit_lifecycle',
      params: {'p_field_number': fieldNumber.trim()},
    );
    if (response is! Map) {
      throw const FormatException('Format status PLD audit tidak valid.');
    }
    return PldAuditLifecycleBundle.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
