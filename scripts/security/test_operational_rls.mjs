// Real PostgreSQL policy checks in an isolated in-memory PGlite database.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { readFileSync } from 'node:fs';
const { PGlite } = createRequire(resolve('.dart_tool/act-sync-tests/package.json'))('@electric-sql/pglite');
const db = new PGlite();
let passed = 0;
const indexedScope = process.argv.includes('--indexed-scope');
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

  if (indexedScope) {
    await db.exec(readFileSync('supabase/migrations/20261026100000_optimize_operational_scope_checks.sql','utf8'));
    const before = new Map();
    for (const id of [uid(1),uid(2),uid(3),uid(4),uid(5),uid(6),uid(99)]) {
      before.set(id, await asUser(id, async () =>
        (await db.query('select f from kroscek_readable_field_numbers() f order by f')).rows));
    }
    await db.exec(readFileSync('supabase/migrations/20261026110000_index_operational_assignment_scope.sql','utf8'));
    await test('indexed scope preserves every role and inactive/orphan result', async () => {
      for (const [id, expected] of before) {
        const actual = await asUser(id, async () =>
          (await db.query('select f from kroscek_readable_field_numbers() f order by f')).rows);
        assert.deepEqual(actual,expected,id);
      }
    });
    await test('indexed tokens preserve exact legacy name/list matching', async () => {
      const assignments = [null,'','Alice',' alice ','Alice Smith','Alice  Smith',
        'Alice,Bob','Alice; Bob','Alice|Bob','Alice/Bob','Alice & Bob','Alice dan Bob',
        'Alice AND Bob','Alice Anderson','Bob\tand\tAlice','Álice / Bob','A%_B'];
      for (const names of assignments) for (const actor of ['Alice','Bob','alice smith','Álice','A%_B','A','Other']) {
        const row = (await db.query(`select act_monitor_name_matches($1,$2) old,
          kroscek_assignment_name_tokens($1) @> array[lower(regexp_replace(btrim($2),'\\s+',' ','g'))] optimized`,[names,actor])).rows[0];
        assert.equal(row.optimized,row.old,JSON.stringify({names,actor}));
      }
    });
    await test('anonymous cannot execute scope or normalization helpers', async () => {
      for (const signature of ['kroscek_readable_field_numbers()','kroscek_assignment_name_tokens(text)']) {
        assert.equal((await db.query("select has_function_privilege('anon',$1,'EXECUTE') allowed",[signature])).rows[0].allowed,false);
      }
    });
  }

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
  if (indexedScope) {
    await test('generative upsert remains scoped to the assigned FI', async () => {
      await asUser(uid(1), async () => {
        await db.exec("insert into audit_generative(field_number,value) values('A','checkpoint 2')");
        assert.equal((await db.query("update audit_generative set value='updated checkpoint 2' where field_number='A' returning value")).rows[0].value,'updated checkpoint 2');
      });
      await assert.rejects(() => asUser(uid(2), () => db.exec("insert into audit_generative(field_number,value) values('A','other account')")),/row-level security/);
      await assert.rejects(() => asUser(uid(1), () => db.exec("insert into audit_generative(field_number,value) values('MISSING','orphan')")),/row-level security/);
    });
    await db.exec(`insert into master_fields(field_number,qa_fi,qa_spv,area)
      select 'SYNTHETIC-'||n,'Unrelated FI '||n,'Unrelated SPV '||n,1 from generate_series(1,35000) n;
      analyze master_fields;`);
    await test('35,000 unrelated assignments use both GIN indexes', async () => {
      for (const [column,target,index] of [['qa_fi','alice','master_fields_qa_fi_assignment_tokens_idx'],
        ['qa_spv','sue','master_fields_qa_spv_assignment_tokens_idx']]) {
        const plan = await db.query(`explain (format json) select field_number from master_fields
          where kroscek_assignment_name_tokens(${column}) @> array[$1]`,[target]);
        assert.ok(JSON.stringify(plan.rows).includes(index),index);
      }
    });
    await test('audit upsert succeeds with 35,000 unrelated assignments', async () => {
      await db.exec('create unique index audit_generative_test_field_key on audit_generative(field_number)');
      const started = performance.now();
      await asUser(uid(1), async () => {
        const rows = await db.query(`insert into audit_generative(field_number,value) values('A','checkpoint 2')
          on conflict(field_number) do update set value=excluded.value returning field_number`);
        assert.equal(rows.rows[0].field_number,'A');
        assert.deepEqual((await db.query('select field_number from master_fields order by 1')).rows.map(r=>r.field_number),['A','AB']);
      });
      console.log(`35,000-row scoped audit upsert/read: ${Math.round(performance.now()-started)} ms locally`);
    });
  }
  console.log(`${passed} isolated PostgreSQL security checks passed`);
} finally { await db.close(); }
