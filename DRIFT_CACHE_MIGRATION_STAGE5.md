# Drift local-cache migration: Stage 5 guarded Map cutover

Status: implemented as an opt-in, percentage-based Map rollout. The default
rollout remains 0%, so ordinary production builds continue to use Hive until a
release is explicitly built with an approved cohort percentage.

## Purpose

Stage 5 promotes Drift from a shadow store to the primary local read cache for
a controlled cohort of Map users. Coverage and Planning remain Hive-primary.
The rollout adds:

- deterministic, account-sticky Map cohorts;
- percentage clamping from 0% through 100%;
- mandatory Hive dual-write for every enrolled scope;
- Hive fallback and asynchronous Drift warm-up on a healthy Drift miss;
- per-key serialization for overlapping Drift-primary writes;
- a process-local circuit breaker after three consecutive Drift failures;
- privacy-safe session telemetry for hits, misses, fallbacks, repair, writes,
  and circuit state;
- immediate rollback through one compile-time flag.

No Supabase query, Redis behavior, SQLite schema, dependency, API, Coverage
route, or Planning route changes in this stage.

## Rollout flag

| Dart define | Default | Effective range | Effect |
| --- | --- | --- | --- |
| `KC_MASTER_FIELD_MAP_DRIFT_ROLLOUT_PERCENT` | `0` | `0..100` | Percentage of accounts whose Map cache is Drift-primary |

Example 1% cohort build:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_MAP_DRIFT_ROLLOUT_PERCENT=1
```

The cohort hash uses only the Map family and account ID. It is deterministic,
so all Map scopes for one account use the same backend across process starts.
The identifier is never persisted in rollout telemetry or emitted in rollout
diagnostics.

Existing full-backend flags remain authoritative. An explicit
`KC_MASTER_FIELD_MAP_CACHE_BACKEND=disabled` disables Map local caching, while
`KC_MASTER_FIELD_MAP_CACHE_BACKEND=drift` remains the deliberate 100% route.
The percentage rollout applies only while the configured Map backend is Hive.

## Read behavior

```text
non-cohort Map read -> Hive

cohort Map read -> Drift hit -> return Drift
                -> healthy Drift miss -> read Hive -> return Hive immediately
                                      -> repair Drift asynchronously
                -> Drift error/unavailable -> read Hive
                -> open circuit -> bypass Drift -> read Hive
```

Read-repair runs only after a healthy Drift miss. It is not attempted after a
Drift exception, avoiding repeated work against an unhealthy database. Repair
is skipped when a newer primary write for the same key is already queued.

## Write behavior and rollback copy

Every cohort write is serialized per exact cache key, written to Drift, and
then written to Hive even when the legacy global dual-write flag is false.
This mandatory Hive copy is the rollback snapshot for the first production
cohorts. If Drift fails, the Hive write still runs. Once the circuit is open,
the process writes only to Hive for that dataset family.

The existing `KC_MASTER_FIELD_DRIFT_DUAL_WRITE_HIVE` flag continues to govern
explicit full-Drift routes. Percentage rollout safety does not depend on that
flag.

## Circuit breaker

Three consecutive Drift read, write, unavailable-store, or read-repair
failures open the Map circuit for the rest of the process. A successful Drift
operation resets the consecutive counter before the circuit opens. Once open:

- further Map reads and writes bypass Drift;
- Hive remains available;
- restart provides a clean retry opportunity;
- setting the rollout percentage to 0 disables Drift startup on the next
  process start unless another Drift or shadow flag still requires it.

The circuit is intentionally process-local. It does not change remote config,
write to Supabase, or silently alter another user's rollout assignment.

## Telemetry and privacy

`MasterFieldReadCache.rolloutSnapshot` exposes in-process aggregate counters,
per-family Drift read-hit rate, failure totals, and circuit-open state.
Diagnostics include only:

- dataset family/base name;
- outcome and elapsed time;
- cache version and row count when relevant;
- consecutive failure count.

They exclude account ID, cache key, role identity, region, district, field
number, and row content. Telemetry remains session-local and is not sent to an
external service.

## Recommended rollout ladder

Do not advance a cohort merely because the build succeeds. For each step,
observe a representative usage window and retain the Stage 4 parity gate:

1. 1% internal/low-risk cohort;
2. 5% after zero unexplained mismatches and no user-facing regression;
3. 25% after stable Drift hit/failure and memory metrics;
4. 50% after rollback has been exercised on the same release line;
5. 100% percentage rollout while Hive dual-write remains mandatory;
6. explicit full-Drift backend only after the rollback retention window ends.

Rollback at any percentage is a build with
`KC_MASTER_FIELD_MAP_DRIFT_ROLLOUT_PERCENT=0`. Coverage and Planning are not
part of this ladder and require their own evidence before future cutover.

## Verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- all 17 focused Stage 5 tests passed, covering percentage boundaries,
  account-sticky cohort selection, dataset isolation, authoritative legacy
  flags, Drift-primary reads, mandatory Hive dual-write, Hive-only defaults,
  read-repair, circuit opening, recovery counter reset, unavailable Drift,
  Stage 4 shadow exclusion, overlapping-write serialization, telemetry
  privacy, and aggregate health metrics;
- the combined router, Stage 4 canary, and Stage 5 suite passed 49 tests;
- the complete project suite passed 191 tests with one pre-existing skip;
- static analysis completed with no issues;
- both the default 0% debug APK and a Map 1% cohort debug APK built
  successfully;
- no dependency, SQLite schema, Supabase query, Redis behavior, API, Coverage,
  Planning, or default production route changed.
