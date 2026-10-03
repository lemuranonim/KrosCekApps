# Drift local-cache migration: Stage 1 baseline

Status: implemented as a non-production baseline. This stage does not add
Drift, change the active Hive cache, or change Map, Coverage, and Planning
runtime behavior.

## Scope

Stage 1 freezes the behavior that later migration stages must preserve:

- Supabase/PostgreSQL remains the source of truth.
- Redis remains the shared server cache behind the authenticated Edge Function.
- The local cache is disposable and scoped to an authenticated account.
- Map, Coverage, and Planning payloads preserve their current
  `Map<String, dynamic>` shape at the provider boundary.
- A cache failure is fail-open. It must never prevent the direct Supabase path.
- Role and geographic scope must never be widened by local persistence.

Write paths such as inspection submission, mass inspection, attendance,
profile changes, and QA mapping are explicitly outside this migration stage.

## Locked dataset contract

The versioned fixture at `test/fixtures/cache_baseline_v1.json` defines a small,
synthetic representation of the three expensive read datasets.

| Dataset | Identity | Indexed scope candidates | Important payload behavior |
| --- | --- | --- | --- |
| `map` | `field_number` | season, region, district, QA identity | Includes ACT/correction geometry and compact audit projections |
| `coverage` | `field_number` | season, region, district, QA identity | Includes the wider audit status projection; excludes polygon geometry |
| `planning_index` | `field_number` | season, region, district, QA identity | Includes only eligibility dates and audit observations; excludes polygon geometry |

The fixture is deliberately synthetic and contains no production or personal
data. `contractVersion` must be increased when the fixture contract changes.
Its `productionScaleReference` records the verified Supabase scale used by the
synthetic benchmark: 34,600 active rows and 34,600 unique field numbers,
captured on 4 October 2026. The earlier 34,457 value was a valid 3 September
2026 snapshot; 143 unique fields were added afterward.

## Existing local-cache invariants

The Stage 1 contract test locks these behaviors before Drift is introduced:

1. Nested rows survive a Hive encode/write/read/decode round trip unchanged.
2. User, dataset, season, region, and district produce isolated cache keys.
3. Whitespace-only scope differences normalize to the same key.
4. Corrupt entries fail open as a cache miss.
5. Each user retains no more than 12 scoped snapshots.
6. Map correction geometry keeps priority over ACT geometry.

These are compatibility requirements for the future Drift repository, not a
recommendation to copy Hive's blob layout into SQLite.

## Repeatable baseline commands

Run the contract and existing feature tests:

```powershell
flutter test test/cache_migration_stage1_contract_test.dart test/master_field_read_cache_test.dart test/master_fields_paging_test.dart test/audit_plan_provider_test.dart
```

Run the synthetic serialization workload at the current production-scale row
count:

```powershell
dart run tool/cache_baseline.dart --rows=34600 --iterations=5
```

The workload reports JSON payload bytes plus median encode, decode, and scoped
filter durations for each dataset. It measures the current whole-payload shape;
it is not a device-performance SLO and does not include network latency.

### Initial host baseline

Captured on 4 October 2026 with Dart 3.13.3 on Windows x64, using 34,600
synthetic rows and five iterations:

| Dataset | JSON payload | Median encode | Median decode | Median scoped filter |
| --- | ---: | ---: | ---: | ---: |
| Map | 22,236,695 bytes | 149.948 ms | 230.520 ms | 10.517 ms |
| Coverage | 31,198,095 bytes | 259.873 ms | 422.550 ms | 14.332 ms |
| Planning index | 25,385,295 bytes | 172.906 ms | 256.488 ms | 7.100 ms |

These values establish a reproducible host reference for whole-JSON work. They
must not be presented as Android production measurements. The future Drift
benchmark must use the same fixture generator and row count.

For release decisions, repeat it on the supported Flutter SDK and capture a
profile-build trace on at least one lower-end Android device. Compare Drift
against the same fixture, row count, scope, and device.

## Measurements to capture before Stage 5

| Metric | Cold | Warm | Required comparison |
| --- | ---: | ---: | --- |
| Map time to first usable marker | pending device run | pending device run | Drift must not regress |
| Coverage time to first complete result | pending device run | pending device run | Drift must not regress |
| Planning time to first complete result | pending device run | pending device run | Drift must not regress |
| Peak RSS while decoding each dataset | pending device run | pending device run | Drift must be lower or equal |
| Downloaded response bytes | pending device run | pending device run | Same contract for Stage 1 |
| Local cache size per account | pending device run | pending device run | Must stay under the agreed quota |
| Visible field-number parity | 100% required | 100% required | No unresolved mismatch |

## Go/no-go gate for Stage 2

Stage 2 may introduce the cache abstraction and feature flags only after:

- the new contract test passes;
- the existing Map/Coverage/Planning tests pass;
- the fixture contains no production data or secrets;
- current behavior and fallback rules are documented here;
- no production code path has changed during Stage 1.

Future stages must preserve a dataset-specific rollback path:

```text
Drift -> Hive (temporary) -> Edge/Redis -> direct Supabase
```

## Stage 1 verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- the Stage 1 contract and existing cache/Map/Coverage/Planning suite passed
  all 27 tests;
- Flutter analysis of the new Dart artifacts completed with no issues;
- the 34,600-row synthetic baseline completed for all three datasets;
- no file under `lib/`, `supabase/`, `pubspec.yaml`, or `pubspec.lock` changed.
