import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
const {PGlite}=createRequire(resolve('.dart_tool/act-sync-tests/package.json'))('@electric-sql/pglite');
const db=new PGlite();const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let passed=0;
async function check(name,fn){await fn();passed++;console.log('ok - '+name);}
async function actor(n,fn,role='authenticated'){
  await db.exec('begin');try{
    await db.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:id(n),role,user_metadata:{role:'DEV'}})]);
    await db.exec(`set local role ${role}`);return await fn();
  }finally{await db.exec('rollback');}
}
const query="select * from public.resolve_unique_qa_fi($1,'R','D','K','V','FA','FS')";
try{
  await db.exec(`create role anon;create role authenticated;create role service_role;
    create schema auth;create function auth.uid() returns uuid language sql stable as $$select (current_setting('request.jwt.claims',true)::jsonb->>'sub')::uuid$$;
    create function auth.role() returns text language sql stable as $$select current_setting('request.jwt.claims',true)::jsonb->>'role'$$;
    create table app_users(id uuid,name text,role text,is_active boolean);
    create function canonical_person_name(text,text) returns text language sql immutable as $$select lower(btrim(coalesce($2,'')))$$;
    create table master_qa_mapping(id bigint,qa_fi text,qa_spv text,region text,district_kab text,sub_district_kec text,village_desa text,fa text,field_spv text,supervisor text,updated_at timestamptz,is_active boolean,status text,approval_status text);
    insert into master_qa_mapping values(1,'Alice','Sue','R','D','K','V','FA','FS',null,now(),true,'active','approved'),(2,'Bob','Other','R','D','K','V','FA','FS',null,now(),true,'active','approved');
    create table input_attempts(resolved text);grant insert,select on input_attempts to authenticated;`);
  for(const [n,name,role,active]of[[1,'Alice','FI',true],[2,'Sue','SPV',true],[3,'Developer','DEV',true],[4,'Sue','SPV',false]])
    await db.query('insert into app_users values($1,$2,$3,$4)',[id(n),name,role,active]);
  await db.exec(readFileSync('supabase/migrations/20261025093000_scope_internal_qa_resolver.sql','utf8'));
  await check('anonymous resolver execution revoked',async()=>assert.equal((await db.query("select has_function_privilege('anon','resolve_unique_qa_fi(text,text,text,text,text,text,text)','EXECUTE') allowed")).rows[0].allowed,false));
  await check('unprovisioned metadata DEV cannot query mappings',async()=>actor(99,async()=>assert.equal((await db.query(query,['Sue'])).rows.length,0)));
  await check('FI direct lookup is denied',async()=>actor(1,async()=>assert.equal((await db.query(query,['Sue'])).rows.length,0)));
  await check('SPV can resolve own scope',async()=>actor(2,async()=>assert.equal((await db.query(query,['Sue'])).rows[0].qa_fi,'Alice')));
  await check('SPV cannot query another scope',async()=>actor(2,async()=>assert.equal((await db.query(query,['Other'])).rows.length,0)));
  await check('inactive SPV denied',async()=>actor(4,async()=>assert.equal((await db.query(query,['Sue'])).rows.length,0)));
  await check('DEV and server lookups preserved',async()=>{
    await actor(3,async()=>assert.equal((await db.query(query,['Other'])).rows[0].qa_fi,'Bob'));
    await actor(99,async()=>assert.equal((await db.query(query,['Sue'])).rows[0].qa_fi,'Alice'),'service_role');
  });
  await db.exec(`create function invoker_assignment() returns trigger language plpgsql as $$begin
    select r.qa_fi into new.resolved from public.resolve_unique_qa_fi('Sue','R','D','K','V','FA','FS') r;
    return new;end$$;create trigger assignment before insert on input_attempts for each row execute function invoker_assignment();`);
  await check('FI invoker trigger retains resolver access',async()=>actor(1,async()=>assert.equal((await db.query('insert into input_attempts values(null) returning resolved')).rows[0].resolved,'Alice')));
  console.log(`${passed} resolver boundary checks passed`);
}catch(error){console.error(error.message,error.code);process.exitCode=1;}finally{await db.close();}
