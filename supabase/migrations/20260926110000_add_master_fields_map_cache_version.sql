create table if not exists public.app_cache_versions (
  namespace text primary key,
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

insert into public.app_cache_versions (namespace, version)
values ('master_fields_map', 1)
on conflict (namespace) do nothing;

alter table public.app_cache_versions enable row level security;

drop policy if exists "Authenticated users can read cache versions"
  on public.app_cache_versions;

create policy "Authenticated users can read cache versions"
  on public.app_cache_versions
  for select
  to authenticated
  using (true);

create or replace function public.bump_master_fields_map_cache_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.app_cache_versions (namespace, version, updated_at)
  values ('master_fields_map', 1, now())
  on conflict (namespace) do update
    set version = public.app_cache_versions.version + 1,
        updated_at = excluded.updated_at;
  return null;
end;
$$;

revoke all on function public.bump_master_fields_map_cache_version()
  from public, anon, authenticated;

do $$
declare
  relation_name text;
  trigger_name text;
begin
  foreach relation_name in array array[
    'master_fields',
    'audit_vegetative',
    'audit_generative',
    'audit_pre_harvest',
    'audit_harvest'
  ]
  loop
    trigger_name := 'bump_map_cache_version_' || relation_name;
    execute format(
      'drop trigger if exists %I on public.%I',
      trigger_name,
      relation_name
    );
    execute format(
      'create trigger %I after insert or update or delete or truncate on public.%I for each statement execute function public.bump_master_fields_map_cache_version()',
      trigger_name,
      relation_name
    );
  end loop;
end;
$$;

comment on table public.app_cache_versions is
  'Generation counters used to invalidate external caches without serving stale records.';

comment on function public.bump_master_fields_map_cache_version() is
  'Invalidates cached map payloads after master field or audit writes.';
