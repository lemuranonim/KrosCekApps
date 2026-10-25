-- Authorized security containment for the sixteen operational/reference tables.
-- Keep legitimate QA reads/writes and trigger-generated history available.
begin;
set local lock_timeout = '2s';
set local statement_timeout = '30s';

create or replace function public.kroscek_access_context()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('role',upper(btrim(u.role)),'name',u.name)
  from public.app_users u where u.id=(select auth.uid()) and u.is_active is true
    and upper(btrim(u.role)) in ('ADMIN','DEV','MANAGER','QA','FI','SPV','GUEST');
$$;

create or replace function public.kroscek_assignment_allowed(
  p_qa_fi text,p_qa_spv text,p_context jsonb,p_write boolean default false)
returns boolean language sql immutable security definer set search_path = '' as $$
  select coalesce(
    p_context->>'role' in ('ADMIN','DEV','MANAGER','QA')
    or (not p_write and p_context->>'role'='GUEST')
    or (p_context->>'role'='FI' and public.act_monitor_name_matches(p_qa_fi,p_context->>'name'))
    or (p_context->>'role'='SPV' and public.act_monitor_name_matches(p_qa_spv,p_context->>'name')),
    false);
$$;

revoke all on function public.kroscek_access_context(),
  public.kroscek_assignment_allowed(text,text,jsonb,boolean) from public,anon,authenticated;
grant execute on function public.kroscek_access_context(),
  public.kroscek_assignment_allowed(text,text,jsonb,boolean) to authenticated,service_role;

do $$
declare t text; cols text; read_expr text; write_expr text; s record;
  targets text[] := array['master_fields','audit_vegetative','audit_generative',
    'audit_pre_harvest','audit_harvest','master_qa_mapping','field_qa_assignment',
    'audit_sync_log','wilayah_resolve_log','import_logs','master_field_geometry_history',
    'seasons','provinsi','kabupaten','kecamatan','desa'];
  member_expr text := '(select public.kroscek_access_context()) is not null';
  writer_expr text := '(select public.kroscek_access_context())->>''role'' in (''ADMIN'',''DEV'',''MANAGER'',''QA'',''FI'',''SPV'')';
  admin_expr text := '(select public.kroscek_access_context())->>''role'' in (''ADMIN'',''DEV'',''MANAGER'')';
begin
  foreach t in array targets loop
    if to_regclass(format('public.%I',t)) is null then
      raise exception 'Required containment table % is missing',t;
    end if;
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all privileges on table public.%I from public,anon',t);
    select string_agg(quote_ident(a.attname),', ') into cols from pg_attribute a
      where a.attrelid=format('public.%I',t)::regclass and a.attnum>0 and not a.attisdropped;
    execute format('revoke all privileges (%s) on table public.%I from public,anon',cols,t);

    if t in ('master_fields','master_qa_mapping') then
      read_expr := 'public.kroscek_assignment_allowed(qa_fi,qa_spv,(select public.kroscek_access_context()),false)';
      write_expr := 'public.kroscek_assignment_allowed(qa_fi,qa_spv,(select public.kroscek_access_context()),true)';
    elsif t in ('audit_vegetative','audit_generative','audit_pre_harvest','audit_harvest',
        'field_qa_assignment','audit_sync_log','wilayah_resolve_log','master_field_geometry_history') then
      read_expr := format('exists(select 1 from public.master_fields scope_field where scope_field.field_number=public.%I.field_number)',t);
      write_expr := '('||writer_expr||') and ('||read_expr||')';
      if t in ('field_qa_assignment','audit_sync_log','wilayah_resolve_log','master_field_geometry_history') then
        -- Ordinary requests cannot forge internal history. Invoker triggers
        -- still need this insertion/update path while processing a scoped edit.
        write_expr := '('||write_expr||') and pg_trigger_depth()>0';
      end if;
    elsif t='import_logs' then
      read_expr := admin_expr;
      write_expr := '('||admin_expr||') and pg_trigger_depth()>0';
    else
      read_expr := member_expr;
      write_expr := admin_expr;
    end if;

    execute format('drop policy if exists kroscek_operational_access on public.%I',t);
    execute format('create policy kroscek_operational_access on public.%I for all to authenticated using (%s) with check (%s)',t,read_expr,write_expr);
    execute format('drop policy if exists kroscek_operational_boundary on public.%I',t);
    execute format('create policy kroscek_operational_boundary on public.%I as restrictive for all to authenticated using (%s) with check (%s)',t,read_expr,write_expr);
    execute format('drop policy if exists kroscek_operational_update on public.%I',t);
    execute format('create policy kroscek_operational_update on public.%I as restrictive for update to authenticated using (%s) with check (%s)',t,write_expr,write_expr);
    execute format('drop policy if exists kroscek_operational_delete on public.%I',t);
    execute format('create policy kroscek_operational_delete on public.%I as restrictive for delete to authenticated using (%s)',t,write_expr);
  end loop;

  -- Restrict only sequences owned by these tables; unrelated APIs are unchanged.
  for s in select distinct seq.relname from pg_class seq join pg_namespace n on n.oid=seq.relnamespace
    join pg_depend d on d.objid=seq.oid join pg_class tab on tab.oid=d.refobjid
    where seq.relkind='S' and n.nspname='public' and tab.relname=any(targets)
      and d.deptype in ('a','i') loop
    execute format('revoke all privileges on sequence public.%I from public,anon',s.relname);
  end loop;
end;
$$;

create or replace function public.kroscek_guard_assignment_change()
returns trigger language plpgsql set search_path = '' as $$
declare context jsonb; role_name text;
begin
  -- Trusted definer assignment/import functions retain their privileges.
  if current_user <> 'authenticated' then return new; end if;
  context := public.kroscek_access_context(); role_name := context->>'role';
  if tg_table_name='master_fields' then
    if role_name not in ('ADMIN','DEV','MANAGER') and
      (new.qa_fi is distinct from old.qa_fi or new.qa_spv is distinct from old.qa_spv) then
      raise exception 'QA ownership changes require the assignment workflow.' using errcode='42501';
    end if;
  elsif role_name='FI' then
    if tg_op='INSERT' then
      new.qa_fi := context->>'name';
      new.qa_spv := null;
      new.approval_status := 'pending';
    elsif (to_jsonb(new)-array['district_kab','sub_district_kec','village_desa','fa','ha',
      'status','is_active','change_reason','updated_at']) is distinct from
      (to_jsonb(old)-array['district_kab','sub_district_kec','village_desa','fa','ha',
      'status','is_active','change_reason','updated_at']) then
      raise exception 'FI cannot change assignment identity or approval.' using errcode='42501';
    end if;
  elsif role_name='SPV' and new.qa_spv is distinct from context->>'name' then
    raise exception 'SPV can manage only their own assignments.' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function public.kroscek_guard_assignment_change() from public,anon,authenticated;
drop trigger if exists aaa_security_guard_assignment on public.master_fields;
create trigger aaa_security_guard_assignment before update of qa_fi,qa_spv on public.master_fields
  for each row execute function public.kroscek_guard_assignment_change();
drop trigger if exists aaa_security_guard_mapping on public.master_qa_mapping;
create trigger aaa_security_guard_mapping before insert or update on public.master_qa_mapping
  for each row execute function public.kroscek_guard_assignment_change();

commit;
