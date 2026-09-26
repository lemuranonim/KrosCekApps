create or replace function public.get_act_sync_public_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with local_clock as (
    select
      (now() at time zone 'Asia/Bangkok')::date as local_date,
      (now() at time zone 'Asia/Bangkok')::time as local_time
  ),
  latest as (
    select r.*
    from public.act_sync_runs r
    where r.dry_run = false
    order by r.started_at desc
    limit 1
  ),
  latest_success as (
    select r.*
    from public.act_sync_runs r
    where r.dry_run = false
      and r.status = 'COMPLETED'
    order by r.completed_at desc nulls last, r.started_at desc
    limit 1
  ),
  expected as (
    select case
      when local_time < time '01:00' then local_date - 1
      else local_date
    end as source_date
    from local_clock
  )
  select jsonb_build_object(
    'latest_status', coalesce(l.status, 'NEVER'),
    'latest_target_source_date', l.source_to,
    'latest_started_at', l.started_at,
    'latest_completed_at', l.completed_at,
    'last_success_source_date', s.source_to,
    'last_success_at', s.completed_at,
    'is_current', coalesce(s.source_to >= e.source_date, false),
    'source_counts', jsonb_build_object(
      'FC', coalesce((s.source_counts ->> 'FC')::integer, 0),
      'PS', coalesce((s.source_counts ->> 'PS')::integer, 0),
      'SC', coalesce((s.source_counts ->> 'SC')::integer, 0)
    ),
    'summary', jsonb_build_object(
      'source_rows', coalesce((s.summary ->> 'source_rows')::integer, 0),
      'insert', coalesce((s.summary ->> 'applied_insert')::integer,
                         (s.summary ->> 'insert')::integer, 0),
      'update', coalesce((s.summary ->> 'applied_update')::integer,
                         (s.summary ->> 'update')::integer, 0),
      'unchanged', coalesce((s.summary ->> 'unchanged')::integer, 0),
      'missing_source', coalesce((s.summary ->> 'missing_source')::integer, 0),
      'invalid', coalesce((s.summary ->> 'invalid')::integer, 0),
      'blockers', coalesce((s.summary ->> 'blockers')::integer, 0)
    )
  )
  from expected e
  left join latest l on true
  left join latest_success s on true;
$$;

revoke all on function public.get_act_sync_public_status()
  from public, anon;
grant execute on function public.get_act_sync_public_status()
  to authenticated, service_role;

comment on function public.get_act_sync_public_status() is
  'Returns a minimal non-sensitive ACT sync freshness summary for authenticated KC users.';
