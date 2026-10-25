import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
const { PGlite }=createRequire(resolve('.dart_tool/act-sync-tests/package.json'))('@electric-sql/pglite');
const db=new PGlite();
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let passed=0;
async function check(name,callback) { await callback(); passed++; console.log('ok - '+name); }
async function claims(n,extra={}) {
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:id(n),role:'authenticated',...extra})]);
}
try {
  await db.exec(`create role anon;create role authenticated;create role service_role;
    create schema auth;grant usage on schema auth to anon,authenticated;
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claims',true)::jsonb->>'sub','')::uuid $$;
    create function auth.jwt() returns jsonb language sql stable as $$
      select current_setting('request.jwt.claims',true)::jsonb $$;
    create table public.app_users(id uuid primary key,email text,name text,role text,action text,is_active boolean default true);
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb);
    create function public.master_qa_mapping_editor_access() returns text language plpgsql security definer as $$
      begin if public.master_qa_mapping_admin_allowed() then return 'admin';end if;
      if public.master_qa_mapping_current_qa_spv_name() is not null then return 'qa_spv';end if;return 'none';end $$;
    create function public.admin_count_master_qa_mapping() returns bigint language plpgsql security definer as $$
      begin if not public.master_qa_mapping_admin_allowed() then raise insufficient_privilege;end if;return 0;end $$;
    create function public.master_qa_mapping_admin_allowed() returns boolean language sql security definer as $$
      select auth.uid() is not null and auth.jwt()->'user_metadata'->>'role'='DEV' $$;`);
  await claims(1,{user_metadata:{role:'DEV'}});
  assert.equal((await db.query('select public.master_qa_mapping_admin_allowed() allowed')).rows[0].allowed,true);
  await db.exec(readFileSync('supabase/migrations/20261025090000_close_metadata_role_escalation.sql','utf8'));
  await db.exec('create trigger signup after insert on auth.users for each row execute function public.handle_new_user()');
  await check('forged signup role and action produce inactive GUEST',async()=>{
    await db.query('insert into auth.users values($1,$2,$3)',[id(1),'attacker@example.invalid',{role:'DEV',action:'admin',name:'Existing FI'}]);
    const row=(await db.query('select role,action,is_active from app_users where id=$1',[id(1)])).rows[0];
    assert.deepEqual(row,{role:'GUEST',action:'audit',is_active:false});
  });
  await check('self-supplied DEV metadata no longer passes admin guard',async()=>{
    await claims(1,{user_metadata:{role:'DEV'},app_metadata:{role:'DEV'}});
    assert.equal((await db.query('select public.master_qa_mapping_admin_allowed() allowed')).rows[0].allowed,false);
  });
  await db.query("insert into app_users values($1,'dev@example.invalid','Developer','DEV','audit',true),($2,'spv@example.invalid','Supervisor','SPV','audit',true),($3,'inactive@example.invalid','Former developer','DEV','audit',false),($4,'fi@example.invalid','FI','FI','audit',true)",[id(2),id(3),id(4),id(5)]);
  await check('active DEV retains mapping administration by exact UID',async()=>{
    await claims(2,{email:'unrelated@example.invalid'});
    assert.equal((await db.query('select public.master_qa_mapping_admin_allowed() allowed')).rows[0].allowed,true);
  });
  await check('inactive DEV is denied despite privileged JWT metadata',async()=>{
    await claims(4,{app_metadata:{role:'DEV'},user_metadata:{role:'DEV'}});
    assert.equal((await db.query('select public.master_qa_mapping_admin_allowed() allowed')).rows[0].allowed,false);
  });
  await check('active FI cannot acquire DEV from metadata or another email',async()=>{
    await claims(5,{email:'dev@example.invalid',user_metadata:{role:'DEV'}});
    assert.equal((await db.query('select public.master_qa_mapping_admin_allowed() allowed')).rows[0].allowed,false);
  });
  await check('SPV scope uses exact UID',async()=>{
    await claims(3);assert.equal((await db.query('select master_qa_mapping_current_qa_spv_name() name')).rows[0].name,'Supervisor');
    await claims(1,{email:'spv@example.invalid'});assert.equal((await db.query('select master_qa_mapping_current_qa_spv_name() name')).rows[0].name,null);
  });
  await check('anonymous RPC execution revoked, authenticated workflow preserved',async()=>{
    const row=(await db.query("select has_function_privilege('anon','admin_count_master_qa_mapping()','EXECUTE') a,has_function_privilege('authenticated','admin_count_master_qa_mapping()','EXECUTE') b")).rows[0];
    assert.deepEqual(row,{a:false,b:true});
  });
  console.log(`${passed} metadata-escalation checks passed`);
} finally {await db.close();}
