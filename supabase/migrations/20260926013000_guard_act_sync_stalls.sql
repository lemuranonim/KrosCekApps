alter table public.act_sync_runs
  add column if not exists progress_at timestamptz not null default now();

update public.act_sync_runs
set progress_at = coalesce(completed_at, started_at)
where status in ('COMPLETED', 'BLOCKED', 'FAILED', 'READY');

create index if not exists act_sync_runs_active_progress_idx
  on public.act_sync_runs (progress_at)
  where status in ('EXTRACTING', 'WAITING_EXPORT', 'VALIDATING', 'APPLYING');

create or replace function public.fail_stalled_act_master_fields_sync()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_failed integer := 0;
begin
  update public.act_sync_runs r
  set status = 'FAILED',
      error_message = format(
        'ACT sync watchdog: no successful checkpoint for more than 60 minutes (last progress %s).',
        r.progress_at
      ),
      completed_at = clock_timestamp()
  where r.status in ('EXTRACTING', 'WAITING_EXPORT', 'VALIDATING', 'APPLYING')
    and r.progress_at < clock_timestamp() - interval '60 minutes';

  get diagnostics v_failed = row_count;
  return v_failed;
end;
$$;

revoke all on function public.fail_stalled_act_master_fields_sync()
  from public, anon, authenticated;
grant execute on function public.fail_stalled_act_master_fields_sync()
  to service_role;

comment on function public.fail_stalled_act_master_fields_sync() is
  'Marks an ACT sync FAILED when no resumable checkpoint has succeeded for 60 minutes.';

create or replace function public.dispatch_guarded_act_master_fields_sync()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.fail_stalled_act_master_fields_sync();
  return public.dispatch_act_master_fields_sync();
end;
$$;

revoke all on function public.dispatch_guarded_act_master_fields_sync()
  from public, anon, authenticated;

comment on function public.dispatch_guarded_act_master_fields_sync() is
  'Runs the stalled-sync watchdog, then dispatches or resumes one ACT sync checkpoint.';

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
    'select public.dispatch_guarded_act_master_fields_sync();'
  );
end;
$$;
