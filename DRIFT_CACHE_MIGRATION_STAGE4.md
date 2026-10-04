# Drift local-cache migration: Stage 4 canary validation

Status: implemented as an opt-in native canary. Hive remains the primary read
backend unless an existing dataset-backend flag explicitly selects Drift.

## Purpose

Stage 4 measures whether Drift stores the same Map, Coverage, and Planning
snapshots as Hive before any production cutover. It adds:

- dataset-family shadow selection;
- automatic Hive-to-Drift mirrored writes for selected families;
- deterministic sampling of Drift shadow reads;
- exact version, row-count, row-order, and JSON-content comparison;
- asynchronous comparisons that never replace or delay the Hive response;
- privacy-safe session counters and structured diagnostics for mismatches;
- immediate rollback through compile-time flags.

No Supabase query, Redis cache, database schema, or default backend changes in
this stage.

## Compile-time flags

| Dart define | Default | Values | Effect |
| --- | --- | --- | --- |
| `KC_MASTER_FIELD_DRIFT_SHADOW_DATASETS` | empty | comma-separated `map`, `coverage`, `planning` | Families mirrored and measured while Hive remains primary |
| `KC_MASTER_FIELD_DRIFT_SHADOW_SAMPLE_PERCENT` | `10` | integer, clamped to `0..100` | Percentage of eligible cache reads compared with Drift |

Example Map-only canary:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_DRIFT_SHADOW_DATASETS=map `
  --dart-define=KC_MASTER_FIELD_DRIFT_SHADOW_SAMPLE_PERCENT=5
```

Every selected-family write is mirrored so Drift stays warm. Only reads are
sampled. Sampling is deterministic per exact cache scope, keeping the same
scope consistently inside or outside the canary percentage.

Shadow mode applies only while that family is Hive-primary. If its backend is
explicitly changed to `drift`, the Stage 3 Drift-primary route and Hive fallback
take over instead of running a redundant shadow comparison.

## Read and write behavior

```text
Network result -> write Hive -> write Drift -> record mirror outcome

Cache read -> return Hive result immediately
              -> sampled Drift read in background
              -> compare metadata and exact ordered JSON rows
              -> update session counters
```

The write path awaits both stores so the measured snapshot is well-defined.
Failures remain fail-open: a Drift write/read error never removes the Hive
snapshot and never blocks Edge/Redis or direct Supabase fallback.

Comparison outcomes distinguish:

- exact match;
- both stores missing;
- Hive-only or Drift-only snapshots;
- version mismatch;
- row-count mismatch;
- exact content/order mismatch;
- Drift unavailable, read failure, or write failure.

## Telemetry and privacy

`MasterFieldReadCache.canarySnapshot` exposes in-process counters by outcome
and dataset family, plus an exact-content match rate. Mismatches and failures
emit a structured debug diagnostic.

Telemetry deliberately reduces dataset identifiers to their base family and
excludes role identity, user ID, cache key, region, district, row content, and
field number. It is session-local and does not send anything to Supabase or
another external service. A future developer diagnostics screen or approved
observability sink can consume the same typed event contract.

## Cost controls and rollback

Expected canary-only costs are one additional local write for every selected
snapshot and one additional read/decode for sampled scopes. Controls:

- default shadow dataset list is empty;
- read sampling defaults to 10% once a family is enabled;
- content comparison runs outside the UI isolate;
- Hive results are returned before comparison completes;
- duplicate reads for one scope are coalesced and at most two shadow reads run
  concurrently;
- overlapping mirror writes are serialized per cache key to prevent ordering
  races;
- comparisons wait for an in-flight mirrored write and retry a mismatch once,
  so a concurrent refresh is not recorded as a false parity failure;
- existing 12-snapshot per-user retention still bounds both stores.

Rollback is immediate: remove the family from
`KC_MASTER_FIELD_DRIFT_SHADOW_DATASETS`. With no Drift-primary or shadow family,
the SQLite database is not opened on the next process start.

## Stage 5 readiness gate

Do not switch a production family to Drift until a representative canary has:

- at least 1,000 exact-content comparisons for that family;
- at least 99.9% exact match rate;
- zero unexplained version or content mismatches;
- less than 0.1% Drift read/write failures;
- no measurable user-facing fetch regression or memory-pressure issue;
- a tested rollback build with the shadow family removed.

Stage 5 may then cut over one family at a time while retaining Hive dual-write
for the first production cohort.

## Verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- 23 focused canary tests passed, including deterministic sampling, every
  parity outcome, fail-open behavior, per-key write serialization, shadow-read
  deduplication, transient-mismatch retry, telemetry privacy, per-family
  metrics, and a 34,600-row off-isolate comparison;
- the complete project suite passed 174 tests with one pre-existing skip;
- static analysis completed with no issues;
- both the default debug APK and a Map 5% canary debug APK built successfully;
- no dependency, SQLite schema, Supabase query, Redis behavior, or default
  backend changed in this stage.
