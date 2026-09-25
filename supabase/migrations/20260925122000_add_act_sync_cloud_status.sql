create or replace function public.act_master_fields_sync_cloud_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'timezone', 'Asia/Bangkok',
    'vault_secret_configured', exists (
      select 1
      from vault.secrets s
      where s.name = 'act_sync_service_role_key'
    ),
    'jobs', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'job_id', j.jobid,
          'name', j.jobname,
          'schedule_utc', j.schedule,
          'active', j.active
        )
        order by j.jobname
      )
      from cron.job j
      where j.jobname in (
        'act-master-fields-sync-cloud',
        'act-master-fields-sync-cleanup'
      )
    ), '[]'::jsonb),
    'latest_run', (
      select jsonb_build_object(
        'run_id', r.id,
        'status', r.status,
        'dry_run', r.dry_run,
        'source_from', r.source_from,
        'source_to', r.source_to,
        'source_counts', r.source_counts,
        'summary', r.summary,
        'error_message', r.error_message,
        'started_at', r.started_at,
        'completed_at', r.completed_at
      )
      from public.act_sync_runs r
      order by r.started_at desc
      limit 1
    )
  );
$$;

revoke all on function public.act_master_fields_sync_cloud_status()
  from public, anon, authenticated;
grant execute on function public.act_master_fields_sync_cloud_status()
  to service_role;

comment on function public.act_master_fields_sync_cloud_status() is
  'Service-only health summary for ACT sync Cron, Vault configuration, and latest run.';
