-- Client profile and release configuration must never be writable using a
-- public key or a regular user session. Display names currently determine QA
-- scope, so self-service name changes also require an administrative workflow.
begin;
set local lock_timeout = '2s';
set local statement_timeout = '15s';

alter table public.app_users enable row level security;
alter table public.app_config enable row level security;

revoke all privileges on table public.app_users, public.app_config
  from public, anon, authenticated;

-- Remove explicit column grants too; table REVOKE alone does not remove them.
do $$
declare relation_name text; columns_sql text;
begin
  foreach relation_name in array array['app_users', 'app_config'] loop
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum)
      into columns_sql
    from pg_attribute a
    where a.attrelid = format('public.%I', relation_name)::regclass
      and a.attnum > 0 and not a.attisdropped;
    execute format('revoke all privileges (%s) on table public.%I from public, anon, authenticated',
                   columns_sql, relation_name);
  end loop;
end;
$$;

grant select on table public.app_users to authenticated;
grant select on table public.app_config to anon, authenticated;
grant all privileges on table public.app_users, public.app_config to service_role;

drop policy if exists client_read_own_profile on public.app_users;
create policy client_read_own_profile on public.app_users
  for select to authenticated using (id = (select auth.uid()));

-- Keep isolation even if an older permissive policy exists or a future
-- migration grants additional client operations by mistake.
drop policy if exists client_profile_identity_boundary on public.app_users;
create policy client_profile_identity_boundary on public.app_users
  as restrictive for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists client_read_release_config on public.app_config;
create policy client_read_release_config on public.app_config
  for select to anon, authenticated using (id = 'kroscek');

-- Existing permissive policies must not re-open writes later.
drop policy if exists client_release_config_boundary on public.app_config;
create policy client_release_config_boundary on public.app_config
  as restrictive for all to anon, authenticated
  using (id = 'kroscek') with check (false);

commit;
