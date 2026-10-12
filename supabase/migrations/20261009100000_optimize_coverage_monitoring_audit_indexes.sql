-- Coverage monitoring loads audit rows in bounded field-number chunks instead
-- of one large embedded wildcard join. These indexes keep each lookup cheap.

create index if not exists audit_generative_field_number_idx
  on public.audit_generative (field_number);

create index if not exists audit_pre_harvest_field_number_idx
  on public.audit_pre_harvest (field_number);

create index if not exists audit_harvest_field_number_idx
  on public.audit_harvest (field_number);
