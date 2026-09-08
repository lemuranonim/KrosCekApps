-- Remove synchronous QA resolver scans from writes and refresh the cache in one set-based batch.
begin;
set local lock_timeout='3s';
set local statement_timeout='45s';
set local idle_in_transaction_session_timeout='45s';
set local work_mem='16MB';
set local jit=off;

do $guard$ begin
  if not pg_try_advisory_xact_lock(hashtextextended('qa_resolution_timeout_hotfix',0)) then
    raise exception 'Another QA resolver timeout hotfix is active';
  end if;
  if to_regprocedure('public.refresh_qa_resolution_cache(integer)') is null
     or to_regprocedure('public.qa_resolution_cache_sync_field_trigger()') is null then
    raise exception 'QA resolution dashboard functions are incomplete';
  end if;
  if not exists(
    select 1 from information_schema.tables
    where table_schema='public' and table_name='qa_resolver_migrations'
  ) then
    raise exception 'qa_resolver_migrations is missing';
  end if;
  if exists(
    select 1 from public.qa_resolver_migrations
    where run_id='20260908_qa_resolution_timeout_hotfix_001'
  ) then
    raise exception 'Hotfix run already exists; inspect instead of rerunning';
  end if;
end $guard$;

create temp table qa_resolution_timeout_before(definitions jsonb not null)
on commit drop;
insert into qa_resolution_timeout_before
values(jsonb_build_object(
  'cache_sync',pg_get_functiondef(
    'public.qa_resolution_cache_sync_field_trigger()'::regprocedure
  ),
  'refresh',pg_get_functiondef(
    'public.refresh_qa_resolution_cache(integer)'::regprocedure
  ),
  'auto_fill_trigger',(
    select pg_get_triggerdef(oid,true)
    from pg_trigger
    where tgrelid='public.master_qa_mapping'::regclass
      and tgname='trigger_auto_fill_empty_qa'
      and not tgisinternal
  )
));

-- Mapping changes only mark affected cache entries stale. Existing empty QA FI rows
-- are handled explicitly through preview/apply, outside the mapping write transaction.
drop trigger if exists trigger_auto_fill_empty_qa on public.master_qa_mapping;

-- Master-field writes only synchronize source values and mark an existing cache row
-- stale. The next resolver refresh performs the expensive calculation in one batch.
create or replace function public.qa_resolution_cache_sync_field_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if tg_op='DELETE' then
    delete from public.qa_resolution_cache
    where field_number=old.field_number::text;
    return null;
  end if;

  if not coalesce(new.is_active,true) then
    delete from public.qa_resolution_cache
    where field_number=new.field_number::text;
    return null;
  end if;

  update public.qa_resolution_cache c set
    region=btrim(coalesce(new.region,'')),
    district_kab=btrim(coalesce(new.district_kab,'')),
    sub_district_kec=btrim(coalesce(new.sub_district_kec,'')),
    village_desa=btrim(coalesce(new.village_desa,'')),
    qa_spv=btrim(coalesce(new.qa_spv,'')),
    existing_qa_fi=btrim(coalesce(new.qa_fi,'')),
    fa=btrim(coalesce(new.fa,'')),
    field_spv=btrim(coalesce(new.field_spv,'')),
    effective_ha=coalesce(new.effective_area_ha,0),
    planted_ha=coalesce(new.total_area_planted_ha,0),
    source_updated_at=new.updated_at,
    is_stale=true
  where c.field_number=new.field_number::text;

  return null;
end;
$function$;

comment on function public.qa_resolution_cache_sync_field_trigger() is
  'Keeps cached source columns current and marks rows stale; resolver work is deferred to refresh_qa_resolution_cache.';

