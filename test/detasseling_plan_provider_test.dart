import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/providers/detasseling_plan_provider.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/services/supabase_auth_service.dart';

void main() {
  const manager = AppUser(
    id: 'manager',
    email: 'manager@example.invalid',
    name: 'Manager',
    role: 'MANAGER',
    action: 'all',
  );
  final params = DetasselingPlanningParams(weekStart: DateTime(2026, 8, 24));

  ParsedFieldData field(Map<String, dynamic> raw) => ParsedFieldData(
    raw: raw,
    lat: -7.6,
    lng: 112.1,
    isDefault: false,
    isCorrected: false,
    isFromPolygon: false,
    dap: 50,
  );

  Map<String, dynamic> raw({
    Object? vegetative,
    String? topLevelCodet,
    double effectiveAreaHa = 2.5,
  }) => {
    'field_number': 'FN-1',
    'farmer_name': 'Pak Budi',
    'hybrid': 'FC',
    'effective_area_ha': effectiveAreaHa,
    'planting_date_pdn': '2026-07-06',
    'village_desa': 'Sumber',
    'district_kab': 'Blitar',
    'region': 'East',
    if (vegetative != null) 'audit_vegetative': vegetative,
    if (topLevelCodet != null) 'co_detasseling': topLevelCodet,
  };

  test('FI and QA SPV stay role-scoped when action is all', () {
    final spv = detasselingRoleScopeForValues(
      role: 'SPV',
      action: 'all',
      name: 'SPV Team',
    );
    final fi = detasselingRoleScopeForValues(
      role: 'FI',
      action: 'all',
      name: 'FI Team',
    );

    expect(spv.type, DetasselingScopeType.spv);
    expect(spv.isRestricted, isTrue);
    expect(fi.type, DetasselingScopeType.fi);
    expect(fi.isRestricted, isTrue);
  });

  test('Planning DT keeps the CODET name from vegetative audit data', () {
    final plan = buildDetasselingPlanningData(
      [
        field(raw(vegetative: {'co_detasseling': 'CODET RESINDRA'})),
      ],
      params,
      user: manager,
    );

    expect(plan.groups.single.codet, 'CODET RESINDRA');
  });

  test('Planning DT accepts a flattened CODET payload as fallback', () {
    final plan = buildDetasselingPlanningData(
      [field(raw(topLevelCodet: 'CODET 07'))],
      params,
      user: manager,
    );

    expect(plan.groups.single.codet, 'CODET 07');
  });

  test('every positive-area detasseling pass gets at least one TKD', () {
    expect(detasselingAllocatedTkdByPass(0.05, DetasselingCropFilter.fc), [
      1,
      1,
      1,
    ]);
    expect(detasselingAllocatedTkdByPass(0.05, DetasselingCropFilter.sc), [
      1,
      1,
      1,
      1,
      1,
    ]);
    expect(detasselingRecommendedTkdForArea(0.05, DetasselingCropFilter.fc), 3);
  });

  test('zero-area and terminal PLD fields are excluded from DT planning', () {
    final plan = buildDetasselingPlanningData(
      [
        field(raw(effectiveAreaHa: 0)),
        field(
          raw(vegetative: {'date_of_audit': '2026-08-20', 'flagging': 'PLD'}),
        ),
      ],
      params,
      user: manager,
    );

    expect(plan.groups, isEmpty);
    expect(plan.plannedFieldCount, 0);
    expect(plan.recommendedTkd, 0);
  });
}
