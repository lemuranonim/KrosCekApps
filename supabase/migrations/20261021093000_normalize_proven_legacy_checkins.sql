begin;
set local lock_timeout = '5s';
set local statement_timeout = '45s';
select pg_advisory_xact_lock(hashtextextended('kroscek:legacy-checkin-time:20261021', 0));

-- Legacy clients sent local WIB wall time without an offset. PostgreSQL stored
-- it as UTC. Only repair check-ins independently corroborated by created_at:
-- seven hours apart within five seconds, before the server-time rollout,
-- same operational date, and no checkout whose duration could be affected.
-- Keep the complete original rows in a schema outside the public REST API.
create schema if not exists kroscek_maintenance;
create table if not exists kroscek_maintenance.attendance_time_corrections_20261021 (
  attendance_id uuid primary key,
  original_check_in_time timestamptz not null,
  corrected_check_in_time timestamptz not null,
  server_created_at timestamptz not null,
  original_row jsonb not null,
  backed_up_at timestamptz not null default now(),
  check (corrected_check_in_time = original_check_in_time - interval '7 hours')
);
alter table kroscek_maintenance.attendance_time_corrections_20261021 enable row level security;
revoke all on table kroscek_maintenance.attendance_time_corrections_20261021
  from public, anon, authenticated;
comment on table kroscek_maintenance.attendance_time_corrections_20261021 is
  'Restricted recovery backup for evidence-based legacy check-in UTC normalization. Do not expose through the API.';

do $repair$
declare
  expected_count constant integer := 5771;
  backed_up_count integer;
  candidate_count integer;
  inserted_count integer;
  updated_count integer;
begin
  -- The existing attendance trigger deliberately permits database maintenance.
  -- Refuse to run this maintenance transaction under an end-user JWT.
  if auth.uid() is not null then
    raise exception 'Run the attendance repair as database maintenance only';
  end if;

  select count(*) into backed_up_count
    from kroscek_maintenance.attendance_time_corrections_20261021;
  select count(*) into candidate_count
    from public.attendance_header h
    where h.created_at < timestamptz '2026-10-17 00:00:00+00'
      and h.check_out_time is null and h.status = 'open'
      and abs(extract(epoch from (h.check_in_time - h.created_at)) - 25200) <= 5
      and h.attendance_date = (h.created_at at time zone 'Asia/Bangkok')::date
      and h.attendance_date = ((h.check_in_time - interval '7 hours') at time zone 'Asia/Bangkok')::date;

  if not ((backed_up_count = 0 and candidate_count = expected_count)
       or (backed_up_count = expected_count and candidate_count = 0)) then
    raise exception 'Attendance repair candidate or backup count changed; inspect before retrying';
  end if;

  with locked_candidates as materialized (
    select h.* from public.attendance_header h
    where h.created_at < timestamptz '2026-10-17 00:00:00+00'
      and h.check_out_time is null and h.status = 'open'
      and abs(extract(epoch from (h.check_in_time - h.created_at)) - 25200) <= 5
      and h.attendance_date = (h.created_at at time zone 'Asia/Bangkok')::date
      and h.attendance_date = ((h.check_in_time - interval '7 hours') at time zone 'Asia/Bangkok')::date
    for update
  )
  insert into kroscek_maintenance.attendance_time_corrections_20261021
    (attendance_id, original_check_in_time, corrected_check_in_time, server_created_at, original_row)
  select h.attendance_id, h.check_in_time, h.check_in_time - interval '7 hours', h.created_at, to_jsonb(h)
    from locked_candidates h
  on conflict (attendance_id) do nothing;
  get diagnostics inserted_count = row_count;
  if inserted_count <> candidate_count then
    raise exception 'Attendance backup count does not match the locked candidates';
  end if;

  update public.attendance_header h
    set check_in_time = b.corrected_check_in_time
    from kroscek_maintenance.attendance_time_corrections_20261021 b
    where h.attendance_id = b.attendance_id
      and h.check_in_time = b.original_check_in_time
      and to_jsonb(h) = b.original_row;
  get diagnostics updated_count = row_count;
  if updated_count <> candidate_count then
    raise exception 'Attendance changed after backup; rolling back the repair';
  end if;

  if (select count(*) from kroscek_maintenance.attendance_time_corrections_20261021) <> expected_count
     or exists (
       select 1 from kroscek_maintenance.attendance_time_corrections_20261021 b
       left join public.attendance_header h using (attendance_id)
       where h.attendance_id is null
         or h.check_in_time is distinct from b.corrected_check_in_time
         or abs(extract(epoch from (h.check_in_time - h.created_at))) > 5
         or (to_jsonb(h) - 'check_in_time') is distinct from (b.original_row - 'check_in_time')
     ) then
    raise exception 'Attendance repair verification failed; rolling back';
  end if;

  if has_table_privilege('anon', 'kroscek_maintenance.attendance_time_corrections_20261021', 'SELECT')
     or has_table_privilege('authenticated', 'kroscek_maintenance.attendance_time_corrections_20261021', 'SELECT') then
    raise exception 'Attendance recovery backup must not be readable by app users';
  end if;
end;
$repair$;

select count(*) as backed_up_rows,
  count(*) filter (where h.check_in_time = b.corrected_check_in_time) as corrected_rows,
  count(*) filter (where (to_jsonb(h) - 'check_in_time') = (b.original_row - 'check_in_time')) as other_columns_preserved,
  count(distinct h.user_id) as affected_accounts,
  bool_and(abs(extract(epoch from (h.check_in_time - h.created_at))) <= 5) as server_time_matches,
  not has_table_privilege('anon', 'kroscek_maintenance.attendance_time_corrections_20261021', 'SELECT')
    and not has_table_privilege('authenticated', 'kroscek_maintenance.attendance_time_corrections_20261021', 'SELECT') as backup_is_private
from kroscek_maintenance.attendance_time_corrections_20261021 b
join public.attendance_header h using (attendance_id);
commit;
