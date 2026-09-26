import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/act_sync_status.dart';

class ActSyncStatusService {
  ActSyncStatusService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<ActSyncStatus> getStatus() async {
    final response = await _client.rpc('get_act_sync_public_status');
    if (response is! Map) {
      throw const FormatException(
        'Format status sinkronisasi ACT tidak valid.',
      );
    }

    return ActSyncStatus.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
