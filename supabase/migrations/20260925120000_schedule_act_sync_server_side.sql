create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

create index if not exists act_sync_runs_source_to_started_idx
  on public.act_sync_runs (source_to, started_at desc)
  where dry_run = false;

create index if not exists act_sync_rows_created_idx
  on public.act_sync_rows (created_at);

create index if not exists act_sync_changes_created_idx
  on public.act_sync_changes (created_at);

create or replace function public.provision_act_sync_cron_service_key(
  p_service_key text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret_id uuid;
begin
  if nullif(p_service_key, '') is null then
    raise exception 'Service key cannot be empty';
  end if;

  select s.id
  into v_secret_id
  from vault.secrets s
  where s.name = 'act_sync_service_role_key'
  order by s.created_at desc
  limit 1;

  if v_secret_id is null then
    select vault.create_secret(
      p_service_key,
      'act_sync_service_role_key',
      'Service credential used only by Supabase Cron to invoke ACT sync'
    )
    into v_secret_id;
  else
    perform vault.update_secret(
      v_secret_id,
      p_service_key,
      'act_sync_service_role_key',
      'Service credential used only by Supabase Cron to invoke ACT sync'
    );
  end if;

  return v_secret_id;
end;
$$;

revoke all on function public.provision_act_sync_cron_service_key(text)
  from public, anon, authenticated;
grant execute on function public.provision_act_sync_cron_service_key(text)
  to service_role;

create or replace function public.dispatch_act_master_fields_sync()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := (clock_timestamp() at time zone 'Asia/Bangkok')::date;
  v_run_id uuid;
  v_status text;
  v_service_key text;
  v_body jsonb;
  v_request_id bigint;
begin
  if not pg_try_advisory_xact_lock(hashtext('act-master-fields-sync-cloud-dispatch')) then
    return null;
  end if;

  select r.id, r.status
  into v_run_id, v_status
  from public.act_sync_runs r
  where r.dry_run = false
    and r.status in ('EXTRACTING', 'WAITING_EXPORT', 'VALIDATING', 'APPLYING')
  order by r.started_at
  limit 1;

  if v_run_id is null then
    select r.id, r.status
    into v_run_id, v_status
    from public.act_sync_runs r
    where r.dry_run = false
      and r.source_to = v_today
    order by r.started_at desc
    limit 1;
  end if;

  if v_run_id is not null and v_status = 'APPLYING' then
    return null;
  end if;

  if v_run_id is not null
    and v_status in ('COMPLETED', 'FAILED', 'BLOCKED', 'READY') then
    return null;
  end if;

  select s.decrypted_secret
  into v_service_key
  from vault.decrypted_secrets s
  where s.name = 'act_sync_service_role_key'
  order by s.created_at desc
  limit 1;

  if nullif(v_service_key, '') is null then
    raise warning 'Vault secret act_sync_service_role_key is missing; ACT sync was not dispatched';
    return null;
  end if;

  if v_run_id is not null then
    v_body := jsonb_build_object('runId', v_run_id);
  else
    v_body := jsonb_build_object(
      'from', make_date(extract(year from v_today)::integer, 1, 1),
      'to', v_today,
      'apply', true,
      'sources', jsonb_build_array('FC', 'PS', 'SC'),
      'exportMode', 'table',
      'minimumRows', 30000,
      'maxChangeRatio', 0.25
    );
  end if;

  select net.http_post(
    url := 'https://crwvenlejfkrouimnxui.supabase.co/functions/v1/act-master-fields-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key,
      'apikey', v_service_key
    ),
    body := v_body,
    timeout_milliseconds := 150000
  )
  into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.dispatch_act_master_fields_sync()
  from public, anon, authenticated;

comment on function public.dispatch_act_master_fields_sync() is
  'Dispatches or resumes one guarded ACT-to-KC production sync step from Supabase Cron.';

create or replace function public.cleanup_act_master_fields_sync_history()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rows_deleted bigint := 0;
  v_changes_deleted bigint := 0;
begin
  delete from public.act_sync_rows sr
  using public.act_sync_runs r
  where r.id = sr.run_id
    and r.status in ('COMPLETED', 'BLOCKED', 'FAILED')
    and coalesce(r.completed_at, r.started_at) < now() - interval '3 days';
  get diagnostics v_rows_deleted = row_count;

  delete from public.act_sync_changes sc
  using public.act_sync_runs r
  where r.id = sc.run_id
    and r.status in ('COMPLETED', 'BLOCKED', 'FAILED')
    and coalesce(r.completed_at, r.started_at) < now() - interval '7 days';
  get diagnostics v_changes_deleted = row_count;

  return jsonb_build_object(
    'staged_rows_deleted', v_rows_deleted,
    'reconciliation_rows_deleted', v_changes_deleted,
    'run_summaries_retained', true,
    'applied_audit_retained', true
  );
end;
$$;

revoke all on function public.cleanup_act_master_fields_sync_history()
  from public, anon, authenticated;

comment on function public.cleanup_act_master_fields_sync_history() is
  'Bounds ACT sync staging storage while retaining run summaries and applied change audit.';

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid
    from cron.job
    where jobname in ('act-master-fields-sync-cloud', 'act-master-fields-sync-cleanup')
  loop
    perform cron.unschedule(v_job_id);
  end loop;

  perform cron.schedule(
    'act-master-fields-sync-cloud',
    '0-59/3 18 * * *',
    'select public.dispatch_act_master_fields_sync();'
  );

  perform cron.schedule(
    'act-master-fields-sync-cleanup',
    '30 19 * * *',
    'select public.cleanup_act_master_fields_sync_history();'
  );
end;
$$;
