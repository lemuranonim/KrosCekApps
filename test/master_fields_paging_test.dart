import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/screens/coverage/coverage_screen.dart';
import 'package:kroscek/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('map fetch still includes polygon geometry', () async {
    const wkt = 'POLYGON((112 -7,113 -7,113 -8,112 -7))';
    const correctionWkt = 'POLYGON((114 -8,115 -8,115 -9,114 -8))';
    var requestCount = 0;
    final client = SupabaseClient(
      'https://fields.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        requestCount++;
        expect(request.url.queryParameters['select'], contains('geometry_wkt'));
        expect(
          request.url.queryParameters['select'],
          contains('correction_geometry_wkt'),
        );
        expect(request.url.queryParameters['region'], 'eq.Region 5');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {
                'field_number': 'F1',
                'geometry_wkt': wkt,
                'correction_geometry_wkt': correctionWkt,
              },
            ]),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final rows = await SupabaseService(
      client: client,
      mapCacheEnabled: false,
    ).getMasterFieldsForMap(region: 'Region 5');
    expect(rows.single['geometry_wkt'], wkt);
    expect(rows.single['correction_geometry_wkt'], correctionWkt);
    expect(requestCount, 1);
  });

  test('correction geometry has priority over ACT geometry', () async {
    const actWkt = 'POLYGON((112 -7,113 -7,113 -8,112 -8,112 -7))';
    const correctionWkt = 'POLYGON((114 -8,115 -8,115 -9,114 -9,114 -8))';

    final rows = await parseMasterFieldMapRows([
      {
        'field_number': 'F1',
        'geometry_wkt': actWkt,
        'correction_geometry_wkt': correctionWkt,
        'coordinate': '-6,110',
      },
    ]);

    expect(rows.single.lat, closeTo(-8.5, 0.0000001));
    expect(rows.single.lng, closeTo(114.5, 0.0000001));
    expect(rows.single.geometryWkt, correctionWkt);
    expect(rows.single.isFromPolygon, isTrue);
    expect(rows.single.isCorrected, isTrue);
  });

  test('invalid correction geometry falls back to ACT geometry', () async {
    const actWkt = 'POLYGON((112 -7,113 -7,113 -8,112 -8,112 -7))';

    final rows = await parseMasterFieldMapRows([
      {
        'field_number': 'F1',
        'geometry_wkt': actWkt,
        'correction_geometry_wkt': 'INVALID',
      },
    ]);

    expect(rows.single.lat, closeTo(-7.5, 0.0000001));
    expect(rows.single.lng, closeTo(112.5, 0.0000001));
    expect(rows.single.geometryWkt, actWkt);
    expect(rows.single.isCorrected, isFalse);
  });

  test('KML correction writes only correction_geometry_wkt', () async {
    const wkt = 'POLYGON((112 -7,113 -7,113 -8,112 -7))';
    final client = SupabaseClient(
      'https://fields.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['correction_geometry_wkt'], wkt);
        expect(body.containsKey('geometry_wkt'), isFalse);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'field_number': 'F1'},
            ]),
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    await SupabaseService(client: client)
        .updateFieldCorrectionGeometryWkt(fieldNumber: 'F1', geometryWkt: wkt);
  });

  test('coverage pages load concurrently and remain in field order', () async {
    final requests = <http.Request>[];
    var activeRequests = 0;
    var peakRequests = 0;
    final client = SupabaseClient(
      'https://fields.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        activeRequests++;
        if (activeRequests > peakRequests) peakRequests = activeRequests;
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        // Complete pages out of order to verify the returned rows stay sorted.
        await Future<void>.delayed(
          Duration(milliseconds: offset == 1000 ? 20 : 2),
        );
        activeRequests--;
        final count = offset < 3000 ? 1000 : 10;
        final rows = List.generate(
          count,
          (i) => {
            'field_number': 'F${(offset + i).toString().padLeft(4, '0')}',
          },
        );
        return http.Response.bytes(
          utf8.encode(jsonEncode(rows)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    final rows = await SupabaseService(client: client)
        .getMasterFieldsForCoverage(
          region: 'Region 5',
          season: 'S1',
          qaFi: 'FI A',
        );

    expect(rows, hasLength(3010));
    expect(rows[0]['field_number'], 'F0000');
    expect(rows[1000]['field_number'], 'F1000');
    expect(rows[2000]['field_number'], 'F2000');
    expect(rows.last['field_number'], 'F3009');
    expect(peakRequests, 3);
    expect(requests, hasLength(4));
    for (final request in requests) {
      final params = request.url.queryParameters;
      expect(params['is_active'], 'eq.true');
      expect(params['region'], 'eq.Region 5');
      expect(params['season'], 'eq.S1');
      expect(params['qa_fi'], 'ilike.%FI A%');
      expect(params['order'], contains('season.asc'));
      expect(params['select'], contains('audit_vegetative'));
      expect(params['select'], isNot(contains('geometry_wkt')));
    }
  });

  test(
    'large coverage status lists can be parsed off the UI isolate',
    () async {
      final rawFields = List.generate(
        200,
        (index) => <String, dynamic>{
          'field_number': 'F$index',
          'hybrid': 'FC',
          'effective_area_ha': 1,
          'planting_date_pdn': '2026-08-01',
          'region': 'Region 5',
        },
      );
      final container = ProviderContainer(
        overrides: [
          masterFieldCoverageScopedProvider.overrideWith(
            (ref, scope) async => rawFields,
          ),
        ],
      );
      addTearDown(container.dispose);

      final statuses = await container.read(
        coverageStatusListScopedProvider(const MasterFieldMapScope.all())
            .future,
      );
      expect(statuses, hasLength(200));
      expect(statuses.first.fieldNumber, 'F0');
      expect(statuses.last.fieldNumber, 'F199');
    },
  );
}
