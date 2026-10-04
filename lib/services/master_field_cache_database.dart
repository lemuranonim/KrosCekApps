import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'master_field_cache_database.g.dart';

@TableIndex(
  name: 'mf_cache_snapshots_user_saved_at',
  columns: {#userId, #savedAtMillis},
)
@TableIndex(
  name: 'mf_cache_snapshots_user_dataset',
  columns: {#userId, #dataset},
)
class MasterFieldCacheSnapshots extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get userId => text()();
  TextColumn get dataset => text()();
  TextColumn get season => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get district => text().nullable()();
  IntColumn get version => integer()();
  IntColumn get savedAtMillis => integer()();
  IntColumn get rowCount => integer()();
  IntColumn get payloadBytes => integer()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};

  @override
  String get tableName => 'master_field_cache_snapshots';
}

@TableIndex(name: 'mf_cache_rows_field_number', columns: {#fieldNumber})
@TableIndex(name: 'mf_cache_rows_scope', columns: {#season, #region, #district})
class MasterFieldCacheRows extends Table {
  TextColumn get cacheKey => text().references(
    MasterFieldCacheSnapshots,
    #cacheKey,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get rowIndex => integer()();
  TextColumn get fieldNumber => text().nullable()();
  TextColumn get season => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get qaFi => text().nullable()();
  TextColumn get qaSpv => text().nullable()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey, rowIndex};

  @override
  String get tableName => 'master_field_cache_rows';
}

@DriftDatabase(tables: [MasterFieldCacheSnapshots, MasterFieldCacheRows])
class MasterFieldCacheDatabase extends _$MasterFieldCacheDatabase {
  static const databaseName = 'kroscek_master_field_cache';

  MasterFieldCacheDatabase(super.executor);

  MasterFieldCacheDatabase.defaults()
    : super(driftDatabase(name: databaseName));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
