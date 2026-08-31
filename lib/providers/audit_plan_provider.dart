import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/qa_name_helper.dart';
import '../utils/weekly_audit.dart';
import 'detasseling_plan_provider.dart';
import 'master_fields_provider.dart';

typedef AuditPlanningScope = ({
  String? region,
  String? district,
  String? season,
});
typedef AuditPlanningParams = ({
  DateTime weekStart,
  String? region,
  String? district,
  String? season,
});
const auditPlanningPhases = {
  'vegetative',
  'generative',
  'pre_harvest',
  'harvest'
};

final auditPlanningRegionsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  final user = await ref
      .watch(currentUserProvider.future)
      .timeout(const Duration(seconds: 30));
  final scope = detasselingRoleScopeFor(user);
  if (!scope.canView || (scope.isRestricted && scope.name.isEmpty)) return [];
  final regions = await service
      .getActiveMasterFieldRegions(
        qaFi: scope.type == DetasselingScopeType.fi ? scope.name : null,
        qaSpv: scope.type == DetasselingScopeType.spv ? scope.name : null,
      )
      .timeout(const Duration(seconds: 30));
  return regions
      .where((region) => region.trim().toLowerCase() != 'region tester')
      .toSet()
      .toList()
    ..sort();
}, retry: (_, __) => null);

// Reused when changing the week: only dates/phase completion, not map geometry
// or all audit observations for every active field.
final auditPlanningIndexProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, AuditPlanningScope>(
        (ref, planningScope) async {
  final service = ref.watch(supabaseServiceProvider);
  final user = await ref
      .watch(currentUserProvider.future)
      .timeout(const Duration(seconds: 30));
  final roleScope = detasselingRoleScopeFor(user);
  if (!ref.mounted ||
      !roleScope.canView ||
      (roleScope.isRestricted && roleScope.name.isEmpty)) {
    return [];
  }
  final rows = await service.getAuditPlanningIndex(
    region: planningScope.region,
    district: planningScope.district,
    season: planningScope.season,
    qaFi: roleScope.type == DetasselingScopeType.fi ? roleScope.name : null,
    qaSpv: roleScope.type == DetasselingScopeType.spv ? roleScope.name : null,
  );
  return rows.where((row) => _visibleToPlanning(row, roleScope)).toList();
}, retry: (_, __) => null);

class AuditPlanField {
  final ParsedFieldData parsed;
  final WeeklyAuditField weekly;
  const AuditPlanField(this.parsed, this.weekly);
}

final auditPlanningProvider = FutureProvider.autoDispose
    .family<List<AuditPlanField>, AuditPlanningParams>((ref, params) async {
  final service = ref.watch(supabaseServiceProvider);
  final user = await ref
      .watch(currentUserProvider.future)
      .timeout(const Duration(seconds: 30));
  final roleScope = detasselingRoleScopeFor(user);
  if (!ref.mounted ||
      !roleScope.canView ||
      (roleScope.isRestricted && roleScope.name.isEmpty)) {
    return [];
  }
  final planningScope = (
    region: params.region,
    district: params.district,
    season: params.season,
  );
  final index =
      await ref.watch(auditPlanningIndexProvider(planningScope).future);
  if (!ref.mounted) return [];
  final now = DateTime.now();
  final numbers = await compute(_planningTargetNumbers,
      (rows: index, weekStart: params.weekStart, now: now));
  if (!ref.mounted || numbers.isEmpty) return [];
  final raw = await service.getAuditPlanningFields(
    numbers,
    region: params.region,
    district: params.district,
    season: params.season,
    qaFi: roleScope.type == DetasselingScopeType.fi ? roleScope.name : null,
    qaSpv: roleScope.type == DetasselingScopeType.spv ? roleScope.name : null,
  );
  if (!ref.mounted) return [];
  // Recheck scope and eligibility in case a field changed between requests.
  final weekly = await compute(_planningTargets, (
    rows: raw.where((row) => _visibleToPlanning(row, roleScope)).toList(),
    weekStart: params.weekStart,
    now: now,
  ));
  if (!ref.mounted) return [];
  final parsed =
      await parseMasterFieldMapRows(weekly.map((field) => field.raw).toList());
  return [
    for (var i = 0; i < weekly.length; i++)
      AuditPlanField(parsed[i], weekly[i]),
  ];
}, retry: (_, __) => null);

bool _visibleToPlanning(Map<String, dynamic> row, DetasselingRoleScope scope) {
  if (row['region']?.toString().trim().toLowerCase() == 'region tester') {
    return false;
  }
  return switch (scope.type) {
    DetasselingScopeType.fi => QaNameHelper.fieldHasFi(row, scope.name),
    DetasselingScopeType.spv => QaNameHelper.fieldHasSpv(row, scope.name),
    DetasselingScopeType.all => true,
    DetasselingScopeType.blocked => false,
  };
}

typedef _PlanningProjection = ({
  List<Map<String, dynamic>> rows,
  DateTime weekStart,
  DateTime now,
});

List<WeeklyAuditField> _planningTargets(_PlanningProjection input) => input.rows
    .map((row) => WeeklyAuditField.fromRaw(row,
        weekStart: input.weekStart, now: input.now))
    .where((field) => field.targets.any(
        (target) => auditPlanningPhases.contains(auditStage(target.phase))))
    .toList();

List<String> _planningTargetNumbers(_PlanningProjection input) =>
    _planningTargets(input)
        .map((field) => field.raw['field_number']?.toString().trim() ?? '')
        .where((number) => number.isNotEmpty)
        .toSet()
        .toList();
