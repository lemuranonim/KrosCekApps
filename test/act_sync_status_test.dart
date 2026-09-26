import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/models/act_sync_status.dart';

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
}
