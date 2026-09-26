begin;

alter table public.master_fields
  add column if not exists correction_geometry_wkt text;

comment on column public.master_fields.correction_geometry_wkt is
  'KC/user geometry override. When valid, its centroid and polygon take priority over ACT geometry_wkt.';

-- Establish the requested initial correction baseline without ever replacing an
-- existing correction if this migration is replayed.
update public.master_fields
set correction_geometry_wkt = geometry_wkt
where nullif(btrim(correction_geometry_wkt), '') is null
  and nullif(btrim(geometry_wkt), '') is not null;

commit;
