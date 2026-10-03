create or replace function public.refresh_act_sync_harvest_reviews(
  p_run_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_review_count bigint := 0;
begin
  delete from public.act_sync_harvest_reviews review
  using public.act_sync_rows r
  where review.run_id = p_run_id
    and r.run_id = review.run_id
    and r.field_number_norm = review.field_number_norm
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
  from public.act_sync_rows r
  where r.run_id = p_run_id
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

  select count(*) into v_review_count
  from public.act_sync_harvest_reviews
  where run_id = p_run_id
    and status = 'NEEDS_CONFIRMATION';

  return v_review_count;
end;
$$;

revoke all on function public.refresh_act_sync_harvest_reviews(uuid)
  from public, anon, authenticated;
grant execute on function public.refresh_act_sync_harvest_reviews(uuid)
  to service_role;

create or replace function public.merge_act_sync_pld_page(
  p_run_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_matched bigint;
  v_harvest_review_count bigint := 0;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'PLD page payload must be a JSON array';
  end if;

  with incoming as (
    select
      upper(regexp_replace(btrim(x.field_number_norm), '[[:space:]]+', '', 'g')) as field_number_norm,
      x.approved_at,
      x.source_row,
      x.planted_area_ha,
      x.effective_area_ha,
      x.discard_area_ha
    from jsonb_to_recordset(p_rows) as x(
      field_number_norm text,
      approved_at text,
      source_row integer,
      planted_area_ha numeric,
      effective_area_ha numeric,
      discard_area_ha numeric
    )
    where nullif(btrim(x.field_number_norm), '') is not null
      and x.effective_area_ha is not null
  ),
  final_in_page as (
    select distinct on (field_number_norm) *
    from incoming
    order by field_number_norm, effective_area_ha asc, approved_at desc nulls last, source_row desc
  ),
  normalized as (
    select
      p.*,
      (r.source_payload ->> 'total_area_planted_ha')::numeric as actual_planted_area_ha,
      least(
        greatest(p.effective_area_ha, 0),
        (r.source_payload ->> 'total_area_planted_ha')::numeric
      ) as final_nett_area_ha
    from final_in_page p
    join public.act_sync_rows r
      on r.run_id = p_run_id
     and r.field_number_norm = p.field_number_norm
    where r.source_payload ? 'total_area_planted_ha'
  ),
  updated as (
    update public.act_sync_rows r
    set source_payload = r.source_payload || jsonb_build_object(
          'effective_area_ha', p.final_nett_area_ha,
          'discard_area_ha', greatest(p.actual_planted_area_ha - p.final_nett_area_ha, 0)
        ) || case
          when r.source_payload ? 'harvested_area_ha' then jsonb_build_object(
            'harvested_area_ha', least(
              coalesce((r.source_payload ->> 'harvested_area_ha')::numeric, 0),
              p.final_nett_area_ha
            )
          )
          else '{}'::jsonb
        end,
        raw_payload = r.raw_payload || jsonb_build_object(
          '_act_pld_approved_at', p.approved_at,
          '_act_pld_source_row', p.source_row,
          '_act_pld_nett_area_ha', p.final_nett_area_ha,
          'PLD Transaction Planted Area(Ha)', p.planted_area_ha,
          'PLD Transaction Effective Area(Ha)', p.effective_area_ha,
          'PLD Transaction Discard Area(Ha)', p.discard_area_ha
        ) || case
          when r.raw_payload ? '_act_harvest_reported_area_ha' then jsonb_build_object(
            '_act_harvest_review_status', case
              when (r.raw_payload ->> '_act_harvest_reported_area_ha')::numeric
                > p.final_nett_area_ha + 0.01
              then 'NEEDS_CONFIRMATION'
              else 'VALID'
            end,
            'ACT Harvested Area(Ha)', least(
              coalesce((r.source_payload ->> 'harvested_area_ha')::numeric, 0),
              p.final_nett_area_ha
            )
          )
          else '{}'::jsonb
        end,
        validation_errors = case
          when (p.effective_area_ha < 0 or p.effective_area_ha - p.actual_planted_area_ha > 0.01)
            and not ('pld_nett_outside_actual_planted' = any(r.validation_errors))
          then array_append(r.validation_errors, 'pld_nett_outside_actual_planted')
          else r.validation_errors
        end,
        row_hash = md5((r.source_payload || jsonb_build_object(
          'effective_area_ha', p.final_nett_area_ha,
          'discard_area_ha', greatest(p.actual_planted_area_ha - p.final_nett_area_ha, 0)
        ) || case
          when r.source_payload ? 'harvested_area_ha' then jsonb_build_object(
            'harvested_area_ha', least(
              coalesce((r.source_payload ->> 'harvested_area_ha')::numeric, 0),
              p.final_nett_area_ha
            )
          )
          else '{}'::jsonb
        end)::text)
    from normalized p
    where r.run_id = p_run_id
      and r.field_number_norm = p.field_number_norm
      and (
        not (r.raw_payload ? '_act_pld_nett_area_ha')
        or p.final_nett_area_ha < (r.raw_payload ->> '_act_pld_nett_area_ha')::numeric
        or (
          p.final_nett_area_ha = (r.raw_payload ->> '_act_pld_nett_area_ha')::numeric
          and coalesce(p.approved_at, '') > coalesce(r.raw_payload ->> '_act_pld_approved_at', '')
        )
      )
    returning r.id
  )
  select count(*) into v_matched from updated;

  select public.refresh_act_sync_harvest_reviews(p_run_id)
  into v_harvest_review_count;

  return jsonb_build_object(
    'run_id', p_run_id,
    'matched', v_matched,
    'received', jsonb_array_length(p_rows),
    'harvest_needs_review', v_harvest_review_count
  );
end;
$$;

revoke all on function public.merge_act_sync_pld_page(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_act_sync_pld_page(uuid, jsonb)
  to service_role;

do $$
declare
  v_run_id uuid;
begin
  for v_run_id in
    select distinct run_id from public.act_sync_harvest_reviews
  loop
    perform public.refresh_act_sync_harvest_reviews(v_run_id);
  end loop;
end;
$$;
