import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pld_audit_lifecycle.dart';
import '../services/pld_audit_lifecycle_service.dart';

final pldAuditLifecycleServiceProvider = Provider<PldAuditLifecycleService>((
  ref,
) {
  return PldAuditLifecycleService();
});

final pldAuditLifecycleProvider = FutureProvider.autoDispose
    .family<PldAuditLifecycleBundle, String>((ref, fieldNumber) {
      return ref
          .watch(pldAuditLifecycleServiceProvider)
          .getFieldLifecycle(fieldNumber);
    });