create or replace function public.refresh_qa_resolution_cache(
  p_limit integer default 200
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_action text;
  v_actor_is_active boolean;
  v_is_service boolean:=coalesce(auth.role(),'')='service_role';
  v_limit integer:=least(greatest(coalesce(p_limit,200),1),500);
  v_field_numbers text[]:=array[]::text[];
  v_processed integer:=0;
begin
  if auth.uid() is not null then
    select action,is_active into v_actor_action,v_actor_is_active
    from public.app_users where id=auth.uid();
    if not found or not coalesce(v_actor_is_active,false)
       or lower(btrim(coalesce(v_actor_action,'')))<>'all' then
      raise exception 'Refresh resolver hanya tersedia untuk pengguna aktif dengan akses semua area'
        using errcode='42501';
    end if;
  elsif not v_is_service and session_user not in ('postgres','supabase_admin') then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select coalesce(array_agg(q.field_number order by q.priority,q.field_number),array[]::text[])
  into v_field_numbers
  from (
    select candidates.field_number,candidates.priority
    from (
      select c.field_number,0 as priority
      from public.qa_resolution_cache c where c.is_stale
      union all
      select f.field_number::text,1 as priority
      from public.master_fields f
      where coalesce(f.is_active,true)
        and not exists(
          select 1 from public.qa_resolution_cache c
          where c.field_number=f.field_number::text
        )
    ) candidates
    order by candidates.priority,candidates.field_number
    limit v_limit
  ) q;

  v_processed:=cardinality(v_field_numbers);
  if v_processed=0 then
    return jsonb_build_object(
      'processed',0,
      'stale_remaining',(select count(*) from public.qa_resolution_cache where is_stale),
      'missing_remaining',(select count(*) from public.master_fields f
        where coalesce(f.is_active,true) and not exists(
          select 1 from public.qa_resolution_cache c
          where c.field_number=f.field_number::text
        )),
      'refreshed_at',clock_timestamp()
    );
  end if;

  delete from public.qa_resolution_cache c
  where c.field_number=any(v_field_numbers)
    and not exists(
      select 1 from public.master_fields f
      where f.field_number::text=c.field_number
        and coalesce(f.is_active,true)
    );

  with fields_norm as materialized (
    select
      f.field_number::text as field_number,
      btrim(coalesce(f.region,'')) as region,
      btrim(coalesce(f.district_kab,'')) as district_kab,
      btrim(coalesce(f.sub_district_kec,'')) as sub_district_kec,
      btrim(coalesce(f.village_desa,'')) as village_desa,
      btrim(coalesce(f.qa_spv,'')) as qa_spv,
      btrim(coalesce(f.qa_fi,'')) as existing_qa_fi,
      btrim(coalesce(f.fa,'')) as fa,
      btrim(coalesce(f.field_spv,'')) as field_spv,
      coalesce(f.effective_area_ha,0)::numeric as effective_ha,
      coalesce(f.total_area_planted_ha,0)::numeric as planted_ha,
      f.updated_at as source_updated_at,
      lower(btrim(coalesce(f.region,''))) as region_key,
      lower(btrim(coalesce(f.district_kab,''))) as district_key,
      lower(btrim(coalesce(f.sub_district_kec,''))) as sub_district_key,
      lower(btrim(coalesce(f.village_desa,''))) as village_key,
      public.canonical_person_name('qa_spv',f.qa_spv) as qa_spv_key,
      public.canonical_person_name('qa_fi',f.qa_fi) as existing_qa_fi_key,
      public.canonical_person_name('fa',f.fa) as fa_key,
      public.canonical_person_name('supervisor',f.field_spv) as field_spv_key
    from public.master_fields f
    where f.field_number::text=any(v_field_numbers)
      and coalesce(f.is_active,true)
  ),
  mapping_norm as materialized (
    select
      m.id::bigint as mapping_id,
      btrim(m.qa_fi) as mapping_qa_fi,
      m.updated_at as mapping_updated_at,
      public.canonical_person_name('qa_fi',m.qa_fi) as fi_key,
      public.canonical_person_name('qa_spv',m.qa_spv) as qa_spv_key,
      lower(btrim(coalesce(m.region,''))) as region_key,
      lower(btrim(coalesce(m.district_kab,''))) as district_key,
      lower(btrim(coalesce(m.sub_district_kec,''))) as sub_district_key,
      lower(btrim(coalesce(m.village_desa,''))) as village_key,
      public.canonical_person_name('fa',m.fa) as fa_key,
      public.canonical_person_name(
        'supervisor',coalesce(nullif(btrim(m.field_spv),''),m.supervisor)
      ) as field_spv_key
    from public.master_qa_mapping m
    where coalesce(m.is_active,true)
      and coalesce(nullif(lower(btrim(m.status)),''),'active')='active'
      and coalesce(nullif(lower(btrim(m.approval_status)),''),'approved')='approved'
      and nullif(btrim(m.district_kab),'') is not null
      and nullif(btrim(m.sub_district_kec),'') is not null
      and nullif(btrim(m.village_desa),'') is not null
      and public.canonical_person_name('qa_spv',m.qa_spv)<>''
      and public.canonical_person_name('qa_fi',m.qa_fi)<>''
      and exists(
        select 1 from fields_norm f
        where f.qa_spv_key=public.canonical_person_name('qa_spv',m.qa_spv)
          and f.district_key=lower(btrim(coalesce(m.district_kab,'')))
          and f.sub_district_key=lower(btrim(coalesce(m.sub_district_kec,'')))
      )
  ),
  compatible as materialized (
    select
      f.field_number,m.mapping_id,m.mapping_qa_fi,m.mapping_updated_at,m.fi_key,
      (m.village_key=f.village_key) as village_match,
      case
        when m.region_key=f.region_key and f.region_key<>'' then 20
        when m.region_key='swc' or f.region_key='swc' then 10
        else 0
      end as region_score,
      case when m.fa_key<>'' and f.fa_key<>'' and m.fa_key=f.fa_key
        then 80 else 0 end as fa_score,
      case when m.field_spv_key<>'' and f.field_spv_key<>''
        and m.field_spv_key=f.field_spv_key then 40 else 0 end as field_spv_score
    from fields_norm f
    join mapping_norm m
      on m.qa_spv_key=f.qa_spv_key
     and m.district_key=f.district_key
     and m.sub_district_key=f.sub_district_key
     and (
       m.region_key=''
       or m.region_key=f.region_key
       or (m.region_key='swc' and f.region_key in ('zona 1','zona 2','zona 3','zona 4'))
       or (f.region_key='swc' and m.region_key in ('zona 1','zona 2','zona 3','zona 4'))
     )
  ),
  with_level as (
    select c.*,bool_or(c.village_match) over(partition by c.field_number) as has_exact
    from compatible c
  ),
  scored as (
    select l.*,
      case when l.village_match then 400 else 300 end as base_score,
      case when l.village_match then 400 else 300 end
        +l.region_score+l.fa_score+l.field_spv_score as score
    from with_level l
    where (l.has_exact and l.village_match) or not l.has_exact
  ),
  ranked as (
    select s.*,max(s.score) over(partition by s.field_number) as top_score
    from scored s
  ),
  top_candidates as (
    select * from ranked where score=top_score
  ),
  candidate_rollup as (
    select
      field_number,
      count(distinct fi_key)::integer as candidate_fi_count,
      max(score)::integer as specificity,
      max(base_score)::integer as base_score,
      array_agg(distinct mapping_id order by mapping_id) as mapping_ids,
      (array_agg(mapping_qa_fi
        order by mapping_updated_at desc nulls last,mapping_id desc))[1]
        as resolved_qa_fi,
      min(fi_key) as resolved_qa_fi_key
    from top_candidates
    group by field_number
  ),
  classified as (
    select
      f.*,
      case
        when f.qa_spv_key='' then 'MISSING_QA_SPV'
        when f.district_key='' or f.sub_district_key='' or f.village_key=''
          then 'UNMAPPED'
        when coalesce(r.candidate_fi_count,0)=0 then 'UNMAPPED'
        when r.candidate_fi_count>1 then 'AMBIGUOUS'
        when f.existing_qa_fi_key<>''
          and f.existing_qa_fi_key<>r.resolved_qa_fi_key then 'MISMATCH'
        else 'RESOLVED'
      end as resolution_status,
      case when r.candidate_fi_count=1 then r.resolved_qa_fi end as resolved_qa_fi,
      coalesce(r.candidate_fi_count,0) as candidate_fi_count,
      r.specificity,
      coalesce(r.mapping_ids,array[]::bigint[]) as mapping_ids,
      case
        when f.qa_spv_key='' then 'QA SPV kosong pada data tanam'
        when f.district_key='' or f.sub_district_key='' or f.village_key=''
          then 'Wilayah data tanam belum lengkap'
        when coalesce(r.candidate_fi_count,0)=0
          then 'Tidak ada mapping aktif yang cocok'
        when r.candidate_fi_count>1
          then 'Lebih dari satu FI pada tingkat kecocokan tertinggi'
        when f.existing_qa_fi_key<>''
          and f.existing_qa_fi_key<>r.resolved_qa_fi_key
          then 'QA FI existing berbeda dari hasil resolver; perlu review manual'
        when r.base_score=400 then 'Satu FI unik pada tingkat Desa'
        else 'Satu FI unik pada fallback Kecamatan'
      end as resolution_reason
    from fields_norm f
    left join candidate_rollup r using(field_number)
  ),
  resolved_batch as (
    select
      c.field_number,c.region,c.district_kab,c.sub_district_kec,c.village_desa,
      c.qa_spv,c.existing_qa_fi,c.fa,c.field_spv,c.effective_ha,c.planted_ha,
      c.resolution_status,c.resolved_qa_fi,c.candidate_fi_count,c.specificity,
      c.mapping_ids,c.resolution_reason,
      public.qa_resolution_group_key(
        c.region,c.district_kab,c.sub_district_kec,c.village_desa,c.qa_spv,
        c.fa,c.field_spv,c.resolution_status,c.resolved_qa_fi
      ) as group_key,
      c.source_updated_at
    from classified c
  )
  insert into public.qa_resolution_cache(
    field_number,region,district_kab,sub_district_kec,village_desa,
    qa_spv,existing_qa_fi,fa,field_spv,effective_ha,planted_ha,
    resolution_status,resolved_qa_fi,candidate_fi_count,specificity,
    mapping_ids,resolution_reason,group_key,source_updated_at,computed_at,is_stale
  )
  select
    r.field_number,r.region,r.district_kab,r.sub_district_kec,r.village_desa,
    r.qa_spv,r.existing_qa_fi,r.fa,r.field_spv,r.effective_ha,r.planted_ha,
    r.resolution_status,r.resolved_qa_fi,r.candidate_fi_count,r.specificity,
    r.mapping_ids,r.resolution_reason,r.group_key,r.source_updated_at,
    clock_timestamp(),false
  from resolved_batch r
  on conflict(field_number) do update set
    region=excluded.region,district_kab=excluded.district_kab,
    sub_district_kec=excluded.sub_district_kec,
    village_desa=excluded.village_desa,qa_spv=excluded.qa_spv,
    existing_qa_fi=excluded.existing_qa_fi,fa=excluded.fa,
    field_spv=excluded.field_spv,effective_ha=excluded.effective_ha,
    planted_ha=excluded.planted_ha,
    resolution_status=excluded.resolution_status,
    resolved_qa_fi=excluded.resolved_qa_fi,
    candidate_fi_count=excluded.candidate_fi_count,
    specificity=excluded.specificity,mapping_ids=excluded.mapping_ids,
    resolution_reason=excluded.resolution_reason,
    group_key=excluded.group_key,source_updated_at=excluded.source_updated_at,
    computed_at=excluded.computed_at,is_stale=false;

  return jsonb_build_object(
    'processed',v_processed,
    'stale_remaining',(select count(*) from public.qa_resolution_cache where is_stale),
    'missing_remaining',(select count(*) from public.master_fields f
      where coalesce(f.is_active,true) and not exists(
        select 1 from public.qa_resolution_cache c
        where c.field_number=f.field_number::text
      )),
    'refreshed_at',clock_timestamp()
  );
end;
$function$;

comment on function public.refresh_qa_resolution_cache(integer) is
  'Refreshes up to 500 stale or missing QA cache rows in one set-based resolver batch.';

insert into public.qa_resolver_migrations(
  run_id,status,definitions_before,definitions_after,source_state,
  shadow_analysis,verification
)
select
  '20260908_qa_resolution_timeout_hotfix_001','installed',b.definitions,
  jsonb_build_object(
    'cache_sync',pg_get_functiondef(
      'public.qa_resolution_cache_sync_field_trigger()'::regprocedure
    ),
    'refresh',pg_get_functiondef(
      'public.refresh_qa_resolution_cache(integer)'::regprocedure
    ),
    'auto_fill_trigger',null
  ),
  jsonb_build_object(
    'mapping_rows',(select count(*) from public.master_qa_mapping),
    'field_rows',(select count(*) from public.master_fields),
    'cache_rows',(select count(*) from public.qa_resolution_cache),
    'stale_rows',(select count(*) from public.qa_resolution_cache where is_stale)
  ),
  jsonb_build_object(
    'cause','Synchronous per-row resolver calls on mapping writes and cache refresh'
  ),
  jsonb_build_object(
    'installed_at',clock_timestamp(),
    'master_or_audit_rows_changed',0,
    'legacy_auto_fill_trigger_removed',true,
    'refresh_mode','set_based_batch'
  )
from qa_resolution_timeout_before b;

select jsonb_build_object(
  'run_id','20260908_qa_resolution_timeout_hotfix_001',
  'status',(select status from public.qa_resolver_migrations
    where run_id='20260908_qa_resolution_timeout_hotfix_001'),
  'legacy_auto_fill_trigger_exists',exists(
    select 1 from pg_trigger
    where tgrelid='public.master_qa_mapping'::regclass
      and tgname='trigger_auto_fill_empty_qa' and not tgisinternal
  ),
  'stale_rows',(select count(*) from public.qa_resolution_cache where is_stale)
) as verification;
commit;
