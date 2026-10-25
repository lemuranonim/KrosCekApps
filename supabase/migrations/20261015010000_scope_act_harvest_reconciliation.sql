-- Fix Harvest/PLD timeouts introduced by the unscoped set-returning source
-- helper. Resolve duplicates only for the FN in this checkpoint, return IDs,
-- then fetch JSON for those rows by primary key. Keep Advance and identity
-- guards unchanged; do not raise the timeout or skip Harvest validation.
create or replace function public.act_sync_source_duplicate_choices_for_fields(p_run_id uuid, p_field_numbers text[])
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
  with duplicate_keys as materialized (
    -- Identify duplicate FN using the (run_id, field_number_norm) index before
    -- touching any large/TOASTed source_payload or raw_payload JSON documents.
    select r.field_number_norm
    from public.act_sync_rows r
    where r.run_id = p_run_id and nullif(r.field_number_norm, '') is not null
      and (p_field_numbers is null or r.field_number_norm = any(p_field_numbers))
    group by r.field_number_norm
    having count(*) > 1
  ),
  duplicate_groups as materialized (
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
    from duplicate_keys k
    join public.act_sync_rows r
      on r.run_id = p_run_id and r.field_number_norm = k.field_number_norm
    group by r.field_number_norm
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

-- Return lightweight IDs, never full JSON rows, so callers cannot materialize
-- the entire season's polygons before applying their affected-FN predicate.
create or replace function public.act_sync_reconciliation_row_ids(
  p_run_id uuid, p_field_numbers text[]
)
returns table (source_row_id bigint, field_number_norm text)
language sql
stable
security definer
set search_path = public
as $$
  with choices as materialized (
    select * from public.act_sync_source_duplicate_choices_for_fields(p_run_id, p_field_numbers)
  )
  select r.id, r.field_number_norm
  from public.act_sync_rows r
  left join choices d on d.field_number_norm = r.field_number_norm
  where r.run_id = p_run_id
    and (p_field_numbers is null or r.field_number_norm = any(p_field_numbers))
    and (d.field_number_norm is null
      or r.id = coalesce(d.selected_row_id, d.representative_row_id));
$$;

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
    using public.act_sync_reconciliation_row_ids(p_run_id, p_field_numbers) chosen,
      public.act_sync_rows r
    where r.id = chosen.source_row_id
      and review.run_id = p_run_id
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
    from public.act_sync_reconciliation_row_ids(p_run_id, p_field_numbers) chosen
    join public.act_sync_rows r on r.id = chosen.source_row_id
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
  v_affected_fields text[] := '{}'::text[];
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'Harvest page payload must be a JSON array';
  end if;
  v_received := jsonb_array_length(p_rows);
  select coalesce(array_agg(distinct upper(
    regexp_replace(btrim(entry ->> 'field_number_norm'), '[[:space:]]+', '', 'g')
  )), '{}'::text[]) into v_affected_fields
  from jsonb_array_elements(p_rows) entry
  where nullif(btrim(entry ->> 'field_number_norm'), '') is not null;

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
  selected_rows as materialized (
    select * from public.act_sync_reconciliation_row_ids(p_run_id, v_affected_fields)
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
    join selected_rows chosen on chosen.field_number_norm = a.field_number_norm
    join public.act_sync_rows r on r.id = chosen.source_row_id
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

  v_review_count := public.refresh_act_sync_harvest_reviews_for_fields(p_run_id, v_affected_fields);

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

revoke all on function public.act_sync_source_duplicate_choices_for_fields(uuid, text[]) from public, anon, authenticated;
grant execute on function public.act_sync_source_duplicate_choices_for_fields(uuid, text[]) to service_role;
revoke all on function public.act_sync_reconciliation_row_ids(uuid, text[]) from public, anon, authenticated;
grant execute on function public.act_sync_reconciliation_row_ids(uuid, text[]) to service_role;
revoke all on function public.refresh_act_sync_harvest_reviews_for_fields(uuid, text[]) from public, anon, authenticated;
grant execute on function public.refresh_act_sync_harvest_reviews_for_fields(uuid, text[]) to service_role;
revoke all on function public.merge_act_sync_harvest_page(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.merge_act_sync_harvest_page(uuid, jsonb) to service_role;
