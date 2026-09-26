create or replace function public.apply_act_master_fields_sync(
  p_run_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
set statement_timeout = '120s'
as $$
declare
  v_run public.act_sync_runs%rowtype;
  v_inserted integer := 0;
  v_updated integer := 0;
begin
  select *
  into v_run
  from public.act_sync_runs
  where id = p_run_id
  for update;

  if not found then
    raise exception 'ACT sync run not found: %', p_run_id;
  end if;
  if v_run.dry_run then
    raise exception 'Dry-run cannot be applied: %', p_run_id;
  end if;
  if v_run.status <> 'READY' then
    raise exception 'ACT sync run must be READY, current status: %', v_run.status;
  end if;
  if exists (
    select 1
    from public.act_sync_changes
    where run_id = p_run_id
      and change_kind in ('INVALID', 'CONFLICT_SOURCE_DUPLICATE', 'CONFLICT_KC_DUPLICATE')
  ) then
    raise exception 'ACT sync run contains blocking validation errors: %', p_run_id;
  end if;
  if exists (
    select 1
    from public.act_sync_changes c
    left join public.master_fields mf
      on upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) = c.field_number_norm
    where c.run_id = p_run_id
      and c.change_kind = 'UPDATE'
      and mf.field_number is null
  ) then
    raise exception 'One or more KC fields disappeared before apply: %', p_run_id;
  end if;
  if exists (
    select 1
    from public.act_sync_changes c
    join public.master_fields mf
      on upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) = c.field_number_norm
    where c.run_id = p_run_id
      and c.change_kind = 'INSERT'
  ) then
    raise exception 'One or more ACT inserts already exist in KC: %', p_run_id;
  end if;

  update public.act_sync_runs set status = 'APPLYING' where id = p_run_id;

  create temporary table tmp_act_update_before (
    change_id bigint primary key,
    field_number text not null,
    before_payload jsonb not null
  ) on commit drop;

  insert into tmp_act_update_before (change_id, field_number, before_payload)
  select
    c.id,
    mf.field_number,
    public.act_master_fields_sync_snapshot(mf)
  from public.act_sync_changes c
  join public.master_fields mf
    on upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) = c.field_number_norm
  where c.run_id = p_run_id
    and c.change_kind = 'UPDATE'
    and c.applied = false;

  update public.master_fields mf
  set farmer_name = case when c.source_payload ? 'farmer_name'
        then c.source_payload ->> 'farmer_name' else mf.farmer_name end,
      grower = case when c.source_payload ? 'grower'
        then c.source_payload ->> 'grower' else mf.grower end,
      hybrid = case when c.source_payload ? 'hybrid'
        then c.source_payload ->> 'hybrid' else mf.hybrid end,
      total_area_planted_ha = case when c.source_payload ? 'total_area_planted_ha'
        then (c.source_payload ->> 'total_area_planted_ha')::numeric else mf.total_area_planted_ha end,
      discard_area_ha = case when c.source_payload ? 'discard_area_ha'
        then (c.source_payload ->> 'discard_area_ha')::numeric else mf.discard_area_ha end,
      effective_area_ha = case when c.source_payload ? 'effective_area_ha'
        then (c.source_payload ->> 'effective_area_ha')::numeric else mf.effective_area_ha end,
      planting_date_pdn = case when c.source_payload ? 'planting_date_pdn'
        then c.source_payload ->> 'planting_date_pdn' else mf.planting_date_pdn end,
      hamlet_dusun = case when c.source_payload ? 'hamlet_dusun'
        then c.source_payload ->> 'hamlet_dusun' else mf.hamlet_dusun end,
      village_desa = case when c.source_payload ? 'village_desa'
        then c.source_payload ->> 'village_desa' else mf.village_desa end,
      sub_district_kec = case when c.source_payload ? 'sub_district_kec'
        then c.source_payload ->> 'sub_district_kec' else mf.sub_district_kec end,
      district_kab = case when c.source_payload ? 'district_kab'
        then c.source_payload ->> 'district_kab' else mf.district_kab end,
      fa = case when c.source_payload ? 'fa'
        then c.source_payload ->> 'fa' else mf.fa end,
      field_spv = case when c.source_payload ? 'field_spv'
        then c.source_payload ->> 'field_spv' else mf.field_spv end,
      coordinate = case when c.source_payload ? 'coordinate'
        then c.source_payload ->> 'coordinate' else mf.coordinate end,
      region = case when c.source_payload ? 'region'
        then c.source_payload ->> 'region' else mf.region end,
      area_manager = case when c.source_payload ? 'area_manager'
        then c.source_payload ->> 'area_manager' else mf.area_manager end,
      type = case when c.source_payload ? 'type'
        then c.source_payload ->> 'type' else mf.type end,
      prov = case when c.source_payload ? 'prov'
        then c.source_payload ->> 'prov' else mf.prov end,
      planting_ratio = case when c.source_payload ? 'planting_ratio'
        then c.source_payload ->> 'planting_ratio' else mf.planting_ratio end,
      planting_space = case when c.source_payload ? 'planting_space'
        then c.source_payload ->> 'planting_space' else mf.planting_space end,
      geometry_wkt = case
        when c.source_payload ? 'geometry_wkt'
          and lower(coalesce(mf.geometry_source, '')) not in ('manual', 'kc_manual')
        then c.source_payload ->> 'geometry_wkt'
        else mf.geometry_wkt
      end,
      geometry_source = case
        when c.source_payload ? 'geometry_wkt'
          and lower(coalesce(mf.geometry_source, '')) not in ('manual', 'kc_manual')
        then 'ACT'
        else mf.geometry_source
      end
  from public.act_sync_changes c
  where c.run_id = p_run_id
    and c.change_kind = 'UPDATE'
    and c.applied = false
    and upper(regexp_replace(btrim(mf.field_number), '[[:space:]]+', '', 'g')) = c.field_number_norm;

  get diagnostics v_updated = row_count;

  insert into public.act_master_fields_change_log (
    run_id,
    field_number,
    operation,
    source_type,
    changed_columns,
    before_payload,
    after_payload
  )
  select
    p_run_id,
    c.field_number_norm,
    'UPDATE',
    c.source_type,
    c.changed_columns,
    b.before_payload,
    public.act_master_fields_sync_snapshot(mf)
  from tmp_act_update_before b
  join public.act_sync_changes c on c.id = b.change_id
  join public.master_fields mf on mf.field_number = b.field_number;

  create temporary table tmp_act_inserted (
    change_id bigint primary key,
    field_number text not null
  ) on commit drop;

  with inserted as (
    insert into public.master_fields (
      field_number,
      farmer_name,
      grower,
      hybrid,
      total_area_planted_ha,
      discard_area_ha,
      effective_area_ha,
      planting_date_pdn,
      hamlet_dusun,
      village_desa,
      sub_district_kec,
      district_kab,
      fa,
      field_spv,
      coordinate,
      region,
      area_manager,
      type,
      prov,
      planting_ratio,
      planting_space,
      geometry_wkt,
      geometry_source,
      is_active
    )
    select
      c.field_number_norm,
      c.source_payload ->> 'farmer_name',
      c.source_payload ->> 'grower',
      c.source_payload ->> 'hybrid',
      (c.source_payload ->> 'total_area_planted_ha')::numeric,
      (c.source_payload ->> 'discard_area_ha')::numeric,
      (c.source_payload ->> 'effective_area_ha')::numeric,
      c.source_payload ->> 'planting_date_pdn',
      c.source_payload ->> 'hamlet_dusun',
      c.source_payload ->> 'village_desa',
      c.source_payload ->> 'sub_district_kec',
      c.source_payload ->> 'district_kab',
      c.source_payload ->> 'fa',
      c.source_payload ->> 'field_spv',
      c.source_payload ->> 'coordinate',
      c.source_payload ->> 'region',
      c.source_payload ->> 'area_manager',
      c.source_payload ->> 'type',
      c.source_payload ->> 'prov',
      c.source_payload ->> 'planting_ratio',
      c.source_payload ->> 'planting_space',
      c.source_payload ->> 'geometry_wkt',
      case when c.source_payload ? 'geometry_wkt' then 'ACT' else null end,
      true
    from public.act_sync_changes c
    where c.run_id = p_run_id
      and c.change_kind = 'INSERT'
      and c.applied = false
    returning field_number
  )
  insert into tmp_act_inserted (change_id, field_number)
  select c.id, i.field_number
  from inserted i
  join public.act_sync_changes c
    on c.run_id = p_run_id
    and c.change_kind = 'INSERT'
    and c.field_number_norm = i.field_number;

  select count(*) into v_inserted from tmp_act_inserted;

  insert into public.act_master_fields_change_log (
    run_id,
    field_number,
    operation,
    source_type,
    changed_columns,
    before_payload,
    after_payload
  )
  select
    p_run_id,
    c.field_number_norm,
    'INSERT',
    c.source_type,
    c.changed_columns,
    null,
    public.act_master_fields_sync_snapshot(mf)
  from tmp_act_inserted i
  join public.act_sync_changes c on c.id = i.change_id
  join public.master_fields mf on mf.field_number = i.field_number;

  update public.act_sync_changes
  set applied = true,
      applied_at = now(),
      apply_error = null
  where run_id = p_run_id
    and change_kind in ('INSERT', 'UPDATE')
    and applied = false;

  update public.act_sync_runs
  set status = 'COMPLETED',
      completed_at = now(),
      summary = summary || jsonb_build_object(
        'applied_insert', v_inserted,
        'applied_update', v_updated
      )
  where id = p_run_id;

  return jsonb_build_object(
    'run_id', p_run_id,
    'inserted', v_inserted,
    'updated', v_updated
  );
end;
$$;

revoke all on function public.apply_act_master_fields_sync(uuid)
  from public, anon, authenticated;
grant execute on function public.apply_act_master_fields_sync(uuid)
  to service_role;

comment on function public.apply_act_master_fields_sync(uuid) is
  'Applies validated ACT INSERT/UPDATE changes set-wise in one audited transaction.';
