-- Krisna is operationally a QA SPV. Restore the authoritative profile role so
-- server-side scoping and the client view cannot fall back to Manager access.
update public.app_users
set role = 'SPV'
where lower(btrim(email)) = 'k.bagusandrian@gmail.com'
  and upper(btrim(coalesce(role::text, ''))) is distinct from 'SPV';

create or replace function public.enforce_krisna_qa_spv_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if lower(btrim(coalesce(new.email, ''))) =
      'k.bagusandrian@gmail.com' then
    new.role := 'SPV';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_krisna_qa_spv_role()
  from public, anon, authenticated;

drop trigger if exists enforce_krisna_qa_spv_role
  on public.app_users;

create trigger enforce_krisna_qa_spv_role
before insert or update of email, role on public.app_users
for each row execute function public.enforce_krisna_qa_spv_role();

comment on function public.enforce_krisna_qa_spv_role() is
  'Keeps the explicit Krisna account exception scoped as QA SPV.';
