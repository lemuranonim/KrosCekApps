import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/act_sync_status.dart';
import '../services/act_sync_status_service.dart';

final actSyncStatusServiceProvider = Provider<ActSyncStatusService>((ref) {
  return ActSyncStatusService();
});

final actSyncStatusProvider = FutureProvider.autoDispose<ActSyncStatus>((ref) {
  return ref.watch(actSyncStatusServiceProvider).getStatus();
});

final actSyncHarvestReviewsProvider =
    FutureProvider.autoDispose<List<ActHarvestReview>>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getHarvestReviews();
    });

final actSyncHistoryProvider =
    FutureProvider.autoDispose<List<ActSyncHistoryItem>>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getHistory();
    });

final actSyncDailySummaryProvider =
    FutureProvider.autoDispose<ActSyncDailySummary>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getDailySummary();
    });

final actSyncDailyChangesProvider = FutureProvider.autoDispose
    .family<ActSyncDailyPage, ActSyncDailyQuery>((ref, query) {
      return ref.watch(actSyncStatusServiceProvider).getDailyChanges(query);
    });

final plantingDataMonitorSummaryProvider = FutureProvider.autoDispose
    .family<PlantingDataMonitorSummary, PlantingDataMonitorFilter>((
      ref,
      filter,
    ) {
      return ref.watch(actSyncStatusServiceProvider).getPlantingSummary(filter);
    });

final plantingDataMonitorOptionsProvider =
    FutureProvider.autoDispose<PlantingDataMonitorOptions>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getPlantingOptions();
    });
