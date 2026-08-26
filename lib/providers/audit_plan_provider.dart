import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/weekly_audit.dart';
import 'detasseling_plan_provider.dart';
import 'master_fields_provider.dart';

typedef AuditPlanningParams = ({DateTime weekStart, String? region});

class AuditPlanField {
  final ParsedFieldData parsed;
  final WeeklyAuditField weekly;
  const AuditPlanField(this.parsed, this.weekly);
}

final auditPlanningProvider =
    FutureProvider.family<List<AuditPlanField>, AuditPlanningParams>(
        (ref, params) async {
  final user = await ref.watch(currentUserProvider.future);
  if (!detasselingRoleScopeFor(user).canView) return [];
  final raw = await ref.watch(masterFieldCoverageScopedProvider(
          MasterFieldMapScope(region: params.region))
      .future);
  final parsed = await parseMasterFieldMapRows(raw);
  return parsed
      .where((f) =>
          f.raw['region']?.toString().trim().toLowerCase() != 'region tester')
      .map((f) => AuditPlanField(
          f, WeeklyAuditField.fromRaw(f.raw, weekStart: params.weekStart)))
      .toList();
});
