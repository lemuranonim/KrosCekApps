import 'dart:convert';

import 'package:flutter/foundation.dart';

Future<bool> compareMasterFieldCacheRows(
  List<Map<String, dynamic>> hiveRows,
  List<Map<String, dynamic>> driftRows,
) => compute(_rowsHaveExactJsonParity, <List<Map<String, dynamic>>>[
  hiveRows,
  driftRows,
]);

bool _rowsHaveExactJsonParity(List<List<Map<String, dynamic>>> entries) {
  final hiveRows = entries[0];
  final driftRows = entries[1];
  if (hiveRows.length != driftRows.length) return false;
  for (var index = 0; index < hiveRows.length; index++) {
    if (jsonEncode(hiveRows[index]) != jsonEncode(driftRows[index])) {
      return false;
    }
  }
  return true;
}
