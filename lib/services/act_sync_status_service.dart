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

  Future<List<ActHarvestReview>> getHarvestReviews() async {
    final response = await _client.rpc('get_act_sync_harvest_reviews');
    if (response is! List) {
      throw const FormatException('Format review panen ACT tidak valid.');
    }

    return response
        .whereType<Map>()
        .map((row) {
          return ActHarvestReview.fromJson(
            row.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .toList(growable: false);
  }

  Future<List<ActSyncHistoryItem>> getHistory({int limit = 8}) async {
    final response = await _client.rpc(
      'get_act_sync_public_history',
      params: {'p_limit': limit},
    );
    if (response is! List) {
      throw const FormatException(
        'Format riwayat sinkronisasi ACT tidak valid.',
      );
    }

    return response
        .whereType<Map>()
        .map((row) {
          return ActSyncHistoryItem.fromJson(
            row.map((key, value) => MapEntry(key.toString(), value)),
          );
        })
        .toList(growable: false);
  }
}
