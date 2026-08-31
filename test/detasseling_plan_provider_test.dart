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
  final params = DetasselingPlanningParams(
    weekStart: DateTime(2026, 8, 24),
  );

  ParsedFieldData field(Map<String, dynamic> raw) => ParsedFieldData(
        raw: raw,
        lat: -7.6,
        lng: 112.1,
        isDefault: false,
        isCorrected: false,
        isFromPolygon: false,
        dap: 50,
      );

  Map<String, dynamic> raw({Object? vegetative, String? topLevelCodet}) => {
        'field_number': 'FN-1',
        'farmer_name': 'Pak Budi',
        'hybrid': 'FC',
        'effective_area_ha': 2.5,
        'planting_date_pdn': '2026-07-06',
        'village_desa': 'Sumber',
        'district_kab': 'Blitar',
        'region': 'East',
        if (vegetative != null) 'audit_vegetative': vegetative,
        if (topLevelCodet != null) 'co_detasseling': topLevelCodet,
      };

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
}
