-- Roll back 20260908_qa_resolution_timeout_hotfix_001 from its captured definitions.
begin;
set local lock_timeout='3s';
set local statement_timeout='30s';

do $rollback$
declare
  v_before jsonb;
  v_trigger text;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('qa_resolution_timeout_hotfix',0)) then
    raise exception 'Another QA resolver timeout hotfix is active';
  end if;

  select definitions_before into v_before
  from public.qa_resolver_migrations
  where run_id='20260908_qa_resolution_timeout_hotfix_001'
    and status='installed'
  for update;
  if not found then
    raise exception 'Installed timeout hotfix migration was not found';
  end if;

  execute v_before->>'cache_sync';
  execute v_before->>'refresh';

  drop trigger if exists trigger_auto_fill_empty_qa on public.master_qa_mapping;
  v_trigger:=v_before->>'auto_fill_trigger';
  if nullif(v_trigger,'') is not null then
    execute v_trigger;
  end if;

  update public.qa_resolver_migrations
  set status='rolled_back',
      verification=coalesce(verification,'{}'::jsonb)||jsonb_build_object(
        'rolled_back_at',clock_timestamp()
      )
  where run_id='20260908_qa_resolution_timeout_hotfix_001';
end;
$rollback$;
commit;
