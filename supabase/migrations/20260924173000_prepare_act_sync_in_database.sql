create index if not exists master_fields_field_number_norm_act_idx
  on public.master_fields (
    (upper(regexp_replace(btrim(field_number), '[[:space:]]+', '', 'g')))
  );

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
    when p_field in ('total_area_planted_ha', 'discard_area_ha', 'effective_area_ha') then
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

revoke all on function public.act_master_fields_values_differ(text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.act_master_fields_values_differ(text, jsonb, jsonb)
  to service_role;

create or replace function public.prepare_act_master_fields_sync(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_run public.act_sync_runs%rowtype;
  v_source_rows bigint;
  v_current_rows bigint;
  v_insert bigint;
  v_update bigint;
  v_unchanged bigint;
  v_invalid bigint;
  v_source_conflict bigint;
  v_kc_conflict bigint;
  v_missing bigint;
  v_blockers bigint;
  v_actionable bigint;
  v_minimum_rows integer;
  v_max_change_ratio numeric;
  v_change_ratio numeric;
  v_guard_errors text[] := '{}'::text[];
  v_source text;
  v_blocked boolean;
  v_status text;
  v_summary jsonb;
begin
  select *
  into v_run
  from public.act_sync_runs
  where id = p_run_id
  for update;

  if not found then
    raise exception 'ACT sync run not found: %', p_run_id;
  end if;
  if v_run.status <> 'VALIDATING' then
    raise exception 'ACT sync run must be VALIDATING, current status: %', v_run.status;
  end if;

  delete from public.act_sync_changes where run_id = p_run_id;

  with source_numbered as (
    select
      r.*,
      coalesce(
        nullif(r.field_number_norm, ''),
        format('__INVALID_SOURCE_%s_%s', r.source_type, r.source_row)
      ) as group_key,
      count(*) over (
        partition by coalesce(
          nullif(r.field_number_norm, ''),
          format('__INVALID_SOURCE_%s_%s', r.source_type, r.source_row)
        )
      ) as source_match_count,
      row_number() over (
        partition by coalesce(
          nullif(r.field_number_norm, ''),
          format('__INVALID_SOURCE_%s_%s', r.source_type, r.source_row)
        )
        order by r.id
      ) as source_rank
    from public.act_sync_rows r
    where r.run_id = p_run_id
  ),
  source_first as (
    select * from source_numbered where source_rank = 1
  ),
  kc_numbered as (
    select
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) as field_number_norm,
      public.act_master_fields_sync_snapshot(mf) as current_payload,
      count(*) over (
        partition by upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
      ) as kc_match_count,
      row_number() over (
        partition by upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        order by mf.field_number
      ) as kc_rank
    from public.master_fields mf
    where nullif(btrim(mf.field_number), '') is not null
  ),
  kc_first as (
    select * from kc_numbered where kc_rank = 1
  ),
  compared as (
    select
      s.group_key,
      s.field_number_norm,
      s.source_type,
      s.source_payload,
      s.validation_errors,
      s.source_match_count,
      k.current_payload,
      coalesce(k.kc_match_count, 0) as kc_match_count,
      coalesce(diff.changed_columns, '{}'::jsonb) as changed_columns,
      coalesce(ins.insert_columns, '{}'::jsonb) as insert_columns
    from source_first s
    left join kc_first k
      on k.field_number_norm = s.field_number_norm
    left join lateral (
      select jsonb_object_agg(
        entry.key,
        jsonb_build_object(
          'old', k.current_payload -> entry.key,
          'new', entry.value
        )
      ) as changed_columns
      from jsonb_each(s.source_payload - 'field_number') entry
      where public.act_master_fields_values_differ(
        entry.key,
        k.current_payload -> entry.key,
        entry.value
      )
    ) diff on true
    left join lateral (
      select jsonb_object_agg(
        entry.key,
        jsonb_build_object('old', 'null'::jsonb, 'new', entry.value)
      ) as insert_columns
      from jsonb_each(s.source_payload) entry
    ) ins on true
  ),
  decided as (
    select
      c.*,
      case
        when nullif(c.field_number_norm, '') is null
          or cardinality(c.validation_errors) > 0 then 'INVALID'
        when c.source_match_count > 1 then 'CONFLICT_SOURCE_DUPLICATE'
        when c.kc_match_count > 1 then 'CONFLICT_KC_DUPLICATE'
        when c.current_payload is null then 'INSERT'
        when c.changed_columns <> '{}'::jsonb then 'UPDATE'
        else 'UNCHANGED'
      end as change_kind
    from compared c
  )
  insert into public.act_sync_changes (
    run_id,
    field_number_norm,
    source_type,
    change_kind,
    current_payload,
    source_payload,
    changed_columns,
    validation_errors
  )
  select
    p_run_id,
    case when nullif(d.field_number_norm, '') is null then d.group_key else d.field_number_norm end,
    d.source_type,
    d.change_kind,
    d.current_payload,
    d.source_payload,
    case
      when d.change_kind = 'INSERT' then d.insert_columns
      when d.change_kind = 'UPDATE' then d.changed_columns
      else '{}'::jsonb
    end,
    case
      when d.change_kind = 'INVALID' then d.validation_errors
      when d.change_kind = 'CONFLICT_SOURCE_DUPLICATE'
        then array[format('duplicate_source_rows:%s', d.source_match_count)]
      when d.change_kind = 'CONFLICT_KC_DUPLICATE'
        then array[format('duplicate_kc_rows:%s', d.kc_match_count)]
      else '{}'::text[]
    end
  from decided d;

  with source_present as (
    select distinct field_number_norm
    from public.act_sync_rows
    where run_id = p_run_id
      and nullif(field_number_norm, '') is not null
  ),
  kc_numbered as (
    select
      upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) as field_number_norm,
      public.act_master_fields_sync_snapshot(mf) as current_payload,
      row_number() over (
        partition by upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
        order by mf.field_number
      ) as kc_rank
    from public.master_fields mf
    where nullif(btrim(mf.field_number), '') is not null
  )
  insert into public.act_sync_changes (
    run_id,
    field_number_norm,
    source_type,
    change_kind,
    current_payload,
    source_payload,
    changed_columns,
    validation_errors
  )
  select
    p_run_id,
    k.field_number_norm,
    null,
    'MISSING_SOURCE',
    k.current_payload,
    null,
    '{}'::jsonb,
    '{}'::text[]
  from kc_numbered k
  left join source_present s using (field_number_norm)
  where k.kc_rank = 1
    and s.field_number_norm is null;

  select
    count(*) filter (where change_kind = 'INSERT'),
    count(*) filter (where change_kind = 'UPDATE'),
    count(*) filter (where change_kind = 'UNCHANGED'),
    count(*) filter (where change_kind = 'INVALID'),
    count(*) filter (where change_kind = 'CONFLICT_SOURCE_DUPLICATE'),
    count(*) filter (where change_kind = 'CONFLICT_KC_DUPLICATE'),
    count(*) filter (where change_kind = 'MISSING_SOURCE')
  into
    v_insert,
    v_update,
    v_unchanged,
    v_invalid,
    v_source_conflict,
    v_kc_conflict,
    v_missing
  from public.act_sync_changes
  where run_id = p_run_id;

  select count(*) into v_source_rows
  from public.act_sync_rows where run_id = p_run_id;
  select count(*) into v_current_rows from public.master_fields;

  v_blockers := v_invalid + v_source_conflict + v_kc_conflict;
  v_actionable := v_insert + v_update;
  v_minimum_rows := coalesce(
    (v_run.source_meta -> 'sync_config' ->> 'minimum_rows')::integer,
    1000
  );
  v_max_change_ratio := coalesce(
    (v_run.source_meta -> 'sync_config' ->> 'max_change_ratio')::numeric,
    0.25
  );
  v_change_ratio := v_actionable::numeric / greatest(v_source_rows, 1);

  if v_source_rows < v_minimum_rows then
    v_guard_errors := array_append(
      v_guard_errors,
      format('source_rows_below_minimum:%s<%s', v_source_rows, v_minimum_rows)
    );
  end if;
  foreach v_source in array v_run.requested_sources loop
    if coalesce((v_run.source_counts ->> v_source)::integer, 0) = 0 then
      v_guard_errors := array_append(v_guard_errors, format('empty_source:%s', v_source));
    end if;
  end loop;
  if not v_run.dry_run and v_change_ratio > v_max_change_ratio then
    v_guard_errors := array_append(
      v_guard_errors,
      format('change_ratio_exceeded:%s>%s', round(v_change_ratio, 4), v_max_change_ratio)
    );
  end if;

  v_blocked := v_blockers > 0 or cardinality(v_guard_errors) > 0;
  v_status := case when v_blocked then 'BLOCKED' else 'READY' end;
  v_summary := jsonb_build_object(
    'source_rows', v_source_rows,
    'current_rows', v_current_rows,
    'insert', v_insert,
    'update', v_update,
    'unchanged', v_unchanged,
    'invalid', v_invalid,
    'conflict_source_duplicate', v_source_conflict,
    'conflict_kc_duplicate', v_kc_conflict,
    'missing_source', v_missing,
    'blockers', v_blockers,
    'actionable', v_actionable,
    'source_counts', v_run.source_counts,
    'change_ratio', v_change_ratio,
    'guard_errors', to_jsonb(v_guard_errors)
  );

  update public.act_sync_runs
  set status = v_status,
      summary = v_summary,
      completed_at = case when dry_run or v_blocked then now() else null end
  where id = p_run_id;

  return jsonb_build_object(
    'run_id', p_run_id,
    'status', v_status,
    'dry_run', v_run.dry_run,
    'summary', v_summary
  );
end;
$$;

revoke all on function public.prepare_act_master_fields_sync(uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_act_master_fields_sync(uuid)
  to service_role;

comment on function public.prepare_act_master_fields_sync(uuid) is
  'Builds ACT-versus-KC reconciliation decisions set-wise inside PostgreSQL.';
