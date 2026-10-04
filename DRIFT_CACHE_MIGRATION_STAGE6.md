# Drift local-cache migration: Stage 6 guarded Coverage and Planning rollout

Status: implemented as two independent opt-in percentage rollouts. Both new
rollouts default to 0%, so the default production build remains Hive-primary
for Map, Coverage, and Planning.

## Purpose

Stage 6 extends the guarded Drift-primary path proven by the Stage 5 Map
cohort to the expensive Coverage and Planning cache families. It preserves the
same safety envelope:

- deterministic, account-sticky cohorts per dataset family;
- independent percentages for Coverage and Planning;
- mandatory Hive dual-write for every enrolled scope;
- Hive fallback and asynchronous Drift read-repair after a healthy miss;
- per-key write serialization;
- circuit breakers isolated by dataset family;
- privacy-safe, per-family session telemetry;
- immediate rollback by setting the affected family percentage to 0.

No Hive data is deleted. This stage does not change Redis, Supabase queries,
the SQLite schema, dependencies, remote APIs, or Map's existing rollout flag.

## Rollout flags

| Dart define | Default | Effective range | Effect |
| --- | --- | --- | --- |
| `KC_MASTER_FIELD_COVERAGE_DRIFT_ROLLOUT_PERCENT` | `0` | `0..100` | Percentage of accounts whose Coverage cache is Drift-primary |
| `KC_MASTER_FIELD_PLANNING_DRIFT_ROLLOUT_PERCENT` | `0` | `0..100` | Percentage of accounts whose Planning cache is Drift-primary |

Example Coverage 1% build:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_COVERAGE_DRIFT_ROLLOUT_PERCENT=1
```

Example Planning 1% build:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_PLANNING_DRIFT_ROLLOUT_PERCENT=1
```

The family name and account ID are hashed locally. This keeps every
`coverage` and `coverage-regions` scope for one account in the same Coverage
cohort, while Planning has a separate assignment. Account identity is not
persisted or reported by rollout telemetry.

Existing full-backend flags remain authoritative. For example,
`KC_MASTER_FIELD_COVERAGE_CACHE_BACKEND=disabled` is not overridden by a
percentage, and an explicit `drift` backend remains the deliberate full-family
route. Percentage rollout applies only while that family's configured backend
is Hive.

## Runtime behavior

For an enrolled Coverage or Planning scope:

```text
read -> Drift hit -> return Drift
     -> healthy Drift miss -> read Hive -> return Hive immediately
                           -> repair Drift asynchronously
     -> Drift error/unavailable -> read Hive
     -> family circuit open -> bypass Drift -> read Hive

write -> serialize by exact cache key
      -> attempt Drift
      -> always retain the Hive rollback copy
      -> family circuit open -> write Hive only
```

Three consecutive Drift failures open only the affected family circuit for the
rest of the process. A Coverage circuit does not bypass Planning or Map, and a
successful Drift operation resets that family's pre-open failure counter.

## Safe activation order

The flags are technically independent, but production activation should be
sequential so regressions have one likely source:

1. keep both new flags at 0 and retain the Stage 4 parity evidence;
2. progress Coverage through 1%, 5%, 25%, 50%, and 100%;
3. exercise rollback to 0% on the same release line;
4. keep Hive dual-write through the agreed retention window;
5. only then progress Planning through the same ladder;
6. do not retire Hive until every family has separate production evidence and
   a tested recovery procedure.

At each step, stop or roll back the affected family when unexplained parity
mismatches, repeated circuit opening, user-visible latency regression, cache
growth, or crash/memory regression exceeds the agreed baseline. A rollback is
a new build with only that family's rollout percentage set to 0; the other
families do not need to change.

## Verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- 10 focused Stage 6 tests cover default-off and percentage clamping,
  independent family routing, Coverage cohort stability across related
  datasets, authoritative legacy flags, mandatory Hive rollback copies,
  fallback and read-repair for both families, circuit isolation, Stage 4
  shadow exclusion, and telemetry privacy;
- all 17 Stage 5 Map rollout tests continue to pass alongside Stage 6;
- the combined Stage 2–6 cache suite passed all 69 tests;
- the complete project suite passed 201 tests with one pre-existing skip;
- static analysis completed with no issues;
- the default 0%, Coverage 1%, and Planning 1% debug APK variants all built
  successfully;
- database schema and external data paths remain unchanged.
