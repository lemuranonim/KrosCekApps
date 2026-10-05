import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/act_sync_status.dart';
import '../services/act_sync_status_service.dart';

final actSyncStatusServiceProvider = Provider<ActSyncStatusService>((ref) {
  return ActSyncStatusService();
});

final actSyncStatusProvider = FutureProvider.autoDispose<ActSyncStatus>((ref) {
  return ref.watch(actSyncStatusServiceProvider).getStatus();
}, retry: (_, __) => null);

final actSyncHarvestReviewsProvider =
    FutureProvider.autoDispose<List<ActHarvestReview>>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getHarvestReviews();
    }, retry: (_, __) => null);

final actSyncHistoryProvider =
    FutureProvider.autoDispose<List<ActSyncHistoryItem>>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getHistory();
    }, retry: (_, __) => null);

final actSyncDailySummaryProvider =
    FutureProvider.autoDispose<ActSyncDailySummary>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getDailySummary();
    }, retry: (_, __) => null);

final actSyncDailyChangesProvider = FutureProvider.autoDispose
    .family<ActSyncDailyPage, ActSyncDailyQuery>((ref, query) {
      return ref.watch(actSyncStatusServiceProvider).getDailyChanges(query);
    }, retry: (_, __) => null);

final plantingDataMonitorSummaryProvider = FutureProvider.autoDispose
    .family<PlantingDataMonitorSummary, PlantingDataMonitorFilter>((
      ref,
      filter,
    ) {
      return ref.watch(actSyncStatusServiceProvider).getPlantingSummary(filter);
    }, retry: (_, __) => null);

final plantingDataMonitorOptionsProvider =
    FutureProvider.autoDispose<PlantingDataMonitorOptions>((ref) {
      return ref.watch(actSyncStatusServiceProvider).getPlantingOptions();
    }, retry: (_, __) => null);

final plantingPldLifecycleSummaryProvider = FutureProvider.autoDispose
    .family<PlantingPldLifecycleSummary, PlantingDataMonitorFilter>((
      ref,
      filter,
    ) {
      return ref
          .watch(actSyncStatusServiceProvider)
          .getPlantingPldLifecycleSummary(filter);
    }, retry: (_, __) => null);

final plantingPldLifecycleItemsProvider = FutureProvider.autoDispose
    .family<PlantingPldLifecyclePage, PlantingPldLifecycleQuery>((ref, query) {
      return ref
          .watch(actSyncStatusServiceProvider)
          .getPlantingPldLifecycleItems(query);
    }, retry: (_, __) => null);
