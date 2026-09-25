alter table public.master_fields
  drop constraint if exists master_fields_geometry_source_check;

alter table public.master_fields
  add constraint master_fields_geometry_source_check
  check (
    geometry_source is null
    or geometry_source in (
      'qa_manual',
      'qa_kml',
      'vegetative_kml',
      'inspection_kml',
      'system',
      'unknown',
      'ACT'
    )
  );

comment on column public.master_fields.geometry_source is
  'Origin of geometry_wkt; ACT identifies geometry synchronized from the ACT planting export.';
