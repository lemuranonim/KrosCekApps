-- Restrict direct resolver lookups while preserving invoker triggers and server jobs.
begin;
set local lock_timeout='2s';
set local statement_timeout='15s';
CREATE OR REPLACE FUNCTION public.resolve_unique_qa_fi(p_qa_spv text, p_region text, p_district_kab text, p_sub_district_kec text, p_village_desa text, p_fa text, p_field_spv text)
 RETURNS TABLE(resolution_status text, qa_fi text, candidate_fi_count integer, specificity integer, mapping_ids bigint[], resolution_reason text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
with input as (
  select
    public.canonical_person_name('qa_spv',p_qa_spv) as qa_spv_key,
    lower(btrim(coalesce(p_region,''))) as region_key,
    lower(btrim(coalesce(p_district_kab,''))) as district_key,
    lower(btrim(coalesce(p_sub_district_kec,''))) as sub_district_key,
    lower(btrim(coalesce(p_village_desa,''))) as village_key,
    public.canonical_person_name('fa',p_fa) as fa_key,
    public.canonical_person_name('supervisor',p_field_spv) as field_spv_key
  where (
    pg_catalog.pg_trigger_depth()>0
    or (select auth.role())='service_role'
    or (session_user in ('postgres','supabase_admin')
        and coalesce(current_setting('role',true),'none') in ('none','postgres','supabase_admin'))
    or exists(select 1 from public.app_users actor
      where actor.id=(select auth.uid()) and actor.is_active is true
        and (upper(btrim(actor.role)) in ('DEV','DEVELOPER')
          or (upper(btrim(actor.role))='SPV'
            and public.canonical_person_name('qa_spv',actor.name)
              =public.canonical_person_name('qa_spv',p_qa_spv))))
  )
),
mapping_norm as materialized (
  select m.id::bigint as id,btrim(m.qa_fi) as qa_fi,m.updated_at,
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
),
exact_candidates as (
  select m.* from mapping_norm m cross join input i
  where m.qa_spv_key=i.qa_spv_key
    and m.district_key=i.district_key
    and m.sub_district_key=i.sub_district_key
    and m.village_key=i.village_key
    and (m.region_key='' or m.region_key=i.region_key
      or (m.region_key='swc' and i.region_key in ('zona 1','zona 2','zona 3','zona 4'))
      or (i.region_key='swc' and m.region_key in ('zona 1','zona 2','zona 3','zona 4')))
),
kecamatan_candidates as (
  select m.* from mapping_norm m cross join input i
  where not exists(select 1 from exact_candidates)
    and m.qa_spv_key=i.qa_spv_key
    and m.district_key=i.district_key
    and m.sub_district_key=i.sub_district_key
    and (m.region_key='' or m.region_key=i.region_key
      or (m.region_key='swc' and i.region_key in ('zona 1','zona 2','zona 3','zona 4'))
      or (i.region_key='swc' and m.region_key in ('zona 1','zona 2','zona 3','zona 4')))
),
scored as (
  select c.*,400 as base_score,
    400
      + case when c.region_key=i.region_key and i.region_key<>'' then 20
             when c.region_key='swc' or i.region_key='swc' then 10 else 0 end
      + case when c.fa_key<>'' and i.fa_key<>'' and c.fa_key=i.fa_key then 80 else 0 end
      + case when c.field_spv_key<>'' and i.field_spv_key<>''
                  and c.field_spv_key=i.field_spv_key then 40 else 0 end as score
  from exact_candidates c cross join input i
  union all
  select c.*,300 as base_score,
    300
      + case when c.region_key=i.region_key and i.region_key<>'' then 20
             when c.region_key='swc' or i.region_key='swc' then 10 else 0 end
      + case when c.fa_key<>'' and i.fa_key<>'' and c.fa_key=i.fa_key then 80 else 0 end
      + case when c.field_spv_key<>'' and i.field_spv_key<>''
                  and c.field_spv_key=i.field_spv_key then 40 else 0 end as score
  from kecamatan_candidates c cross join input i
),
top_score as (select max(score) as score from scored),
top_candidates as (
  select s.* from scored s join top_score t on t.score=s.score
),
top_stats as (
  select count(distinct fi_key)::integer as fi_count,max(score)::integer as score,
    max(base_score)::integer as base_score,
    array_agg(distinct id order by id) as ids
  from top_candidates
),
chosen as (
  select qa_fi from top_candidates
  order by updated_at desc nulls last,id desc limit 1
)
select
  case
    when i.qa_spv_key='' then 'MISSING_QA_SPV'
    when i.district_key='' or i.sub_district_key='' or i.village_key='' then 'UNMAPPED'
    when coalesce(s.fi_count,0)=0 then 'UNMAPPED'
    when s.fi_count=1 then 'RESOLVED'
    else 'AMBIGUOUS'
  end,
  case when s.fi_count=1 then c.qa_fi end,
  coalesce(s.fi_count,0),s.score,coalesce(s.ids,array[]::bigint[]),
  case
    when i.qa_spv_key='' then 'QA SPV kosong pada data tanam'
    when i.district_key='' or i.sub_district_key='' or i.village_key=''
      then 'Wilayah data tanam belum lengkap'
    when coalesce(s.fi_count,0)=0 then 'Tidak ada mapping aktif yang cocok'
    when s.fi_count=1 and s.base_score=400 then 'Satu FI unik pada tingkat Desa'
    when s.fi_count=1 then 'Satu FI unik pada fallback Kecamatan'
    else 'Lebih dari satu FI pada tingkat kecocokan tertinggi'
  end
from input i cross join top_stats s left join chosen c on true;
$function$;

revoke all on function public.resolve_unique_qa_fi(text,text,text,text,text,text,text) from public,anon;
grant execute on function public.resolve_unique_qa_fi(text,text,text,text,text,text,text) to authenticated,service_role;
commit;
