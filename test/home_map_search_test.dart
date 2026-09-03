import 'package:flutter_test/flutter_test.dart';
import 'package:kroscek/screens/qa/qa_screen.dart';

void main() {
  test('Home Map keeps Region 1 when switching to all seasons', () {
    final scope = resolveHomeMapSeasonScope(
      allSeasons: true,
      season: '-',
      selectedRegion: 'Region 1',
      showAllRegions: false,
    );

    expect(scope.allSeasons, true);
    expect(scope.season, null);
    expect(scope.region, 'Region 1');
    expect(scope.allRegions, false);
  });

  test('Home Map keeps all-region scope when season changes', () {
    final scope = resolveHomeMapSeasonScope(
      allSeasons: false,
      season: '-',
      selectedRegion: null,
      showAllRegions: true,
    );

    expect(scope.allSeasons, false);
    expect(scope.season, '-');
    expect(scope.region, null);
    expect(scope.allRegions, true);
  });

  test('Home Map field-number lookup is case-insensitive and explicit', () {
    final filters = [
      SearchFilter(
        param: SearchParam.fieldNumber,
        value: ' dc6q5e019 ',
      ),
    ];
    final field = <String, dynamic>{
      'field_number': 'DC6Q5E019',
      'qa_fi': 'Mohammad Wahyudi',
    };

    expect(homeMapHasActiveFieldNumberSearch(filters), true);
    expect(homeMapMatchesSearchFilters(field, filters), true);
    expect(
      homeMapMatchesSearchFilters(
        {...field, 'field_number': 'DC6Q5E020'},
        filters,
      ),
      false,
    );
  });

  test('Home Map keeps additional search parameters conjunctive', () {
    final filters = [
      SearchFilter(param: SearchParam.fieldNumber, value: 'DC6Q5E019'),
      SearchFilter(param: SearchParam.qaFI, value: 'wahyudi'),
    ];

    expect(
      homeMapMatchesSearchFilters(
        {
          'field_number': 'DC6Q5E019',
          'qa_fi': 'Mohammad Wahyudi',
        },
        filters,
      ),
      true,
    );
    expect(
      homeMapMatchesSearchFilters(
        {
          'field_number': 'DC6Q5E019',
          'qa_fi': 'QA Lain',
        },
        filters,
      ),
      false,
    );
  });
}
