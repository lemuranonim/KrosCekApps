drop function if exists public.get_act_sync_harvest_reviews(uuid);

create function public.get_act_sync_harvest_reviews(
  p_run_id uuid default null
)
returns table (
  run_id uuid,
  field_number text,
  status text,
  reason text,
  effective_area_ha numeric,
  reported_harvest_area_ha numeric,
  safe_harvest_area_ha numeric,
  harvest_event_count integer,
  last_harvest_date date,
  updated_at timestamptz,
  hybrid text,
  farmer_name text,
  grower text,
  region text,
  district_kab text,
  sub_district_kec text,
  village_desa text,
  qa_fi text,
  qa_spv text,
  fa text,
  season text,
  type text
)
language sql
stable
security definer
set search_path = ''
as $$
  with selected_run as (
    select coalesce(
      p_run_id,
      (
        select r.id
        from public.act_sync_runs r
        where r.dry_run = false
          and r.status = 'COMPLETED'
        order by r.completed_at desc nulls last, r.started_at desc
        limit 1
      )
    ) as id
  )
  select
    review.run_id,
    review.field_number_norm,
    review.status,
    review.reason,
    review.effective_area_ha,
    review.reported_harvest_area_ha,
    review.safe_harvest_area_ha,
    review.harvest_event_count,
    review.last_harvest_date,
    review.updated_at,
    mf.hybrid,
    mf.farmer_name,
    mf.grower,
    mf.region,
    mf.district_kab,
    mf.sub_district_kec,
    mf.village_desa,
    mf.qa_fi,
    mf.qa_spv,
    mf.fa,
    mf.season,
    mf.type
  from public.act_sync_harvest_reviews review
  join selected_run selected on selected.id = review.run_id
  left join public.master_fields mf
    on upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
      = review.field_number_norm
  order by
    case review.status when 'NEEDS_CONFIRMATION' then 0 else 1 end,
    review.field_number_norm;
$$;

revoke all on function public.get_act_sync_harvest_reviews(uuid)
  from public, anon;
grant execute on function public.get_act_sync_harvest_reviews(uuid)
  to authenticated, service_role;

comment on function public.get_act_sync_harvest_reviews(uuid) is
  'Lists sanitized ACT Harvest review items enriched with KC field ownership and location metadata for ACT Data Monitor.';

create or replace function public.get_act_sync_public_history(
  p_limit integer default 8
)
returns table (
  run_id uuid,
  status text,
  source_from date,
  source_to date,
  source_rows integer,
  inserted_rows integer,
  updated_rows integer,
  invalid_rows integer,
  blockers integer,
  harvest_needs_review integer,
  started_at timestamptz,
  completed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    run.id,
    run.status,
    run.source_from,
    run.source_to,
    coalesce((run.summary ->> 'source_rows')::integer, 0),
    coalesce((run.summary ->> 'insert')::integer, 0),
    coalesce((run.summary ->> 'update')::integer, 0),
    coalesce((run.summary ->> 'invalid')::integer, 0),
    coalesce((run.summary ->> 'blockers')::integer, 0),
    case
      when run.status = 'COMPLETED' then (
        select count(*)::integer
        from public.act_sync_harvest_reviews review
        where review.run_id = run.id
          and review.status = 'NEEDS_CONFIRMATION'
      )
      else 0
    end,
    run.started_at,
    run.completed_at
  from public.act_sync_runs run
  where run.dry_run = false
  order by run.started_at desc
  limit least(greatest(coalesce(p_limit, 8), 1), 20);
$$;

revoke all on function public.get_act_sync_public_history(integer)
  from public, anon;
grant execute on function public.get_act_sync_public_history(integer)
  to authenticated, service_role;

comment on function public.get_act_sync_public_history(integer) is
  'Returns a bounded sanitized ACT sync history for authenticated KC users.';
