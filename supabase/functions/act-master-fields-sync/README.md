# ACT master-fields sync

This Edge Function imports authenticated ACT Planting data for Field Corn,
Parent Seed, and Sweet Corn, then reconciles it against KC `master_fields` by
normalized `field_number`.

The default `table` mode reads the three paginated Planting JSON endpoints,
merges `Geometry WKT` from authenticated background export workbooks, and then
overlays final PLD/Area Adjustment rows (`status=3`). WKT and reconciliation
are processed in resumable 2,000-row batches, so the large FC workbook is never
applied in one Edge invocation. FC WKT is exported in monthly shards while the
smaller PS and SC exports remain full-range. Within each shard, the reader skips
rows before the saved cursor without decoding them and resolves shared strings
only for Field Number and Geometry WKT. Pending/process PLD recommendations are
never applied. The approved PLD mapping is:

- planted area: column 12
- effective area: column 13
- discard area: column 14

The older mode that imports every workbook column remains a fallback. Production
uses the workbook only for `Geometry WKT`; all other ACT-owned planting columns
come from the paginated Planting endpoint and final PLD overlay.

ACT manages `field_number`, farmer/grower/hybrid, planted/discard/effective
areas, female planting date, address hierarchy, FA/supervisor/manager/region,
crop type, province, planting ratio/space, and `geometry_wkt`. KC-owned harvest,
QA, lot, audit, correction, and derived geometry columns are not overwritten.
`Previous Crop Corn` remains unmapped because legacy KC
`previous_crop_data_a_b` contains mixed numeric codes and labels; it requires a
separate approved normalization before ACT can own that column.

The first run should always use `"apply": false`. It stages every ACT row and
creates an auditable decision for each field:

- `INSERT`
- `UPDATE`
- `UNCHANGED`
- `INVALID`
- `CONFLICT_SOURCE_DUPLICATE`
- `CONFLICT_KC_DUPLICATE`
- `MISSING_SOURCE` (informational; never deletes or deactivates KC data)

## Safety model

- ACT credentials stay in Supabase Edge Function secrets, never in Flutter.
- Only KC `ADMIN`, `DEV`, or a Supabase `service_role` request may invoke it.
- `apply=true` is blocked when validation or duplicate conflicts exist.
- A configurable change-ratio guard prevents unexpectedly large writes.
- Application is one database transaction through
  `apply_act_master_fields_sync`.
- KC-owned audit, QA, and correction columns are not included in the update.
- ACT geometry is written only to `geometry_wkt`; Planting latitude/longitude
  never update the legacy `coordinate` column.
- User/KC polygon revisions are stored separately in
  `correction_geometry_wkt` and are never managed by ACT sync. The app uses a
  valid correction polygon first, then falls back to ACT `geometry_wkt`.
- The legacy `manual`/`kc_manual` geometry-source guard remains as an additional
  safeguard for older records.
- Every applied insert/update is stored in `act_master_fields_change_log`.

## Database setup

Apply migration:

```powershell
supabase db push
```

Required secrets:

```powershell
supabase secrets set ACT_SYNC_USERNAME="<dedicated ACT integration account>"
supabase secrets set ACT_SYNC_PASSWORD="<password>"
```

Use a dedicated ACT account with read access to all regions. Do not use a
personal super-admin account for the scheduled production job.

Optional secrets:

```text
ACT_SYNC_ORIGIN=https://act.advantaseeds.com
ACT_SYNC_MIN_TOTAL_ROWS=1000
ACT_SYNC_MAX_CHANGE_RATIO=0.25
```

Deploy:

```powershell
supabase functions deploy act-master-fields-sync
```

## First dry-run

Invoke with an authenticated KC admin JWT:

```json
{
  "from": "2026-01-01",
  "to": "2026-09-24",
  "apply": false,
  "sources": ["FC", "PS", "SC"],
  "exportMode": "table",
  "includeWkt": true,
  "minimumRows": 30000,
  "maxChangeRatio": 0.25
}
```

The first response returns `status=EXTRACTING` and a `run_id`. Resume the same
run until it reaches `READY`, `BLOCKED`, `FAILED`, or `COMPLETED`:

```json
{
  "runId": "<run-id>"
}
```

Each resume request handles at most 5,000 Planting rows, 2,000 workbook rows for
WKT, 1,000 final PLD rows, or 2,000 reconciliation rows. Reconciliation runs in
resumable PostgreSQL batches, avoiding Edge memory/CPU and statement-timeout
limits.

Inspect the run before applying:

```sql
select id, status, dry_run, source_counts, summary, error_message, started_at
from public.act_sync_runs
order by started_at desc
limit 10;

select field_number_norm, source_type, change_kind, changed_columns,
       validation_errors
from public.act_sync_changes
where run_id = '<run-id>'
  and change_kind <> 'UNCHANGED'
order by change_kind, field_number_norm;
```

Acceptance check for the reported Sweet Corn correction:

```sql
select field_number_norm, change_kind, changed_columns
from public.act_sync_changes
where run_id = '<run-id>'
  and field_number_norm = 'DC6FHK045';
```

The expected first dry-run result is an `UPDATE` whose `hybrid` change is
`AX01` to `AX04` if KC still contains the old value. On 2026-09-24 the accepted
snapshot contained 32,704 FC, 274 PS, and 1,540 SC rows; 2,131 final PLD rows
were read and 2,115 matched that Planting snapshot.

## Apply and scheduling

After the dry-run counts and sampled changes are accepted, invoke the same date
range with `"apply": true`, then resume its returned `run_id` until terminal.
This creates a new run, repeats extraction and validation, then applies the
validated snapshot transactionally.

For automation, use a trusted server-side scheduler that starts one daily run
with `apply=true` and resumes its `run_id` every few minutes until terminal.
Always use the full active-season range because ACT can edit an older field
without changing its planting date.

The manual fallback runner is `scripts/run_act_master_fields_sync.ps1`. It uses
the current Bangkok calendar year, resumes an existing run for the same source
date, and skips a duplicate when that date is already `COMPLETED`.

Production scheduling runs entirely inside Supabase. Cron job
`act-master-fields-sync-cloud` starts at 01:00 WIB and dispatches one resumable
batch every three minutes through 05:59 WIB. The extended window accommodates
ACT background-export queue time and the large FC WKT workbook. It stops
dispatching as soon as the run is terminal, prevents duplicate runs for the
same source date, and uses the encrypted Vault secret
`act_sync_service_role_key`. The former local Codex automation is paused and is
not required for production. Every successful batch advances `progress_at`; a
server-side watchdog marks an active run `FAILED` after 60 minutes without a
checkpoint, so a forced Edge shutdown cannot leave KC showing an endless sync.

Cron job `act-master-fields-sync-cleanup` runs at 02:30 WIB. Raw staged rows are
kept for three days and reconciliation rows for seven days; run summaries and
the applied INSERT/UPDATE audit are retained permanently. Cleanup never touches
`master_fields`.

Operational reports are available in:

- `act_sync_runs` for the run status and summary counts;
- `act_sync_changes` for reconciliation decisions and old/new values;
- `act_master_fields_change_log` for the immutable applied INSERT/UPDATE audit.

Service-side health can be read through
`act_master_fields_sync_cloud_status()`, which reports the Cron jobs, Vault
configuration state, and latest sync summary without returning any secret.

Do not place the service-role key in the Flutter app or a client-side scheduler.
