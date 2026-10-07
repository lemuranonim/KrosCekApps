-- Keep Parent Seed hybrids visible in region/season-scoped KC views even when
-- the ACT PS export omits planting_region and season.

create or replace function public.resolve_parent_seed_scope(
  p_hybrid text,
  p_district text,
  p_planting_date date
)
returns jsonb
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  v_hybrid text := upper(btrim(coalesce(p_hybrid, '')));
  v_district text := upper(
    btrim(
      regexp_replace(
        coalesce(p_district, ''),
        '[^[:alnum:]]+',
        ' ',
        'g'
      )
    )
  );
  v_season_date date;
  v_result jsonb := '{}'::jsonb;
begin
  if v_hybrid not like 'AS%' then
    return v_result;
  end if;

  if v_district ~ '(^| )MALANG( |$)' then
    v_result := v_result || jsonb_build_object('region', 'West');
  elsif v_district ~ '(^| )(JEMBER|BANYUWANGI)( |$)' then
    v_result := v_result || jsonb_build_object('region', 'East');
  end if;

  if p_planting_date is not null then
    v_season_date := case
      when extract(month from p_planting_date) >= 3 then p_planting_date
      else (p_planting_date - interval '1 year')::date
    end;
    v_result := v_result || jsonb_build_object(
      'season',
      'DS' || to_char(v_season_date, 'YY')
    );
  end if;

  return v_result;
end;
$$;

revoke all on function public.resolve_parent_seed_scope(text, text, date)
  from public, anon, authenticated;
grant execute on function public.resolve_parent_seed_scope(text, text, date)
  to service_role;

create or replace function public.normalize_act_sync_parent_seed_region()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment jsonb;
begin
  v_assignment := public.resolve_parent_seed_scope(
    new.source_payload ->> 'hybrid',
    new.source_payload ->> 'district_kab',
    nullif(new.source_payload ->> 'planting_date_pdn', '')::date
  );

  if nullif(btrim(new.source_payload ->> 'region'), '') is null
      and v_assignment ? 'region' then
    new.source_payload := jsonb_set(
      coalesce(new.source_payload, '{}'::jsonb),
      '{region}',
      to_jsonb(v_assignment ->> 'region'),
      true
    );
  end if;

  return new;
end;
$$;

revoke all on function public.normalize_act_sync_parent_seed_region()
  from public, anon, authenticated;

drop trigger if exists normalize_act_sync_parent_seed_region
  on public.act_sync_rows;
create trigger normalize_act_sync_parent_seed_region
before insert or update of source_payload on public.act_sync_rows
for each row
execute function public.normalize_act_sync_parent_seed_region();

create or replace function public.fill_master_field_parent_seed_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment jsonb;
begin
  v_assignment := public.resolve_parent_seed_scope(
    new.hybrid,
    new.district_kab,
    new.planting_date_pdn
  );

  if nullif(btrim(new.region), '') is null and v_assignment ? 'region' then
    new.region := v_assignment ->> 'region';
  end if;
  if nullif(btrim(new.season), '') is null and v_assignment ? 'season' then
    new.season := v_assignment ->> 'season';
  end if;

  return new;
end;
$$;

revoke all on function public.fill_master_field_parent_seed_scope()
  from public, anon, authenticated;

drop trigger if exists fill_master_field_parent_seed_scope
  on public.master_fields;
create trigger fill_master_field_parent_seed_scope
before insert or update on public.master_fields
for each row
execute function public.fill_master_field_parent_seed_scope();

with resolved as (
  select
    mf.ctid as row_id,
    public.resolve_parent_seed_scope(
      mf.hybrid,
      mf.district_kab,
      mf.planting_date_pdn
    ) as assignment
  from public.master_fields mf
  where mf.is_active is true
    and upper(btrim(coalesce(mf.hybrid, ''))) like 'AS%'
)
update public.master_fields mf
set
  region = case
    when nullif(btrim(mf.region), '') is null
      and resolved.assignment ? 'region'
      then resolved.assignment ->> 'region'
    else mf.region
  end,
  season = case
    when nullif(btrim(mf.season), '') is null
      and resolved.assignment ? 'season'
      then resolved.assignment ->> 'season'
    else mf.season
  end
from resolved
where mf.ctid = resolved.row_id
  and (
    (
      nullif(btrim(mf.region), '') is null
      and resolved.assignment ? 'region'
    )
    or (
      nullif(btrim(mf.season), '') is null
      and resolved.assignment ? 'season'
    )
  );

do $$
declare
  v_missing_region integer;
  v_missing_season integer;
begin
  if public.resolve_parent_seed_scope(
      'ASF8',
      'Kabupaten Malang',
      date '2026-08-01'
    ) <> jsonb_build_object('region', 'West', 'season', 'DS26') then
    raise exception 'Parent Seed West/DS26 rule verification failed';
  end if;

  if public.resolve_parent_seed_scope(
      'ASS2',
      'Kabupaten Jember',
      date '2027-01-15'
    ) <> jsonb_build_object('region', 'East', 'season', 'DS26') then
    raise exception 'Parent Seed East/season-boundary rule verification failed';
  end if;

  if public.resolve_parent_seed_scope(
      'ADV01',
      'Kabupaten Malang',
      date '2026-08-01'
    ) <> '{}'::jsonb then
    raise exception 'Non-Parent-Seed hybrid must remain outside the scope rule';
  end if;

  select count(*)
  into v_missing_region
  from public.master_fields mf
  where mf.is_active is true
    and upper(btrim(coalesce(mf.hybrid, ''))) like 'AS%'
    and nullif(btrim(mf.region), '') is null
    and public.resolve_parent_seed_scope(
      mf.hybrid,
      mf.district_kab,
      mf.planting_date_pdn
    ) ? 'region';

  select count(*)
  into v_missing_season
  from public.master_fields mf
  where mf.is_active is true
    and upper(btrim(coalesce(mf.hybrid, ''))) like 'AS%'
    and mf.planting_date_pdn is not null
    and nullif(btrim(mf.season), '') is null;

  if v_missing_region <> 0 then
    raise exception 'Parent Seed region backfill incomplete: % rows', v_missing_region;
  end if;
  if v_missing_season <> 0 then
    raise exception 'Parent Seed season backfill incomplete: % rows', v_missing_season;
  end if;
end;
$$;

comment on function public.resolve_parent_seed_scope(text, text, date) is
  'Derives fallback East/West region and DS season for AS* Parent Seed hybrids when ACT omits them.';
comment on function public.normalize_act_sync_parent_seed_region() is
  'Adds an approved fallback region to ACT PS staging rows without overwriting a supplied region.';
comment on function public.fill_master_field_parent_seed_scope() is
  'Fills missing region and season for AS* master fields while preserving explicit values.';
