import 'dart:convert';
import 'dart:io';

int intArgument(List<String> arguments, String name, int fallback) {
  final prefix = '--$name=';
  final raw = arguments
      .where((argument) => argument.startsWith(prefix))
      .map((argument) => argument.substring(prefix.length))
      .firstOrNull;
  return raw == null ? fallback : int.tryParse(raw) ?? fallback;
}

int median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

List<Map<String, dynamic>> scaledRows(
  List<Map<String, dynamic>> seeds,
  String dataset,
  int count,
) => List.generate(count, (index) {
  final row = Map<String, dynamic>.from(seeds[index % seeds.length]);
  row['field_number'] = '${dataset.toUpperCase()}-${index + 1}';
  return row;
}, growable: false);

void main(List<String> arguments) {
  final fixtureFile = File('test/fixtures/cache_baseline_v1.json');
  if (!fixtureFile.existsSync()) {
    stderr.writeln('Run this command from the Kroscek repository root.');
    exitCode = 66;
    return;
  }

  final fixture = jsonDecode(fixtureFile.readAsStringSync()) as Map;
  final productionScale = fixture['productionScaleReference'] as Map;
  final defaultRowCount = productionScale['rowCount'] as int;
  final rowCount = intArgument(arguments, 'rows', defaultRowCount);
  final iterations = intArgument(arguments, 'iterations', 5);
  if (rowCount <= 0 || iterations <= 0) {
    stderr.writeln('--rows and --iterations must be positive integers');
    exitCode = 64;
    return;
  }

  final datasets = fixture['datasets'] as Map;
  final results = <Map<String, Object?>>[];

  for (final datasetEntry in datasets.entries) {
    final dataset = datasetEntry.key as String;
    final contract = datasetEntry.value as Map;
    final seeds = (contract['rows'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final rows = scaledRows(seeds, dataset, rowCount);

    // Warm up the JIT and JSON implementation outside the measured samples.
    final warmup = jsonEncode(rows.take(10).toList(growable: false));
    jsonDecode(warmup);

    final encodeMicros = <int>[];
    final decodeMicros = <int>[];
    final filterMicros = <int>[];
    var payloadBytes = 0;
    var matchedRows = 0;

    for (var iteration = 0; iteration < iterations; iteration++) {
      final encodeWatch = Stopwatch()..start();
      final encoded = jsonEncode(rows);
      encodeWatch.stop();
      encodeMicros.add(encodeWatch.elapsedMicroseconds);
      payloadBytes = utf8.encode(encoded).length;

      final decodeWatch = Stopwatch()..start();
      final decoded = jsonDecode(encoded) as List;
      decodeWatch.stop();
      decodeMicros.add(decodeWatch.elapsedMicroseconds);

      final filterWatch = Stopwatch()..start();
      matchedRows = decoded.where((item) {
        final row = item as Map;
        return row['region'] == 'Region 5' &&
            (row['district_kab'] == null || row['district_kab'] == 'Blitar');
      }).length;
      filterWatch.stop();
      filterMicros.add(filterWatch.elapsedMicroseconds);
    }

    results.add({
      'dataset': dataset,
      'rows': rowCount,
      'matchedRows': matchedRows,
      'payloadBytes': payloadBytes,
      'medianEncodeMicros': median(encodeMicros),
      'medianDecodeMicros': median(decodeMicros),
      'medianScopedFilterMicros': median(filterMicros),
    });
  }

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'baselineContractVersion': fixture['contractVersion'],
      'productionScaleReference': productionScale,
      'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'runtime': Platform.version,
      'operatingSystem': Platform.operatingSystem,
      'iterations': iterations,
      'note': 'Synthetic whole-JSON serialization baseline; not a device SLO.',
      'datasets': results,
    }),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
