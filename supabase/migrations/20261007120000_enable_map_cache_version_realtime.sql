-- Publish the lightweight cache-generation table instead of streaming complete
-- master-field or WKT payloads to every open Home Map.
alter table public.app_cache_versions replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'app_cache_versions'
  ) then
    alter publication supabase_realtime
      add table public.app_cache_versions;
  end if;
end;
$$;

comment on table public.app_cache_versions is
  'Generation counters used to invalidate Redis and device-local map caches; published as lightweight realtime signals.';
