# Drift local-cache migration: Stage 3 SQLite foundation

Status: implemented as an opt-in foundation. The production default remains
Hive for Map, Coverage, and Planning, so a normal build does not open or create
the new SQLite database.

## Scope

Stage 3 adds the native Drift/SQLite storage layer behind the Stage 2 contract:

- Drift, `drift_flutter`, `drift_dev`, and generated schema code;
- a versioned SQLite database named `kroscek_master_field_cache`;
- snapshot and row tables with foreign-key cascade and query indexes;
- atomic replacement writes and a 12-snapshot per-account retention limit;
- JSON work moved off the UI isolate;
- lazy database startup only when a Map, Coverage, or Planning flag selects
  Drift;
- automatic Hive fallback if SQLite cannot start, read, or write;
- account cleanup across both registered stores.

This stage does not migrate existing Hive entries, change Redis or Supabase,
or switch any dataset to Drift by default.

## Schema version 1

`master_field_cache_snapshots` owns one logical cached result per exact v2
cache key. It records the user, dataset scope, version, save timestamp, row
count, and encoded byte count.

`master_field_cache_rows` stores rows in their original order. Each row keeps
its full JSON payload plus normalized columns for `field_number`, `season`,
`region`, `district_kab`, `qa_fi`, and `qa_spv`. Those columns make future local
filtering possible without changing the cached payload.

The row table references its snapshot with `ON DELETE CASCADE`. SQLite foreign
keys are enabled whenever the database opens. Indexes cover:

- snapshot retention by user and save time;
- snapshot selection by user and dataset;
- row lookup by field number;
- row filtering by season, region, and district.

Every write runs in one transaction: upsert snapshot metadata, remove the old
rows, insert the replacement rows in bounded batches, and prune old snapshots.
A failed transaction leaves the previous snapshot intact.

## Runtime and rollout behavior

The Stage 2 Dart defines remain the control plane. With their defaults, all
three dataset families use Hive and `MasterFieldCacheRuntime` does not
instantiate Drift.

An opt-in native build can select one dataset independently, for example:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_MAP_CACHE_BACKEND=drift `
  --dart-define=KC_MASTER_FIELD_COVERAGE_CACHE_BACKEND=hive `
  --dart-define=KC_MASTER_FIELD_PLANNING_CACHE_BACKEND=hive `
  --dart-define=KC_MASTER_FIELD_DRIFT_DUAL_WRITE_HIVE=true
```

During Stage 3, web requests for Drift deliberately fall back to Hive. Native
database initialization is forced before registration so schema or file-open
errors are detected early. Errors remain fail-open and preserve the existing
network path: Drift, then Hive, then Edge/Redis, then direct Supabase.

## Integrity and rollback controls

- Snapshot row counts are checked before cached data is returned. Partial data
  is rejected and falls through to Hive/network.
- Rewrites are transactional and do not expose a half-written result.
- Foreign-key cascade prevents orphan rows during retention and logout cleanup.
- Exact Stage 2 keys and scope normalization remain unchanged.
- Setting a dataset flag back to `hive` is the immediate rollback; the database
  is then not opened on the next process start.
- Enabling dual-write keeps a current Hive copy during a future canary.

## Verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- generated schema code completed successfully with `build_runner`;
- 10 Drift store tests passed, covering round-trip fidelity, replacement,
  isolation, retention, cascade cleanup, metadata indexes, corruption
  rejection, foreign keys, file reopen persistence, and the 34,600-row
  production reference size;
- the full Flutter suite passed 151 tests with one pre-existing skip;
- static analysis completed with no issues;
- the debug Android APK built successfully with the SQLite native dependency;
- the debug web target built successfully while retaining the Stage 3 Hive
  fallback;
- the default feature flags still use only Hive at runtime.

Stage 4 should introduce controlled dual-write/shadow-read measurement and
parity telemetry before any production dataset defaults to Drift.
