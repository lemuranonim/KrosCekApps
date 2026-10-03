-- Keep the daily ACT monitor responsive while a large sync is running.
-- The previous functions performed one master_fields lookup and expanded the
-- changed_columns JSON for every decision row before pagination.

create index if not exists act_sync_runs_completed_latest_idx
  on public.act_sync_runs (completed_at desc nulls last, started_at desc)
  where dry_run = false and status = 'COMPLETED';

create or replace function public.get_act_sync_scoped_daily_summary(
  p_run_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with viewer_scope as materialized (
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
  scope as materialized (
    select *
    from viewer_scope
    limit 1
  ),
  selected_run as materialized (
    select r.*
    from public.act_sync_runs r
    where r.id = coalesce(
      p_run_id,
      (
        select latest.id
        from public.act_sync_runs latest
        where latest.dry_run = false
          and latest.status = 'COMPLETED'
        order by latest.completed_at desc nulls last, latest.started_at desc
        limit 1
      )
    )
      and r.dry_run = false
      and r.status = 'COMPLETED'
    limit 1
  ),
  field_owners as materialized (
    select distinct on (
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    )
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm,
      mf.qa_spv,
      mf.qa_fi
    from public.master_fields mf
    cross join scope s
    where not s.can_view_all
    order by
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')),
      mf.field_number
  ),
  scoped_changes as materialized (
    select change.change_kind, change.applied
    from selected_run run
    join public.act_sync_changes change on change.run_id = run.id
    join scope s on s.can_view_all

    union all

    select change.change_kind, change.applied
    from selected_run run
    join public.act_sync_changes change on change.run_id = run.id
    join field_owners owner
      on owner.field_number_norm = change.field_number_norm
    cross join scope s
    where not s.can_view_all
      and (
        (
          s.role = 'SPV'
          and public.act_monitor_name_matches(owner.qa_spv, s.name)
        )
        or (
          s.role = 'FI'
          and public.act_monitor_name_matches(owner.qa_fi, s.name)
        )
      )
  ),
  totals as (
    select
      count(*)::integer as total_rows,
      count(*) filter (where change_kind = 'INSERT')::integer as inserted_rows,
      count(*) filter (where change_kind = 'UPDATE')::integer as updated_rows,
      count(*) filter (where change_kind = 'UNCHANGED')::integer as unchanged_rows,
      count(*) filter (where change_kind = 'MISSING_SOURCE')::integer
        as missing_source_rows,
      count(*) filter (where change_kind = 'INVALID')::integer as invalid_rows,
      count(*) filter (
        where change_kind in (
          'CONFLICT_SOURCE_DUPLICATE',
          'CONFLICT_KC_DUPLICATE'
        )
      )::integer as conflict_rows,
      count(*) filter (where change_kind <> 'UNCHANGED')::integer as changed_rows,
      count(*) filter (where applied)::integer as applied_rows
    from scoped_changes
  )
  select jsonb_build_object(
    'run_id', run.id,
    'status', run.status,
    'source_from', run.source_from,
    'source_to', run.source_to,
    'started_at', run.started_at,
    'completed_at', run.completed_at,
    'scope_role', coalesce((select role from scope), 'NONE'),
    'total_rows', coalesce(totals.total_rows, 0),
    'inserted_rows', coalesce(totals.inserted_rows, 0),
    'updated_rows', coalesce(totals.updated_rows, 0),
    'unchanged_rows', coalesce(totals.unchanged_rows, 0),
    'missing_source_rows', coalesce(totals.missing_source_rows, 0),
    'invalid_rows', coalesce(totals.invalid_rows, 0),
    'conflict_rows', coalesce(totals.conflict_rows, 0),
    'changed_rows', coalesce(totals.changed_rows, 0),
    'applied_rows', coalesce(totals.applied_rows, 0)
  )
  from selected_run run
  cross join totals;
$$;

revoke all on function public.get_act_sync_scoped_daily_summary(uuid)
  from public, anon;
grant execute on function public.get_act_sync_scoped_daily_summary(uuid)
  to authenticated, service_role;

comment on function public.get_act_sync_scoped_daily_summary(uuid) is
  'Returns indexed latest ACT sync totals for the signed-in account scope without per-change field lookups.';

create or replace function public.get_act_sync_scoped_daily_changes(
  p_run_id uuid default null,
  p_category text default 'CHANGED',
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
  with viewer_scope as materialized (
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
  scope as materialized (
    select *
    from viewer_scope
    limit 1
  ),
  selected_run as materialized (
    select r.*
    from public.act_sync_runs r
    where r.id = coalesce(
      p_run_id,
      (
        select latest.id
        from public.act_sync_runs latest
        where latest.dry_run = false
          and latest.status = 'COMPLETED'
        order by latest.completed_at desc nulls last, latest.started_at desc
        limit 1
      )
    )
      and r.dry_run = false
      and r.status = 'COMPLETED'
    limit 1
  ),
  visible_field_numbers as materialized (
    select distinct on (
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    )
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm
    from public.master_fields mf
    cross join scope s
    where not s.can_view_all
      and (
        (
          s.role = 'SPV'
          and public.act_monitor_name_matches(mf.qa_spv, s.name)
        )
        or (
          s.role = 'FI'
          and public.act_monitor_name_matches(mf.qa_fi, s.name)
        )
      )
    order by
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')),
      mf.field_number
  ),
  authorized_changes as materialized (
    select
      change.id,
      change.change_kind,
      change.field_number_norm
    from selected_run run
    join public.act_sync_changes change on change.run_id = run.id
    join scope s on s.can_view_all

    union all

    select
      change.id,
      change.change_kind,
      change.field_number_norm
    from selected_run run
    join public.act_sync_changes change on change.run_id = run.id
    join visible_field_numbers visible
      on visible.field_number_norm = change.field_number_norm
  ),
  categorized_changes as materialized (
    select change.*
    from authorized_changes change
    where case upper(coalesce(nullif(btrim(p_category), ''), 'CHANGED'))
      when 'ALL' then true
      when 'INSERT' then change.change_kind = 'INSERT'
      when 'UPDATE' then change.change_kind = 'UPDATE'
      when 'UNCHANGED' then change.change_kind = 'UNCHANGED'
      when 'ISSUE' then change.change_kind in (
        'INVALID',
        'CONFLICT_SOURCE_DUPLICATE',
        'CONFLICT_KC_DUPLICATE',
        'MISSING_SOURCE'
      )
      else change.change_kind <> 'UNCHANGED'
    end
  ),
  search_field_data as materialized (
    select distinct on (
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    )
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        as field_number_norm,
      mf.field_number,
      mf.farmer_name,
      mf.hybrid,
      mf.region,
      mf.district_kab,
      mf.village_desa
    from public.master_fields mf
    where nullif(btrim(p_query), '') is not null
    order by
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')),
      mf.field_number
  ),
  filtered_ids as materialized (
    select change.*
    from categorized_changes change
    where nullif(btrim(p_query), '') is null

    union all

    select change.*
    from categorized_changes change
    join public.act_sync_changes payload on payload.id = change.id
    left join search_field_data field_data
      on field_data.field_number_norm = change.field_number_norm
    where nullif(btrim(p_query), '') is not null
      and (
        coalesce(field_data.field_number, change.field_number_norm)
          ilike '%' || btrim(p_query) || '%'
        or coalesce(
          nullif(btrim(field_data.farmer_name), ''),
          nullif(btrim(payload.source_payload ->> 'farmer_name'), ''),
          nullif(btrim(payload.current_payload ->> 'farmer_name'), ''),
          ''
        ) ilike '%' || btrim(p_query) || '%'
        or coalesce(
          nullif(btrim(field_data.hybrid), ''),
          nullif(btrim(payload.source_payload ->> 'hybrid'), ''),
          nullif(btrim(payload.current_payload ->> 'hybrid'), ''),
          ''
        ) ilike '%' || btrim(p_query) || '%'
        or coalesce(
          nullif(btrim(field_data.region), ''),
          nullif(btrim(payload.source_payload ->> 'region'), ''),
          nullif(btrim(payload.current_payload ->> 'region'), ''),
          ''
        ) ilike '%' || btrim(p_query) || '%'
        or coalesce(
          nullif(btrim(field_data.district_kab), ''),
          nullif(btrim(payload.source_payload ->> 'district_kab'), ''),
          nullif(btrim(payload.current_payload ->> 'district_kab'), ''),
          ''
        ) ilike '%' || btrim(p_query) || '%'
        or coalesce(
          nullif(btrim(field_data.village_desa), ''),
          nullif(btrim(payload.source_payload ->> 'village_desa'), ''),
          nullif(btrim(payload.current_payload ->> 'village_desa'), ''),
          ''
        ) ilike '%' || btrim(p_query) || '%'
      )
  ),
  page_ids as materialized (
    select change.*
    from filtered_ids change
    order by
      case change.change_kind
        when 'INVALID' then 0
        when 'CONFLICT_SOURCE_DUPLICATE' then 1
        when 'CONFLICT_KC_DUPLICATE' then 2
        when 'MISSING_SOURCE' then 3
        when 'INSERT' then 4
        when 'UPDATE' then 5
        else 6
      end,
      change.field_number_norm
    offset greatest(coalesce(p_offset, 0), 0)
    limit least(greatest(coalesce(p_limit, 20), 1), 50)
  ),
  page as materialized (
    select
      change.*,
      coalesce(
        nullif(btrim(field_data.field_number), ''),
        change.field_number_norm
      ) as field_number,
      coalesce(
        nullif(btrim(field_data.farmer_name), ''),
        nullif(btrim(change.source_payload ->> 'farmer_name'), ''),
        nullif(btrim(change.current_payload ->> 'farmer_name'), '')
      ) as farmer_name,
      coalesce(
        nullif(btrim(field_data.hybrid), ''),
        nullif(btrim(change.source_payload ->> 'hybrid'), ''),
        nullif(btrim(change.current_payload ->> 'hybrid'), '')
      ) as hybrid,
      coalesce(
        nullif(btrim(field_data.region), ''),
        nullif(btrim(change.source_payload ->> 'region'), ''),
        nullif(btrim(change.current_payload ->> 'region'), '')
      ) as region,
      coalesce(
        nullif(btrim(field_data.district_kab), ''),
        nullif(btrim(change.source_payload ->> 'district_kab'), ''),
        nullif(btrim(change.current_payload ->> 'district_kab'), '')
      ) as district_kab,
      coalesce(
        nullif(btrim(field_data.village_desa), ''),
        nullif(btrim(change.source_payload ->> 'village_desa'), ''),
        nullif(btrim(change.current_payload ->> 'village_desa'), '')
      ) as village_desa,
      field_data.qa_fi,
      field_data.qa_spv
    from page_ids page_id
    join public.act_sync_changes change on change.id = page_id.id
    left join lateral (
      select
        mf.field_number,
        mf.farmer_name,
        mf.hybrid,
        mf.region,
        mf.district_kab,
        mf.village_desa,
        mf.qa_fi,
        mf.qa_spv
      from public.master_fields mf
      where upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        = page_id.field_number_norm
      order by mf.field_number
      limit 1
    ) field_data on true
  ),
  page_with_safe_changes as (
    select
      item.*,
      coalesce(safe_changes.value, '{}'::jsonb) as safe_changed_columns,
      coalesce(safe_changes.field_count, 0)::integer as changed_field_count
    from page item
    left join lateral (
      select
        jsonb_object_agg(
          entry.key,
          case
            when entry.key in ('geometry_wkt', 'correction_geometry_wkt') then
              jsonb_build_object(
                'old', case
                  when entry.value -> 'old' is null
                    or entry.value -> 'old' = 'null'::jsonb then 'Belum ada'
                  else 'Geometry sebelumnya'
                end,
                'new', case
                  when entry.value -> 'new' is null
                    or entry.value -> 'new' = 'null'::jsonb then 'Dikosongkan'
                  else 'Geometry ACT terbaru'
                end
              )
            else entry.value
          end
          order by entry.key
        ) as value,
        count(*) as field_count
      from jsonb_each(coalesce(item.changed_columns, '{}'::jsonb)) entry
    ) safe_changes on true
  )
  select jsonb_build_object(
    'run_id', (select id from selected_run),
    'total_count', (select count(*) from filtered_ids),
    'offset', greatest(coalesce(p_offset, 0), 0),
    'limit', least(greatest(coalesce(p_limit, 20), 1), 50),
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'field_number', item.field_number,
          'change_kind', item.change_kind,
          'source_type', item.source_type,
          'applied', item.applied,
          'applied_at', item.applied_at,
          'farmer_name', item.farmer_name,
          'hybrid', item.hybrid,
          'region', item.region,
          'district_kab', item.district_kab,
          'village_desa', item.village_desa,
          'qa_fi', item.qa_fi,
          'qa_spv', item.qa_spv,
          'changed_field_count', item.changed_field_count,
          'changed_columns', item.safe_changed_columns,
          'validation_errors', to_jsonb(item.validation_errors),
          'apply_error', item.apply_error
        )
        order by
          case item.change_kind
            when 'INVALID' then 0
            when 'CONFLICT_SOURCE_DUPLICATE' then 1
            when 'CONFLICT_KC_DUPLICATE' then 2
            when 'MISSING_SOURCE' then 3
            when 'INSERT' then 4
            when 'UPDATE' then 5
            else 6
          end,
          item.field_number
      )
      from page_with_safe_changes item
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_act_sync_scoped_daily_changes(
  uuid, text, text, integer, integer
) from public, anon;
grant execute on function public.get_act_sync_scoped_daily_changes(
  uuid, text, text, integer, integer
) to authenticated, service_role;

comment on function public.get_act_sync_scoped_daily_changes(
  uuid, text, text, integer, integer
) is
  'Returns a bounded latest ACT sync decision page using set-based ownership lookup and post-pagination JSON expansion.';
