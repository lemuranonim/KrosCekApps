import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/services/detasseling_iso_export_service.dart';

void main() {
  group('DetasselingIsoExportService.latestAvailablePass', () {
    test('returns null when no pass has been completed', () {
      expect(
        DetasselingIsoExportService.latestAvailablePass(null),
        isNull,
      );
      expect(
        DetasselingIsoExportService.latestAvailablePass({
          'date_of_audit_1': '   ',
          'date_of_audit_2': null,
        }),
        isNull,
      );
    });

    test('allows export as soon as pass 1 is completed', () {
      expect(
        DetasselingIsoExportService.latestAvailablePass({
          'date_of_audit_1': '2026-09-17',
        }),
        1,
      );
    });

    test('selects the latest completed pass', () {
      expect(
        DetasselingIsoExportService.latestAvailablePass({
          'date_of_audit_1': '2026-09-15',
          'date_of_audit_2': '2026-09-17',
        }),
        2,
      );
      expect(
        DetasselingIsoExportService.latestAvailablePass({
          'date_of_audit_1': '2026-09-13',
          'date_of_audit_2': '2026-09-15',
          'date_of_audit_3': '2026-09-17',
        }),
        3,
      );
    });

    test('respects the crop pass limit', () {
      final audit = {
        'date_of_audit_3': '2026-09-13',
        'date_of_audit_4': '2026-09-15',
        'date_of_audit_5': '2026-09-17',
      };

      expect(
        DetasselingIsoExportService.latestAvailablePass(audit, maxPass: 3),
        3,
      );
      expect(
        DetasselingIsoExportService.latestAvailablePass(audit, maxPass: 5),
        5,
      );
    });
  });
}
