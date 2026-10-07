import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/utils/dap_helper.dart';

void main() {
  group('DapHelper.isPsp', () {
    test('recognizes every AS hybrid family as PSP', () {
      expect(DapHelper.isPsp('ASF8'), isTrue);
      expect(DapHelper.isPsp('ASS2'), isTrue);
      expect(DapHelper.isPsp(' asf11 '), isTrue);
      expect(DapHelper.isPsp('ass6'), isTrue);
    });

    test('does not classify FC, SC, or empty hybrids as PSP', () {
      expect(DapHelper.isPsp('ADV 777'), isFalse);
      expect(DapHelper.isPsp('AX01'), isFalse);
      expect(DapHelper.isPsp(''), isFalse);
      expect(DapHelper.isPsp(null), isFalse);
    });
  });
}
