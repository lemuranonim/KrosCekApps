-- Canonical Sweet Corn ownership rules.
--
-- ACT exposes a generic/misaligned planting region for many SC fields (for
-- example "Swc", Region 4, or Region 5). KC owns the operational Zona and
-- QA SPV assignment, so normalize it before reconciliation and guard the
-- canonical master_fields row as well.

create or replace function public.resolve_sweet_corn_area_assignment(
  p_hybrid text,
  p_district text
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
begin
  if v_hybrid not in ('AX01', 'AX02', 'AX03', 'AX04') then
    return '{}'::jsonb;
  end if;

  if v_district ~ '(^| )(JOMBANG|NGANJUK|KEDIRI)( |$)' then
    return jsonb_build_object(
      'region', 'Zona 3',
      'qa_spv', 'Adityan Gutsa Marwaka'
    );
  end if;

  if v_district ~ '(^| )(MALANG|PASURUAN)( |$)' then
    return jsonb_build_object(
      'region', 'Zona 2',
      'qa_spv', 'Heru Agustrio Wibowo'
    );
  end if;

  if v_district ~ '(^| )BLITAR( |$)' then
    return jsonb_build_object(
      'region', 'Zona 4',
      'qa_spv', 'Krisna Bagus Andrian'
    );
  end if;

  return '{}'::jsonb;
end;
$$;

revoke all on function public.resolve_sweet_corn_area_assignment(text, text)
  from public, anon, authenticated;
grant execute on function public.resolve_sweet_corn_area_assignment(text, text)
  to service_role;

create or replace function public.normalize_act_sync_sweet_corn_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment jsonb;
begin
  v_assignment := public.resolve_sweet_corn_area_assignment(
    new.source_payload ->> 'hybrid',
    new.source_payload ->> 'district_kab'
  );

  if v_assignment ? 'region' then
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

revoke all on function public.normalize_act_sync_sweet_corn_assignment()
  from public, anon, authenticated;

drop trigger if exists normalize_act_sync_sweet_corn_assignment
  on public.act_sync_rows;
create trigger normalize_act_sync_sweet_corn_assignment
before insert or update of source_payload on public.act_sync_rows
for each row
execute function public.normalize_act_sync_sweet_corn_assignment();

create or replace function public.enforce_master_field_sweet_corn_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment jsonb;
begin
  v_assignment := public.resolve_sweet_corn_area_assignment(
    new.hybrid,
    new.district_kab
  );

  if v_assignment ? 'region' then
    new.region := v_assignment ->> 'region';
    new.qa_spv := v_assignment ->> 'qa_spv';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_master_field_sweet_corn_assignment()
  from public, anon, authenticated;

drop trigger if exists enforce_master_field_sweet_corn_assignment
  on public.master_fields;
create trigger enforce_master_field_sweet_corn_assignment
before insert or update on public.master_fields
for each row
execute function public.enforce_master_field_sweet_corn_assignment();

-- Backfill only rows covered by the approved hybrid + district rule. The
-- explicit values also make this migration idempotent and auditable.
update public.master_fields mf
set
  region = public.resolve_sweet_corn_area_assignment(
    mf.hybrid,
    mf.district_kab
  ) ->> 'region',
  qa_spv = public.resolve_sweet_corn_area_assignment(
    mf.hybrid,
    mf.district_kab
  ) ->> 'qa_spv'
where public.resolve_sweet_corn_area_assignment(
    mf.hybrid,
    mf.district_kab
  ) ? 'region'
  and (
    mf.region is distinct from (
      public.resolve_sweet_corn_area_assignment(mf.hybrid, mf.district_kab) ->> 'region'
    )
    or mf.qa_spv is distinct from (
      public.resolve_sweet_corn_area_assignment(mf.hybrid, mf.district_kab) ->> 'qa_spv'
    )
  );

-- Fail the migration if a future edit breaks an approved rule.
do $$
begin
  if public.resolve_sweet_corn_area_assignment('AX01', 'Kabupaten Malang')
      <> jsonb_build_object('region', 'Zona 2', 'qa_spv', 'Heru Agustrio Wibowo') then
    raise exception 'Sweet Corn Zona 2 rule verification failed';
  end if;

  if public.resolve_sweet_corn_area_assignment('AX02', 'Kabupaten Nganjuk')
      <> jsonb_build_object('region', 'Zona 3', 'qa_spv', 'Adityan Gutsa Marwaka') then
    raise exception 'Sweet Corn Zona 3 rule verification failed';
  end if;

  if public.resolve_sweet_corn_area_assignment('AX04', 'KABUPATEN BLITAR')
      <> jsonb_build_object('region', 'Zona 4', 'qa_spv', 'Krisna Bagus Andrian') then
    raise exception 'Sweet Corn Zona 4 rule verification failed';
  end if;

  if public.resolve_sweet_corn_area_assignment('ADV01', 'Kabupaten Blitar')
      <> '{}'::jsonb then
    raise exception 'Non-Sweet-Corn hybrid must remain outside the assignment rule';
  end if;
end;
$$;

comment on function public.resolve_sweet_corn_area_assignment(text, text) is
  'Returns KC Zona and dedicated QA SPV for AX01-AX04 based on the approved district rules.';
comment on function public.normalize_act_sync_sweet_corn_assignment() is
  'Normalizes raw ACT Sweet Corn region before reconciliation so subsequent syncs remain stable.';
comment on function public.enforce_master_field_sweet_corn_assignment() is
  'Keeps master_fields Region and QA SPV canonical for approved AX01-AX04 district assignments.';
