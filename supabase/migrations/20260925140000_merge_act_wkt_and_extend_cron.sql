create or replace function public.merge_act_sync_geometry_page(
  p_run_id uuid,
  p_source_type text,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
set statement_timeout = '60s'
as $$
declare
  v_input integer := 0;
  v_matched integer := 0;
begin
  if p_source_type not in ('FC', 'PS', 'SC') then
    raise exception 'Unsupported ACT source type: %', p_source_type;
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'ACT WKT page payload must be a JSON array';
  end if;

  v_input := jsonb_array_length(p_rows);

  with payload as (
    select
      upper(regexp_replace(btrim(value ->> 'field_number_norm'), '[[:space:]]+', '', 'g'))
        as field_number_norm,
      nullif(btrim(value ->> 'geometry_wkt'), '') as geometry_wkt
    from jsonb_array_elements(p_rows)
  ),
  updated as (
    update public.act_sync_rows r
    set source_payload = r.source_payload || jsonb_build_object('geometry_wkt', p.geometry_wkt),
        raw_payload = r.raw_payload || jsonb_build_object('Geometry WKT', p.geometry_wkt),
        row_hash = md5(
          (r.source_payload || jsonb_build_object('geometry_wkt', p.geometry_wkt))::text
        )
    from payload p
    where r.run_id = p_run_id
      and r.source_type = p_source_type
      and r.field_number_norm = p.field_number_norm
      and p.geometry_wkt is not null
    returning r.id
  )
  select count(*) into v_matched from updated;

  return jsonb_build_object(
    'input', v_input,
    'matched', v_matched,
    'unmatched', greatest(v_input - v_matched, 0)
  );
end;
$$;

revoke all on function public.merge_act_sync_geometry_page(uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.merge_act_sync_geometry_page(uuid, text, jsonb)
  to service_role;

comment on function public.merge_act_sync_geometry_page(uuid, text, jsonb) is
  'Overlays non-empty ACT Geometry WKT values onto staged Planting rows in resumable batches.';

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname = 'act-master-fields-sync-cloud'
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'act-master-fields-sync-cloud',
    '0-59/3 18-22 * * *',
    'select public.dispatch_act_master_fields_sync();'
  );
end;
$$;
