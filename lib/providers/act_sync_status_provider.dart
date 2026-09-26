import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/act_sync_status.dart';
import '../services/act_sync_status_service.dart';

final actSyncStatusServiceProvider = Provider<ActSyncStatusService>((ref) {
  return ActSyncStatusService();
});

final actSyncStatusProvider = FutureProvider.autoDispose<ActSyncStatus>((ref) {
  return ref.watch(actSyncStatusServiceProvider).getStatus();
});
