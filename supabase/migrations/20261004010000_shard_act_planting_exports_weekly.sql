-- Seven-day Planting/WKT exports create more resumable checkpoints than the
-- former monthly/full-range strategy. Dispatch every minute during the same
-- 01:00-05:59 WIB window so the daily run can still finish before business
-- hours. PLD and Harvest date ranges are intentionally unchanged.

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
    '* 18-22 * * *',
    'select public.dispatch_guarded_act_master_fields_sync();'
  );
end;
$$;
