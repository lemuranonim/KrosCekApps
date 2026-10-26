-- Preserve exact assignment membership while avoiding a regex scan of every
-- master field for each RLS subquery in an audit upsert or embedded read.
begin;
set local lock_timeout = '2s';
set local statement_timeout = '45s';

create or replace function public.kroscek_assignment_name_tokens(p_names text)
returns text[]
language sql immutable parallel safe
set search_path = ''
as $$
  select coalesce(array_agg(lower(regexp_replace(btrim(part), '\s+', ' ', 'g'))),array[]::text[])
  from regexp_split_to_table(coalesce(p_names,''),'\s*[,;|/&]\s*|\s+(dan|and)\s+','i') as part;
$$;
revoke all on function public.kroscek_assignment_name_tokens(text) from public,anon,authenticated;
grant execute on function public.kroscek_assignment_name_tokens(text) to authenticated,service_role;

create index if not exists master_fields_qa_fi_assignment_tokens_idx
  on public.master_fields using gin (public.kroscek_assignment_name_tokens(qa_fi::text));
create index if not exists master_fields_qa_spv_assignment_tokens_idx
  on public.master_fields using gin (public.kroscek_assignment_name_tokens(qa_spv::text));

create or replace function public.kroscek_readable_field_numbers()
returns setof text
language plpgsql stable security definer
set search_path = ''
as $$
declare
  actor_context jsonb := public.kroscek_access_context();
  actor_role text := actor_context->>'role';
  actor_name text;
begin
  if actor_context is null then return; end if;
  if actor_role in ('ADMIN','DEV','MANAGER','QA','GUEST') then
    return query select f.field_number::text from public.master_fields f;
  elsif actor_role in ('FI','SPV') then
    if nullif(btrim(actor_context->>'name'),'') is null then return; end if;
    actor_name := lower(regexp_replace(btrim(actor_context->>'name'),'\s+',' ','g'));
    if actor_role='FI' then
      return query select f.field_number::text from public.master_fields f
        where public.kroscek_assignment_name_tokens(f.qa_fi::text) @> array[actor_name];
    else
      return query select f.field_number::text from public.master_fields f
        where public.kroscek_assignment_name_tokens(f.qa_spv::text) @> array[actor_name];
    end if;
  end if;
end;
$$;
revoke all on function public.kroscek_readable_field_numbers() from public,anon,authenticated;
grant execute on function public.kroscek_readable_field_numbers() to authenticated,service_role;

-- Refresh planner estimates for the new expression indexes. No audit payload,
-- assignment, policy, role, or timeout outside this transaction is changed.
analyze public.master_fields;
commit;
