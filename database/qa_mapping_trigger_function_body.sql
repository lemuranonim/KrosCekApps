-- Replacement body for the existing master_qa_mapping trigger function.
-- Paste this block into the Supabase function body editor.
--
-- Notes:
-- - master_qa_mapping.supervisor is treated as the field_spv reference.
-- - FA-only matches are kept for affected-field discovery, but no longer win
--   automatic assignment unless another stronger key also matches.
-- - Rows with multiple top candidate pairs are skipped instead of being picked
--   by updated_at/id, so ambiguous mappings stay unchanged for manual review.

begin
  create temp table if not exists qa_mapping_affected_fields
  on commit drop
  as
  select field_number
  from public.master_fields
  where false;

  create temp table if not exists qa_mapping_changed_scope (
    district_kab text,
    sub_district_kec text,
    village_desa text,
    fa text,
    supervisor text,
    manager text
  ) on commit drop;

  truncate table qa_mapping_affected_fields;
  truncate table qa_mapping_changed_scope;

  insert into qa_mapping_changed_scope (
    district_kab,
    sub_district_kec,
    village_desa,
    fa,
    supervisor,
    manager
  ) values (
    trim(lower(coalesce(new.district_kab, ''))),
    trim(lower(coalesce(new.sub_district_kec, ''))),
    trim(lower(coalesce(new.village_desa, ''))),
    trim(lower(coalesce(new.fa, ''))),
    trim(lower(coalesce(new.supervisor, ''))),
    trim(lower(coalesce(new.manager, '')))
  );

  if tg_op = 'UPDATE' then
    insert into qa_mapping_changed_scope (
      district_kab,
      sub_district_kec,
      village_desa,
      fa,
      supervisor,
      manager
    ) values (
      trim(lower(coalesce(old.district_kab, ''))),
      trim(lower(coalesce(old.sub_district_kec, ''))),
      trim(lower(coalesce(old.village_desa, ''))),
      trim(lower(coalesce(old.fa, ''))),
      trim(lower(coalesce(old.supervisor, ''))),
      trim(lower(coalesce(old.manager, '')))
    );
  end if;

  insert into qa_mapping_affected_fields (field_number)
  select distinct mf.field_number
  from public.master_fields mf
  where exists (
    select 1
    from qa_mapping_changed_scope s
    where
      (
        s.supervisor = ''
        or trim(lower(coalesce(mf.field_spv, ''))) = s.supervisor
      )
      and (
        s.manager = ''
        or trim(lower(coalesce(mf.area_manager, ''))) = s.manager
      )
      and (
        (
          s.district_kab <> ''
          and s.sub_district_kec <> ''
          and trim(lower(coalesce(mf.district_kab, ''))) = s.district_kab
          and trim(lower(coalesce(mf.sub_district_kec, ''))) = s.sub_district_kec
          and (
            s.village_desa = ''
            or trim(lower(coalesce(mf.village_desa, ''))) = s.village_desa
            or (
              s.fa <> ''
              and trim(lower(coalesce(mf.fa, ''))) = s.fa
            )
          )
        )
        or (
          s.fa <> ''
          and trim(lower(coalesce(mf.fa, ''))) = s.fa
        )
      )
  );

  with mf_target as (
    select
      mf_sub.field_number,
      trim(lower(coalesce(mf_sub.district_kab, ''))) as district_kab_norm,
      trim(lower(coalesce(mf_sub.sub_district_kec, ''))) as sub_district_kec_norm,
      trim(lower(coalesce(mf_sub.village_desa, ''))) as village_desa_norm,
      trim(lower(coalesce(mf_sub.fa, ''))) as fa_norm,
      trim(lower(coalesce(mf_sub.field_spv, ''))) as field_spv_norm,
      trim(lower(coalesce(mf_sub.area_manager, ''))) as area_manager_norm,
      trim(lower(coalesce(mf_sub.qa_spv, ''))) as qa_spv_norm
    from public.master_fields mf_sub
    join qa_mapping_affected_fields af
      on af.field_number = mf_sub.field_number
  ),

  mapping_norm as (
    select
      m.id,
      nullif(trim(coalesce(m.qa_fi, '')), '') as qa_fi,
      nullif(trim(coalesce(m.qa_spv, '')), '') as qa_spv,
      m.updated_at,

      trim(lower(coalesce(m.district_kab, ''))) as district_kab_norm,
      trim(lower(coalesce(m.sub_district_kec, ''))) as sub_district_kec_norm,
      trim(lower(coalesce(m.village_desa, ''))) as village_desa_norm,
      trim(lower(coalesce(m.fa, ''))) as fa_norm,
      trim(lower(coalesce(m.supervisor, ''))) as supervisor_norm,
      trim(lower(coalesce(m.manager, ''))) as manager_norm,
      trim(lower(coalesce(m.qa_spv, ''))) as qa_spv_norm
    from public.master_qa_mapping m
    where
      (
        nullif(trim(coalesce(m.qa_fi, '')), '') is not null
        or nullif(trim(coalesce(m.qa_spv, '')), '') is not null
      )
      and coalesce(m.is_active, true) = true
      and coalesce(nullif(trim(lower(m.status)), ''), 'active') = 'active'
      and coalesce(nullif(trim(lower(m.approval_status)), ''), 'approved') = 'approved'
  ),

  candidates as (
    select
      mt.field_number,
      m.qa_fi,
      m.qa_spv,
      m.id,
      m.updated_at,

      (
        case
          when
            m.district_kab_norm <> ''
            and m.sub_district_kec_norm <> ''
            and m.village_desa_norm <> ''
            and m.fa_norm <> ''
            and m.supervisor_norm <> ''
            and m.district_kab_norm = mt.district_kab_norm
            and m.sub_district_kec_norm = mt.sub_district_kec_norm
            and m.village_desa_norm = mt.village_desa_norm
            and m.fa_norm = mt.fa_norm
            and m.supervisor_norm = mt.field_spv_norm
          then 600

          when
            m.district_kab_norm <> ''
            and m.sub_district_kec_norm <> ''
            and m.village_desa_norm <> ''
            and m.fa_norm <> ''
            and m.district_kab_norm = mt.district_kab_norm
            and m.sub_district_kec_norm = mt.sub_district_kec_norm
            and m.village_desa_norm = mt.village_desa_norm
            and m.fa_norm = mt.fa_norm
          then 550

          when
            m.district_kab_norm <> ''
            and m.sub_district_kec_norm <> ''
            and m.village_desa_norm <> ''
            and m.supervisor_norm <> ''
            and m.district_kab_norm = mt.district_kab_norm
            and m.sub_district_kec_norm = mt.sub_district_kec_norm
            and m.village_desa_norm = mt.village_desa_norm
            and m.supervisor_norm = mt.field_spv_norm
          then 500

          when
            m.district_kab_norm <> ''
            and m.sub_district_kec_norm <> ''
            and m.village_desa_norm <> ''
            and m.district_kab_norm = mt.district_kab_norm
            and m.sub_district_kec_norm = mt.sub_district_kec_norm
            and m.village_desa_norm = mt.village_desa_norm
          then 450

          when
            m.district_kab_norm <> ''
            and m.sub_district_kec_norm <> ''
            and m.fa_norm <> ''
            and m.supervisor_norm <> ''
            and m.district_kab_norm = mt.district_kab_norm
            and m.sub_district_kec_norm = mt.sub_district_kec_norm
            and m.fa_norm = mt.fa_norm
            and m.supervisor_norm = mt.field_spv_norm
          then 360

          when
            m.district_kab_norm <> ''
            and m.sub_district_kec_norm <> ''
            and m.fa_norm <> ''
            and m.district_kab_norm = mt.district_kab_norm
            and m.sub_district_kec_norm = mt.sub_district_kec_norm
            and m.fa_norm = mt.fa_norm
          then 320

          when
            m.fa_norm <> ''
            and m.supervisor_norm <> ''
            and m.qa_spv_norm <> ''
            and mt.qa_spv_norm <> ''
            and m.fa_norm = mt.fa_norm
            and m.supervisor_norm = mt.field_spv_norm
            and m.qa_spv_norm = mt.qa_spv_norm
          then 280

          when
            m.fa_norm <> ''
            and m.supervisor_norm <> ''
            and m.fa_norm = mt.fa_norm
            and m.supervisor_norm = mt.field_spv_norm
          then 180

          else 0
        end

        +

        case
          when m.manager_norm <> ''
            and m.manager_norm = mt.area_manager_norm
          then 10
          else 0
        end
      )::integer as score

    from mf_target mt
    join mapping_norm m
      on (
        (
          m.district_kab_norm <> ''
          and m.sub_district_kec_norm <> ''
          and m.district_kab_norm = mt.district_kab_norm
          and m.sub_district_kec_norm = mt.sub_district_kec_norm
        )
        or (
          m.fa_norm <> ''
          and m.fa_norm = mt.fa_norm
        )
      )
      and (
        m.supervisor_norm = ''
        or m.supervisor_norm = mt.field_spv_norm
      )
      and (
        m.manager_norm = ''
        or m.manager_norm = mt.area_manager_norm
      )
  ),

  grouped_pairs as (
    select
      field_number,
      qa_fi,
      qa_spv,
      score,
      count(*) as hit_count,
      max(updated_at) as last_updated_at,
      max(id) as last_id
    from candidates
    where score >= 180
      and (
        qa_fi is not null
        or qa_spv is not null
      )
    group by field_number, qa_fi, qa_spv, score
  ),

  top_scores as (
    select
      field_number,
      max(score) as top_score
    from grouped_pairs
    group by field_number
  ),

  top_pairs as (
    select gp.*
    from grouped_pairs gp
    join top_scores ts
      on ts.field_number = gp.field_number
      and ts.top_score = gp.score
  ),

  resolved as (
    select
      field_number,
      max(qa_fi) as qa_fi,
      max(qa_spv) as qa_spv
    from top_pairs
    group by field_number
    having count(*) = 1
  )

  update public.master_fields mf
  set
    qa_fi = coalesce(r.qa_fi, mf.qa_fi),
    qa_spv = coalesce(r.qa_spv, mf.qa_spv)
  from resolved r
  where mf.field_number = r.field_number
    and (
      r.qa_fi is not null
      or r.qa_spv is not null
    )
    and (
      mf.qa_fi is distinct from coalesce(r.qa_fi, mf.qa_fi)
      or mf.qa_spv is distinct from coalesce(r.qa_spv, mf.qa_spv)
    );

  update public.audit_vegetative av
  set
    qa_fi = mf.qa_fi,
    qa_spv = mf.qa_spv
  from public.master_fields mf
  join qa_mapping_affected_fields af
    on af.field_number = mf.field_number
  where av.field_number = mf.field_number
    and (
      av.qa_fi is distinct from mf.qa_fi
      or av.qa_spv is distinct from mf.qa_spv
    );

  update public.audit_generative ag
  set
    qa_fi = mf.qa_fi,
    qa_spv = mf.qa_spv
  from public.master_fields mf
  join qa_mapping_affected_fields af
    on af.field_number = mf.field_number
  where ag.field_number = mf.field_number
    and (
      ag.qa_fi is distinct from mf.qa_fi
      or ag.qa_spv is distinct from mf.qa_spv
    );

  update public.audit_pre_harvest aph
  set
    qa_fi = mf.qa_fi,
    qa_spv = mf.qa_spv
  from public.master_fields mf
  join qa_mapping_affected_fields af
    on af.field_number = mf.field_number
  where aph.field_number = mf.field_number
    and (
      aph.qa_fi is distinct from mf.qa_fi
      or aph.qa_spv is distinct from mf.qa_spv
    );

  update public.audit_harvest ah
  set
    qa_fi = mf.qa_fi,
    qa_spv = mf.qa_spv
  from public.master_fields mf
  join qa_mapping_affected_fields af
    on af.field_number = mf.field_number
  where ah.field_number = mf.field_number
    and (
      ah.qa_fi is distinct from mf.qa_fi
      or ah.qa_spv is distinct from mf.qa_spv
    );

  return null;
end;
