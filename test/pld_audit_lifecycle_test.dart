import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/models/pld_audit_lifecycle.dart';

void main() {
  test('parses per-phase Pending, Confirmed, and Updated PLD states', () {
    final bundle = PldAuditLifecycleBundle.fromJson({
      'field_number': 'DC6FHK045',
      'viewer_role': 'FI',
      'can_revise': true,
      'statuses': [
        {
          'phase_key': 'vegetative',
          'status': 'PENDING',
          'effective_area_ha': 0.5,
          'recommended_flagging': 'PLD',
          'locked': false,
        },
        {
          'phase_key': 'generative_1',
          'status': 'CONFIRMED',
          'effective_area_ha': 0,
          'recommended_flagging': 'PLD',
          'locked': true,
        },
        {
          'phase_key': 'pre_harvest',
          'status': 'UPDATED',
          'effective_area_ha': 0.25,
          'active_flagging': 'RFI',
          'locked': false,
        },
      ],
      'history': [
        {
          'id': 7,
          'phase_key': 'vegetative',
          'event_type': 'UPDATED',
          'old_payload': {'flagging': 'PLD'},
          'new_payload': {'flagging': 'GF'},
          'old_flagging': 'PLD',
          'new_flagging': 'GF',
          'lifecycle_status': 'UPDATED',
          'actor_name': 'Nanda Widjaksono',
          'actor_role': 'FI',
          'created_at': '2026-09-29T08:00:00+07:00',
        },
      ],
    });

    expect(bundle.fieldNumber, 'DC6FHK045');
    expect(bundle.viewerRole, 'FI');
    expect(bundle.canRevise, isTrue);
    expect(bundle.pendingPhaseKeys, {'vegetative'});
    expect(bundle.hasPending, isTrue);
    expect(bundle.hasConfirmed, isTrue);
    expect(bundle.byPhase['generative_1']!.locked, isTrue);
    expect(bundle.byPhase['pre_harvest']!.activeFlagging, 'RFI');
    expect(bundle.history.single.oldFlagging, 'PLD');
    expect(bundle.history.single.newFlagging, 'GF');
  });

  test('recognizes ACT lifecycle events and Indonesian phase labels', () {
    final revision = PldAuditRevision.fromJson({
      'id': 8,
      'phase_key': 'harvest',
      'event_type': 'ACT_CONFIRMED',
      'old_payload': const <String, dynamic>{},
      'new_payload': const <String, dynamic>{},
      'created_at': '2026-09-29T01:00:00Z',
    });

    expect(revision.isActEvent, isTrue);
    expect(pldAuditPhaseLabel('generative_3'), 'Generative CP3');
    expect(pldAuditPhaseLabel('pre_harvest'), 'Pre-Harvest');
  });
}
