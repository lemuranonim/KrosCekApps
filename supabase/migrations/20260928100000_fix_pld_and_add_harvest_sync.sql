create table if not exists public.act_sync_harvest_rows (
  run_id uuid not null references public.act_sync_runs(id) on delete cascade,
  source_row integer not null,
  harvest_date date not null,
  field_number_norm text not null,
  harvested_area_ha numeric,
  harvested_qty_kg numeric,
  created_at timestamptz not null default now(),
  primary key (run_id, source_row)
);

create index if not exists act_sync_harvest_rows_run_field_idx
  on public.act_sync_harvest_rows (run_id, field_number_norm);

alter table public.act_sync_harvest_rows enable row level security;
revoke all on table public.act_sync_harvest_rows from anon, authenticated;
grant all on table public.act_sync_harvest_rows to service_role;

create table if not exists public.act_sync_harvest_reviews (
  run_id uuid not null references public.act_sync_runs(id) on delete cascade,
  field_number_norm text not null,
  status text not null default 'NEEDS_CONFIRMATION'
    check (status in ('NEEDS_CONFIRMATION', 'CONFIRMED', 'DISMISSED')),
  reason text not null,
  effective_area_ha numeric,
  reported_harvest_area_ha numeric,
  safe_harvest_area_ha numeric,
  harvest_event_count integer not null default 0,
  last_harvest_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (run_id, field_number_norm)
);

create index if not exists act_sync_harvest_reviews_status_idx
  on public.act_sync_harvest_reviews (run_id, status);

alter table public.act_sync_harvest_reviews enable row level security;
revoke all on table public.act_sync_harvest_reviews from anon, authenticated;
grant all on table public.act_sync_harvest_reviews to service_role;

create or replace function public.act_master_fields_sync_snapshot(
  p_row public.master_fields
)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'field_number', p_row.field_number,
    'farmer_name', p_row.farmer_name,
    'grower', p_row.grower,
    'hybrid', p_row.hybrid,
    'total_area_planted_ha', p_row.total_area_planted_ha,
    'discard_area_ha', p_row.discard_area_ha,
    'effective_area_ha', p_row.effective_area_ha,
    'harvested_area_ha', p_row.harvested_area_ha,
    'harvested_qty_kg', p_row.harvested_qty_kg,
    'planting_date_pdn', p_row.planting_date_pdn,
    'hamlet_dusun', p_row.hamlet_dusun,
    'village_desa', p_row.village_desa,
    'sub_district_kec', p_row.sub_district_kec,
    'district_kab', p_row.district_kab,
    'fa', p_row.fa,
    'field_spv', p_row.field_spv,
    'coordinate', p_row.coordinate,
    'region', p_row.region,
    'area_manager', p_row.area_manager,
    'type', p_row.type,
    'prov', p_row.prov,
    'planting_ratio', p_row.planting_ratio,
    'planting_space', p_row.planting_space,
    'geometry_wkt', p_row.geometry_wkt,
    'geometry_source', p_row.geometry_source,
    'is_active', p_row.is_active
  );
$$;

revoke all on function public.act_master_fields_sync_snapshot(public.master_fields)
  from public, anon, authenticated;
grant execute on function public.act_master_fields_sync_snapshot(public.master_fields)
  to service_role;

