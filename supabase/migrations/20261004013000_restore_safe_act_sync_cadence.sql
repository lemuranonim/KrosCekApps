-- pg_net starts Edge requests asynchronously, so a one-minute schedule can
-- overlap a still-running invocation. Keep the guarded production dispatcher
-- at its safe three-minute cadence; the Edge checkpoint itself now processes
-- up to three ready seven-day Planting/WKT shards.

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
