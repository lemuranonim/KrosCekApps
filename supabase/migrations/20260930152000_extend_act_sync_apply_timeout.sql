-- A full ACT reconciliation can update several thousand master_fields rows.
-- Keep the operation atomic, but allow enough time for audit logging and the
-- cache/PLD lifecycle triggers that run after the set-based update.
alter function public.apply_act_master_fields_sync(uuid)
  set statement_timeout = '10min';

comment on function public.apply_act_master_fields_sync(uuid) is
  'Applies validated ACT Planting, PLD, geometry, and Harvest INSERT/UPDATE changes set-wise in one audited transaction; allows up to 10 minutes for large daily reconciliations.';
