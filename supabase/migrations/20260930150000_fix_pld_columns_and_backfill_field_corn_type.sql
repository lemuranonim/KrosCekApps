-- ACT final PLD rows expose area columns in this order:
-- planted, discarded, nett/effective. The Edge Function owns that positional
-- mapping. This migration makes the reconciliation layer backfill crop type
-- when older KC rows still have a null type.

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
    when p_field in (
      'total_area_planted_ha',
      'discard_area_ha',
      'effective_area_ha',
      'harvested_area_ha',
      'harvested_qty_kg'
    ) then
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

revoke all on function public.act_master_fields_values_differ(text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.act_master_fields_values_differ(text, jsonb, jsonb)
  to service_role;

comment on function public.act_master_fields_values_differ(text, jsonb, jsonb) is
  'Compares ACT and KC values and treats a missing crop type as a real change so the next sync backfills it.';
