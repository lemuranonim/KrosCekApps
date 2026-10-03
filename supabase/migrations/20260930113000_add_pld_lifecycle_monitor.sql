-- Role-scoped PLD lifecycle monitoring for Data Tanam Monitor.
-- Counts are based on unique field numbers, while phase details remain
-- available in the paginated drill-down.

create index if not exists audit_pld_lifecycle_field_norm_idx
  on public.audit_pld_lifecycle (
    upper(regexp_replace(btrim(field_number), '[[:space:]]+', '', 'g'))
  );

create or replace function public.get_planting_pld_lifecycle_summary(
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
  visible_fields as (
    select distinct on (
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    )
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm
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
    order by
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')),
      mf.field_number
  ),
  lifecycle_by_field as (
    select
      upper(regexp_replace(btrim(lifecycle.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm,
      case
        when bool_or(lifecycle.status = 'PENDING') then 'PENDING'
        when bool_or(lifecycle.status = 'CONFIRMED') then 'CONFIRMED'
        else 'UPDATED'
      end as lifecycle_status,
      count(*)::integer as phase_count,
      bool_or(lifecycle.recommended_by is not null) as has_recommender
    from public.audit_pld_lifecycle lifecycle
    join visible_fields visible
      on visible.field_number_norm = upper(
        regexp_replace(btrim(lifecycle.field_number), '[[:space:]]+', '', 'g')
      )
    group by upper(
      regexp_replace(btrim(lifecycle.field_number), '[[:space:]]+', '', 'g')
    )
  ),
  totals as (
    select
      count(*)::integer as total_recommended_fn,
      count(*) filter (
        where lifecycle_status in ('PENDING', 'CONFIRMED')
      )::integer as active_recommended_fn,
      count(*) filter (where lifecycle_status = 'PENDING')::integer as pending_fn,
      count(*) filter (where lifecycle_status = 'CONFIRMED')::integer as confirmed_fn,
      count(*) filter (where lifecycle_status = 'UPDATED')::integer as updated_fn,
      coalesce(sum(phase_count), 0)::integer as phase_rows,
      count(*) filter (where not has_recommender)::integer as historical_fn
    from lifecycle_by_field
  )
  select jsonb_build_object(
    'total_recommended_fn', totals.total_recommended_fn,
    'active_recommended_fn', totals.active_recommended_fn,
    'pending_fn', totals.pending_fn,
    'confirmed_fn', totals.confirmed_fn,
    'updated_fn', totals.updated_fn,
    'phase_rows', totals.phase_rows,
    'historical_fn', totals.historical_fn,
    'confirmation_rate', case
      when totals.active_recommended_fn = 0 then 0
      else round(
        totals.confirmed_fn::numeric * 100 / totals.active_recommended_fn,
        1
      )
    end
  )
  from totals;
$$;

revoke all on function public.get_planting_pld_lifecycle_summary(
  text, text, text, text, text
) from public, anon;
grant execute on function public.get_planting_pld_lifecycle_summary(
  text, text, text, text, text
) to authenticated, service_role;

create or replace function public.get_planting_pld_lifecycle_items(
  p_region text default null,
  p_district text default null,
  p_owner text default null,
  p_season text default null,
  p_seed_type text default null,
  p_status text default 'ALL',
  p_query text default null,
  p_offset integer default 0,
  p_limit integer default 20
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
  visible_fields as (
    select distinct on (
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    )
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm,
      mf.field_number,
      mf.farmer_name,
      mf.grower,
      mf.hybrid,
      mf.total_area_planted_ha,
      mf.effective_area_ha,
      greatest(
        coalesce(mf.total_area_planted_ha, mf.effective_area_ha, 0)
          - coalesce(mf.effective_area_ha, 0),
        0
      )::numeric as discard_area_ha,
      mf.region,
      mf.district_kab,
      mf.sub_district_kec,
      mf.village_desa,
      mf.qa_fi,
      mf.qa_spv,
      mf.fa,
      mf.season,
      mf.type
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
    order by
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')),
      mf.field_number
  ),
  lifecycle_by_field as (
    select
      visible.*,
      case
        when bool_or(lifecycle.status = 'PENDING') then 'PENDING'
        when bool_or(lifecycle.status = 'CONFIRMED') then 'CONFIRMED'
        else 'UPDATED'
      end as lifecycle_status,
      count(*)::integer as phase_count,
      min(lifecycle.recommended_at) as recommended_at,
      max(lifecycle.confirmed_at) as confirmed_at,
      max(lifecycle.revised_at) as revised_at,
      (
        array_agg(
          lifecycle.confirmed_run_id::text
          order by lifecycle.confirmed_at desc nulls last
        ) filter (where lifecycle.confirmed_run_id is not null)
      )[1] as confirmed_run_id,
      string_agg(
        distinct nullif(btrim(recommender.name), ''),
        ', '
      ) filter (where nullif(btrim(recommender.name), '') is not null)
        as recommender_names,
      bool_and(lifecycle.recommended_by is null) as historical_only,
      jsonb_agg(
        jsonb_build_object(
          'phase_key', lifecycle.phase_key,
          'status', lifecycle.status,
          'recommended_flagging', lifecycle.recommended_flagging,
          'active_flagging', lifecycle.active_flagging,
          'recommended_at', lifecycle.recommended_at,
          'confirmed_at', lifecycle.confirmed_at,
          'revised_at', lifecycle.revised_at
        )
        order by case lifecycle.phase_key
          when 'vegetative' then 1
          when 'generative_1' then 2
          when 'generative_2' then 3
          when 'generative_3' then 4
          when 'generative_4' then 5
          when 'generative_5' then 6
          when 'pre_harvest' then 7
          when 'harvest' then 8
          else 9
        end
      ) as phases
    from visible_fields visible
    join public.audit_pld_lifecycle lifecycle
      on upper(regexp_replace(btrim(lifecycle.field_number), '[[:space:]]+', '', 'g'))
        = visible.field_number_norm
    left join public.app_users recommender
      on recommender.id = lifecycle.recommended_by
    group by
      visible.field_number_norm,
      visible.field_number,
      visible.farmer_name,
      visible.grower,
      visible.hybrid,
      visible.total_area_planted_ha,
      visible.effective_area_ha,
      visible.discard_area_ha,
      visible.region,
      visible.district_kab,
      visible.sub_district_kec,
      visible.village_desa,
      visible.qa_fi,
      visible.qa_spv,
      visible.fa,
      visible.season,
      visible.type
  ),
  filtered as (
    select item.*
    from lifecycle_by_field item
    where (
      upper(coalesce(nullif(btrim(p_status), ''), 'ALL')) = 'ALL'
      or item.lifecycle_status = upper(btrim(p_status))
    )
      and (
        nullif(btrim(p_query), '') is null
        or concat_ws(
          ' ',
          item.field_number,
          item.farmer_name,
          item.grower,
          item.hybrid,
          item.village_desa,
          item.sub_district_kec,
          item.district_kab,
          item.region,
          item.qa_fi,
          item.qa_spv,
          item.fa
        ) ilike '%' || btrim(p_query) || '%'
      )
  ),
  page as (
    select item.*
    from filtered item
    order by
      case item.lifecycle_status
        when 'PENDING' then 1
        when 'CONFIRMED' then 2
        else 3
      end,
      item.recommended_at desc nulls last,
      item.field_number_norm
    offset greatest(coalesce(p_offset, 0), 0)
    limit least(greatest(coalesce(p_limit, 20), 1), 50)
  )
  select jsonb_build_object(
    'total_count', (select count(*)::integer from filtered),
    'offset', greatest(coalesce(p_offset, 0), 0),
    'limit', least(greatest(coalesce(p_limit, 20), 1), 50),
    'status', upper(coalesce(nullif(btrim(p_status), ''), 'ALL')),
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'field_number', item.field_number,
          'status', item.lifecycle_status,
          'phase_count', item.phase_count,
          'farmer_name', item.farmer_name,
          'grower', item.grower,
          'hybrid', item.hybrid,
          'total_area_planted_ha', item.total_area_planted_ha,
          'discard_area_ha', item.discard_area_ha,
          'effective_area_ha', item.effective_area_ha,
          'region', item.region,
          'district_kab', item.district_kab,
          'sub_district_kec', item.sub_district_kec,
          'village_desa', item.village_desa,
          'qa_fi', item.qa_fi,
          'qa_spv', item.qa_spv,
          'fa', item.fa,
          'season', item.season,
          'type', item.type,
          'recommended_at', item.recommended_at,
          'confirmed_at', item.confirmed_at,
          'revised_at', item.revised_at,
          'confirmed_run_id', item.confirmed_run_id,
          'recommender_names', item.recommender_names,
          'historical_only', item.historical_only,
          'phases', item.phases
        )
        order by
          case item.lifecycle_status
            when 'PENDING' then 1
            when 'CONFIRMED' then 2
            else 3
          end,
          item.recommended_at desc nulls last,
          item.field_number_norm
      )
      from page item
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_planting_pld_lifecycle_items(
  text, text, text, text, text, text, text, integer, integer
) from public, anon;
grant execute on function public.get_planting_pld_lifecycle_items(
  text, text, text, text, text, text, text, integer, integer
) to authenticated, service_role;

comment on function public.get_planting_pld_lifecycle_summary(
  text, text, text, text, text
) is
  'Returns unique-FN PLD audit recommendation progress scoped to the signed-in account and Data Tanam filters.';

comment on function public.get_planting_pld_lifecycle_items(
  text, text, text, text, text, text, text, integer, integer
) is
  'Returns a role-scoped paginated PLD lifecycle drill-down for Data Tanam Monitor.';
