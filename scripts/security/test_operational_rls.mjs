// Real PostgreSQL policy checks in an isolated in-memory PGlite database.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
const { PGlite } = createRequire(resolve('.dart_tool/act-sync-tests/package.json'))('@electric-sql/pglite');
const db = new PGlite();
let passed = 0;
async function test(name, callback) { await callback(); passed++; console.log('ok - ' + name); }
async function asUser(id, callback) {
  await db.exec('begin');
  try {
    await db.query("select set_config('request.jwt.claims',$1,true)", [JSON.stringify({ sub: id, role: 'authenticated' })]);
    await db.exec('set local role authenticated');
    return await callback();
  } finally { await db.exec('rollback'); }
}
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const names = ['master_fields','audit_vegetative','audit_generative','audit_pre_harvest','audit_harvest',
  'master_qa_mapping','field_qa_assignment','audit_sync_log','wilayah_resolve_log','import_logs',
  'master_field_geometry_history','seasons','provinsi','kabupaten','kecamatan','desa'];
try {
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; grant usage on schema auth to authenticated,anon;
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claims',true)::jsonb->>'sub','')::uuid $$;
    create table app_users(id uuid primary key,name text,role text,is_active boolean);
    create table master_fields(field_number text primary key,qa_fi text,qa_spv text,area numeric);
    create table master_qa_mapping(id serial primary key,region text,qa_fi text,qa_spv text,
      district_kab text,sub_district_kec text,village_desa text,fa text,field_spv text,supervisor text,
      manager text,ha numeric,status text,is_active boolean,approval_status text,change_reason text,
      created_at timestamptz default now(),updated_at timestamptz default now());`);
  for (const name of names.filter((n) => !['master_fields','master_qa_mapping'].includes(n))) {
    await db.exec(`create table ${name}(id serial primary key,field_number text,value text)`);
  }
  const matcher = readFileSync('supabase/migrations/20260929014500_scope_planting_monitor_by_role.sql','utf8');
  await db.exec(matcher.slice(0, matcher.indexOf('$$;') + 3));
  await db.exec('grant all on all tables in schema public to anon,authenticated,service_role; grant all on all sequences in schema public to anon,authenticated,service_role;');
  const migration = readFileSync('supabase/migrations/20261024083000_enforce_operational_api_membership.sql','utf8');
  await db.exec(migration);
  for (const [n,name,role,active] of [[1,'Alice','FI',true],[2,'Bob','FI',true],[3,'Sue','SPV',true],
    [4,'Lead','MANAGER',true],[5,'Guest','GUEST',true],[6,'Alice','FI',false]]) {
    await db.query('insert into app_users values($1,$2,$3,$4)',[uid(n),name,role,active]);
  }
  await db.exec(`insert into master_fields values ('A','Alice','Sue',1),('B','Bob','Other',2),('AB','Alice and Bob','Sue',3);
    insert into audit_vegetative(field_number) values('A'),('B'),('AB');
    insert into master_qa_mapping(region,qa_fi,qa_spv,approval_status) values('Region 1','Alice','Sue','approved');
    create function test_geometry_history() returns trigger language plpgsql as $$ begin
      insert into master_field_geometry_history(field_number,value) values(new.field_number,'changed');return new;end $$;
    create trigger test_history after update of area on master_fields for each row execute function test_geometry_history();`);

  await test('anonymous table grants removed for all sixteen targets', async () => {
    for (const name of names) {
      const result = await db.query("select has_table_privilege('anon',$1,'SELECT') or has_table_privilege('anon',$1,'UPDATE') as exposed", [name]);
      assert.equal(result.rows[0].exposed,false,name);
    }
  });
  await test('FI reads only exact owned assignments and nested audits', async () => asUser(uid(1), async () => {
    assert.deepEqual((await db.query('select field_number from master_fields order by 1')).rows.map(r=>r.field_number),['A','AB']);
    assert.deepEqual((await db.query('select field_number from audit_vegetative order by 1')).rows.map(r=>r.field_number),['A','AB']);
  }));
  await test('FI cannot modify another assignment', async () => asUser(uid(1), async () => {
    assert.equal((await db.query("update master_fields set area=10 where field_number='B' returning *")).rows.length,0);
  }));
  await test('assigned FI can edit field and invoker trigger can record history', async () => asUser(uid(1), async () => {
    assert.equal((await db.query("update master_fields set area=10 where field_number='A' returning *")).rows.length,1);
    assert.equal((await db.query('select * from master_field_geometry_history')).rows.length,1);
  }));
  await test('client cannot forge geometry history', async () => {
    await assert.rejects(() => asUser(uid(1), () => db.exec("insert into master_field_geometry_history(field_number) values('A')")),/row-level security/);
  });
  await test('FI cannot transfer QA ownership', async () => {
    await assert.rejects(() => asUser(uid(1), () => db.exec("update master_fields set qa_fi='Bob' where field_number='A'")),/assignment workflow/);
  });
  await test('FI can edit approved mapping details but cannot self-approve or impersonate', async () => {
    await asUser(uid(1), async () => assert.equal((await db.query("update master_qa_mapping set village_desa='New' returning *")).rows.length,1));
    await assert.rejects(() => asUser(uid(1), () => db.exec("update master_qa_mapping set qa_fi='Bob'")),/assignment identity/);
  });
  await test('new FI mapping is forced to own identity and pending approval', async () => asUser(uid(1), async () => {
    const row = (await db.query("insert into master_qa_mapping(qa_fi,qa_spv,approval_status) values('Bob','Other','approved') returning *")).rows[0];
    assert.equal(row.qa_fi,'Alice');assert.equal(row.qa_spv,null);assert.equal(row.approval_status,'pending');
  }));
  await test('SPV is restricted to supervisor ownership', async () => asUser(uid(3), async () => {
    assert.deepEqual((await db.query('select field_number from master_fields order by 1')).rows.map(r=>r.field_number),['A','AB']);
  }));
  await test('manager can see all fields', async () => asUser(uid(4), async () => {
    assert.equal((await db.query('select * from master_fields')).rows.length,3);
  }));
  await test('guest cannot write or delete operational data', async () => asUser(uid(5), async () => {
    assert.equal((await db.query('select * from master_fields')).rows.length,3);
    assert.equal((await db.query('update master_fields set area=100 returning *')).rows.length,0);
    assert.equal((await db.query('delete from master_fields returning *')).rows.length,0);
  }));
  await test('inactive and unprovisioned accounts cannot read or write', async () => {
    for (const id of [uid(6),uid(99)]) await asUser(id, async () => {
      assert.equal((await db.query('select * from master_fields')).rows.length,0);
      assert.equal((await db.query('select * from audit_vegetative')).rows.length,0);
      assert.equal((await db.query('select * from provinsi')).rows.length,0);
    });
  });
  console.log(`${passed} isolated PostgreSQL security checks passed`);
} finally { await db.close(); }
