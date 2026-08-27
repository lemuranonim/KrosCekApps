import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kroscek/providers/audit_plan_provider.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/services/supabase_auth_service.dart';
import 'package:kroscek/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'weekly_audit_test.dart' as fixtures;

http.Response response(List<Map<String, dynamic>> rows) =>
    http.Response(jsonEncode(rows), 200,
        headers: {'content-type': 'application/json'});

SupabaseService mockService(
    Future<http.Response> Function(http.Request) handler,
    {Duration timeout = const Duration(seconds: 45)}) {
  final client = SupabaseClient('https://planning.invalid', 'test-key',
      httpClient: MockClient((request) async {
    final result = await handler(request);
    return http.Response.bytes(result.bodyBytes, result.statusCode,
        headers: result.headers, request: request);
  }));
  addTearDown(client.dispose);
  return SupabaseService(client: client, auditPlanningTimeout: timeout);
}

ProviderContainer planningContainer(SupabaseService service,
    {String role = 'MANAGER', String name = 'QA 1', String action = 'all'}) {
  final container = ProviderContainer(overrides: [
    supabaseServiceProvider.overrideWithValue(service),
    currentUserProvider.overrideWith((ref) async => AppUser(
        id: 'test-user',
        email: 'qa@example.invalid',
        name: name,
        role: role,
        action: action)),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<List<AuditPlanField>> loadPlan(ProviderContainer container,
    {DateTime? week}) {
  final provider = auditPlanningProvider((
    weekStart: week ?? fixtures.week,
    region: 'East',
    district: null,
    season: null,
  ));
  final subscription = container.listen(provider, (_, __) {});
  addTearDown(subscription.close);
  return container.read(provider.future);
}

List<String> requestedNumbers(http.Request request) =>
    request.url.queryParameters['field_number']!
        .replaceFirst('in.(', '')
        .replaceFirst(RegExp(r'\)$'), '')
        .split(',')
        .map((number) => number.replaceAll('"', ''))
        .toList();

void main() {
  test('planning index is slim, scoped in the query and reads every page',
      () async {
    final requests = <http.Request>[];
    final service = mockService((request) async {
      requests.add(request);
      final count = requests.length == 1 ? 1000 : 1;
      return response(List.generate(count, (i) => {'field_number': 'F$i'}));
    });
    final rows = await service.getAuditPlanningIndex(
        region: 'East',
        district: 'Blitar',
        season: 'S1',
        qaFi: 'FI 1',
        qaSpv: 'SPV 1');
    expect(rows, hasLength(1001));
    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters['offset'], '1000');
    for (final request in requests) {
      final params = request.url.queryParameters;
      expect(params['is_active'], 'eq.true');
      expect(params['region'], 'eq.East');
      expect(params['district_kab'], 'eq.Blitar');
      expect(params['season'], 'eq.S1');
      expect(params['qa_fi'], 'ilike.%FI 1%');
      expect(params['qa_spv'], 'ilike.%SPV 1%');
      expect(params['select'], contains('rev_planting_date'));
      expect(params['select'], contains('date_of_inspeksi_roguing_4'));
      expect(params['select'], isNot(contains('geometry_wkt')));
      expect(params['select'], isNot(contains('crop_uniformity')));
      expect(params['select'], isNot(contains('audit_generative')));
    }
  });

  test('detail queries use bounded field-number batches and preserve scope',
      () async {
    final requests = <http.Request>[];
    final service = mockService((request) async {
      requests.add(request);
      return response(requestedNumbers(request)
          .map((number) => {'field_number': number})
          .toList());
    });
    expect(await service.getAuditPlanningFields([' ', '']), isEmpty);
    expect(requests, isEmpty);
    final rows = await service.getAuditPlanningFields(
        [...List.generate(121, (i) => 'F$i'), ' F0 '],
        region: 'East', district: 'Blitar', season: 'S1', qaSpv: 'SPV 1');
    expect(rows, hasLength(121));
    expect(requests.map((r) => requestedNumbers(r).length), [100, 21]);
    for (final request in requests) {
      expect(request.url.queryParameters['region'], 'eq.East');
      expect(request.url.queryParameters['district_kab'], 'eq.Blitar');
      expect(request.url.queryParameters['season'], 'eq.S1');
      expect(request.url.queryParameters['qa_spv'], 'ilike.%SPV 1%');
      expect(request.url.queryParameters['is_active'], 'eq.true');
      // This column is referenced by an old SC form but is not present in the
      // production audit_generative schema. Including it rejects the complete
      // embedded select with PostgREST 42703.
      expect(request.url.queryParameters['select'],
          isNot(contains('roguing_status_3')));
    }
  });

  test('a stalled page ends with timeout instead of a partial planning total',
      () async {
    final stalledPage = Completer<http.Response>();
    var requests = 0;
    final service = mockService((request) async {
      requests++;
      if (requests == 1) {
        return response(List.generate(1000, (i) => {'field_number': 'F$i'}));
      }
      return stalledPage.future;
    }, timeout: const Duration(seconds: 1));
    await expectLater(
        service.getAuditPlanningIndex(), throwsA(isA<TimeoutException>()));
    expect(requests, 2);
    stalledPage.complete(response([]));
  });

  test(
      'details are requested only for weekly targets including revised dates '
      'and incomplete PSP passes', () async {
    final rows = [
      fixtures.fieldAt(20, id: 'veg'),
      fixtures.fieldAt(71, id: 'ph'),
      fixtures.fieldAt(95, id: 'harvest'),
      fixtures.fieldAt(200, id: 'old'),
      fixtures.fieldAt(50, id: 'generative-only'),
      fixtures.fieldAt(20,
          id: 'done-before-week', veg: {'date_of_audit': '2026-08-23'}),
      fixtures.fieldAt(200,
          id: 'revised', veg: {'rev_planting_date': '04/08/2026'}),
      fixtures.fieldAt(35, id: 'psp-partial', hybrid: 'ASF 1', veg: {
        'date_of_inspeksi_roguing_1': '2026-08-20',
      }),
      fixtures.fieldAt(35, id: 'psp-done', hybrid: 'ASF 1', veg: {
        for (var i = 1; i <= 4; i++)
          'date_of_inspeksi_roguing_$i': '2026-08-20',
      }),
      {...fixtures.fieldAt(20, id: 'tester'), 'region': 'Region Tester'},
    ];
    final detailNumbers = <String>[];
    final service = mockService((request) async {
      if (request.url.queryParameters.containsKey('field_number')) {
        detailNumbers.addAll(requestedNumbers(request));
      }
      // Return extra rows too, to exercise the final eligibility recheck.
      return response(rows);
    });
    final fields = await loadPlan(planningContainer(service));
    const targets = ['veg', 'ph', 'harvest', 'revised', 'psp-partial'];
    expect(detailNumbers, unorderedEquals(targets));
    expect(fields.map((field) => field.weekly.raw['field_number']),
        unorderedEquals(targets));
  });

  test('no eligible targets skips the detail request entirely', () async {
    var requests = 0;
    final service = mockService((request) async {
      requests++;
      return response([fixtures.fieldAt(200)]);
    });
    expect(await loadPlan(planningContainer(service)), isEmpty);
    expect(requests, 1);
  });

  test('changing week reuses the index and only reloads targeted details',
      () async {
    var indexRequests = 0;
    var detailRequests = 0;
    final service = mockService((request) async {
      request.url.queryParameters.containsKey('field_number')
          ? detailRequests++
          : indexRequests++;
      return response([fixtures.fieldAt(20)]);
    });
    final container = planningContainer(service);
    final firstProvider = auditPlanningProvider((
      weekStart: fixtures.week,
      region: 'East',
      district: null,
      season: null,
    ));
    final subscription = container.listen(firstProvider, (_, __) {});
    expect(await container.read(firstProvider.future), hasLength(1));
    // The screen replaces its old week subscription; it does not keep both
    // weeks mounted just to retain the shared index.
    subscription.close();
    expect(
        await loadPlan(container,
            week: fixtures.week.add(const Duration(days: 7))),
        hasLength(1));
    expect(indexRequests, 1);
    expect(detailRequests, 2);
  });

  for (final role in ['FI', 'SPV']) {
    test('$role keeps exact team scoping for both index and detail requests',
        () async {
      final requests = <http.Request>[];
      final service = mockService((request) async {
        requests.add(request);
        return response([
          fixtures.fieldAt(20, id: 'mine'),
          {
            ...fixtures.fieldAt(20, id: 'similar-name'),
            'qa_fi': 'FI 10',
            'qa_spv': 'SPV 10',
          },
        ]);
      });
      final fields = await loadPlan(planningContainer(service,
          role: role, name: '$role 1', action: 'audit'));
      expect(fields.single.weekly.raw['field_number'], 'mine');
      expect(requestedNumbers(requests.last), ['mine']);
      for (final request in requests) {
        expect(request.url.queryParameters['qa_${role.toLowerCase()}'],
            'ilike.%$role 1%');
      }
    });
  }

  test('guest access never starts a database query', () async {
    var requests = 0;
    final service = mockService((request) async {
      requests++;
      return response([]);
    });
    expect(await loadPlan(planningContainer(service, role: 'GUEST')), isEmpty);
    expect(requests, 0);
  });

  test('a query error surfaces without automatic background retries', () async {
    var requests = 0;
    final service = mockService((request) async {
      requests++;
      return http.Response(
          jsonEncode({'code': '42703', 'message': 'Column missing'}), 400,
          headers: {'content-type': 'application/json'});
    });
    final container = planningContainer(service);
    await expectLater(loadPlan(container), throwsA(anything));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(requests, 1);
    expect(
        container
            .read(auditPlanningProvider((
              weekStart: fixtures.week,
              region: 'East',
              district: null,
              season: null,
            )))
            .hasError,
        true);
  });
}
