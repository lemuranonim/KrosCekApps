-- Retain all raw ACT rows. Prefer ACT's explicit Advance status, then a valid
-- existing row containing every populated value from the same-priority rows.
-- Missing planting identity, conflicting values, and cross-crop FN still block.
create or replace function public.act_sync_advance_status(p_raw_payload jsonb)
returns integer
language sql
immutable
set search_path = public
as $$
  select case lower(btrim(coalesce(
    p_raw_payload ->> '_act_advance_status', p_raw_payload ->> 'Advance', ''
  )))
    when '1' then 1 when 'advance' then 1
    when '2' then 2 when 'no advance' then 2
    when '3' then 3 when 'custom advance' then 3
    else null
  end;
$$;

revoke all on function public.act_sync_advance_status(jsonb) from public, anon, authenticated;
grant execute on function public.act_sync_advance_status(jsonb) to service_role;

create or replace function public.act_sync_source_duplicate_choices(p_run_id uuid)
returns table (
  field_number_norm text,
  source_row_count bigint,
  representative_row_id bigint,
  selected_row_id bigint,
  selected_source_type text,
  selected_source_row integer,
  selection_reason text,
  candidate_rows jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  with duplicate_groups as materialized (
    select
      r.field_number_norm,
      count(*) as source_row_count,
      min(r.id) as representative_row_id,
      count(*) filter (where public.act_sync_advance_status(r.raw_payload) = 1) as advance_count,
      count(distinct r.source_type) = 1 and bool_and(
        cardinality(r.validation_errors) = 0
        and nullif(btrim(r.source_payload ->> 'planting_date_pdn'), '') is not null
        and nullif(btrim(r.source_payload ->> 'hybrid'), '') is not null
        and nullif(btrim(r.source_payload ->> 'total_area_planted_ha'), '') is not null
      ) as eligible,
      jsonb_agg(jsonb_build_object(
        'source_type', r.source_type,
        'source_row', r.source_row,
        'act_planting_id', r.raw_payload ->> '_act_planting_id',
        'advance_status', public.act_sync_advance_status(r.raw_payload),
        'row_hash', r.row_hash
      ) order by r.source_type, r.source_row, r.id) as candidate_rows
    from public.act_sync_rows r
    where r.run_id = p_run_id and nullif(r.field_number_norm, '') is not null
    group by r.field_number_norm
    having count(*) > 1
  )
  select
    d.field_number_norm,
    d.source_row_count,
    d.representative_row_id,
    chosen.id,
    chosen.source_type,
    chosen.source_row,
    case when chosen.id is null then 'CONFLICT_OR_IDENTITY_MISSING'
      when d.advance_count > 0 then 'ADVANCE_STATUS'
      else 'MOST_COMPLETE_COMPATIBLE_ROW'
    end,
    d.candidate_rows
  from duplicate_groups d
  left join lateral (
    select candidate.id, candidate.source_type, candidate.source_row
    from public.act_sync_rows candidate
    where d.eligible
      and candidate.run_id = p_run_id
      and candidate.field_number_norm = d.field_number_norm
      and (d.advance_count = 0 or public.act_sync_advance_status(candidate.raw_payload) = 1)
      -- Advance establishes authority within a planting, never identity across
      -- different planting dates, hybrids, areas, or crop sources.
      and not exists (
        select 1 from public.act_sync_rows other
        cross join lateral unnest(array[
          'planting_date_pdn', 'hybrid', 'total_area_planted_ha'
        ]) as identity_fields(field_name)
        where other.run_id = p_run_id
          and other.field_number_norm = d.field_number_norm
          and public.act_master_fields_values_differ(
            field_name, candidate.source_payload -> field_name,
            other.source_payload -> field_name
          )
      )
      and not exists (
        select 1
        from public.act_sync_rows other
        cross join lateral jsonb_each(other.source_payload) entry
        where other.run_id = p_run_id
          and other.field_number_norm = d.field_number_norm
          and (d.advance_count = 0 or public.act_sync_advance_status(other.raw_payload) = 1)
          and nullif(btrim(entry.value #>> '{}'), '') is not null
          and public.act_master_fields_values_differ(
            entry.key, candidate.source_payload -> entry.key, entry.value
          )
      )
    -- Compatible winners contain the same complete set of values. Prefer a
    -- stable source position so retries do not depend on insertion order.
    order by candidate.source_row, candidate.id
    limit 1
  ) chosen on true;
$$;

revoke all on function public.act_sync_source_duplicate_choices(uuid)
  from public, anon, authenticated;
grant execute on function public.act_sync_source_duplicate_choices(uuid) to service_role;

comment on function public.act_sync_source_duplicate_choices(uuid) is
  'Prefers Advance, then a complete compatible existing row for duplicate ACT FN in one planting; retains conflicting, invalid, or unidentified plantings as blockers and never deletes source rows.';


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

  with duplicate_choices as materialized (
    select * from public.act_sync_source_duplicate_choices(p_run_id)
  ),
  source_batch as (
    select r.*, d.source_row_count as duplicate_count, d.selected_row_id
    from public.act_sync_rows r
    left join duplicate_choices d on d.field_number_norm = r.field_number_norm
    where r.run_id = p_run_id
      and r.source_type = p_source_type
      and r.source_row between p_from_row and p_to_row
      and (d.field_number_norm is null
        or r.id = coalesce(d.selected_row_id, d.representative_row_id))
  ),
  compared as (
    select
      r.field_number_norm,
      r.source_type,
      r.source_row,
      r.source_payload,
      r.validation_errors,
      r.duplicate_count,
      r.selected_row_id,
      coalesce(mf.match_count, 0) as current_match_count,
      mf.current_payload,
      coalesce(diff.changed_columns, '{}'::jsonb) as changed_columns,
      coalesce(ins.insert_columns, '{}'::jsonb) as insert_columns
    from source_batch r
    left join lateral (
      select public.act_master_fields_sync_snapshot(current_field) as current_payload,
        count(*) over () as match_count
      from public.master_fields current_field
      where upper(regexp_replace(btrim(current_field.field_number), '[[:space:]]+', '', 'g'))
        = r.field_number_norm
      order by current_field.field_number
      limit 1
    ) mf on true
    left join lateral (
      select jsonb_object_agg(
        entry.key,
        jsonb_build_object(
          'old', mf.current_payload -> entry.key,
          'new', entry.value
        )
      ) as changed_columns
      from jsonb_each(r.source_payload - 'field_number') entry
      where mf.current_payload is not null
        and public.act_master_fields_values_differ(
          entry.key,
          mf.current_payload -> entry.key,
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
        when c.duplicate_count > 1 and c.selected_row_id is null
          then 'CONFLICT_SOURCE_DUPLICATE'
        when c.current_match_count > 1 then 'CONFLICT_KC_DUPLICATE'
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
      case
        when c.duplicate_count > 1 and c.selected_row_id is null
          then array['duplicate_source_values_conflict_or_identity_missing']::text[]
        when c.current_match_count > 1
          then array[format('duplicate_kc_rows:%s', c.current_match_count)]::text[]
        else c.validation_errors
      end as validation_errors
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
  v_effective_source_rows bigint;
  v_current_rows bigint;
  v_insert bigint;
  v_update bigint;
  v_unchanged bigint;
  v_invalid bigint;
  v_source_conflict bigint;
  v_resolved_duplicates bigint;
  v_ignored_duplicate_rows bigint;
  v_duplicate_resolutions jsonb;
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

  select
    count(*) filter (where d.selected_row_id is null),
    count(*) filter (where d.selected_row_id is not null),
    coalesce(sum(d.source_row_count - 1) filter (where d.selected_row_id is not null), 0),
    coalesce(jsonb_agg(jsonb_build_object(
      'field_number', d.field_number_norm,
      'selected_source_type', d.selected_source_type,
      'selected_source_row', d.selected_source_row,
      'reason', d.selection_reason,
      'candidate_rows', d.candidate_rows
    ) order by d.field_number_norm), '[]'::jsonb)
  into v_source_conflict, v_resolved_duplicates, v_ignored_duplicate_rows, v_duplicate_resolutions
  from public.act_sync_source_duplicate_choices(p_run_id) d;

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
  v_effective_source_rows := v_source_rows - v_ignored_duplicate_rows;

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
  v_change_ratio := v_actionable::numeric / greatest(v_effective_source_rows, 1);

  if v_effective_source_rows < v_minimum_rows then
    v_guard_errors := array_append(
      v_guard_errors,
      format('source_rows_below_minimum:%s<%s', v_effective_source_rows, v_minimum_rows)
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
    'source_rows_after_deduplication', v_effective_source_rows,
    'current_rows', v_current_rows,
    'insert', v_insert,
    'update', v_update,
    'unchanged', v_unchanged,
    'invalid', v_invalid,
    'conflict_source_duplicate', v_source_conflict,
    'resolved_source_duplicate', v_resolved_duplicates,
    'ignored_source_duplicate_rows', v_ignored_duplicate_rows,
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
      source_meta = source_meta || jsonb_build_object(
        'source_duplicate_resolutions', v_duplicate_resolutions
      ),
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

-- The synchronous/workbook fallback must use the same selection and guards
-- as the production resumable table path.
create or replace function public.prepare_act_master_fields_sync(p_run_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
set statement_timeout = '120s'
as $$
declare
  v_status text;
  v_source record;
  v_from_row integer;
begin
  select status into v_status from public.act_sync_runs where id = p_run_id for update;
  if not found then
    raise exception 'ACT sync run not found: %', p_run_id;
  end if;
  if v_status <> 'VALIDATING' then
    raise exception 'ACT sync run must be VALIDATING, current status: %', v_status;
  end if;

  delete from public.act_sync_changes where run_id = p_run_id;
  for v_source in
    select source_type, min(source_row) as min_row, max(source_row) as max_row
    from public.act_sync_rows where run_id = p_run_id
    group by source_type order by source_type
  loop
    v_from_row := v_source.min_row;
    while v_from_row <= v_source.max_row loop
      perform public.prepare_act_master_fields_sync_batch(
        p_run_id, v_source.source_type, v_from_row, least(v_from_row + 1999, v_source.max_row)
      );
      v_from_row := v_from_row + 2000;
    end loop;
  end loop;
  return public.finalize_act_master_fields_sync_batches(p_run_id);
end;
$$;

revoke all on function public.prepare_act_master_fields_sync(uuid)
  from public, anon, authenticated;
grant execute on function public.prepare_act_master_fields_sync(uuid) to service_role;


-- Harvest/PLD review upserts also need one representative per FN; otherwise
-- duplicate Planting rows can hit the same review key twice before validation.
create or replace function public.act_sync_reconciliation_rows(p_run_id uuid)
returns setof public.act_sync_rows
language sql
stable
security definer
set search_path = public
as $$
  with choices as materialized (
    select * from public.act_sync_source_duplicate_choices(p_run_id)
  )
  select r.* from public.act_sync_rows r
  left join choices d on d.field_number_norm = r.field_number_norm
  where r.run_id = p_run_id
    and (d.field_number_norm is null
      or r.id = coalesce(d.selected_row_id, d.representative_row_id));
$$;
revoke all on function public.act_sync_reconciliation_rows(uuid) from public, anon, authenticated;
grant execute on function public.act_sync_reconciliation_rows(uuid) to service_role;

create or replace function public.refresh_act_sync_harvest_reviews_for_fields(
  p_run_id uuid,
  p_field_numbers text[]
)
returns bigint
language plpgsql
security definer
set search_path = public
set statement_timeout = '60s'
as $$
declare
  v_review_count bigint := 0;
begin
  if coalesce(cardinality(p_field_numbers), 0) > 0 then
    delete from public.act_sync_harvest_reviews review
    using public.act_sync_reconciliation_rows(p_run_id) r
    where review.run_id = p_run_id
      and r.run_id = review.run_id
      and r.field_number_norm = review.field_number_norm
      and r.field_number_norm = any(p_field_numbers)
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
      least(
        (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric,
        coalesce(
          (r.source_payload ->> 'effective_area_ha')::numeric,
          (r.source_payload ->> 'total_area_planted_ha')::numeric,
          0
        )
      ),
      coalesce((r.raw_payload ->> '_act_harvest_event_count')::integer, 0),
      nullif(r.raw_payload ->> '_act_harvest_last_date', '')::date,
      now()
    from public.act_sync_reconciliation_rows(p_run_id) r
    where r.run_id = p_run_id
      and r.field_number_norm = any(p_field_numbers)
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
  end if;

  select count(*) into v_review_count
  from public.act_sync_harvest_reviews
  where run_id = p_run_id
    and status = 'NEEDS_CONFIRMATION';

  return v_review_count;
end;
$$;

create or replace function public.refresh_act_sync_harvest_reviews(p_run_id uuid)
returns bigint
language sql
security definer
set search_path = public
set statement_timeout = '60s'
as $$
  select public.refresh_act_sync_harvest_reviews_for_fields(p_run_id, array(
    select distinct field_number_norm from public.act_sync_rows
    where run_id = p_run_id and raw_payload ? '_act_harvest_reported_area_ha'
  ));
$$;

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
    join public.act_sync_reconciliation_rows(p_run_id) r
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

  v_review_count := public.refresh_act_sync_harvest_reviews_for_fields(p_run_id, array(
    select distinct upper(regexp_replace(btrim(entry ->> 'field_number_norm'), '[[:space:]]+', '', 'g'))
    from jsonb_array_elements(p_rows) entry
    where nullif(btrim(entry ->> 'field_number_norm'), '') is not null
  ));

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

revoke all on function public.refresh_act_sync_harvest_reviews_for_fields(uuid, text[]) from public, anon, authenticated;
grant execute on function public.refresh_act_sync_harvest_reviews_for_fields(uuid, text[]) to service_role;
revoke all on function public.refresh_act_sync_harvest_reviews(uuid) from public, anon, authenticated;
grant execute on function public.refresh_act_sync_harvest_reviews(uuid) to service_role;
revoke all on function public.merge_act_sync_harvest_page(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.merge_act_sync_harvest_page(uuid, jsonb) to service_role;
