# Drift local-cache migration: Stage 8 storage hardening

Status: implemented as runtime hardening with no production routing change.
Hive remains the default backend unless the existing Stage 4–7 flags explicitly
select Drift, and no Hive retirement token is enabled by this stage.

## Purpose

Stage 8 closes three operational gaps that become important when Drift is the
only local cache for Map, Coverage, and Planning:

- reject an unhealthy SQLite database before it becomes the active store;
- remove a malformed snapshot after the first failed read instead of allowing
  it to repeatedly trip the family circuit breaker;
- bound live cached payload per account as well as the existing snapshot-count
  limit.

The cache remains disposable. Redis and Supabase remain the recovery path, and
an SQLite failure must never prevent the application from fetching remote data.

## Startup integrity gate

The Drift database now runs `PRAGMA quick_check(1)` before the store is exposed
to the cache router. It also enables the existing foreign-key guard and sets an
8 MiB SQLite journal retention target.

If the integrity check or database initialization fails:

1. the database is closed;
2. the process removes Hive retirement from its effective configuration;
3. the legacy Hive box is opened when available;
4. the existing Hive, Edge/Redis, and direct Supabase fallback path remains
   usable.

Stage 8 does not automatically delete an unhealthy SQLite file. Preserving it
avoids turning a detection mechanism into an irreversible cleanup action and
allows a future release or support workflow to inspect or replace it safely.

## Corrupt-snapshot self-healing

A snapshot is treated as corrupt when its child-row count does not match its
metadata or a row payload is not a JSON object. The store then:

- deletes only that snapshot inside SQLite;
- relies on the foreign key to cascade its child rows;
- returns a normal cache miss;
- leaves every other scope and account untouched.

The next normal remote response repopulates the missing scope. Because the
router receives a miss rather than a repeated store exception, one bad cached
scope cannot unnecessarily open the Drift circuit for its whole dataset
family.

## Per-account payload quota

Drift already retained at most 12 snapshots per account. Stage 8 adds a
128 MiB live payload budget per account using the existing `payloadBytes`
metadata. After every successful write, snapshots are ordered by timestamp and
cache key, then the oldest entries are evicted until both limits are met.

The snapshot just written is protected during that pruning pass. If a single
valid snapshot is larger than the budget, it remains as the account's only
snapshot instead of immediately deleting itself. A later write can replace it.

The 128 MiB limit is intentionally above the Stage 1 combined Map, Coverage,
and Planning reference payload of about 79 MiB. It prevents the previous
12-snapshot worst case from growing without a byte bound while retaining room
for the three primary datasets. This is a soft payload limit: SQLite indexes,
page overhead, and reusable free pages are not counted as payload bytes.

Quota decisions and corrupt cleanup are account-isolated. Logout and account
switching continue to clear that account through the existing `clearUser`
path.

## Compatibility and rollback

Stage 8 keeps database schema version 1 because all required metadata and
indexes already exist. It does not regenerate tables or migrate production
rows. It also does not change:

- cache keys or provider payloads;
- Map, Coverage, or Planning queries;
- rollout cohort selection;
- Hive dual-write, fallback, or retirement rules;
- Redis or Supabase behavior;
- authentication and account scoping.

Rollback is therefore the same as Stage 7: select Hive or remove the relevant
Drift/retirement defines. An integrity failure performs that fallback
automatically for the current process.

## Verification

Verified on 4 October 2026 with Flutter 3.47.4 and Dart 3.13.3:

- 7 focused Stage 8 tests cover integrity and journal guards, malformed JSON,
  account-isolated repair, deterministic quota eviction, account-isolated
  quota, oversized-current-snapshot retention, and replacement accounting;
- the focused Drift store and Stage 8 suite passed all 17 tests;
- the complete Stage 1–8 cache regression suite passed all 95 tests;
- the complete project suite passed all 219 tests, with one pre-existing skip;
- static analysis completed with no issues;
- the default Hive-primary Android debug build completed successfully;
- the full-Drift, all-family Hive-retired Android debug build completed
  successfully;
- database schema version, generated Drift sources, and production defaults
  remain unchanged.
