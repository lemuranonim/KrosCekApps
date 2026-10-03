import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kroscek/providers/master_fields_provider.dart';
import 'package:kroscek/services/master_field_read_cache.dart';

Map<String, dynamic> asMap(Object? value) =>
    Map<String, dynamic>.from(value! as Map);

List<Map<String, dynamic>> asRows(Object? value) => (value! as List)
    .map((row) => Map<String, dynamic>.from(row as Map))
    .toList(growable: false);

void main() {
  late Directory cacheDirectory;
  late Map<String, dynamic> fixture;
  late Map<String, dynamic> scope;
  late Map<String, dynamic> datasets;

  setUpAll(() async {
    fixture = asMap(
      jsonDecode(
        await File('test/fixtures/cache_baseline_v1.json').readAsString(),
      ),
    );
    scope = asMap(fixture['scope']);
    datasets = asMap(fixture['datasets']);

    cacheDirectory = await Directory.systemTemp.createTemp(
      'kroscek-cache-stage1-contract-',
    );
    Hive.init(cacheDirectory.path);
    await Hive.openBox<dynamic>(MasterFieldReadCache.boxName);
  });

  setUp(() async {
    await Hive.box<dynamic>(MasterFieldReadCache.boxName).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await cacheDirectory.delete(recursive: true);
  });

  test('versioned fixture locks all three read-cache dataset contracts', () {
    expect(fixture['contractVersion'], 1);
    final productionScale = asMap(fixture['productionScaleReference']);
    expect(productionScale['rowCount'], 34600);
    expect(productionScale['activeRowCount'], 34600);
    expect(productionScale['uniqueFieldNumberCount'], 34600);
    final capturedAt = productionScale['capturedAt']! as String;
    expect(() => DateTime.parse(capturedAt), returnsNormally);
    expect(capturedAt, endsWith('+07:00'));
    expect(productionScale['source'], 'Supabase public.master_fields');
    expect(datasets.keys.toSet(), {'map', 'coverage', 'planning_index'});

    for (final datasetEntry in datasets.entries) {
      final contract = asMap(datasetEntry.value);
      final requiredKeys = (contract['requiredKeys'] as List).cast<String>();
      final forbiddenKeys = (contract['forbiddenKeys'] as List).cast<String>();
      final rows = asRows(contract['rows']);
      final fieldNumbers = <String>{};

      expect(rows, isNotEmpty, reason: '${datasetEntry.key} must have rows');
      for (final row in rows) {
        final fieldNumber = row['field_number']?.toString().trim() ?? '';
        expect(fieldNumber, isNotEmpty);
        expect(
          fieldNumbers.add(fieldNumber),
          isTrue,
          reason: '${datasetEntry.key} contains duplicate $fieldNumber',
        );
        for (final key in requiredKeys) {
          expect(
            row.containsKey(key),
            isTrue,
            reason: '${datasetEntry.key}/$fieldNumber is missing $key',
          );
        }
        for (final key in forbiddenKeys) {
          expect(
            row.containsKey(key),
            isFalse,
            reason: '${datasetEntry.key}/$fieldNumber unexpectedly has $key',
          );
        }
      }
    }
  });

  test(
    'current Hive cache round-trips every baseline payload losslessly',
    () async {
      for (final datasetEntry in datasets.entries) {
        final contract = asMap(datasetEntry.value);
        final rows = asRows(contract['rows']);
        final version = contract['serverVersion']! as int;

        await MasterFieldReadCache.write(
          userId: scope['userId']! as String,
          dataset: datasetEntry.key,
          version: version,
          rows: rows,
          season: scope['season']! as String,
          region: scope['region']! as String,
          district: scope['district']! as String,
        );

        final saved = await MasterFieldReadCache.read(
          userId: scope['userId']! as String,
          dataset: datasetEntry.key,
          season: scope['season']! as String,
          region: scope['region']! as String,
          district: scope['district']! as String,
        );

        expect(saved, isNotNull, reason: '${datasetEntry.key} cache miss');
        expect(saved!.version, version);
        expect(saved.rows, rows);
      }
    },
  );

  test(
    'cache identity isolates account, dataset and every geographic scope',
    () {
      String key({
        String userId = 'user-a',
        String dataset = 'map',
        String? season = 'DS26',
        String? region = 'Region 5',
        String? district = 'Blitar',
      }) => MasterFieldReadCache.key(
        userId: userId,
        dataset: dataset,
        season: season,
        region: region,
        district: district,
      );

      final baseline = key();
      expect(key(userId: 'user-b'), isNot(baseline));
      expect(key(dataset: 'coverage'), isNot(baseline));
      expect(key(season: 'WS26'), isNot(baseline));
      expect(key(region: 'Region 4'), isNot(baseline));
      expect(key(district: 'Kediri'), isNot(baseline));
      expect(
        key(season: ' DS26 ', region: ' Region 5 ', district: ' Blitar '),
        baseline,
      );
      expect(
        key(season: null, region: null, district: null),
        key(season: ' ', region: '', district: '   '),
      );
    },
  );

  test('corrupt local entries fail open as a cache miss', () async {
    final cacheKey = MasterFieldReadCache.key(
      userId: 'user-a',
      dataset: 'map',
      region: 'Region 5',
    );
    await Hive.box<dynamic>(MasterFieldReadCache.boxName).put(cacheKey, {
      'version': 1,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'payload': '{not-json',
    });

    expect(
      await MasterFieldReadCache.read(
        userId: 'user-a',
        dataset: 'map',
        region: 'Region 5',
      ),
      isNull,
    );
  });

  test(
    'current retention contract keeps at most 12 entries per account',
    () async {
      for (var index = 0; index < 13; index++) {
        await MasterFieldReadCache.write(
          userId: 'user-a',
          dataset: 'map',
          version: index,
          district: 'District $index',
          rows: [
            {'field_number': 'FIELD-$index'},
          ],
        );
      }

      final prefix = 'mf-read-v2:user-a:';
      final userKeys = Hive.box<dynamic>(MasterFieldReadCache.boxName).keys
          .where((key) => key is String && key.startsWith(prefix));
      expect(userKeys, hasLength(12));
    },
  );

  test('map baseline preserves correction-geometry priority', () async {
    final mapRows = asRows(asMap(datasets['map'])['rows']);
    final parsed = await parseMasterFieldMapRows(mapRows);
    final corrected = parsed.firstWhere(
      (field) => field.raw['field_number'] == 'MAP-001',
    );

    expect(corrected.isCorrected, isTrue);
    expect(corrected.isFromPolygon, isTrue);
    expect(corrected.geometryWkt, mapRows.first['correction_geometry_wkt']);
    expect(corrected.lat, closeTo(-8.5, 0.0000001));
    expect(corrected.lng, closeTo(114.5, 0.0000001));
  });
}
