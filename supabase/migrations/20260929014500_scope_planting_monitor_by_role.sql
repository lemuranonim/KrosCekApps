create or replace function public.act_monitor_name_matches(
  p_names text,
  p_name text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when nullif(btrim(p_name), '') is null then false
    else exists (
      select 1
      from regexp_split_to_table(
        coalesce(p_names, ''),
        '\s*[,;|/&]\s*|\s+(dan|and)\s+',
        'i'
      ) as part
      where lower(regexp_replace(btrim(part), '\s+', ' ', 'g')) =
        lower(regexp_replace(btrim(p_name), '\s+', ' ', 'g'))
    )
  end;
$$;

revoke all on function public.act_monitor_name_matches(text, text)
  from public, anon, authenticated;
grant execute on function public.act_monitor_name_matches(text, text)
  to service_role;

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
  with viewer_scope as (
    select
      upper(btrim(u.role)) as role,
      btrim(u.name) as name,
      upper(btrim(u.role)) in ('ADMIN', 'DEV', 'MANAGER') as can_view_all
    from public.app_users u
    where u.id = auth.uid()
      and coalesce(u.is_active, true) = true

    union all

    select 'SERVICE_ROLE', '', true
    where auth.role() = 'service_role'
  ),
  selected_run as (
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
  join public.master_fields mf
    on upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
      = review.field_number_norm
  where exists (
    select 1
    from viewer_scope scope
    where scope.can_view_all
      or (
        scope.role = 'SPV'
        and public.act_monitor_name_matches(mf.qa_spv, scope.name)
      )
      or (
        scope.role = 'FI'
        and public.act_monitor_name_matches(mf.qa_fi, scope.name)
      )
  )
  order by
    case review.status when 'NEEDS_CONFIRMATION' then 0 else 1 end,
    review.field_number_norm;
$$;

revoke all on function public.get_act_sync_harvest_reviews(uuid)
  from public, anon;
grant execute on function public.get_act_sync_harvest_reviews(uuid)
  to authenticated, service_role;

comment on function public.get_act_sync_harvest_reviews(uuid) is
  'Lists Harvest review items scoped server-side to the signed-in Manager/Dev/Admin, QA SPV, or FI account.';

create or replace function public.get_planting_data_monitor_summary(
  p_region text default null,
  p_district text default null,
  p_owner text default null,
  p_season text default null,
  p_seed_type text default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with viewer_scope as (
    select
      upper(btrim(u.role)) as role,
      btrim(u.name) as name,
      upper(btrim(u.role)) in ('ADMIN', 'DEV', 'MANAGER') as can_view_all
    from public.app_users u
    where u.id = auth.uid()
      and coalesce(u.is_active, true) = true

    union all

    select 'SERVICE_ROLE', '', true
    where auth.role() = 'service_role'
  ),
  selected_run as (
    select r.id
    from public.act_sync_runs r
    where r.dry_run = false
      and r.status = 'COMPLETED'
    order by r.completed_at desc nulls last, r.started_at desc
    limit 1
  ),
  filtered as (
    select
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm,
      greatest(
        coalesce(mf.total_area_planted_ha, mf.effective_area_ha, 0),
        0
      )::numeric as planted_area_ha,
      greatest(
        coalesce(mf.effective_area_ha, mf.total_area_planted_ha, 0),
        0
      )::numeric as raw_effective_area_ha,
      greatest(coalesce(mf.harvested_area_ha, 0), 0)::numeric
        as raw_harvested_area_ha
    from public.master_fields mf
    where coalesce(mf.is_active, true) = true
      and exists (
        select 1
        from viewer_scope scope
        where scope.can_view_all
          or (
            scope.role = 'SPV'
            and public.act_monitor_name_matches(mf.qa_spv, scope.name)
          )
          or (
            scope.role = 'FI'
            and public.act_monitor_name_matches(mf.qa_fi, scope.name)
          )
      )
      and (p_region is null or btrim(mf.region) = p_region)
      and (p_district is null or btrim(mf.district_kab) = p_district)
      and (
        p_owner is null
        or public.act_monitor_name_matches(mf.qa_fi, p_owner)
      )
      and (p_season is null or btrim(mf.season) = p_season)
      and (p_seed_type is null or btrim(mf.type) = p_seed_type)
  ),
  effective as (
    select
      field_number_norm,
      planted_area_ha,
      least(raw_effective_area_ha, planted_area_ha) as effective_area_ha,
      raw_harvested_area_ha
    from filtered
  ),
  safe_areas as (
    select
      field_number_norm,
      planted_area_ha,
      effective_area_ha,
      least(raw_harvested_area_ha, effective_area_ha) as harvested_area_ha
    from effective
  ),
  totals as (
    select
      count(*)::integer as field_count,
      coalesce(round(sum(a.planted_area_ha), 4), 0) as planted_area_ha,
      coalesce(
        round(sum(greatest(a.planted_area_ha - a.effective_area_ha, 0)), 4),
        0
      ) as discard_area_ha,
      coalesce(round(sum(a.effective_area_ha), 4), 0) as effective_area_ha,
      coalesce(round(sum(a.harvested_area_ha), 4), 0) as harvested_area_ha,
      coalesce(
        round(sum(greatest(a.effective_area_ha - a.harvested_area_ha, 0)), 4),
        0
      ) as standing_crop_area_ha,
      count(review.field_number_norm)::integer as harvest_needs_review
    from safe_areas a
    left join public.act_sync_harvest_reviews review
      on review.run_id = (select id from selected_run)
     and review.field_number_norm = a.field_number_norm
     and review.status = 'NEEDS_CONFIRMATION'
  )
  select jsonb_build_object(
    'field_count', t.field_count,
    'planted_area_ha', t.planted_area_ha,
    'discard_area_ha', t.discard_area_ha,
    'effective_area_ha', t.effective_area_ha,
    'harvested_area_ha', t.harvested_area_ha,
    'standing_crop_area_ha', t.standing_crop_area_ha,
    'harvest_needs_review', t.harvest_needs_review
  )
  from totals t;
$$;

revoke all on function public.get_planting_data_monitor_summary(
  text, text, text, text, text
) from public, anon;
grant execute on function public.get_planting_data_monitor_summary(
  text, text, text, text, text
) to authenticated, service_role;

comment on function public.get_planting_data_monitor_summary(
  text, text, text, text, text
) is
  'Returns safe planting-area aggregates restricted server-side to the signed-in account scope.';

create or replace function public.get_planting_data_monitor_options()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with viewer_scope as (
    select
      upper(btrim(u.role)) as role,
      btrim(u.name) as name,
      upper(btrim(u.role)) in ('ADMIN', 'DEV', 'MANAGER') as can_view_all
    from public.app_users u
    where u.id = auth.uid()
      and coalesce(u.is_active, true) = true

    union all

    select 'SERVICE_ROLE', '', true
    where auth.role() = 'service_role'
  ),
  visible_fields as (
    select
      nullif(btrim(mf.region), '') as region,
      nullif(btrim(mf.district_kab), '') as district,
      mf.qa_fi,
      nullif(btrim(mf.season), '') as season,
      nullif(btrim(mf.type), '') as seed_type
    from public.master_fields mf
    where coalesce(mf.is_active, true) = true
      and exists (
        select 1
        from viewer_scope scope
        where scope.can_view_all
          or (
            scope.role = 'SPV'
            and public.act_monitor_name_matches(mf.qa_spv, scope.name)
          )
          or (
            scope.role = 'FI'
            and public.act_monitor_name_matches(mf.qa_fi, scope.name)
          )
      )
  ),
  owners as (
    select distinct nullif(btrim(part), '') as value
    from visible_fields fields
    cross join lateral regexp_split_to_table(
      coalesce(fields.qa_fi, ''),
      '\s*[,;|/&]\s*|\s+(dan|and)\s+',
      'i'
    ) as part
    where nullif(btrim(part), '') is not null
  )
  select jsonb_build_object(
    'regions', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct region as value from visible_fields where region is not null) x
    ), '[]'::jsonb),
    'districts', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct district as value from visible_fields where district is not null) x
    ), '[]'::jsonb),
    'owners', coalesce((
      select jsonb_agg(x.value order by x.value)
      from owners x
      where x.value is not null
    ), '[]'::jsonb),
    'seasons', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct season as value from visible_fields where season is not null) x
    ), '[]'::jsonb),
    'seed_types', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct seed_type as value from visible_fields where seed_type is not null) x
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_planting_data_monitor_options()
  from public, anon;
grant execute on function public.get_planting_data_monitor_options()
  to authenticated, service_role;

comment on function public.get_planting_data_monitor_options() is
  'Returns only filter values that exist inside the signed-in account Data Tanam scope.';
