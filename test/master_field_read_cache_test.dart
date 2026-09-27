import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kroscek/services/master_field_read_cache.dart';

void main() {
  late Directory cacheDirectory;

  setUpAll(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'kroscek-master-field-cache-',
    );
    Hive.init(cacheDirectory.path);
    await Hive.openBox<dynamic>(MasterFieldReadCache.boxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await cacheDirectory.delete(recursive: true);
  });

  test('stores snapshots per user, dataset and scope', () async {
    await MasterFieldReadCache.write(
      userId: 'user-a',
      dataset: 'coverage',
      version: 42,
      region: 'Region 5',
      rows: const [
        {'field_number': 'FN-1', 'effective_area_ha': 1.5},
      ],
    );

    final saved = await MasterFieldReadCache.read(
      userId: 'user-a',
      dataset: 'coverage',
      region: 'Region 5',
    );
    final otherUser = await MasterFieldReadCache.read(
      userId: 'user-b',
      dataset: 'coverage',
      region: 'Region 5',
    );
    final otherDataset = await MasterFieldReadCache.read(
      userId: 'user-a',
      dataset: 'map',
      region: 'Region 5',
    );

    expect(saved?.version, 42);
    expect(saved?.rows.single['field_number'], 'FN-1');
    expect(otherUser, isNull);
    expect(otherDataset, isNull);
  });

  test('logout clearing removes only the selected user snapshots', () async {
    for (final userId in ['user-a', 'user-b']) {
      await MasterFieldReadCache.write(
        userId: userId,
        dataset: 'map',
        version: 7,
        region: 'Region 1',
        rows: [
          {'field_number': userId},
        ],
      );
    }

    await MasterFieldReadCache.clearUser('user-a');

    expect(
      await MasterFieldReadCache.read(
        userId: 'user-a',
        dataset: 'map',
        region: 'Region 1',
      ),
      isNull,
    );
    expect(
      await MasterFieldReadCache.read(
        userId: 'user-b',
        dataset: 'map',
        region: 'Region 1',
      ),
      isNotNull,
    );
  });
}
