# Drift local-cache migration: Stage 2 abstraction and flags

Status: implemented without adding Drift or changing the default runtime
backend. Hive remains active for every dataset unless a compile-time flag says
otherwise.

## Scope

Stage 2 introduces the seam required for a reversible migration:

- a backend-neutral cache scope, entry, and store contract;
- a Hive adapter that preserves the existing box, keys, payloads, and
  per-account retention behavior;
- a router that selects a backend independently for Map, Coverage, and
  Planning;
- compile-time rollout flags and a global local-cache kill switch;
- automatic Hive fallback when Drift is unavailable, misses, or fails;
- optional Hive dual-write while Drift is selected;
- clearing every registered backend on account change or logout.

Drift, SQLite schema generation, data migration, and production rollout are
explicitly outside this stage. Redis and direct Supabase behavior are not
changed.

## Compile-time flags

| Dart define | Default | Accepted values | Effect |
| --- | --- | --- | --- |
| `KC_MASTER_FIELD_LOCAL_CACHE_ENABLED` | `true` | `true`, `false` | Global local-cache kill switch |
| `KC_MASTER_FIELD_MAP_CACHE_BACKEND` | `hive` | `hive`, `drift`, `disabled` | Map local backend |
| `KC_MASTER_FIELD_COVERAGE_CACHE_BACKEND` | `hive` | `hive`, `drift`, `disabled` | Coverage and coverage-region local backend |
| `KC_MASTER_FIELD_PLANNING_CACHE_BACKEND` | `hive` | `hive`, `drift`, `disabled` | Planning-index local backend |
| `KC_MASTER_FIELD_DRIFT_DUAL_WRITE_HIVE` | `false` | `true`, `false` | Keep a current Hive rollback copy while Drift is primary |

Unknown backend values deliberately resolve to Hive. Selecting Drift before a
Drift store is registered also resolves operationally to Hive. Selecting
`disabled` affects only the local cache: Edge/Redis and the direct Supabase
fallback remain available.

Example future canary configuration:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_MAP_CACHE_BACKEND=drift `
  --dart-define=KC_MASTER_FIELD_COVERAGE_CACHE_BACKEND=hive `
  --dart-define=KC_MASTER_FIELD_PLANNING_CACHE_BACKEND=hive `
  --dart-define=KC_MASTER_FIELD_DRIFT_DUAL_WRITE_HIVE=true
```

This example is inert until Stage 3 registers a Drift store.

## Rollback behavior

For a dataset routed to Drift, reads follow:

```text
Drift hit -> return rows
Drift miss/error/unavailable -> Hive
Hive miss/error/unavailable -> Edge/Redis -> direct Supabase
```

Writes target Drift. They also target Hive when dual-write is enabled, and
automatically fall back to Hive when a Drift write fails or Drift is not
registered. A global or dataset-specific disable performs no local read/write.

Logout cleanup ignores rollout selection and clears both registered stores.
This prevents data from an earlier account becoming reachable if flags change
later.

## Compatibility guarantees

- `MasterFieldReadCache` remains the stable facade used by existing callers.
- Hive box name remains `masterFieldReadCacheV2`.
- Hive key prefix remains `mf-read-v2`.
- Scope normalization and the 12-entry per-account limit are unchanged.
- Cache exceptions remain fail-open and never block network fetching.
- Default builds continue using Hive only.
- No dependency or generated file was added in this stage.

## Verification and Stage 3 gate

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- the Stage 1 regression suite and Stage 2 router suite passed all 36 tests;
- the complete project suite passed 141 tests with one pre-existing skip;
- static analysis completed with no issues;
- the Hive v2 key is locked by a byte-compatible regression assertion;
- no dependency, generated file, Supabase migration, or production query path
  changed.

Stage 3 may add Drift and its schema only after:

- the Stage 1 contract suite remains green;
- router tests cover disabled, fallback, per-dataset, dual-write, and logout
  cleanup behavior;
- static analysis passes;
- default builds demonstrate byte-compatible Hive keys and payloads;
- no Map, Coverage, Planning, Redis, Supabase, or authentication query path
  changes in Stage 2.
