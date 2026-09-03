import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/providers/qa_mapping_provider.dart';

QaMappingItem _mapping({
  required int id,
  required String fieldSpv,
  required String qaSpv,
  required String qaFi,
  String village = 'Mangunan',
}) {
  return QaMappingItem.fromJson({
    'id': id,
    'region': 'Region 4',
    'district_kab': 'Kabupaten Blitar',
    'sub_district_kec': 'Udanawu',
    'village_desa': village,
    'field_spv': fieldSpv,
    'qa_spv': qaSpv,
    'qa_fi': qaFi,
    'fa': 'FA Test',
    'status': 'active',
    'approval_status': 'approved',
    'is_active': true,
  });
}

void main() {
  test('different Field SPV owners may split the same village', () {
    final resindra = _mapping(
      id: 1,
      fieldSpv: 'Resindra',
      qaSpv: 'Krisna',
      qaFi: 'FI Krisna',
    );
    final antok = _mapping(
      id: 2,
      fieldSpv: 'Antok Yuniarko',
      qaSpv: 'Moch. Aminuddin',
      qaFi: 'FI Aminuddin',
    );

    final index = buildQaMappingConflictIndex([resindra, antok]);

    expect(index.total, 0);
  });

  test('one Field SPV cannot have two QA SPV owners in one district', () {
    final first = _mapping(
      id: 1,
      fieldSpv: 'Resindra',
      qaSpv: 'Krisna',
      qaFi: 'FI A',
      village: 'Mangunan',
    );
    final second = _mapping(
      id: 2,
      fieldSpv: 'Resindra',
      qaSpv: 'Moch. Aminuddin',
      qaFi: 'FI B',
      village: 'Bakung',
    );

    final index = buildQaMappingConflictIndex([first, second]);

    expect(index.hasConflict(first), isTrue);
    expect(index.hasConflict(second), isTrue);
  });

  test('one ownership breakdown cannot have two QA FI names', () {
    final first = _mapping(
      id: 1,
      fieldSpv: 'Resindra',
      qaSpv: 'Krisna',
      qaFi: 'FI A',
    );
    final second = _mapping(
      id: 2,
      fieldSpv: 'Resindra',
      qaSpv: 'Krisna',
      qaFi: 'FI B',
    );

    final index = buildQaMappingConflictIndex([first, second]);

    expect(index.hasConflict(first), isTrue);
    expect(index.hasConflict(second), isTrue);
  });

  test('QA FI area conflict is independent from Field SPV', () {
    final resindra = _mapping(
      id: 1,
      fieldSpv: 'Resindra',
      qaSpv: 'Krisna',
      qaFi: 'FI A',
    );
    final indung = _mapping(
      id: 2,
      fieldSpv: 'Indung',
      qaSpv: 'Krisna',
      qaFi: 'FI B',
    );

    final index = buildQaMappingConflictIndex([resindra, indung]);

    expect(index.hasConflict(resindra), isTrue);
    expect(index.hasConflict(indung), isTrue);
  });

  test('legacy rows without Field SPV retain village conflict detection', () {
    final first = _mapping(
      id: 1,
      fieldSpv: '',
      qaSpv: 'Krisna',
      qaFi: 'FI A',
    );
    final second = _mapping(
      id: 2,
      fieldSpv: '',
      qaSpv: 'Krisna',
      qaFi: 'FI B',
    );

    final index = buildQaMappingConflictIndex([first, second]);

    expect(index.hasConflict(first), isTrue);
    expect(index.hasConflict(second), isTrue);
  });
}
