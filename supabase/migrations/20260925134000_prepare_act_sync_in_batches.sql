create or replace function public.prepare_act_master_fields_sync_batch(
  p_run_id uuid,
  p_source_type text,
  p_from_row integer,
  p_to_row integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
set statement_timeout = '60s'
as $$
declare
  v_status text;
  v_rows integer := 0;
begin
  select status into v_status
  from public.act_sync_runs
  where id = p_run_id;

  if not found then
    raise exception 'ACT sync run not found: %', p_run_id;
  end if;
  if v_status <> 'VALIDATING' then
    raise exception 'ACT sync run must be VALIDATING, current status: %', v_status;
  end if;
  if p_source_type not in ('FC', 'PS', 'SC') then
    raise exception 'Unsupported ACT source type: %', p_source_type;
  end if;
  if p_from_row < 1 or p_to_row < p_from_row then
    raise exception 'Invalid source row range: %..%', p_from_row, p_to_row;
  end if;

  with source_batch as (
    select r.*
    from public.act_sync_rows r
    where r.run_id = p_run_id
      and r.source_type = p_source_type
      and r.source_row between p_from_row and p_to_row
  ),
  compared as (
    select
      r.field_number_norm,
      r.source_type,
      r.source_row,
      r.source_payload,
      r.validation_errors,
      case
        when mf.field_number is null then null
        else public.act_master_fields_sync_snapshot(mf)
      end as current_payload,
      coalesce(diff.changed_columns, '{}'::jsonb) as changed_columns,
      coalesce(ins.insert_columns, '{}'::jsonb) as insert_columns
    from source_batch r
    left join public.master_fields mf
      on upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) = r.field_number_norm
    left join lateral (
      select jsonb_object_agg(
        entry.key,
        jsonb_build_object(
          'old', public.act_master_fields_sync_snapshot(mf) -> entry.key,
          'new', entry.value
        )
      ) as changed_columns
      from jsonb_each(r.source_payload - 'field_number') entry
      where mf.field_number is not null
        and public.act_master_fields_values_differ(
          entry.key,
          public.act_master_fields_sync_snapshot(mf) -> entry.key,
          entry.value
        )
    ) diff on true
    left join lateral (
      select jsonb_object_agg(
        entry.key,
        jsonb_build_object('old', 'null'::jsonb, 'new', entry.value)
      ) as insert_columns
      from jsonb_each(r.source_payload) entry
    ) ins on true
  ),
  prepared as (
    select
      p_run_id as run_id,
      coalesce(nullif(c.field_number_norm, ''), format('__INVALID_%s_%s', p_source_type, c.source_row))
        as field_number_norm,
      c.source_type,
      case
        when nullif(c.field_number_norm, '') is null
          or cardinality(c.validation_errors) > 0 then 'INVALID'
        when c.current_payload is null then 'INSERT'
        when c.changed_columns <> '{}'::jsonb then 'UPDATE'
        else 'UNCHANGED'
      end as change_kind,
      c.current_payload,
      c.source_payload,
      case
        when c.current_payload is null then c.insert_columns
        when c.changed_columns <> '{}'::jsonb then c.changed_columns
        else '{}'::jsonb
      end as changed_columns,
      c.validation_errors
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
    run_id,
    field_number_norm,
    source_type,
    change_kind,
    current_payload,
    source_payload,
    changed_columns,
    validation_errors
  from prepared
  on conflict (run_id, field_number_norm) do update
  set source_type = excluded.source_type,
      change_kind = excluded.change_kind,
      current_payload = excluded.current_payload,
      source_payload = excluded.source_payload,
      changed_columns = excluded.changed_columns,
      validation_errors = excluded.validation_errors,
      applied = false,
      applied_at = null,
      apply_error = null;

  get diagnostics v_rows = row_count;
  return jsonb_build_object(
    'run_id', p_run_id,
    'source_type', p_source_type,
    'from_row', p_from_row,
    'to_row', p_to_row,
    'prepared_rows', v_rows
  );
end;
$$;

revoke all on function public.prepare_act_master_fields_sync_batch(uuid, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.prepare_act_master_fields_sync_batch(uuid, text, integer, integer)
  to service_role;

create or replace function public.finalize_act_master_fields_sync_batches(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
set statement_timeout = '60s'
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
  v_status text;
  v_summary jsonb;
begin
  select * into v_run
  from public.act_sync_runs
  where id = p_run_id
  for update;

  if not found then
    raise exception 'ACT sync run not found: %', p_run_id;
  end if;
  if v_run.status <> 'VALIDATING' then
    raise exception 'ACT sync run must be VALIDATING, current status: %', v_run.status;
  end if;

  select count(*) into v_source_conflict
  from (
    select field_number_norm
    from public.act_sync_rows
    where run_id = p_run_id
      and nullif(field_number_norm, '') is not null
    group by field_number_norm
    having count(*) > 1
  ) duplicates;

  select count(*) into v_kc_conflict
  from (
    select upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) as field_number_norm
    from public.master_fields mf
    join (
      select distinct field_number_norm
      from public.act_sync_rows
      where run_id = p_run_id
        and nullif(field_number_norm, '') is not null
    ) source
      on source.field_number_norm = upper(
        regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')
      )
    group by upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    having count(*) > 1
  ) duplicates;

  if v_source_conflict > 0 then
    v_guard_errors := array_append(v_guard_errors, format('source_duplicate_fields:%s', v_source_conflict));
  end if;
  if v_kc_conflict > 0 then
    v_guard_errors := array_append(v_guard_errors, format('kc_duplicate_fields:%s', v_kc_conflict));
  end if;

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
    upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')),
    null,
    'MISSING_SOURCE',
    public.act_master_fields_sync_snapshot(mf),
    null,
    '{}'::jsonb,
    '{}'::text[]
  from public.master_fields mf
  where nullif(btrim(mf.field_number), '') is not null
    and not exists (
      select 1
      from public.act_sync_rows r
      where r.run_id = p_run_id
        and r.field_number_norm = upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g'))
    )
  on conflict (run_id, field_number_norm) do nothing;

  select
    count(*) filter (where change_kind = 'INSERT'),
    count(*) filter (where change_kind = 'UPDATE'),
    count(*) filter (where change_kind = 'UNCHANGED'),
    count(*) filter (where change_kind = 'INVALID'),
    count(*) filter (where change_kind = 'MISSING_SOURCE')
  into v_insert, v_update, v_unchanged, v_invalid, v_missing
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

  v_status := case
    when v_blockers > 0 or cardinality(v_guard_errors) > 0 then 'BLOCKED'
    else 'READY'
  end;
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
      error_message = null,
      completed_at = case when dry_run or v_status = 'BLOCKED' then now() else null end
  where id = p_run_id;

  return jsonb_build_object(
    'run_id', p_run_id,
    'status', v_status,
    'dry_run', v_run.dry_run,
    'summary', v_summary
  );
end;
$$;

revoke all on function public.finalize_act_master_fields_sync_batches(uuid)
  from public, anon, authenticated;
grant execute on function public.finalize_act_master_fields_sync_batches(uuid)
  to service_role;

comment on function public.prepare_act_master_fields_sync_batch(uuid, text, integer, integer) is
  'Prepares ACT-versus-KC reconciliation decisions in resumable source-row batches.';
comment on function public.finalize_act_master_fields_sync_batches(uuid) is
  'Finalizes batched ACT reconciliation, inserts missing-source audit rows, and applies guards.';
