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

  Future<ActSyncDailySummary> getDailySummary({String? runId}) async {
    final response = await _client.rpc(
      'get_act_sync_scoped_daily_summary',
      params: {'p_run_id': runId},
    );
    if (response is! Map) {
      throw const FormatException(
        'Format ringkasan hasil sync harian tidak valid.',
      );
    }

    return ActSyncDailySummary.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<ActSyncDailyPage> getDailyChanges(ActSyncDailyQuery query) async {
    final response = await _client.rpc(
      'get_act_sync_scoped_daily_changes',
      params: query.rpcParams,
    );
    if (response is! Map) {
      throw const FormatException(
        'Format daftar hasil sync harian tidak valid.',
      );
    }

    return ActSyncDailyPage.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<PlantingDataMonitorSummary> getPlantingSummary(
    PlantingDataMonitorFilter filter,
  ) async {
    final response = await _client.rpc(
      'get_planting_data_monitor_summary',
      params: filter.rpcParams,
    );
    if (response is! Map) {
      throw const FormatException(
        'Format ringkasan Data Tanam Monitor tidak valid.',
      );
    }

    return PlantingDataMonitorSummary.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<PlantingDataMonitorOptions> getPlantingOptions() async {
    final response = await _client.rpc('get_planting_data_monitor_options');
    if (response is! Map) {
      throw const FormatException(
        'Format filter Data Tanam Monitor tidak valid.',
      );
    }

    return PlantingDataMonitorOptions.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
