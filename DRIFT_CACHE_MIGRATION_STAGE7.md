# Drift local-cache migration: Stage 7 guarded Hive retirement

Status: implemented as an opt-in retirement gate. The default remains empty,
so production continues to use the Stage 5–6 Hive fallback and rollback copies
until a release explicitly proves and declares each family ready.

## Purpose

Stage 7 provides the final decommission path for the master-field Hive cache
without making retirement an accidental side effect of percentage rollout.
It adds:

- family-specific Hive retirement for Map, Coverage, and Planning;
- a hard requirement that a retired family use the explicit full-Drift
  backend, not a percentage cohort;
- no Hive read, fallback, read-repair source, or write for a retired family;
- privacy-safe `hiveRetirementBypass` telemetry when a failure or miss falls
  through to the existing network path;
- automatic emergency restoration of Hive fallback for the process when Drift
  cannot initialize or is unavailable on the platform;
- deletion of the disposable `masterFieldReadCacheV2` box only after all three
  families retire and Drift has opened successfully;
- cold rollback support: a later Hive build recreates an empty box and safely
  repopulates it from Edge/Redis or direct Supabase.

This stage does not retire the other Hive boxes used by inspection/draft
features. It does not change Redis, Supabase queries, the Drift schema,
dependencies, authentication, or provider payloads.

## Retirement flag

| Dart define | Default | Accepted tokens | Effect |
| --- | --- | --- | --- |
| `KC_MASTER_FIELD_HIVE_RETIRED_FAMILIES` | empty | comma-separated `map`, `coverage`, `planning` | Removes the Hive safety path only for matching explicit full-Drift backends |

A retirement token is ignored unless its matching backend flag is explicitly
`drift`. For example, this does **not** retire Hive because Map is still using
the percentage rollout route:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_MAP_DRIFT_ROLLOUT_PERCENT=100 `
  --dart-define=KC_MASTER_FIELD_HIVE_RETIRED_FAMILIES=map
```

The application logs the ignored request, keeps mandatory Hive dual-write,
and keeps Hive fallback.

After Map has completed its evidence and rollback-retention window, the
eligible configuration is:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_MAP_CACHE_BACKEND=drift `
  --dart-define=KC_MASTER_FIELD_HIVE_RETIRED_FAMILIES=map
```

Coverage and Planning remain untouched until their tokens and explicit Drift
backends are added separately.

## Full legacy-box cleanup gate

The legacy master-field box is deleted only when all conditions are true:

1. local caching is enabled;
2. Map, Coverage, and Planning all use their explicit `drift` backend;
3. all three tokens are present in `KC_MASTER_FIELD_HIVE_RETIRED_FAMILIES`;
4. the Drift database opened successfully in the current process.

Example final configuration, to be used only after production evidence exists
for every family:

```powershell
flutter build apk `
  --dart-define=KC_MASTER_FIELD_MAP_CACHE_BACKEND=drift `
  --dart-define=KC_MASTER_FIELD_COVERAGE_CACHE_BACKEND=drift `
  --dart-define=KC_MASTER_FIELD_PLANNING_CACHE_BACKEND=drift `
  --dart-define=KC_MASTER_FIELD_HIVE_RETIRED_FAMILIES=map,coverage,planning
```

If Drift fails to open, the application does not delete the legacy box. It
removes retirement from the in-process configuration, opens Hive, and retains
the normal Hive/network fallback. This emergency behavior also applies on web,
where the native Drift store is unavailable.

## Runtime behavior after family retirement

```text
Drift hit -> return Drift

Drift miss/error/circuit-open
  -> do not read Hive
  -> emit retirement bypass telemetry
  -> local miss
  -> Edge/Redis
  -> direct Supabase when required

write
  -> attempt Drift
  -> never dual-write the retired family to Hive
  -> Drift failure leaves local cache empty; application data remains remote
```

Circuit breakers remain family-isolated. Retiring Map does not affect the Hive
fallback or rollout policy of Coverage and Planning.

## Production gate and rollback

Do not add a family token merely because tests and builds pass. Before each
family retirement, retain documented evidence for:

- 100% Drift-primary stability through a representative production window;
- zero unexplained parity mismatch;
- acceptable cache size, startup, memory, and latency metrics;
- a rollback exercise on the same release line;
- completion of the agreed Hive rollback-retention window.

Warm rollback before full box deletion removes only the affected token and can
reuse its retained Hive snapshots. After all-family cleanup, rollback is still
safe but cold: remove the retirement tokens or select Hive, and the empty box
is recreated and repopulated from the existing remote path.

## Verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- 11 focused Stage 7 tests cover default-off behavior, percentage-rollout
  rejection, explicit full-Drift eligibility, all-family cleanup gating,
  emergency rollback configuration, retired read miss/failure behavior,
  write suppression, family isolation, circuit behavior, and legacy-box
  deletion/recreation;
- the combined Stage 5–7 rollout and retirement suite passed all 38 tests;
- the complete Stage 2–7 cache regression suite passed all 80 tests;
- the complete project suite passed all 212 tests, with one pre-existing skip;
- static analysis completed with no issues;
- the default Android debug build completed successfully;
- the full-retirement Android debug build completed successfully with all
  three families explicitly routed to Drift;
- the equivalent full-retirement web build completed successfully and retains
  its runtime Hive fallback when native Drift is unavailable;
- no production retirement token is enabled by default.
