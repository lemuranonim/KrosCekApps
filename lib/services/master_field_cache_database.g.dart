// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'master_field_cache_database.dart';

// ignore_for_file: type=lint
class $MasterFieldCacheSnapshotsTable extends MasterFieldCacheSnapshots
    with TableInfo<$MasterFieldCacheSnapshotsTable, MasterFieldCacheSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MasterFieldCacheSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datasetMeta = const VerificationMeta(
    'dataset',
  );
  @override
  late final GeneratedColumn<String> dataset = GeneratedColumn<String>(
    'dataset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMillisMeta = const VerificationMeta(
    'savedAtMillis',
  );
  @override
  late final GeneratedColumn<int> savedAtMillis = GeneratedColumn<int>(
    'saved_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowCountMeta = const VerificationMeta(
    'rowCount',
  );
  @override
  late final GeneratedColumn<int> rowCount = GeneratedColumn<int>(
    'row_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadBytesMeta = const VerificationMeta(
    'payloadBytes',
  );
  @override
  late final GeneratedColumn<int> payloadBytes = GeneratedColumn<int>(
    'payload_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    userId,
    dataset,
    season,
    region,
    district,
    version,
    savedAtMillis,
    rowCount,
    payloadBytes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'master_field_cache_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<MasterFieldCacheSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('dataset')) {
      context.handle(
        _datasetMeta,
        dataset.isAcceptableOrUnknown(data['dataset']!, _datasetMeta),
      );
    } else if (isInserting) {
      context.missing(_datasetMeta);
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('saved_at_millis')) {
      context.handle(
        _savedAtMillisMeta,
        savedAtMillis.isAcceptableOrUnknown(
          data['saved_at_millis']!,
          _savedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_savedAtMillisMeta);
    }
    if (data.containsKey('row_count')) {
      context.handle(
        _rowCountMeta,
        rowCount.isAcceptableOrUnknown(data['row_count']!, _rowCountMeta),
      );
    } else if (isInserting) {
      context.missing(_rowCountMeta);
    }
    if (data.containsKey('payload_bytes')) {
      context.handle(
        _payloadBytesMeta,
        payloadBytes.isAcceptableOrUnknown(
          data['payload_bytes']!,
          _payloadBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadBytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  MasterFieldCacheSnapshot map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MasterFieldCacheSnapshot(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      dataset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset'],
      )!,
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season'],
      ),
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      savedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_at_millis'],
      )!,
      rowCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_count'],
      )!,
      payloadBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_bytes'],
      )!,
    );
  }

  @override
  $MasterFieldCacheSnapshotsTable createAlias(String alias) {
    return $MasterFieldCacheSnapshotsTable(attachedDatabase, alias);
  }
}

