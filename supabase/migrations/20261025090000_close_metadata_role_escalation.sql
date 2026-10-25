-- User-controlled signup/JWT metadata must never grant application privileges.
begin;
set local lock_timeout = '2s';
set local statement_timeout = '15s';

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.app_users (id,email,name,role,action,is_active)
  values (new.id,new.email,
    coalesce(nullif(btrim(new.raw_user_meta_data->>'name'),''),split_part(new.email,'@',1)),
    'GUEST','audit',false)
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.master_qa_mapping_admin_allowed()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.app_users u
    where u.id=(select auth.uid()) and u.is_active is true
      and upper(btrim(u.role)) in ('DEV','DEVELOPER'));
$$;

create or replace function public.master_qa_mapping_current_qa_spv_name()
returns text language sql stable security definer set search_path = '' as $$
  select nullif(btrim(u.name),'') from public.app_users u
  where u.id=(select auth.uid()) and u.is_active is true
    and upper(btrim(u.role))='SPV';
$$;

revoke all on function public.handle_new_user(),
  public.master_qa_mapping_admin_allowed(),public.master_qa_mapping_current_qa_spv_name(),
  public.master_qa_mapping_editor_access() from public,anon,authenticated;
grant execute on function public.master_qa_mapping_admin_allowed(),
  public.master_qa_mapping_current_qa_spv_name(),public.master_qa_mapping_editor_access()
  to authenticated,service_role;

-- Preserve authenticated RPC workflows, while removing anonymous invocation.
do $$
declare target record;
begin
  for target in
    select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and (
      p.proname like 'admin_%master_qa_mapping%'
      or p.proname in ('admin_get_qa_mapping_editor_context','admin_mark_qa_mapping_refresh_needed',
        'admin_refresh_qa_mapping_all','admin_refresh_qa_mapping_batch'))
  loop
    execute format('revoke all on function %s from public,anon',target.signature);
    execute format('grant execute on function %s to authenticated,service_role',target.signature);
  end loop;
end;
$$;
commit;