create or replace function public.act_master_fields_values_differ(
  p_field text,
  p_current jsonb,
  p_source jsonb
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case
    when p_field = 'type'
      and (p_current is null or p_current = 'null'::jsonb)
      and upper(nullif(btrim(p_source #>> '{}'), '')) = 'FIELD CORN'
      then false
    when p_field in (
      'total_area_planted_ha',
      'discard_area_ha',
      'effective_area_ha',
      'harvested_area_ha',
      'harvested_qty_kg'
    ) then
      (case when p_current is null or p_current = 'null'::jsonb
        then null else (p_current #>> '{}')::numeric end)
      is distinct from
      (case when p_source is null or p_source = 'null'::jsonb
        then null else (p_source #>> '{}')::numeric end)
    when p_field in ('hybrid', 'type') then
      upper(nullif(btrim(p_current #>> '{}'), ''))
      is distinct from
      upper(nullif(btrim(p_source #>> '{}'), ''))
    else
      nullif(btrim(p_current #>> '{}'), '')
      is distinct from
      nullif(btrim(p_source #>> '{}'), '')
  end;
$$;

create or replace function public.merge_act_sync_pld_page(
  p_run_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_matched bigint;
  v_harvest_review_count bigint := 0;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'PLD page payload must be a JSON array';
  end if;

  with incoming as (
    select
      upper(regexp_replace(btrim(x.field_number_norm), '[[:space:]]+', '', 'g')) as field_number_norm,
      x.approved_at,
      x.source_row,
      x.planted_area_ha,
      x.effective_area_ha,
      x.discard_area_ha
    from jsonb_to_recordset(p_rows) as x(
      field_number_norm text,
      approved_at text,
      source_row integer,
      planted_area_ha numeric,
      effective_area_ha numeric,
      discard_area_ha numeric
    )
    where nullif(btrim(x.field_number_norm), '') is not null
      and x.effective_area_ha is not null
  ),
  final_in_page as (
    select distinct on (field_number_norm) *
    from incoming
    order by field_number_norm, effective_area_ha asc, approved_at desc nulls last, source_row desc
  ),
  normalized as (
    select
      p.*,
      (r.source_payload ->> 'total_area_planted_ha')::numeric as actual_planted_area_ha,
      least(
        greatest(p.effective_area_ha, 0),
        (r.source_payload ->> 'total_area_planted_ha')::numeric
      ) as final_nett_area_ha
    from final_in_page p
    join public.act_sync_rows r
      on r.run_id = p_run_id
     and r.field_number_norm = p.field_number_norm
    where r.source_payload ? 'total_area_planted_ha'
  ),
  updated as (
    update public.act_sync_rows r
    set source_payload = r.source_payload || jsonb_build_object(
          'effective_area_ha', p.final_nett_area_ha,
          'discard_area_ha', greatest(p.actual_planted_area_ha - p.final_nett_area_ha, 0)
        ) || case
          when r.source_payload ? 'harvested_area_ha' then jsonb_build_object(
            'harvested_area_ha', least(
              coalesce((r.source_payload ->> 'harvested_area_ha')::numeric, 0),
              p.final_nett_area_ha
            )
          )
          else '{}'::jsonb
        end,
        raw_payload = r.raw_payload || jsonb_build_object(
          '_act_pld_approved_at', p.approved_at,
          '_act_pld_source_row', p.source_row,
          '_act_pld_nett_area_ha', p.final_nett_area_ha,
          'PLD Transaction Planted Area(Ha)', p.planted_area_ha,
          'PLD Transaction Effective Area(Ha)', p.effective_area_ha,
          'PLD Transaction Discard Area(Ha)', p.discard_area_ha
        ) || case
          when r.raw_payload ? '_act_harvest_reported_area_ha' then jsonb_build_object(
            '_act_harvest_review_status', case
              when (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric
                > p.final_nett_area_ha + 0.01
              then 'NEEDS_CONFIRMATION'
              else 'VALID'
            end,
            'ACT Harvested Area(Ha)', least(
              coalesce((r.source_payload ->> 'harvested_area_ha')::numeric, 0),
              p.final_nett_area_ha
            )
          )
          else '{}'::jsonb
        end,
        validation_errors = case
          when (p.effective_area_ha < 0 or p.effective_area_ha - p.actual_planted_area_ha > 0.01)
            and not ('pld_nett_outside_actual_planted' = any(r.validation_errors))
          then array_append(r.validation_errors, 'pld_nett_outside_actual_planted')
          else r.validation_errors
        end,
        row_hash = md5((r.source_payload || jsonb_build_object(
          'effective_area_ha', p.final_nett_area_ha,
          'discard_area_ha', greatest(p.actual_planted_area_ha - p.final_nett_area_ha, 0)
        ) || case
          when r.source_payload ? 'harvested_area_ha' then jsonb_build_object(
            'harvested_area_ha', least(
              coalesce((r.source_payload ->> 'harvested_area_ha')::numeric, 0),
              p.final_nett_area_ha
            )
          )
          else '{}'::jsonb
        end)::text)
    from normalized p
    where r.run_id = p_run_id
      and r.field_number_norm = p.field_number_norm
      and (
        not (r.raw_payload ? '_act_pld_nett_area_ha')
        or p.final_nett_area_ha < (r.raw_payload ->> '_act_pld_nett_area_ha')::numeric
        or (
          p.final_nett_area_ha = (r.raw_payload ->> '_act_pld_nett_area_ha')::numeric
          and coalesce(p.approved_at, '') > coalesce(r.raw_payload ->> '_act_pld_approved_at', '')
        )
      )
    returning r.id
  )
  select count(*) into v_matched from updated;

  delete from public.act_sync_harvest_reviews review
  using public.act_sync_rows r
  where review.run_id = p_run_id
    and r.run_id = review.run_id
    and r.field_number_norm = review.field_number_norm
    and r.raw_payload ? '_act_harvest_reported_area_ha'
    and (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric
      <= coalesce((r.source_payload ->> 'effective_area_ha')::numeric, 0) + 0.01;

  insert into public.act_sync_harvest_reviews (
    run_id,
    field_number_norm,
    status,
    reason,
    effective_area_ha,
    reported_harvest_area_ha,
    safe_harvest_area_ha,
    harvest_event_count,
    last_harvest_date,
    updated_at
  )
  select
    p_run_id,
    r.field_number_norm,
    'NEEDS_CONFIRMATION',
    'REPORTED_AREA_EXCEEDS_EFFECTIVE_AREA',
    (r.source_payload ->> 'effective_area_ha')::numeric,
    (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric,
    (r.source_payload ->> 'harvested_area_ha')::numeric,
    coalesce((r.raw_payload ->> '_act_harvest_event_count')::integer, 0),
    nullif(r.raw_payload ->> '_act_harvest_last_date', '')::date,
    now()
  from public.act_sync_rows r
  where r.run_id = p_run_id
    and r.raw_payload ? '_act_harvest_reported_area_ha'
    and (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric
      > coalesce((r.source_payload ->> 'effective_area_ha')::numeric, 0) + 0.01
  on conflict (run_id, field_number_norm) do update
  set reason = excluded.reason,
      effective_area_ha = excluded.effective_area_ha,
      reported_harvest_area_ha = excluded.reported_harvest_area_ha,
      safe_harvest_area_ha = excluded.safe_harvest_area_ha,
      harvest_event_count = excluded.harvest_event_count,
      last_harvest_date = excluded.last_harvest_date,
      updated_at = now();

  select count(*) into v_harvest_review_count
  from public.act_sync_harvest_reviews
  where run_id = p_run_id
    and status = 'NEEDS_CONFIRMATION';

  return jsonb_build_object(
    'run_id', p_run_id,
    'matched', v_matched,
    'received', jsonb_array_length(p_rows),
    'harvest_needs_review', v_harvest_review_count
  );
end;
$$;

revoke all on function public.merge_act_sync_pld_page(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_act_sync_pld_page(uuid, jsonb)
  to service_role;

comment on function public.merge_act_sync_pld_page(uuid, jsonb) is
  'Keeps Planting actual area and derives final PLD discard as actual planted minus the lowest approved nett area per FN.';

create or replace function public.merge_act_sync_harvest_page(
  p_run_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
set statement_timeout = '60s'
as $$
declare
  v_received integer := 0;
  v_matched_events integer := 0;
  v_matched_fields integer := 0;
  v_review_count integer := 0;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'Harvest page payload must be a JSON array';
  end if;
  v_received := jsonb_array_length(p_rows);

  insert into public.act_sync_harvest_rows (
    run_id,
    source_row,
    harvest_date,
    field_number_norm,
    harvested_area_ha,
    harvested_qty_kg
  )
  select
    p_run_id,
    x.source_row,
    x.harvest_date,
    upper(regexp_replace(btrim(x.field_number_norm), '[[:space:]]+', '', 'g')),
    x.harvested_area_ha,
    x.harvested_qty_kg
  from jsonb_to_recordset(p_rows) as x(
    source_row integer,
    harvest_date date,
    field_number_norm text,
    harvested_area_ha numeric,
    harvested_qty_kg numeric
  )
  where nullif(btrim(x.field_number_norm), '') is not null
  on conflict (run_id, source_row) do update
  set harvest_date = excluded.harvest_date,
      field_number_norm = excluded.field_number_norm,
      harvested_area_ha = excluded.harvested_area_ha,
      harvested_qty_kg = excluded.harvested_qty_kg;

  select count(*) into v_matched_events
  from jsonb_to_recordset(p_rows) as x(
    source_row integer,
    harvest_date date,
    field_number_norm text,
    harvested_area_ha numeric,
    harvested_qty_kg numeric
  )
  where exists (
    select 1
    from public.act_sync_rows r
    where r.run_id = p_run_id
      and r.field_number_norm = upper(
        regexp_replace(btrim(x.field_number_norm), '[[:space:]]+', '', 'g')
      )
  );

  with affected as (
    select distinct upper(
      regexp_replace(btrim(x.field_number_norm), '[[:space:]]+', '', 'g')
    ) as field_number_norm
    from jsonb_to_recordset(p_rows) as x(
      source_row integer,
      harvest_date date,
      field_number_norm text,
      harvested_area_ha numeric,
      harvested_qty_kg numeric
    )
  ),
  harvest_aggregate as (
    select
      h.field_number_norm,
      count(*) as event_count,
      coalesce(max(h.harvested_area_ha), 0) as reported_harvest_area,
      coalesce(sum(h.harvested_qty_kg), 0) as harvested_qty_sum,
      max(h.harvest_date) as last_harvest_date
    from public.act_sync_harvest_rows h
    join affected a on a.field_number_norm = h.field_number_norm
    where h.run_id = p_run_id
    group by h.field_number_norm
  ),
  normalized as (
    select
      a.*,
      coalesce(
        (r.source_payload ->> 'effective_area_ha')::numeric,
        (r.source_payload ->> 'total_area_planted_ha')::numeric,
        a.reported_harvest_area
      ) as allowed_harvest_area,
      least(
        greatest(a.reported_harvest_area, 0),
        coalesce(
          (r.source_payload ->> 'effective_area_ha')::numeric,
          (r.source_payload ->> 'total_area_planted_ha')::numeric,
          a.reported_harvest_area
        )
      ) as harvested_area_final
    from harvest_aggregate a
    join public.act_sync_rows r
      on r.run_id = p_run_id
     and r.field_number_norm = a.field_number_norm
  ),
  updated as (
    update public.act_sync_rows r
    set source_payload = r.source_payload || jsonb_build_object(
          'harvested_area_ha', a.harvested_area_final,
          'harvested_qty_kg', a.harvested_qty_sum
        ),
        raw_payload = r.raw_payload || jsonb_build_object(
          '_act_harvest_event_count', a.event_count,
          '_act_harvest_reported_area_ha', a.reported_harvest_area,
          '_act_harvest_last_date', a.last_harvest_date,
          '_act_harvest_review_status', case
            when a.reported_harvest_area > a.allowed_harvest_area + 0.01
              then 'NEEDS_CONFIRMATION'
            else 'VALID'
          end,
          'ACT Harvested Area(Ha)', a.harvested_area_final,
          'ACT Harvested Qty(Kg)', a.harvested_qty_sum
        ),
        row_hash = md5((r.source_payload || jsonb_build_object(
          'harvested_area_ha', a.harvested_area_final,
          'harvested_qty_kg', a.harvested_qty_sum
        ))::text)
    from normalized a
    where r.run_id = p_run_id
      and r.field_number_norm = a.field_number_norm
    returning r.id
  )
  select count(*) into v_matched_fields from updated;

  delete from public.act_sync_harvest_reviews review
  using public.act_sync_rows r
  where review.run_id = p_run_id
    and r.run_id = review.run_id
    and review.field_number_norm = r.field_number_norm
    and r.raw_payload ? '_act_harvest_reported_area_ha'
    and (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric
      <= coalesce(
        (r.source_payload ->> 'effective_area_ha')::numeric,
        (r.source_payload ->> 'total_area_planted_ha')::numeric,
        0
      ) + 0.01;

  insert into public.act_sync_harvest_reviews (
    run_id,
    field_number_norm,
    status,
    reason,
    effective_area_ha,
    reported_harvest_area_ha,
    safe_harvest_area_ha,
    harvest_event_count,
    last_harvest_date,
    updated_at
  )
  select
    p_run_id,
    r.field_number_norm,
    'NEEDS_CONFIRMATION',
    'REPORTED_AREA_EXCEEDS_EFFECTIVE_AREA',
    coalesce(
      (r.source_payload ->> 'effective_area_ha')::numeric,
      (r.source_payload ->> 'total_area_planted_ha')::numeric,
      0
    ),
    (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric,
    (r.source_payload ->> 'harvested_area_ha')::numeric,
    coalesce((r.raw_payload ->> '_act_harvest_event_count')::integer, 0),
    nullif(r.raw_payload ->> '_act_harvest_last_date', '')::date,
    now()
  from public.act_sync_rows r
  where r.run_id = p_run_id
    and r.raw_payload ? '_act_harvest_reported_area_ha'
    and (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric
      > coalesce(
        (r.source_payload ->> 'effective_area_ha')::numeric,
        (r.source_payload ->> 'total_area_planted_ha')::numeric,
        0
      ) + 0.01
  on conflict (run_id, field_number_norm) do update
  set reason = excluded.reason,
      effective_area_ha = excluded.effective_area_ha,
      reported_harvest_area_ha = excluded.reported_harvest_area_ha,
      safe_harvest_area_ha = excluded.safe_harvest_area_ha,
      harvest_event_count = excluded.harvest_event_count,
      last_harvest_date = excluded.last_harvest_date,
      updated_at = now();

  select count(*) into v_review_count
  from public.act_sync_harvest_reviews
  where run_id = p_run_id
    and status = 'NEEDS_CONFIRMATION';

  return jsonb_build_object(
    'run_id', p_run_id,
    'received', v_received,
    'matched_events', v_matched_events,
    'matched_fields', v_matched_fields,
    'unmatched_events', greatest(v_received - v_matched_events, 0),
    'needs_review', v_review_count
  );
end;
$$;

revoke all on function public.merge_act_sync_harvest_page(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_act_sync_harvest_page(uuid, jsonb)
  to service_role;

comment on function public.merge_act_sync_harvest_page(uuid, jsonb) is
  'Stages Harvest events idempotently, sums weight, uses the maximum reported cumulative area, and queues area anomalies for confirmation.';

create or replace function public.get_act_sync_harvest_reviews(
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
  updated_at timestamptz
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
        order by r.started_at desc
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
    review.updated_at
  from public.act_sync_harvest_reviews review
  join selected_run selected on selected.id = review.run_id
  order by review.status, review.field_number_norm;
$$;

revoke all on function public.get_act_sync_harvest_reviews(uuid)
  from public, anon;
grant execute on function public.get_act_sync_harvest_reviews(uuid)
  to authenticated, service_role;

comment on function public.get_act_sync_harvest_reviews(uuid) is
  'Lists ACT Harvest area anomalies that need confirmation without exposing raw credentials or exports.';

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
      'blockers', coalesce((s.summary ->> 'blockers')::integer, 0),
      'harvest_needs_review', coalesce((s.source_meta ->> 'harvest_needs_review')::integer, 0)
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
