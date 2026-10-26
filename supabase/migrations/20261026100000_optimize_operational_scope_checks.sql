-- Copy of the migration already applied in production, recovered during the
-- audit-submit investigation so repository and database history stay aligned.
begin;
set local lock_timeout = '2s';
set local statement_timeout = '30s';

create or replace function public.kroscek_readable_field_numbers()
returns setof text
language sql stable security definer
set search_path = ''
as $$
  select f.field_number::text from public.master_fields f
  where (select public.kroscek_access_context()) is not null
    and ((select public.kroscek_access_context())->>'role' in ('ADMIN','DEV','MANAGER','QA','GUEST')
      or ((select public.kroscek_access_context())->>'role'='FI'
        and public.act_monitor_name_matches(f.qa_fi,(select public.kroscek_access_context())->>'name'))
      or ((select public.kroscek_access_context())->>'role'='SPV'
        and public.act_monitor_name_matches(f.qa_spv,(select public.kroscek_access_context())->>'name')));
$$;
revoke all on function public.kroscek_readable_field_numbers() from public,anon,authenticated;
grant execute on function public.kroscek_readable_field_numbers() to authenticated,service_role;

do $$
declare t text; read_expr text;
begin
  foreach t in array array['master_fields','master_qa_mapping'] loop
    if t='master_fields' then
      read_expr := 'field_number in (select public.kroscek_readable_field_numbers())';
    else
      read_expr := $expr$
        ((select public.kroscek_access_context())->>'role' in ('ADMIN','DEV','MANAGER','QA','GUEST')
          or public.kroscek_assignment_allowed(qa_fi,qa_spv,(select public.kroscek_access_context()),false))
      $expr$;
    end if;
    execute format('alter policy kroscek_operational_access on public.%I using (true)',t);
    execute format('alter policy kroscek_operational_boundary on public.%I using (%s)',t,read_expr);
  end loop;
  foreach t in array array['audit_vegetative','audit_generative','audit_pre_harvest','audit_harvest',
    'field_qa_assignment','audit_sync_log','wilayah_resolve_log','master_field_geometry_history'] loop
    read_expr := 'field_number in (select public.kroscek_readable_field_numbers())';
    execute format('alter policy kroscek_operational_access on public.%I using (true)',t);
    execute format('alter policy kroscek_operational_boundary on public.%I using (%s)',t,read_expr);
  end loop;
end;
$$;
commit;
