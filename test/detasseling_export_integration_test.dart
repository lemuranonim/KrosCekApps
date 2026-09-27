import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all Detasseling Map exports use the shared durable export flow', () {
    final source = File('lib/screens/qa/detasseling_map_screen.dart')
        .readAsStringSync();

    expect(
      RegExp(r'ExportFileService\.saveBytes\(').allMatches(source).length,
      4,
    );
    expect(source, contains('showExportCompletedDialog('));
    expect(source, contains('ExportFileService.open('));
    expect(source, isNot(contains('MediaStore().saveFile(')));
    expect(source, isNot(contains('OpenFile.open(')));
  });
}
