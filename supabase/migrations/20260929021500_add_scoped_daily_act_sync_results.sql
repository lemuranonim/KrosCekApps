create index if not exists act_sync_changes_run_field_kind_idx
  on public.act_sync_changes (run_id, field_number_norm, change_kind);

create or replace function public.get_act_sync_scoped_daily_summary(
  p_run_id uuid default null
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
  scoped_changes as (
    select change.*
    from selected_run run
    join public.act_sync_changes change on change.run_id = run.id
    left join lateral (
      select mf.qa_spv, mf.qa_fi
      from public.master_fields mf
      where upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        = change.field_number_norm
      order by mf.field_number
      limit 1
    ) owner on true
    where exists (
      select 1
      from viewer_scope scope
      where scope.can_view_all
        or (
          scope.role = 'SPV'
          and public.act_monitor_name_matches(owner.qa_spv, scope.name)
        )
        or (
          scope.role = 'FI'
          and public.act_monitor_name_matches(owner.qa_fi, scope.name)
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
    'scope_role', coalesce((select role from viewer_scope limit 1), 'NONE'),
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
  'Returns latest completed ACT sync decision totals restricted to the signed-in Manager/Dev/Admin, QA SPV, or FI scope.';

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
  scoped_changes as (
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
      field_data.qa_spv,
      coalesce(safe_changes.value, '{}'::jsonb) as safe_changed_columns,
      coalesce(safe_changes.field_count, 0)::integer as changed_field_count
    from selected_run run
    join public.act_sync_changes change on change.run_id = run.id
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
        = change.field_number_norm
      order by mf.field_number
      limit 1
    ) field_data on true
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
      from jsonb_each(coalesce(change.changed_columns, '{}'::jsonb)) entry
    ) safe_changes on true
    where exists (
      select 1
      from viewer_scope scope
      where scope.can_view_all
        or (
          scope.role = 'SPV'
          and public.act_monitor_name_matches(field_data.qa_spv, scope.name)
        )
        or (
          scope.role = 'FI'
          and public.act_monitor_name_matches(field_data.qa_fi, scope.name)
        )
    )
  ),
  filtered as (
    select change.*
    from scoped_changes change
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
      and (
        nullif(btrim(p_query), '') is null
        or change.field_number ilike '%' || btrim(p_query) || '%'
        or coalesce(change.farmer_name, '') ilike '%' || btrim(p_query) || '%'
        or coalesce(change.hybrid, '') ilike '%' || btrim(p_query) || '%'
        or coalesce(change.region, '') ilike '%' || btrim(p_query) || '%'
        or coalesce(change.district_kab, '') ilike '%' || btrim(p_query) || '%'
        or coalesce(change.village_desa, '') ilike '%' || btrim(p_query) || '%'
      )
  ),
  page as (
    select change.*
    from filtered change
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
      change.field_number
    offset greatest(coalesce(p_offset, 0), 0)
    limit least(greatest(coalesce(p_limit, 20), 1), 50)
  )
  select jsonb_build_object(
    'run_id', (select id from selected_run),
    'total_count', (select count(*) from filtered),
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
      from page item
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
  'Returns a bounded page of latest ACT sync decisions restricted to the signed-in account scope. Source-only invalid rows without ownership metadata remain visible only to all-scope roles.';
