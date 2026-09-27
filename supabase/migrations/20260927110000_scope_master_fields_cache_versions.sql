-- Keep the expensive Map/Coverage cache hot per region. A write in one region
-- must not invalidate every other region, while unscoped FI/SPV requests keep
-- using the global generation for correctness.

create or replace function public.normalize_cache_region(p_region text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(regexp_replace(btrim(coalesce(p_region, '')), '[[:space:]]+', ' ', 'g'));
$$;

revoke all on function public.normalize_cache_region(text)
  from public, anon, authenticated;

create or replace function public.bump_master_fields_cache_regions(p_regions text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_region text;
begin
  insert into public.app_cache_versions (namespace, version, updated_at)
  values ('master_fields_map', 1, now())
  on conflict (namespace) do update
    set version = public.app_cache_versions.version + 1,
        updated_at = excluded.updated_at;

  foreach v_region in array coalesce(p_regions, array[]::text[])
  loop
    v_region := public.normalize_cache_region(v_region);
    if v_region <> '' then
      insert into public.app_cache_versions (namespace, version, updated_at)
      values ('master_fields_map:region:' || v_region, 1, now())
      on conflict (namespace) do update
        set version = public.app_cache_versions.version + 1,
            updated_at = excluded.updated_at;
    end if;
  end loop;
end;
$$;

revoke all on function public.bump_master_fields_cache_regions(text[])
  from public, anon, authenticated;

-- Seed existing regions at the current global generation. This guarantees a
-- regional lookup never accidentally treats old cache data as current.
insert into public.app_cache_versions (namespace, version, updated_at)
select
  'master_fields_map:region:' || public.normalize_cache_region(mf.region),
  global_version.version,
  now()
from (
  select distinct region
  from public.master_fields
  where nullif(btrim(region), '') is not null
) mf
cross join lateral (
  select version
  from public.app_cache_versions
  where namespace = 'master_fields_map'
) global_version
on conflict (namespace) do nothing;

create or replace function public.bump_master_fields_cache_from_master_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_regions text[];
begin
  if tg_op = 'INSERT' then
    select array_agg(distinct region) into v_regions from new_rows;
  elsif tg_op = 'DELETE' then
    select array_agg(distinct region) into v_regions from old_rows;
  else
    select array_agg(distinct region) into v_regions
    from (
      select region from new_rows
      union
      select region from old_rows
    ) changed;
  end if;

  perform public.bump_master_fields_cache_regions(v_regions);
  return null;
end;
$$;

create or replace function public.bump_master_fields_cache_from_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_regions text[];
begin
  if tg_op = 'INSERT' then
    select array_agg(distinct mf.region) into v_regions
    from new_rows changed
    join public.master_fields mf on mf.field_number = changed.field_number;
  elsif tg_op = 'DELETE' then
    select array_agg(distinct mf.region) into v_regions
    from old_rows changed
    join public.master_fields mf on mf.field_number = changed.field_number;
  else
    select array_agg(distinct mf.region) into v_regions
    from (
      select field_number from new_rows
      union
      select field_number from old_rows
    ) changed
    join public.master_fields mf on mf.field_number = changed.field_number;
  end if;

  perform public.bump_master_fields_cache_regions(v_regions);
  return null;
end;
$$;

create or replace function public.bump_all_master_fields_cache_versions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.app_cache_versions
  set version = version + 1,
      updated_at = now()
  where namespace = 'master_fields_map'
     or namespace like 'master_fields_map:region:%';
  return null;
end;
$$;

revoke all on function public.bump_master_fields_cache_from_master_fields()
  from public, anon, authenticated;
revoke all on function public.bump_master_fields_cache_from_audit()
  from public, anon, authenticated;
revoke all on function public.bump_all_master_fields_cache_versions()
  from public, anon, authenticated;

do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'master_fields',
    'audit_vegetative',
    'audit_generative',
    'audit_pre_harvest',
    'audit_harvest'
  ]
  loop
    execute format(
      'drop trigger if exists %I on public.%I',
      'bump_map_cache_version_' || relation_name,
      relation_name
    );
    execute format('drop trigger if exists %I on public.%I', 'bump_cache_insert_' || relation_name, relation_name);
    execute format('drop trigger if exists %I on public.%I', 'bump_cache_update_' || relation_name, relation_name);
    execute format('drop trigger if exists %I on public.%I', 'bump_cache_delete_' || relation_name, relation_name);
    execute format('drop trigger if exists %I on public.%I', 'bump_cache_truncate_' || relation_name, relation_name);

    if relation_name = 'master_fields' then
      execute format(
        'create trigger %I after insert on public.%I referencing new table as new_rows for each statement execute function public.bump_master_fields_cache_from_master_fields()',
        'bump_cache_insert_' || relation_name,
        relation_name
      );
      execute format(
        'create trigger %I after update on public.%I referencing old table as old_rows new table as new_rows for each statement execute function public.bump_master_fields_cache_from_master_fields()',
        'bump_cache_update_' || relation_name,
        relation_name
      );
      execute format(
        'create trigger %I after delete on public.%I referencing old table as old_rows for each statement execute function public.bump_master_fields_cache_from_master_fields()',
        'bump_cache_delete_' || relation_name,
        relation_name
      );
    else
      execute format(
        'create trigger %I after insert on public.%I referencing new table as new_rows for each statement execute function public.bump_master_fields_cache_from_audit()',
        'bump_cache_insert_' || relation_name,
        relation_name
      );
      execute format(
        'create trigger %I after update on public.%I referencing old table as old_rows new table as new_rows for each statement execute function public.bump_master_fields_cache_from_audit()',
        'bump_cache_update_' || relation_name,
        relation_name
      );
      execute format(
        'create trigger %I after delete on public.%I referencing old table as old_rows for each statement execute function public.bump_master_fields_cache_from_audit()',
        'bump_cache_delete_' || relation_name,
        relation_name
      );
    end if;

    execute format(
      'create trigger %I after truncate on public.%I for each statement execute function public.bump_all_master_fields_cache_versions()',
      'bump_cache_truncate_' || relation_name,
      relation_name
    );
  end loop;
end;
$$;

comment on function public.bump_master_fields_cache_regions(text[]) is
  'Invalidates global and only the affected regional Map/Coverage generations.';
