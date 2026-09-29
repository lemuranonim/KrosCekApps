import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/services/supabase_auth_service.dart';
import 'package:kroscek/services/supabase_service.dart';
import 'package:kroscek/utils/master_field_region_scope.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RegionScopeService extends SupabaseService {
  _RegionScopeService()
    : super(
        client: SupabaseClient(
          'https://fields.invalid',
          'test-key',
          httpClient: MockClient(
            (_) async => http.Response('unexpected request', 500),
          ),
        ),
        mapCacheEnabled: false,
      );

  final regionSeasons = <String?>[];
  final mapScopes = <({String? season, String? region})>[];

  @override
  Future<String?> getLatestActiveMasterFieldSeason() async => 'DS26';

  @override
  Future<List<String>> getActiveMasterFieldRegions({
    String? season,
    String? qaFi,
    String? qaSpv,
  }) async {
    regionSeasons.add(season);
    return season == null
        ? const ['Region Trial', 'Region Lama']
        : const ['Region 1'];
  }

  @override
  Future<List<Map<String, dynamic>>> getMasterFieldsForMap({
    String? qaFi,
    String? qaSpv,
    String? season,
    String? region,
    String? district,
    bool bypassCache = false,
  }) async {
    mapScopes.add((season: season, region: region));
    return [
      {
        'field_number': region == seasonIndependentMasterFieldRegion
            ? 'TRIAL-1'
            : 'REGULAR-1',
        'region': region ?? 'Region 1',
        'season': season,
      },
    ];
  }
}

void main() {
  test(
    'Region Trial is season-independent without affecting other regions',
    () {
      expect(isSeasonIndependentMasterFieldRegion(' Region Trial '), isTrue);
      expect(isSeasonIndependentMasterFieldRegion('region trial'), isTrue);
      expect(isSeasonIndependentMasterFieldRegion('Region 5'), isFalse);

      expect(
        masterFieldSeasonForRegion(season: 'DS26', region: 'Region Trial'),
        isNull,
      );
      expect(
        masterFieldSeasonForRegion(season: 'DS26', region: 'Region 5'),
        'DS26',
      );
    },
  );

  test('season-scoped options add only Region Trial from all seasons', () {
    final regions = includeSeasonIndependentMasterFieldRegions(
      scopedRegions: const ['Region 5', 'Region 1'],
      allSeasonRegions: const ['Region Lama', 'region trial', 'Region 1'],
    );

    expect(regions, ['Region 1', 'Region 5', 'region trial']);
  });

  test(
    'season-scoped providers append and load Region Trial separately',
    () async {
      final service = _RegionScopeService();
      final container = ProviderContainer(
        overrides: [
          supabaseServiceProvider.overrideWithValue(service),
          currentUserProvider.overrideWith(
            (ref) async => const AppUser(
              id: 'admin',
              email: 'admin@example.test',
              name: 'Admin',
              role: 'ADMIN',
              action: 'all',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      const scope = MasterFieldMapScope(allSeasons: false);

      final regions = await container.read(
        activeMasterFieldRegionsProvider(scope).future,
      );
      final fields = await container.read(
        masterFieldMapScopedProvider(scope).future,
      );

      expect(regions, ['Region 1', 'Region Trial']);
      expect(service.regionSeasons, ['DS26', null]);
      expect(
        service.mapScopes,
        containsAll([
          (season: 'DS26', region: null),
          (season: null, region: 'Region Trial'),
        ]),
      );
      expect(
        fields.map((field) => field['field_number']),
        containsAll(['REGULAR-1', 'TRIAL-1']),
      );
    },
  );
}
