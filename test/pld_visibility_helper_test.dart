import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/utils/pld_visibility_helper.dart';

void main() {
  test('zero effective area stops a field and uses its latest audit date', () {
    final state = PldVisibilityHelper.resolveField({
      'effective_area_ha': 0,
      'audit_vegetative': {
        'date_of_audit': '2026-08-21',
        'decision': 'Continue',
      },
    });

    expect(state.isOperational, isFalse);
    expect(state.reason, FieldStopReason.zeroEffectiveArea);
    expect(state.stoppedAt, DateTime(2026, 8, 21));
    expect(state.stoppedPhase, 'Vegetatif');
  });

  test('PLD freezes a field at the terminal audit date and phase', () {
    final state = PldVisibilityHelper.resolveField({
      'effective_area_ha': 1.25,
      'audit_generative': {
        'date_of_audit_2': '2026-08-26',
        'final_decision_2': 'PLD',
      },
    });

    expect(state.isOperational, isFalse);
    expect(state.reason, FieldStopReason.pld);
    expect(state.stoppedAt, DateTime(2026, 8, 26));
    expect(state.stoppedPhase, 'Generatif CP2');
  });

  test('newer active audit supersedes an older PLD observation', () {
    final state = PldVisibilityHelper.resolveField({
      'effective_area_ha': 1.25,
      'audit_vegetative': {'date_of_audit': '2026-08-01', 'flagging': 'PLD'},
      'audit_generative': {
        'date_of_audit_1': '2026-08-10',
        'final_flagging_1': 'GF',
      },
    });

    expect(state.isOperational, isTrue);
    expect(state.reason, FieldStopReason.active);
  });

  test('partial discard is not treated as a fully stopped field', () {
    final state = PldVisibilityHelper.resolveField({
      'effective_area_ha': 0.5,
      'audit_pre_harvest': {
        'audit_date': '2026-08-30',
        'final_decision': 'Discard Partial',
      },
    });

    expect(state.isOperational, isTrue);
  });
}
