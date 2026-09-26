import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/utils/active_phase_filter.dart';
import 'package:kroscek/widgets/audit_status_widgets.dart';
import 'package:kroscek/widgets/field_list_view.dart';

ParsedFieldData _field(String number, int dap, String hybrid) {
  return ParsedFieldData(
    raw: {
      'field_number': number,
      'farmer_name': 'Farmer $number',
      'hybrid': hybrid,
      'region': 'Region 1',
      'district_kab': 'Test District',
      'sub_district_kec': 'Test Subdistrict',
    },
    lat: -7.0,
    lng: 112.0,
    isDefault: false,
    isCorrected: false,
    isFromPolygon: true,
    dap: dap,
  );
}

void main() {
  test('one active phase applies the correct FC, SC, and PSP DAP rules', () {
    final fields = [
      _field('FC-VEG', 30, 'ADV 777'),
      _field('FC-GEN', 55, 'ADV 777'),
      _field('SC-GEN', 45, 'AX01'),
      _field('PSP-GEN', 80, 'ASF'),
      _field('SC-PRE', 70, 'AX01'),
    ];

    final generative = filterFieldListByActivePhase(
      fields,
      activePhase: ActivePhaseView.generative,
      deltaDays: 0,
    ).map((field) => field.raw['field_number']).toSet();

    expect(generative, {'FC-GEN', 'SC-GEN', 'PSP-GEN'});
  });

  testWidgets('list sheet shows one synchronized phase filter', (tester) async {
    final fields = [
      _field('FC-VEG', 30, 'ADV 777'),
      _field('FC-GEN', 55, 'ADV 777'),
    ];
    var selectedPhase = ActivePhaseView.auto;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => FieldListView.showSheet(
                  context,
                  fieldsData: fields,
                  userLocation: null,
                  getMarkerColor: (dap, {hybrid}) => Colors.green,
                  onUncoordBannerTap: (_) {},
                  onNavigateTap: (_, __) {},
                  isMassMode: false,
                  selectedFieldNumbers: const {},
                  onFieldTap: (_) {},
                  activePhase: selectedPhase,
                  onPhaseChanged: (phase) => selectedPhase = phase,
                  fieldsForPhase: (_) => fields,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AuditPhaseFilterBar), findsOneWidget);
    expect(find.text('FASE & STATUS AUDIT'), findsOneWidget);
    expect(find.text('Vegetative (<50 DAP)'), findsNothing);
    expect(find.text('FC-VEG'), findsOneWidget);
    expect(find.text('FC-GEN'), findsOneWidget);

    await tester.tap(find.text('Veg'));
    await tester.pumpAndSettle();

    expect(selectedPhase, ActivePhaseView.vegetative);
    expect(find.text('FC-VEG'), findsOneWidget);
    expect(find.text('FC-GEN'), findsNothing);
  });
}
