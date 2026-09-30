import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/models/act_sync_status.dart';
import 'package:kroscek/screens/act/act_data_monitor_screen.dart';

void main() {
  test('parses the minimal public ACT sync response', () {
    final status = ActSyncStatus.fromJson({
      'latest_status': 'COMPLETED',
      'latest_target_source_date': '2026-09-24',
      'last_success_source_date': '2026-09-24',
      'last_success_at': '2026-09-25T02:15:53+07:00',
      'is_current': true,
      'source_counts': {'FC': 32704, 'PS': 274, 'SC': 1540},
      'summary': {
        'source_rows': 34518,
        'insert': 129,
        'update': 4934,
        'unchanged': 29455,
        'missing_source': 68,
        'invalid': 0,
        'blockers': 0,
        'harvest_needs_review': 0,
      },
    });

    expect(status.latestStatus, 'COMPLETED');
    expect(status.isCurrent, isTrue);
    expect(status.hasSuccessfulSync, isTrue);
    expect(status.isSyncing, isFalse);
    expect(status.needsAttention, isFalse);
    expect(status.fcCount, 32704);
    expect(status.psCount, 274);
    expect(status.scCount, 1540);
    expect(status.totalRows, 34518);
    expect(status.insertedRows, 129);
    expect(status.updatedRows, 4934);
    expect(status.harvestNeedsReview, 0);
  });

  test('recognizes running and blocked states', () {
    final running = ActSyncStatus.fromJson({
      'latest_status': 'VALIDATING',
      'source_counts': const <String, int>{},
      'summary': const <String, int>{},
    });
    final blocked = ActSyncStatus.fromJson({
      'latest_status': 'BLOCKED',
      'source_counts': const <String, int>{},
      'summary': const <String, int>{'blockers': 1},
    });

    expect(running.isSyncing, isTrue);
    expect(running.needsAttention, isFalse);
    expect(blocked.isSyncing, isFalse);
    expect(blocked.needsAttention, isTrue);
    expect(blocked.blockers, 1);
  });

  test('keeps sync healthy while Harvest confirmation stays separate', () {
    final status = ActSyncStatus.fromJson({
      'latest_status': 'COMPLETED',
      'last_success_source_date': '2026-09-28',
      'source_counts': const <String, int>{},
      'summary': const <String, int>{'harvest_needs_review': 3},
    });
    final review = ActHarvestReview.fromJson({
      'field_number': 'DC6TEST001',
      'status': 'NEEDS_CONFIRMATION',
      'reason': 'REPORTED_AREA_EXCEEDS_EFFECTIVE_AREA',
      'effective_area_ha': 1,
      'reported_harvest_area_ha': 1.5,
      'safe_harvest_area_ha': 1,
      'harvest_event_count': 2,
      'last_harvest_date': '2026-09-27',
      'hybrid': 'AX04',
      'farmer_name': 'Pak Tani',
      'region': 'Region 5',
      'district_kab': 'KABUPATEN BLITAR',
      'village_desa': 'BENCE',
      'qa_fi': 'QA Satu',
    });

    expect(status.hasSyncError, isFalse);
    expect(status.hasHarvestReview, isTrue);
    expect(status.needsAttention, isFalse);
    expect(review.fieldNumber, 'DC6TEST001');
    expect(review.reportedHarvestAreaHa, 1.5);
    expect(review.safeHarvestAreaHa, 1);
    expect(review.harvestEventCount, 2);
    expect(review.qaOwner, 'QA Satu');
    expect(review.locationLabel, 'BENCE • KABUPATEN BLITAR');
    expect(review.searchableText, contains('ax04'));
  });

  test('filters ACT Harvest review by text, scope, owner, and status', () {
    final reviews = [
      ActHarvestReview.fromJson({
        'field_number': 'DC6TEST001',
        'status': 'NEEDS_CONFIRMATION',
        'reason': 'REPORTED_AREA_EXCEEDS_EFFECTIVE_AREA',
        'effective_area_ha': 1,
        'reported_harvest_area_ha': 1.5,
        'safe_harvest_area_ha': 1,
        'harvest_event_count': 2,
        'hybrid': 'AX04',
        'region': 'Region 5',
        'district_kab': 'BLITAR',
        'qa_fi': 'QA Satu',
        'season': '2026',
        'type': 'FC',
      }),
      ActHarvestReview.fromJson({
        'field_number': 'DC6TEST002',
        'status': 'CONFIRMED',
        'reason': 'REPORTED_AREA_EXCEEDS_EFFECTIVE_AREA',
        'effective_area_ha': 0.5,
        'reported_harvest_area_ha': 0.6,
        'safe_harvest_area_ha': 0.5,
        'harvest_event_count': 1,
        'hybrid': 'AX09',
        'region': 'Region 2',
        'district_kab': 'MADIUN',
        'qa_fi': 'QA Dua',
      }),
    ];

    expect(
      filterActHarvestReviews(
        reviews,
        query: 'AX04',
        region: 'Region 5',
        district: 'BLITAR',
        owner: 'QA Satu',
        season: '2026',
        seedType: 'FC',
        status: ActReviewStatusFilter.needsConfirmation,
      ).map((item) => item.fieldNumber),
      ['DC6TEST001'],
    );
    expect(
      filterActHarvestReviews(
        reviews,
        status: ActReviewStatusFilter.reviewed,
      ).single.fieldNumber,
      'DC6TEST002',
    );
  });

  test('parses sanitized ACT sync history', () {
    final history = ActSyncHistoryItem.fromJson({
      'run_id': 'run-1',
      'status': 'COMPLETED',
      'source_from': '2026-03-01',
      'source_to': '2026-09-28',
      'source_rows': 34518,
      'inserted_rows': 0,
      'updated_rows': 14894,
      'invalid_rows': 0,
      'blockers': 0,
      'harvest_needs_review': 44,
      'started_at': '2026-09-28T23:57:23+07:00',
      'completed_at': '2026-09-29T00:50:00+07:00',
    });

    expect(history.isSuccessful, isTrue);
    expect(history.updatedRows, 14894);
    expect(history.harvestNeedsReview, 44);
  });

  test('parses role-scoped daily ACT sync result and change page', () {
    final summary = ActSyncDailySummary.fromJson({
      'run_id': 'run-2',
      'status': 'COMPLETED',
      'scope_role': 'FI',
      'source_to': '2026-09-29',
      'completed_at': '2026-09-29T02:20:00+07:00',
      'total_rows': 120,
      'inserted_rows': 2,
      'updated_rows': 9,
      'unchanged_rows': 106,
      'missing_source_rows': 2,
      'invalid_rows': 1,
      'conflict_rows': 0,
      'changed_rows': 14,
      'applied_rows': 11,
    });
    final page = ActSyncDailyPage.fromJson({
      'run_id': 'run-2',
      'total_count': 14,
      'offset': 0,
      'limit': 20,
      'items': [
        {
          'field_number': 'DC6FHK045',
          'change_kind': 'UPDATE',
          'source_type': 'SC',
          'applied': true,
          'farmer_name': 'Pak Tani',
          'hybrid': 'AX04',
          'region': 'Region 5',
          'district_kab': 'BLITAR',
          'changed_field_count': 1,
          'changed_columns': {
            'hybrid': {'old': 'AX01', 'new': 'AX04'},
          },
          'validation_errors': <String>[],
        },
      ],
    });

    expect(summary.scopeRole, 'FI');
    expect(summary.totalRows, 120);
    expect(summary.issueRows, 3);
    expect(page.totalCount, 14);
    expect(page.hasPrevious, isFalse);
    expect(page.hasNext, isTrue);
    expect(page.items.single.fieldNumber, 'DC6FHK045');
    expect(page.items.single.changedFields.single.oldText, 'AX01');
    expect(page.items.single.changedFields.single.newText, 'AX04');
    expect(page.items.single.locationLabel, 'BLITAR • Region 5');

    const query = ActSyncDailyQuery(category: 'UPDATE', query: 'DC6');
    expect(query.rpcParams['p_category'], 'UPDATE');
    expect(query.rpcParams['p_limit'], 20);
  });

  test('parses planting area summary and filter options', () {
    final summary = PlantingDataMonitorSummary.fromJson({
      'field_count': 34518,
      'planted_area_ha': 1000.5,
      'discard_area_ha': 200.25,
      'effective_area_ha': 800.25,
      'harvested_area_ha': 300,
      'standing_crop_area_ha': 500.25,
      'harvest_needs_review': 44,
    });
    final options = PlantingDataMonitorOptions.fromJson({
      'regions': ['Region 1', 'Region 2'],
      'districts': ['BLITAR'],
      'owners': ['QA Satu'],
      'seasons': ['2026'],
      'seed_types': ['FC'],
    });
    const filter = PlantingDataMonitorFilter(
      region: 'Region 1',
      season: '2026',
    );

    expect(summary.fieldCount, 34518);
    expect(summary.plantedAreaHa, 1000.5);
    expect(summary.discardAreaHa + summary.effectiveAreaHa, 1000.5);
    expect(summary.harvestedAreaHa + summary.standingCropAreaHa, 800.25);
    expect(options.regions, ['Region 1', 'Region 2']);
    expect(options.seedTypes, ['FC']);
    expect(filter.isEmpty, isFalse);
    expect(
      filter,
      const PlantingDataMonitorFilter(region: 'Region 1', season: '2026'),
    );
  });

  test('parses PLD lifecycle summary, page, and query parameters', () {
    final summary = PlantingPldLifecycleSummary.fromJson({
      'total_recommended_fn': 2981,
      'active_recommended_fn': 2981,
      'pending_fn': 1614,
      'confirmed_fn': 1367,
      'updated_fn': 0,
      'phase_rows': 4903,
      'historical_fn': 2965,
      'confirmation_rate': 45.9,
    });
    final page = PlantingPldLifecyclePage.fromJson({
      'total_count': 1,
      'offset': 0,
      'limit': 20,
      'status': 'PENDING',
      'items': [
        {
          'field_number': 'DC6FHK045',
          'status': 'PENDING',
          'phase_count': 2,
          'farmer_name': 'Pak Tani',
          'hybrid': 'AX04',
          'total_area_planted_ha': 1.5,
          'discard_area_ha': 0.5,
          'effective_area_ha': 1.0,
          'region': 'Zona 4',
          'district_kab': 'BLITAR',
          'qa_fi': 'QA FI Satu',
          'qa_spv': 'Krisna Bagus Andrian',
          'recommended_at': '2026-09-28T09:00:00+07:00',
          'recommender_names': 'QA FI Satu',
          'historical_only': false,
          'phases': [
            {
              'phase_key': 'vegetative',
              'status': 'PENDING',
              'recommended_flagging': 'PLD',
              'active_flagging': 'PLD',
            },
            {
              'phase_key': 'generative_1',
              'status': 'CONFIRMED',
              'recommended_flagging': 'PLD',
              'active_flagging': 'PLD',
            },
          ],
        },
      ],
    });
    const filter = PlantingDataMonitorFilter(
      region: 'Zona 4',
      owner: 'QA FI Satu',
      seedType: 'SC',
    );
    const query = PlantingPldLifecycleQuery(
      filter: filter,
      status: 'PENDING',
      query: 'DC6',
      offset: 20,
      limit: 25,
    );

    expect(summary.totalRecommendedFn, 2981);
    expect(summary.pendingFn + summary.confirmedFn, 2981);
    expect(summary.confirmationRate, 45.9);
    expect(page.totalCount, 1);
    expect(page.items.single.fieldNumber, 'DC6FHK045');
    expect(page.items.single.phases, hasLength(2));
    expect(page.items.single.phases.first.phaseKey, 'vegetative');
    expect(page.items.single.historicalOnly, isFalse);
    expect(query.rpcParams['p_region'], 'Zona 4');
    expect(query.rpcParams['p_owner'], 'QA FI Satu');
    expect(query.rpcParams['p_seed_type'], 'SC');
    expect(query.rpcParams['p_status'], 'PENDING');
    expect(query.rpcParams['p_query'], 'DC6');
    expect(query.rpcParams['p_offset'], 20);
    expect(query.rpcParams['p_limit'], 25);
  });
}
