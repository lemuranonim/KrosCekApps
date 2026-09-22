select jsonb_build_object(
  'migration_status',(select status from public.qa_resolver_migrations
    where run_id='20260908_qa_resolution_timeout_hotfix_001'),
  'mapping_rows',(select count(*) from public.master_qa_mapping),
  'cache_rows',(select count(*) from public.qa_resolution_cache),
  'stale_rows',(select count(*) from public.qa_resolution_cache where is_stale),
  'missing_rows',(select count(*) from public.master_fields f
    where coalesce(f.is_active,true) and not exists(
      select 1 from public.qa_resolution_cache c
      where c.field_number=f.field_number::text
    )),
  'legacy_auto_fill_trigger_exists',exists(
    select 1 from pg_trigger
    where tgrelid='public.master_qa_mapping'::regclass
      and tgname='trigger_auto_fill_empty_qa' and not tgisinternal
  ),
  'mapping_stale_trigger_exists',exists(
    select 1 from pg_trigger
    where tgrelid='public.master_qa_mapping'::regclass
      and tgname='qa_resolution_cache_mark_mapping_stale' and not tgisinternal
  ),
  'cache_sync_is_deferred',position(
    'is_stale=true' in pg_get_functiondef(
      'public.qa_resolution_cache_sync_field_trigger()'::regprocedure
    )
  )>0,
  'refresh_is_set_based',position(
    'resolved_batch' in pg_get_functiondef(
      'public.refresh_qa_resolution_cache(integer)'::regprocedure
    )
  )>0,
  'latest_mapping_ids',(
    select jsonb_agg(id order by id)
    from public.master_qa_mapping where id in (20935,20936,20937)
  )
) as postcheck;