class MasterFieldCacheSnapshot extends DataClass
    implements Insertable<MasterFieldCacheSnapshot> {
  final String cacheKey;
  final String userId;
  final String dataset;
  final String? season;
  final String? region;
  final String? district;
  final int version;
  final int savedAtMillis;
  final int rowCount;
  final int payloadBytes;
  const MasterFieldCacheSnapshot({
    required this.cacheKey,
    required this.userId,
    required this.dataset,
    this.season,
    this.region,
    this.district,
    required this.version,
    required this.savedAtMillis,
    required this.rowCount,
    required this.payloadBytes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['user_id'] = Variable<String>(userId);
    map['dataset'] = Variable<String>(dataset);
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<String>(season);
    }
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    map['version'] = Variable<int>(version);
    map['saved_at_millis'] = Variable<int>(savedAtMillis);
    map['row_count'] = Variable<int>(rowCount);
    map['payload_bytes'] = Variable<int>(payloadBytes);
    return map;
  }

  MasterFieldCacheSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return MasterFieldCacheSnapshotsCompanion(
      cacheKey: Value(cacheKey),
      userId: Value(userId),
      dataset: Value(dataset),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      version: Value(version),
      savedAtMillis: Value(savedAtMillis),
      rowCount: Value(rowCount),
      payloadBytes: Value(payloadBytes),
    );
  }

  factory MasterFieldCacheSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MasterFieldCacheSnapshot(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      userId: serializer.fromJson<String>(json['userId']),
      dataset: serializer.fromJson<String>(json['dataset']),
      season: serializer.fromJson<String?>(json['season']),
      region: serializer.fromJson<String?>(json['region']),
      district: serializer.fromJson<String?>(json['district']),
      version: serializer.fromJson<int>(json['version']),
      savedAtMillis: serializer.fromJson<int>(json['savedAtMillis']),
      rowCount: serializer.fromJson<int>(json['rowCount']),
      payloadBytes: serializer.fromJson<int>(json['payloadBytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'userId': serializer.toJson<String>(userId),
      'dataset': serializer.toJson<String>(dataset),
      'season': serializer.toJson<String?>(season),
      'region': serializer.toJson<String?>(region),
      'district': serializer.toJson<String?>(district),
      'version': serializer.toJson<int>(version),
      'savedAtMillis': serializer.toJson<int>(savedAtMillis),
      'rowCount': serializer.toJson<int>(rowCount),
      'payloadBytes': serializer.toJson<int>(payloadBytes),
    };
  }

  MasterFieldCacheSnapshot copyWith({
    String? cacheKey,
    String? userId,
    String? dataset,
    Value<String?> season = const Value.absent(),
    Value<String?> region = const Value.absent(),
    Value<String?> district = const Value.absent(),
    int? version,
    int? savedAtMillis,
    int? rowCount,
    int? payloadBytes,
  }) => MasterFieldCacheSnapshot(
    cacheKey: cacheKey ?? this.cacheKey,
    userId: userId ?? this.userId,
    dataset: dataset ?? this.dataset,
    season: season.present ? season.value : this.season,
    region: region.present ? region.value : this.region,
    district: district.present ? district.value : this.district,
    version: version ?? this.version,
    savedAtMillis: savedAtMillis ?? this.savedAtMillis,
    rowCount: rowCount ?? this.rowCount,
    payloadBytes: payloadBytes ?? this.payloadBytes,
  );
  MasterFieldCacheSnapshot copyWithCompanion(
    MasterFieldCacheSnapshotsCompanion data,
  ) {
    return MasterFieldCacheSnapshot(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      userId: data.userId.present ? data.userId.value : this.userId,
      dataset: data.dataset.present ? data.dataset.value : this.dataset,
      season: data.season.present ? data.season.value : this.season,
      region: data.region.present ? data.region.value : this.region,
      district: data.district.present ? data.district.value : this.district,
      version: data.version.present ? data.version.value : this.version,
      savedAtMillis: data.savedAtMillis.present
          ? data.savedAtMillis.value
          : this.savedAtMillis,
      rowCount: data.rowCount.present ? data.rowCount.value : this.rowCount,
      payloadBytes: data.payloadBytes.present
          ? data.payloadBytes.value
          : this.payloadBytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MasterFieldCacheSnapshot(')
          ..write('cacheKey: $cacheKey, ')
          ..write('userId: $userId, ')
          ..write('dataset: $dataset, ')
          ..write('season: $season, ')
          ..write('region: $region, ')
          ..write('district: $district, ')
          ..write('version: $version, ')
          ..write('savedAtMillis: $savedAtMillis, ')
          ..write('rowCount: $rowCount, ')
          ..write('payloadBytes: $payloadBytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    userId,
    dataset,
    season,
    region,
    district,
    version,
    savedAtMillis,
    rowCount,
    payloadBytes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MasterFieldCacheSnapshot &&
          other.cacheKey == this.cacheKey &&
          other.userId == this.userId &&
          other.dataset == this.dataset &&
          other.season == this.season &&
          other.region == this.region &&
          other.district == this.district &&
          other.version == this.version &&
          other.savedAtMillis == this.savedAtMillis &&
          other.rowCount == this.rowCount &&
          other.payloadBytes == this.payloadBytes);
}

class MasterFieldCacheSnapshotsCompanion
    extends UpdateCompanion<MasterFieldCacheSnapshot> {
  final Value<String> cacheKey;
  final Value<String> userId;
  final Value<String> dataset;
  final Value<String?> season;
  final Value<String?> region;
  final Value<String?> district;
  final Value<int> version;
  final Value<int> savedAtMillis;
  final Value<int> rowCount;
  final Value<int> payloadBytes;
  final Value<int> rowid;
  const MasterFieldCacheSnapshotsCompanion({
    this.cacheKey = const Value.absent(),
    this.userId = const Value.absent(),
    this.dataset = const Value.absent(),
    this.season = const Value.absent(),
    this.region = const Value.absent(),
    this.district = const Value.absent(),
    this.version = const Value.absent(),
    this.savedAtMillis = const Value.absent(),
    this.rowCount = const Value.absent(),
    this.payloadBytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MasterFieldCacheSnapshotsCompanion.insert({
    required String cacheKey,
    required String userId,
    required String dataset,
    this.season = const Value.absent(),
    this.region = const Value.absent(),
    this.district = const Value.absent(),
    required int version,
    required int savedAtMillis,
    required int rowCount,
    required int payloadBytes,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       userId = Value(userId),
       dataset = Value(dataset),
       version = Value(version),
       savedAtMillis = Value(savedAtMillis),
       rowCount = Value(rowCount),
       payloadBytes = Value(payloadBytes);
  static Insertable<MasterFieldCacheSnapshot> custom({
    Expression<String>? cacheKey,
    Expression<String>? userId,
    Expression<String>? dataset,
    Expression<String>? season,
    Expression<String>? region,
    Expression<String>? district,
    Expression<int>? version,
    Expression<int>? savedAtMillis,
    Expression<int>? rowCount,
    Expression<int>? payloadBytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (userId != null) 'user_id': userId,
      if (dataset != null) 'dataset': dataset,
      if (season != null) 'season': season,
      if (region != null) 'region': region,
      if (district != null) 'district': district,
      if (version != null) 'version': version,
      if (savedAtMillis != null) 'saved_at_millis': savedAtMillis,
      if (rowCount != null) 'row_count': rowCount,
      if (payloadBytes != null) 'payload_bytes': payloadBytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MasterFieldCacheSnapshotsCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? userId,
    Value<String>? dataset,
    Value<String?>? season,
    Value<String?>? region,
    Value<String?>? district,
    Value<int>? version,
    Value<int>? savedAtMillis,
    Value<int>? rowCount,
    Value<int>? payloadBytes,
    Value<int>? rowid,
  }) {
    return MasterFieldCacheSnapshotsCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      userId: userId ?? this.userId,
      dataset: dataset ?? this.dataset,
      season: season ?? this.season,
      region: region ?? this.region,
      district: district ?? this.district,
      version: version ?? this.version,
      savedAtMillis: savedAtMillis ?? this.savedAtMillis,
      rowCount: rowCount ?? this.rowCount,
      payloadBytes: payloadBytes ?? this.payloadBytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dataset.present) {
      map['dataset'] = Variable<String>(dataset.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (savedAtMillis.present) {
      map['saved_at_millis'] = Variable<int>(savedAtMillis.value);
    }
    if (rowCount.present) {
      map['row_count'] = Variable<int>(rowCount.value);
    }
    if (payloadBytes.present) {
      map['payload_bytes'] = Variable<int>(payloadBytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MasterFieldCacheSnapshotsCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('userId: $userId, ')
          ..write('dataset: $dataset, ')
          ..write('season: $season, ')
          ..write('region: $region, ')
          ..write('district: $district, ')
          ..write('version: $version, ')
          ..write('savedAtMillis: $savedAtMillis, ')
          ..write('rowCount: $rowCount, ')
          ..write('payloadBytes: $payloadBytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MasterFieldCacheRowsTable extends MasterFieldCacheRows
    with TableInfo<$MasterFieldCacheRowsTable, MasterFieldCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MasterFieldCacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES master_field_cache_snapshots (cache_key) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _rowIndexMeta = const VerificationMeta(
    'rowIndex',
  );
  @override
  late final GeneratedColumn<int> rowIndex = GeneratedColumn<int>(
    'row_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldNumberMeta = const VerificationMeta(
    'fieldNumber',
  );
  @override
  late final GeneratedColumn<String> fieldNumber = GeneratedColumn<String>(
    'field_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
    'season',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regionMeta = const VerificationMeta('region');
  @override
  late final GeneratedColumn<String> region = GeneratedColumn<String>(
    'region',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qaFiMeta = const VerificationMeta('qaFi');
  @override
  late final GeneratedColumn<String> qaFi = GeneratedColumn<String>(
    'qa_fi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qaSpvMeta = const VerificationMeta('qaSpv');
  @override
  late final GeneratedColumn<String> qaSpv = GeneratedColumn<String>(
    'qa_spv',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    rowIndex,
    fieldNumber,
    season,
    region,
    district,
    qaFi,
    qaSpv,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'master_field_cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MasterFieldCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('row_index')) {
      context.handle(
        _rowIndexMeta,
        rowIndex.isAcceptableOrUnknown(data['row_index']!, _rowIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIndexMeta);
    }
    if (data.containsKey('field_number')) {
      context.handle(
        _fieldNumberMeta,
        fieldNumber.isAcceptableOrUnknown(
          data['field_number']!,
          _fieldNumberMeta,
        ),
      );
    }
    if (data.containsKey('season')) {
      context.handle(
        _seasonMeta,
        season.isAcceptableOrUnknown(data['season']!, _seasonMeta),
      );
    }
    if (data.containsKey('region')) {
      context.handle(
        _regionMeta,
        region.isAcceptableOrUnknown(data['region']!, _regionMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('qa_fi')) {
      context.handle(
        _qaFiMeta,
        qaFi.isAcceptableOrUnknown(data['qa_fi']!, _qaFiMeta),
      );
    }
    if (data.containsKey('qa_spv')) {
      context.handle(
        _qaSpvMeta,
        qaSpv.isAcceptableOrUnknown(data['qa_spv']!, _qaSpvMeta),
      );
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey, rowIndex};
  @override
  MasterFieldCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MasterFieldCacheRow(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      rowIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_index'],
      )!,
      fieldNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_number'],
      ),
      season: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season'],
      ),
      region: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      qaFi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qa_fi'],
      ),
      qaSpv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qa_spv'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $MasterFieldCacheRowsTable createAlias(String alias) {
    return $MasterFieldCacheRowsTable(attachedDatabase, alias);
  }
}

class MasterFieldCacheRow extends DataClass
    implements Insertable<MasterFieldCacheRow> {
  final String cacheKey;
  final int rowIndex;
  final String? fieldNumber;
  final String? season;
  final String? region;
  final String? district;
  final String? qaFi;
  final String? qaSpv;
  final String payload;
  const MasterFieldCacheRow({
    required this.cacheKey,
    required this.rowIndex,
    this.fieldNumber,
    this.season,
    this.region,
    this.district,
    this.qaFi,
    this.qaSpv,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['row_index'] = Variable<int>(rowIndex);
    if (!nullToAbsent || fieldNumber != null) {
      map['field_number'] = Variable<String>(fieldNumber);
    }
    if (!nullToAbsent || season != null) {
      map['season'] = Variable<String>(season);
    }
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(region);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    if (!nullToAbsent || qaFi != null) {
      map['qa_fi'] = Variable<String>(qaFi);
    }
    if (!nullToAbsent || qaSpv != null) {
      map['qa_spv'] = Variable<String>(qaSpv);
    }
    map['payload'] = Variable<String>(payload);
    return map;
  }

  MasterFieldCacheRowsCompanion toCompanion(bool nullToAbsent) {
    return MasterFieldCacheRowsCompanion(
      cacheKey: Value(cacheKey),
      rowIndex: Value(rowIndex),
      fieldNumber: fieldNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldNumber),
      season: season == null && nullToAbsent
          ? const Value.absent()
          : Value(season),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      qaFi: qaFi == null && nullToAbsent ? const Value.absent() : Value(qaFi),
      qaSpv: qaSpv == null && nullToAbsent
          ? const Value.absent()
          : Value(qaSpv),
      payload: Value(payload),
    );
  }

  factory MasterFieldCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MasterFieldCacheRow(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      rowIndex: serializer.fromJson<int>(json['rowIndex']),
      fieldNumber: serializer.fromJson<String?>(json['fieldNumber']),
      season: serializer.fromJson<String?>(json['season']),
      region: serializer.fromJson<String?>(json['region']),
      district: serializer.fromJson<String?>(json['district']),
      qaFi: serializer.fromJson<String?>(json['qaFi']),
      qaSpv: serializer.fromJson<String?>(json['qaSpv']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'rowIndex': serializer.toJson<int>(rowIndex),
      'fieldNumber': serializer.toJson<String?>(fieldNumber),
      'season': serializer.toJson<String?>(season),
      'region': serializer.toJson<String?>(region),
      'district': serializer.toJson<String?>(district),
      'qaFi': serializer.toJson<String?>(qaFi),
      'qaSpv': serializer.toJson<String?>(qaSpv),
      'payload': serializer.toJson<String>(payload),
    };
  }

  MasterFieldCacheRow copyWith({
    String? cacheKey,
    int? rowIndex,
    Value<String?> fieldNumber = const Value.absent(),
    Value<String?> season = const Value.absent(),
    Value<String?> region = const Value.absent(),
    Value<String?> district = const Value.absent(),
    Value<String?> qaFi = const Value.absent(),
    Value<String?> qaSpv = const Value.absent(),
    String? payload,
  }) => MasterFieldCacheRow(
    cacheKey: cacheKey ?? this.cacheKey,
    rowIndex: rowIndex ?? this.rowIndex,
    fieldNumber: fieldNumber.present ? fieldNumber.value : this.fieldNumber,
    season: season.present ? season.value : this.season,
    region: region.present ? region.value : this.region,
    district: district.present ? district.value : this.district,
    qaFi: qaFi.present ? qaFi.value : this.qaFi,
    qaSpv: qaSpv.present ? qaSpv.value : this.qaSpv,
    payload: payload ?? this.payload,
  );
  MasterFieldCacheRow copyWithCompanion(MasterFieldCacheRowsCompanion data) {
    return MasterFieldCacheRow(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      rowIndex: data.rowIndex.present ? data.rowIndex.value : this.rowIndex,
      fieldNumber: data.fieldNumber.present
          ? data.fieldNumber.value
          : this.fieldNumber,
      season: data.season.present ? data.season.value : this.season,
      region: data.region.present ? data.region.value : this.region,
      district: data.district.present ? data.district.value : this.district,
      qaFi: data.qaFi.present ? data.qaFi.value : this.qaFi,
      qaSpv: data.qaSpv.present ? data.qaSpv.value : this.qaSpv,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MasterFieldCacheRow(')
          ..write('cacheKey: $cacheKey, ')
          ..write('rowIndex: $rowIndex, ')
          ..write('fieldNumber: $fieldNumber, ')
          ..write('season: $season, ')
          ..write('region: $region, ')
          ..write('district: $district, ')
          ..write('qaFi: $qaFi, ')
          ..write('qaSpv: $qaSpv, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    rowIndex,
    fieldNumber,
    season,
    region,
    district,
    qaFi,
    qaSpv,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MasterFieldCacheRow &&
          other.cacheKey == this.cacheKey &&
          other.rowIndex == this.rowIndex &&
          other.fieldNumber == this.fieldNumber &&
          other.season == this.season &&
          other.region == this.region &&
          other.district == this.district &&
          other.qaFi == this.qaFi &&
          other.qaSpv == this.qaSpv &&
          other.payload == this.payload);
}

class MasterFieldCacheRowsCompanion
    extends UpdateCompanion<MasterFieldCacheRow> {
  final Value<String> cacheKey;
  final Value<int> rowIndex;
  final Value<String?> fieldNumber;
  final Value<String?> season;
  final Value<String?> region;
  final Value<String?> district;
  final Value<String?> qaFi;
  final Value<String?> qaSpv;
  final Value<String> payload;
  final Value<int> rowid;
  const MasterFieldCacheRowsCompanion({
    this.cacheKey = const Value.absent(),
    this.rowIndex = const Value.absent(),
    this.fieldNumber = const Value.absent(),
    this.season = const Value.absent(),
    this.region = const Value.absent(),
    this.district = const Value.absent(),
    this.qaFi = const Value.absent(),
    this.qaSpv = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MasterFieldCacheRowsCompanion.insert({
    required String cacheKey,
    required int rowIndex,
    this.fieldNumber = const Value.absent(),
    this.season = const Value.absent(),
    this.region = const Value.absent(),
    this.district = const Value.absent(),
    this.qaFi = const Value.absent(),
    this.qaSpv = const Value.absent(),
    required String payload,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       rowIndex = Value(rowIndex),
       payload = Value(payload);
  static Insertable<MasterFieldCacheRow> custom({
    Expression<String>? cacheKey,
    Expression<int>? rowIndex,
    Expression<String>? fieldNumber,
    Expression<String>? season,
    Expression<String>? region,
    Expression<String>? district,
    Expression<String>? qaFi,
    Expression<String>? qaSpv,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (rowIndex != null) 'row_index': rowIndex,
      if (fieldNumber != null) 'field_number': fieldNumber,
      if (season != null) 'season': season,
      if (region != null) 'region': region,
      if (district != null) 'district': district,
      if (qaFi != null) 'qa_fi': qaFi,
      if (qaSpv != null) 'qa_spv': qaSpv,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MasterFieldCacheRowsCompanion copyWith({
    Value<String>? cacheKey,
    Value<int>? rowIndex,
    Value<String?>? fieldNumber,
    Value<String?>? season,
    Value<String?>? region,
    Value<String?>? district,
    Value<String?>? qaFi,
    Value<String?>? qaSpv,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return MasterFieldCacheRowsCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      rowIndex: rowIndex ?? this.rowIndex,
      fieldNumber: fieldNumber ?? this.fieldNumber,
      season: season ?? this.season,
      region: region ?? this.region,
      district: district ?? this.district,
      qaFi: qaFi ?? this.qaFi,
      qaSpv: qaSpv ?? this.qaSpv,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (rowIndex.present) {
      map['row_index'] = Variable<int>(rowIndex.value);
    }
    if (fieldNumber.present) {
      map['field_number'] = Variable<String>(fieldNumber.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (region.present) {
      map['region'] = Variable<String>(region.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (qaFi.present) {
      map['qa_fi'] = Variable<String>(qaFi.value);
    }
    if (qaSpv.present) {
      map['qa_spv'] = Variable<String>(qaSpv.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MasterFieldCacheRowsCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('rowIndex: $rowIndex, ')
          ..write('fieldNumber: $fieldNumber, ')
          ..write('season: $season, ')
          ..write('region: $region, ')
          ..write('district: $district, ')
          ..write('qaFi: $qaFi, ')
          ..write('qaSpv: $qaSpv, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MasterFieldCacheDatabase extends GeneratedDatabase {
  _$MasterFieldCacheDatabase(QueryExecutor e) : super(e);
  $MasterFieldCacheDatabaseManager get managers =>
      $MasterFieldCacheDatabaseManager(this);
  late final $MasterFieldCacheSnapshotsTable masterFieldCacheSnapshots =
      $MasterFieldCacheSnapshotsTable(this);
  late final $MasterFieldCacheRowsTable masterFieldCacheRows =
      $MasterFieldCacheRowsTable(this);
  late final Index mfCacheSnapshotsUserSavedAt = Index(
    'mf_cache_snapshots_user_saved_at',
    'CREATE INDEX mf_cache_snapshots_user_saved_at ON master_field_cache_snapshots (user_id, saved_at_millis)',
  );
  late final Index mfCacheSnapshotsUserDataset = Index(
    'mf_cache_snapshots_user_dataset',
    'CREATE INDEX mf_cache_snapshots_user_dataset ON master_field_cache_snapshots (user_id, dataset)',
  );
  late final Index mfCacheRowsFieldNumber = Index(
    'mf_cache_rows_field_number',
    'CREATE INDEX mf_cache_rows_field_number ON master_field_cache_rows (field_number)',
  );
  late final Index mfCacheRowsScope = Index(
    'mf_cache_rows_scope',
    'CREATE INDEX mf_cache_rows_scope ON master_field_cache_rows (season, region, district)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    masterFieldCacheSnapshots,
    masterFieldCacheRows,
    mfCacheSnapshotsUserSavedAt,
    mfCacheSnapshotsUserDataset,
    mfCacheRowsFieldNumber,
    mfCacheRowsScope,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'master_field_cache_snapshots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('master_field_cache_rows', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MasterFieldCacheSnapshotsTableCreateCompanionBuilder =
    MasterFieldCacheSnapshotsCompanion Function({
      required String cacheKey,
      required String userId,
      required String dataset,
      Value<String?> season,
      Value<String?> region,
      Value<String?> district,
      required int version,
      required int savedAtMillis,
      required int rowCount,
      required int payloadBytes,
      Value<int> rowid,
    });
typedef $$MasterFieldCacheSnapshotsTableUpdateCompanionBuilder =
    MasterFieldCacheSnapshotsCompanion Function({
      Value<String> cacheKey,
      Value<String> userId,
      Value<String> dataset,
      Value<String?> season,
      Value<String?> region,
      Value<String?> district,
      Value<int> version,
      Value<int> savedAtMillis,
      Value<int> rowCount,
      Value<int> payloadBytes,
      Value<int> rowid,
    });

final class $$MasterFieldCacheSnapshotsTableReferences
    extends
        BaseReferences<
          _$MasterFieldCacheDatabase,
          $MasterFieldCacheSnapshotsTable,
          MasterFieldCacheSnapshot
        > {
  $$MasterFieldCacheSnapshotsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $MasterFieldCacheRowsTable,
    List<MasterFieldCacheRow>
  >
  _masterFieldCacheRowsRefsTable(_$MasterFieldCacheDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.masterFieldCacheRows,
        aliasName: 'master_field_cache_snapshots__cache_key__master_field_cache_rows__cache_key',
      );

  $$MasterFieldCacheRowsTableProcessedTableManager
  get masterFieldCacheRowsRefs {
    final manager =
        $$MasterFieldCacheRowsTableTableManager(
          $_db,
          $_db.masterFieldCacheRows,
        ).filter(
          (f) =>
              f.cacheKey.cacheKey.sqlEquals($_itemColumn<String>('cache_key')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _masterFieldCacheRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MasterFieldCacheSnapshotsTableFilterComposer
    extends
        Composer<_$MasterFieldCacheDatabase, $MasterFieldCacheSnapshotsTable> {
  $$MasterFieldCacheSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataset => $composableBuilder(
    column: $table.dataset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedAtMillis => $composableBuilder(
    column: $table.savedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowCount => $composableBuilder(
    column: $table.rowCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> masterFieldCacheRowsRefs(
    Expression<bool> Function($$MasterFieldCacheRowsTableFilterComposer f) f,
  ) {
    final $$MasterFieldCacheRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cacheKey,
      referencedTable: $db.masterFieldCacheRows,
      getReferencedColumn: (t) => t.cacheKey,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MasterFieldCacheRowsTableFilterComposer(
            $db: $db,
            $table: $db.masterFieldCacheRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MasterFieldCacheSnapshotsTableOrderingComposer
    extends
        Composer<_$MasterFieldCacheDatabase, $MasterFieldCacheSnapshotsTable> {
  $$MasterFieldCacheSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataset => $composableBuilder(
    column: $table.dataset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedAtMillis => $composableBuilder(
    column: $table.savedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowCount => $composableBuilder(
    column: $table.rowCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MasterFieldCacheSnapshotsTableAnnotationComposer
    extends
        Composer<_$MasterFieldCacheDatabase, $MasterFieldCacheSnapshotsTable> {
  $$MasterFieldCacheSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get dataset =>
      $composableBuilder(column: $table.dataset, builder: (column) => column);

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get savedAtMillis => $composableBuilder(
    column: $table.savedAtMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowCount =>
      $composableBuilder(column: $table.rowCount, builder: (column) => column);

  GeneratedColumn<int> get payloadBytes => $composableBuilder(
    column: $table.payloadBytes,
    builder: (column) => column,
  );

  Expression<T> masterFieldCacheRowsRefs<T extends Object>(
    Expression<T> Function($$MasterFieldCacheRowsTableAnnotationComposer a) f,
  ) {
    final $$MasterFieldCacheRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cacheKey,
          referencedTable: $db.masterFieldCacheRows,
          getReferencedColumn: (t) => t.cacheKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MasterFieldCacheRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.masterFieldCacheRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MasterFieldCacheSnapshotsTableTableManager
    extends
        RootTableManager<
          _$MasterFieldCacheDatabase,
          $MasterFieldCacheSnapshotsTable,
          MasterFieldCacheSnapshot,
          $$MasterFieldCacheSnapshotsTableFilterComposer,
          $$MasterFieldCacheSnapshotsTableOrderingComposer,
          $$MasterFieldCacheSnapshotsTableAnnotationComposer,
          $$MasterFieldCacheSnapshotsTableCreateCompanionBuilder,
          $$MasterFieldCacheSnapshotsTableUpdateCompanionBuilder,
          (
            MasterFieldCacheSnapshot,
            $$MasterFieldCacheSnapshotsTableReferences,
          ),
          MasterFieldCacheSnapshot,
          PrefetchHooks Function({bool masterFieldCacheRowsRefs})
        > {
  $$MasterFieldCacheSnapshotsTableTableManager(
    _$MasterFieldCacheDatabase db,
    $MasterFieldCacheSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MasterFieldCacheSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MasterFieldCacheSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MasterFieldCacheSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> dataset = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> savedAtMillis = const Value.absent(),
                Value<int> rowCount = const Value.absent(),
                Value<int> payloadBytes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MasterFieldCacheSnapshotsCompanion(
                cacheKey: cacheKey,
                userId: userId,
                dataset: dataset,
                season: season,
                region: region,
                district: district,
                version: version,
                savedAtMillis: savedAtMillis,
                rowCount: rowCount,
                payloadBytes: payloadBytes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String userId,
                required String dataset,
                Value<String?> season = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> district = const Value.absent(),
                required int version,
                required int savedAtMillis,
                required int rowCount,
                required int payloadBytes,
                Value<int> rowid = const Value.absent(),
              }) => MasterFieldCacheSnapshotsCompanion.insert(
                cacheKey: cacheKey,
                userId: userId,
                dataset: dataset,
                season: season,
                region: region,
                district: district,
                version: version,
                savedAtMillis: savedAtMillis,
                rowCount: rowCount,
                payloadBytes: payloadBytes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MasterFieldCacheSnapshotsTable,
                    MasterFieldCacheSnapshot
                  >(table),
                  $$MasterFieldCacheSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({masterFieldCacheRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (masterFieldCacheRowsRefs) db.masterFieldCacheRows,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (masterFieldCacheRowsRefs)
                    await $_getPrefetchedData<
                      MasterFieldCacheSnapshot,
                      $MasterFieldCacheSnapshotsTable,
                      MasterFieldCacheRow
                    >(
                      currentTable: table,
                      referencedTable:
                          $$MasterFieldCacheSnapshotsTableReferences
                              ._masterFieldCacheRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MasterFieldCacheSnapshotsTableReferences(
                            db,
                            table,
                            p0,
                          ).masterFieldCacheRowsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.cacheKey == item.cacheKey,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MasterFieldCacheSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$MasterFieldCacheDatabase,
      $MasterFieldCacheSnapshotsTable,
      MasterFieldCacheSnapshot,
      $$MasterFieldCacheSnapshotsTableFilterComposer,
      $$MasterFieldCacheSnapshotsTableOrderingComposer,
      $$MasterFieldCacheSnapshotsTableAnnotationComposer,
      $$MasterFieldCacheSnapshotsTableCreateCompanionBuilder,
      $$MasterFieldCacheSnapshotsTableUpdateCompanionBuilder,
      (MasterFieldCacheSnapshot, $$MasterFieldCacheSnapshotsTableReferences),
      MasterFieldCacheSnapshot,
      PrefetchHooks Function({bool masterFieldCacheRowsRefs})
    >;
typedef $$MasterFieldCacheRowsTableCreateCompanionBuilder =
    MasterFieldCacheRowsCompanion Function({
      required String cacheKey,
      required int rowIndex,
      Value<String?> fieldNumber,
      Value<String?> season,
      Value<String?> region,
      Value<String?> district,
      Value<String?> qaFi,
      Value<String?> qaSpv,
      required String payload,
      Value<int> rowid,
    });
typedef $$MasterFieldCacheRowsTableUpdateCompanionBuilder =
    MasterFieldCacheRowsCompanion Function({
      Value<String> cacheKey,
      Value<int> rowIndex,
      Value<String?> fieldNumber,
      Value<String?> season,
      Value<String?> region,
      Value<String?> district,
      Value<String?> qaFi,
      Value<String?> qaSpv,
      Value<String> payload,
      Value<int> rowid,
    });

final class $$MasterFieldCacheRowsTableReferences
    extends
        BaseReferences<
          _$MasterFieldCacheDatabase,
          $MasterFieldCacheRowsTable,
          MasterFieldCacheRow
        > {
  $$MasterFieldCacheRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MasterFieldCacheSnapshotsTable _cacheKeyTable(
    _$MasterFieldCacheDatabase db,
  ) => db.masterFieldCacheSnapshots.createAlias(
    'master_field_cache_rows__cache_key__master_field_cache_snapshots__cache_key',
  );

  $$MasterFieldCacheSnapshotsTableProcessedTableManager get cacheKey {
    final $_column = $_itemColumn<String>('cache_key')!;

    final manager = $$MasterFieldCacheSnapshotsTableTableManager(
      $_db,
      $_db.masterFieldCacheSnapshots,
    ).filter((f) => f.cacheKey.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cacheKeyTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MasterFieldCacheRowsTableFilterComposer
    extends Composer<_$MasterFieldCacheDatabase, $MasterFieldCacheRowsTable> {
  $$MasterFieldCacheRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowIndex => $composableBuilder(
    column: $table.rowIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldNumber => $composableBuilder(
    column: $table.fieldNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qaFi => $composableBuilder(
    column: $table.qaFi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qaSpv => $composableBuilder(
    column: $table.qaSpv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$MasterFieldCacheSnapshotsTableFilterComposer get cacheKey {
    final $$MasterFieldCacheSnapshotsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cacheKey,
          referencedTable: $db.masterFieldCacheSnapshots,
          getReferencedColumn: (t) => t.cacheKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MasterFieldCacheSnapshotsTableFilterComposer(
                $db: $db,
                $table: $db.masterFieldCacheSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$MasterFieldCacheRowsTableOrderingComposer
    extends Composer<_$MasterFieldCacheDatabase, $MasterFieldCacheRowsTable> {
  $$MasterFieldCacheRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowIndex => $composableBuilder(
    column: $table.rowIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldNumber => $composableBuilder(
    column: $table.fieldNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get season => $composableBuilder(
    column: $table.season,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qaFi => $composableBuilder(
    column: $table.qaFi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qaSpv => $composableBuilder(
    column: $table.qaSpv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$MasterFieldCacheSnapshotsTableOrderingComposer get cacheKey {
    final $$MasterFieldCacheSnapshotsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cacheKey,
          referencedTable: $db.masterFieldCacheSnapshots,
          getReferencedColumn: (t) => t.cacheKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MasterFieldCacheSnapshotsTableOrderingComposer(
                $db: $db,
                $table: $db.masterFieldCacheSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$MasterFieldCacheRowsTableAnnotationComposer
    extends Composer<_$MasterFieldCacheDatabase, $MasterFieldCacheRowsTable> {
  $$MasterFieldCacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowIndex =>
      $composableBuilder(column: $table.rowIndex, builder: (column) => column);

  GeneratedColumn<String> get fieldNumber => $composableBuilder(
    column: $table.fieldNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get qaFi =>
      $composableBuilder(column: $table.qaFi, builder: (column) => column);

  GeneratedColumn<String> get qaSpv =>
      $composableBuilder(column: $table.qaSpv, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$MasterFieldCacheSnapshotsTableAnnotationComposer get cacheKey {
    final $$MasterFieldCacheSnapshotsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cacheKey,
          referencedTable: $db.masterFieldCacheSnapshots,
          getReferencedColumn: (t) => t.cacheKey,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MasterFieldCacheSnapshotsTableAnnotationComposer(
                $db: $db,
                $table: $db.masterFieldCacheSnapshots,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$MasterFieldCacheRowsTableTableManager
    extends
        RootTableManager<
          _$MasterFieldCacheDatabase,
          $MasterFieldCacheRowsTable,
          MasterFieldCacheRow,
          $$MasterFieldCacheRowsTableFilterComposer,
          $$MasterFieldCacheRowsTableOrderingComposer,
          $$MasterFieldCacheRowsTableAnnotationComposer,
          $$MasterFieldCacheRowsTableCreateCompanionBuilder,
          $$MasterFieldCacheRowsTableUpdateCompanionBuilder,
          (MasterFieldCacheRow, $$MasterFieldCacheRowsTableReferences),
          MasterFieldCacheRow,
          PrefetchHooks Function({bool cacheKey})
        > {
  $$MasterFieldCacheRowsTableTableManager(
    _$MasterFieldCacheDatabase db,
    $MasterFieldCacheRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MasterFieldCacheRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MasterFieldCacheRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MasterFieldCacheRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<int> rowIndex = const Value.absent(),
                Value<String?> fieldNumber = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> qaFi = const Value.absent(),
                Value<String?> qaSpv = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MasterFieldCacheRowsCompanion(
                cacheKey: cacheKey,
                rowIndex: rowIndex,
                fieldNumber: fieldNumber,
                season: season,
                region: region,
                district: district,
                qaFi: qaFi,
                qaSpv: qaSpv,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required int rowIndex,
                Value<String?> fieldNumber = const Value.absent(),
                Value<String?> season = const Value.absent(),
                Value<String?> region = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> qaFi = const Value.absent(),
                Value<String?> qaSpv = const Value.absent(),
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => MasterFieldCacheRowsCompanion.insert(
                cacheKey: cacheKey,
                rowIndex: rowIndex,
                fieldNumber: fieldNumber,
                season: season,
                region: region,
                district: district,
                qaFi: qaFi,
                qaSpv: qaSpv,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MasterFieldCacheRowsTable, MasterFieldCacheRow>(
                    table,
                  ),
                  $$MasterFieldCacheRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cacheKey = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cacheKey) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cacheKey,
                        referencedTable: $$MasterFieldCacheRowsTableReferences
                            ._cacheKeyTable(db),
                        referencedColumn: $$MasterFieldCacheRowsTableReferences
                            ._cacheKeyTable(db)
                            .cacheKey,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MasterFieldCacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$MasterFieldCacheDatabase,
      $MasterFieldCacheRowsTable,
      MasterFieldCacheRow,
      $$MasterFieldCacheRowsTableFilterComposer,
      $$MasterFieldCacheRowsTableOrderingComposer,
      $$MasterFieldCacheRowsTableAnnotationComposer,
      $$MasterFieldCacheRowsTableCreateCompanionBuilder,
      $$MasterFieldCacheRowsTableUpdateCompanionBuilder,
      (MasterFieldCacheRow, $$MasterFieldCacheRowsTableReferences),
      MasterFieldCacheRow,
      PrefetchHooks Function({bool cacheKey})
    >;

class $MasterFieldCacheDatabaseManager {
  final _$MasterFieldCacheDatabase _db;
  $MasterFieldCacheDatabaseManager(this._db);
  $$MasterFieldCacheSnapshotsTableTableManager get masterFieldCacheSnapshots =>
      $$MasterFieldCacheSnapshotsTableTableManager(
        _db,
        _db.masterFieldCacheSnapshots,
      );
  $$MasterFieldCacheRowsTableTableManager get masterFieldCacheRows =>
      $$MasterFieldCacheRowsTableTableManager(_db, _db.masterFieldCacheRows);
}
