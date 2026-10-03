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
  with selected_run as (
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
      and (p_region is null or btrim(mf.region) = p_region)
      and (p_district is null or btrim(mf.district_kab) = p_district)
      and (
        p_owner is null
        or coalesce(
          nullif(btrim(mf.qa_fi), ''),
          nullif(btrim(mf.fa), '')
        ) = p_owner
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
  'Returns safe aggregate planting, PLD, effective, harvested, and remaining standing-crop areas for Data Tanam Monitor.';

create or replace function public.get_planting_data_monitor_options()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with active_fields as (
    select
      nullif(btrim(mf.region), '') as region,
      nullif(btrim(mf.district_kab), '') as district,
      coalesce(
        nullif(btrim(mf.qa_fi), ''),
        nullif(btrim(mf.fa), '')
      ) as owner,
      nullif(btrim(mf.season), '') as season,
      nullif(btrim(mf.type), '') as seed_type
    from public.master_fields mf
    where coalesce(mf.is_active, true) = true
  )
  select jsonb_build_object(
    'regions', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct region as value from active_fields where region is not null) x
    ), '[]'::jsonb),
    'districts', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct district as value from active_fields where district is not null) x
    ), '[]'::jsonb),
    'owners', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct owner as value from active_fields where owner is not null) x
    ), '[]'::jsonb),
    'seasons', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct season as value from active_fields where season is not null) x
    ), '[]'::jsonb),
    'seed_types', coalesce((
      select jsonb_agg(x.value order by x.value)
      from (select distinct seed_type as value from active_fields where seed_type is not null) x
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_planting_data_monitor_options()
  from public, anon;
grant execute on function public.get_planting_data_monitor_options()
  to authenticated, service_role;

comment on function public.get_planting_data_monitor_options() is
  'Returns bounded filter dimensions for Data Tanam Monitor without exposing master_fields rows.';
