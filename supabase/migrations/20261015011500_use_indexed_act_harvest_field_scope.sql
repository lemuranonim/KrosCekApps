-- Scoped Harvest helpers always receive an explicit FN list. Avoid the
-- nullable wildcard OR: generic function plans otherwise scan the full run
-- and evaluate a 2,000-element array for every staged row. A null or empty
-- list must select no fields, never the whole season.
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
      and r.field_number_norm = any(p_field_numbers)
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
    and r.field_number_norm = any(p_field_numbers)
    and (d.field_number_norm is null
      or r.id = coalesce(d.selected_row_id, d.representative_row_id));
$$;
