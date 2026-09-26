create or replace function public.act_master_fields_values_differ(
  p_field text,
  p_current jsonb,
  p_source jsonb
)
returns boolean
language sql
immutable
set search_path = public
as $$
  select case
    -- Historical KC imports often left FC type null. Filling that value adds
    -- no operational information and would create thousands of noisy updates.
    -- New rows still receive Field Corn, and SC/PS classification corrections
    -- remain actionable.
    when p_field = 'type'
      and (p_current is null or p_current = 'null'::jsonb)
      and upper(nullif(btrim(p_source #>> '{}'), '')) = 'FIELD CORN'
      then false
    when p_field in ('total_area_planted_ha', 'discard_area_ha', 'effective_area_ha') then
      (case when p_current is null or p_current = 'null'::jsonb
        then null else (p_current #>> '{}')::numeric end)
      is distinct from
      (case when p_source is null or p_source = 'null'::jsonb
        then null else (p_source #>> '{}')::numeric end)
    when p_field in ('hybrid', 'type') then
      upper(nullif(btrim(p_current #>> '{}'), ''))
      is distinct from
      upper(nullif(btrim(p_source #>> '{}'), ''))
    else
      nullif(btrim(p_current #>> '{}'), '')
      is distinct from
      nullif(btrim(p_source #>> '{}'), '')
  end;
$$;
