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
  ),
  latest_in_page as (
    select distinct on (field_number_norm) *
    from incoming
    order by field_number_norm, approved_at desc nulls last, source_row
  ),
  updated as (
    update public.act_sync_rows r
    set source_payload = r.source_payload || jsonb_strip_nulls(jsonb_build_object(
          'total_area_planted_ha', p.planted_area_ha,
          'effective_area_ha', p.effective_area_ha,
          'discard_area_ha', p.discard_area_ha
        )),
        raw_payload = r.raw_payload || jsonb_build_object(
          '_act_pld_approved_at', p.approved_at,
          '_act_pld_source_row', p.source_row,
          'PLD Planted Area(Ha)', p.planted_area_ha,
          'PLD Effective Area(Ha)', p.effective_area_ha,
          'PLD Discard Area(Ha)', p.discard_area_ha
        ),
        validation_errors = case
          when p.planted_area_ha is not null
            and p.effective_area_ha is not null
            and p.discard_area_ha is not null
            and abs(p.planted_area_ha - p.effective_area_ha - p.discard_area_ha) > 0.01
            and not ('area_reconciliation_mismatch' = any(r.validation_errors))
          then array_append(r.validation_errors, 'area_reconciliation_mismatch')
          else r.validation_errors
        end
    from latest_in_page p
    where r.run_id = p_run_id
      and r.field_number_norm = p.field_number_norm
      and not (r.raw_payload ? '_act_pld_approved_at')
    returning r.id
  )
  select count(*) into v_matched from updated;

  return jsonb_build_object(
    'run_id', p_run_id,
    'matched', v_matched,
    'received', jsonb_array_length(p_rows)
  );
end;
$$;

revoke all on function public.merge_act_sync_pld_page(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_act_sync_pld_page(uuid, jsonb)
  to service_role;

comment on function public.merge_act_sync_pld_page(uuid, jsonb) is
  'Overlays latest final ACT PLD planted/effective/discard areas onto staged Planting rows.';
