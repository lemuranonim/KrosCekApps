// Run against an isolated in-memory PostgreSQL, never the linked project.
// Install @electric-sql/pglite into .dart_tool/act-sync-tests and point NODE_PATH
// at its node_modules directory; see README.md for the exact PowerShell commands.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import {
  MANAGED_FIELDS,
  mapExportRow,
  type ParsedSourceRow,
  reconcile,
} from "./sync-core.ts";

const { PGlite } = createRequire(import.meta.url)("@electric-sql/pglite");
const db = new PGlite();
const migration = (name: string) =>
  readFileSync(
    new URL(`../../migrations/${name}.sql`, import.meta.url),
    "utf8",
  );
const functionSql = (sql: string, name: string) => {
  const match = sql.match(
    new RegExp(
      `create or replace function public\\.${name}\\([\\s\\S]*?as \\$\\$[\\s\\S]*?\\$\\$;`,
      "i",
    ),
  );
  assert.ok(match, `Missing SQL function ${name}`);
  return match[0];
};
const numericFields = new Set([
  "total_area_planted_ha",
  "discard_area_ha",
  "effective_area_ha",
  "harvested_area_ha",
  "harvested_qty_kg",
]);
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create table public.master_fields (
    id bigint generated always as identity primary key,
    ${
  MANAGED_FIELDS.map((field) =>
    `${field} ${
      numericFields.has(field)
        ? "numeric"
        : field === "planting_date_pdn"
        ? "date"
        : "text"
    }`
  ).join(",\n")
},
    coordinate text, geometry_source text, is_active boolean default true,
    qa_fi text, correction_geometry_wkt text
  );
  create index master_fields_test_normalized_fn on public.master_fields (
    (upper(regexp_replace(btrim(field_number), '[[:space:]]+', '', 'g')))
  );
`);
const baseSql = migration("20260924090000_create_act_master_fields_sync");
await db.exec(baseSql.slice(0, baseSql.indexOf("create or replace function")));
const harvestSql = migration("20260928100000_fix_pld_and_add_harvest_sync");
await db.exec(
  harvestSql.slice(0, harvestSql.indexOf("create or replace function")),
);
await db.exec(functionSql(
  migration("20260928100000_fix_pld_and_add_harvest_sync"),
  "act_master_fields_sync_snapshot",
));
await db.exec(functionSql(
  migration("20260930150000_fix_pld_columns_and_backfill_field_corn_type"),
  "act_master_fields_values_differ",
));
await db.exec(functionSql(
  migration("20260928101000_apply_act_harvest_fields"),
  "apply_act_master_fields_sync",
));
await db.exec(
  migration("20261014090000_resolve_compatible_act_source_duplicates"),
);
await db.exec(migration("20261015000000_optimize_act_duplicate_selection"));
await db.exec(migration("20261015010000_scope_act_harvest_reconciliation"));
await db.exec(migration("20261015011500_use_indexed_act_harvest_field_scope"));
await db.exec(functionSql(
  migration("20260930060000_optimize_act_pld_merge_reviews"),
  "merge_act_sync_pld_page",
));

const basic = {
  FN: "DUP001",
  "Female Date": "2026-06-11",
  Hybrid: "AX09",
  "Planted Area(Ha)": 0.2,
};
const row = (
  extra: Record<string, unknown> = {},
  position = 2,
  source: "FC" | "SC" = "FC",
) => mapExportRow({ ...basic, ...extra }, source, position);
const complete = {
  Farmer: "Farmer A",
  Organizer: "Grower A",
  Village: "Village A",
};

type Scenario = {
  name: string;
  rows: ParsedSourceRow[];
  selected?: number;
  reason?: string;
};
const scenarios: Scenario[] = [
  {
    name: "reported incomplete and complete snapshots in separate batches",
    rows: [row({}, 8601), row(complete, 29474)],
    selected: 29474,
  },
  {
    name: "complete snapshot comes first",
    rows: [row(complete), row({}, 3)],
    selected: 2,
  },
  {
    name: "same-batch duplicates",
    rows: [row(), row(complete, 3)],
    selected: 3,
  },
  {
    name: "three compatible snapshots",
    rows: [row(), row({ Farmer: "Farmer A" }, 3), row(complete, 4)],
    selected: 4,
  },
  {
    name: "equal complete snapshots choose stable position",
    rows: [row(complete, 30), row(complete, 2)],
    selected: 2,
  },
  {
    name: "zero area is a populated value",
    rows: [
      row({ "Planted Area(Ha)": 0 }),
      row({ ...complete, "Planted Area(Ha)": 0 }, 3),
    ],
    selected: 3,
  },
  {
    name: "Advance wins over a more complete No Advance row",
    rows: [
      row({ _act_advance_status: 1 }),
      row({ ...complete, _act_advance_status: 2 }, 3),
    ],
    selected: 2,
    reason: "ADVANCE_STATUS",
  },
  {
    name: "Advance is authoritative over other populated metadata",
    rows: [
      row({ Farmer: "Authoritative farmer", Advance: "Advance" }),
      row({ ...complete, _act_advance_status: 2 }, 3),
    ],
    selected: 2,
    reason: "ADVANCE_STATUS",
  },
  {
    name: "several compatible Advance rows choose the most complete",
    rows: [
      row({ _act_advance_status: 1 }),
      row({ ...complete, _act_advance_status: "1" }, 3),
    ],
    selected: 3,
    reason: "ADVANCE_STATUS",
  },
  {
    name: "No Advance text is not Advance",
    rows: [row({ Advance: "No Advance" }), row(complete, 3)],
    selected: 3,
  },
  {
    name: "Custom Advance is not promoted to Advance",
    rows: [row({ Advance: "Custom Advance" }), row(complete, 3)],
    selected: 3,
  },
  {
    name: "conflicting farmers",
    rows: [
      row({ Farmer: "Farmer A" }),
      row({ ...complete, Farmer: "Farmer B" }, 3),
    ],
  },
  {
    name: "complementary rows are not combined",
    rows: [row({ Farmer: "Farmer A" }), row({ Village: "Village A" }, 3)],
  },
  {
    name: "different planting dates remain blocked even with Advance",
    rows: [
      row(complete),
      row(
        { ...complete, "Female Date": "2026-10-01", _act_advance_status: 1 },
        3,
      ),
    ],
  },
  {
    name: "different hybrids",
    rows: [row(complete), row({ ...complete, Hybrid: "AX05" }, 3)],
  },
  {
    name: "different areas",
    rows: [row(complete), row({ ...complete, "Planted Area(Ha)": 0.3 }, 3)],
  },
  {
    name: "missing planting identity",
    rows: [row({ "Female Date": null }), row(complete, 3)],
  },
  {
    name: "invalid duplicate remains blocked",
    rows: [row({ ...complete, "PLD Area(Ha)": -1 }), row(complete, 3)],
  },
  { name: "cross-crop FN", rows: [row(complete), row(complete, 3, "SC")] },
  {
    name: "conflicting Advance rows remain blocked",
    rows: [
      row({ ...complete, _act_advance_status: 1 }),
      row({ ...complete, Farmer: "Other farmer", _act_advance_status: 1 }, 3),
    ],
  },
];

async function seed(
  rows: ParsedSourceRow[],
  minimumRows = 1,
  maxChangeRatio = 1,
) {
  await db.exec(
    `truncate public.act_master_fields_change_log, public.act_sync_changes,
    public.act_sync_rows, public.act_sync_runs, public.master_fields restart identity cascade`,
  );
  const counts: Record<string, number> = {};
  for (const sourceRow of rows) {
    counts[sourceRow.sourceType] = (counts[sourceRow.sourceType] ?? 0) + 1;
  }
  const inserted = await db.query(
    `insert into public.act_sync_runs
    (status, dry_run, source_from, source_to, requested_sources, source_counts, source_meta)
    values ('VALIDATING', false, '2026-03-01', '2026-10-14', $1, $2, $3) returning id`,
    [
      Object.keys(counts),
      JSON.stringify(counts),
      JSON.stringify({
        sync_config: {
          minimum_rows: minimumRows,
          max_change_ratio: maxChangeRatio,
        },
      }),
    ],
  );
  const runId = inserted.rows[0].id;
  for (const sourceRow of rows) {
    await db.query(
      `insert into public.act_sync_rows
      (run_id, source_type, source_row, field_number_raw, field_number_norm,
        raw_payload, source_payload, row_hash, validation_errors)
      values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [
        runId,
        sourceRow.sourceType,
        sourceRow.sourceRow,
        sourceRow.fieldNumberRaw,
        sourceRow.fieldNumberNorm,
        JSON.stringify(sourceRow.rawPayload),
        JSON.stringify(sourceRow.sourcePayload),
        createHash("sha256").update(JSON.stringify(sourceRow.sourcePayload))
          .digest("hex"),
        sourceRow.validationErrors,
      ],
    );
  }
  return runId;
}

async function prepareBatches(runId: string, rows: ParsedSourceRow[]) {
  // Replay each range to verify resumable processing is idempotent, including
  // winners located in a later batch than their ignored incomplete duplicate.
  for (const source of [...new Set(rows.map((item) => item.sourceType))]) {
    const maxRow = Math.max(
      ...rows.filter((item) => item.sourceType === source).map((item) =>
        item.sourceRow
      ),
    );
    for (let start = 1; start <= maxRow; start += 2000) {
      for (let retry = 0; retry < 2; retry++) {
        await db.query(
          "select public.prepare_act_master_fields_sync_batch($1,$2,$3,$4)",
          [runId, source, start, Math.min(start + 1999, maxRow)],
        );
      }
    }
  }
}

let passed = 0;
try {
  for (const scenario of scenarios) {
    const js = reconcile(scenario.rows, []);
    const expectedStatus = scenario.selected === undefined
      ? "BLOCKED"
      : "READY";
    const expectedKind = scenario.selected === undefined
      ? "CONFLICT_SOURCE_DUPLICATE"
      : "INSERT";
    assert.equal(js.changes[0].changeKind, expectedKind, scenario.name);
    assert.equal(
      js.sourceDuplicateResolutions[0]?.selected_source_row,
      scenario.selected,
      scenario.name,
    );
    const runId = await seed(scenario.rows);
    const choice = (await db.query(
      "select * from public.act_sync_source_duplicate_choices($1)",
      [runId],
    )).rows[0];
    assert.equal(
      choice.selected_source_row ?? undefined,
      scenario.selected,
      scenario.name,
    );
    if (scenario.selected !== undefined) {
      assert.equal(
        choice.selection_reason,
        scenario.reason ?? "MOST_COMPLETE_COMPATIBLE_ROW",
        scenario.name,
      );
      assert.equal(
        js.sourceDuplicateResolutions[0].reason,
        choice.selection_reason,
      );
    }
    await prepareBatches(runId, scenario.rows);
    const result = (await db.query(
      "select public.finalize_act_master_fields_sync_batches($1) as result",
      [runId],
    )).rows[0].result;
    assert.equal(result.status, expectedStatus, scenario.name);
    const changes =
      (await db.query("select * from public.act_sync_changes where run_id=$1", [
        runId,
      ])).rows;
    assert.equal(changes.length, 1, scenario.name);
    assert.equal(changes[0].change_kind, expectedKind, scenario.name);
    if (scenario.selected !== undefined) {
      assert.deepEqual(
        changes[0].source_payload,
        js.changes[0].sourcePayload,
        scenario.name,
      );
      assert.equal(Number(result.summary.resolved_source_duplicate), 1);
      assert.equal(
        Number(result.summary.ignored_source_duplicate_rows),
        scenario.rows.length - 1,
      );
    } else {
      assert.ok(
        result.summary.guard_errors.includes("source_duplicate_fields:1"),
      );
      await assert.rejects(
        db.query("select public.apply_act_master_fields_sync($1)", [runId]),
        /must be READY/,
      );
    }
    assert.equal(
      Number(
        (await db.query(
          "select count(*) as count from public.act_sync_rows where run_id=$1",
          [runId],
        )).rows[0].count,
      ),
      scenario.rows.length,
    );
    // Test the non-resumable workbook path against the exact same staged rows.
    await db.query(
      "update public.act_sync_runs set status='VALIDATING' where id=$1",
      [runId],
    );
    const fallback = (await db.query(
      "select public.prepare_act_master_fields_sync($1) as result",
      [runId],
    )).rows[0].result;
    assert.equal(
      fallback.status,
      expectedStatus,
      `${scenario.name} (workbook fallback)`,
    );
    assert.deepEqual(fallback.summary, result.summary);
    console.log(`ok - PostgreSQL/TypeScript parity: ${scenario.name}`);
    passed++;
  }

  const duplicateRows = [row(), row(complete, 3)];
  let runId = await seed(duplicateRows);
  await db.query(
    `insert into public.master_fields (field_number, hybrid, total_area_planted_ha,
    planting_date_pdn, type, qa_fi, correction_geometry_wkt)
    values ('DUP001','AX09',0.2,'2026-06-11','Field Corn','KC auditor','KC polygon')`,
  );
  await prepareBatches(runId, duplicateRows);
  const ready = (await db.query(
    "select public.finalize_act_master_fields_sync_batches($1) as result",
    [runId],
  )).rows[0].result;
  assert.equal(ready.status, "READY");
  const applied = (await db.query(
    "select public.apply_act_master_fields_sync($1) as result",
    [runId],
  )).rows[0].result;
  assert.ok(applied);
  const current = (await db.query("select * from public.master_fields")).rows;
  assert.equal(current.length, 1);
  assert.equal(current[0].farmer_name, "Farmer A");
  assert.equal(current[0].qa_fi, "KC auditor");
  assert.equal(current[0].correction_geometry_wkt, "KC polygon");
  assert.equal(
    Number(
      (await db.query(
        "select count(*) as count from public.act_master_fields_change_log",
      )).rows[0].count,
    ),
    1,
  );
  assert.equal(
    Number(
      (await db.query("select count(*) as count from public.act_sync_rows"))
        .rows[0].count,
    ),
    2,
  );
  const audit = (await db.query(
    "select source_meta from public.act_sync_runs where id=$1",
    [runId],
  )).rows[0].source_meta.source_duplicate_resolutions[0];
  assert.equal(audit.selected_source_row, 3);
  assert.equal(audit.candidate_rows.length, 2);
  console.log(
    "ok - applies one selected row, preserves KC QA/polygon and both raw candidates, records selection audit",
  );
  passed++;

  runId = await seed(duplicateRows);
  const harvestPage = JSON.stringify([{
    source_row: 1,
    harvest_date: "2026-10-10",
    field_number_norm: "DUP001",
    harvested_area_ha: 0.5,
    harvested_qty_kg: 100,
  }]);
  for (let retry = 0; retry < 2; retry++) {
    await db.query("select public.merge_act_sync_harvest_page($1,$2)", [
      runId,
      harvestPage,
    ]);
  }
  const pldPage = JSON.stringify([{
    field_number_norm: "DUP001",
    approved_at: "2026-10-11",
    source_row: 1,
    planted_area_ha: 0.2,
    effective_area_ha: 0.1,
    discard_area_ha: 0.1,
  }]);
  await db.query("select public.merge_act_sync_pld_page($1,$2)", [
    runId,
    pldPage,
  ]);
  await db.query("select public.refresh_act_sync_harvest_reviews($1)", [runId]);
  const reviews = (await db.query(
    "select * from public.act_sync_harvest_reviews where run_id=$1",
    [runId],
  )).rows;
  assert.equal(reviews.length, 1);
  assert.equal(Number(reviews[0].safe_harvest_area_ha), 0.1);
  assert.equal(Number(reviews[0].reported_harvest_area_ha), 0.5);
  await prepareBatches(runId, duplicateRows);
  const enriched = (await db.query(
    "select public.finalize_act_master_fields_sync_batches($1) as result",
    [runId],
  )).rows[0].result;
  assert.equal(enriched.status, "READY");
  const enrichedPayload = (await db.query(
    "select source_payload from public.act_sync_changes where run_id=$1",
    [runId],
  )).rows[0].source_payload;
  assert.equal(enrichedPayload.harvested_qty_kg, 100);
  assert.equal(enrichedPayload.harvested_area_ha, 0.1);
  assert.equal(enrichedPayload.total_area_planted_ha, 0.2);
  assert.equal(enrichedPayload.effective_area_ha, 0.1);
  console.log(
    "ok - Harvest retries and PLD overlays create one review and never double-count weight for duplicate FN",
  );
  passed++;

  for (
    const [minimumRows, maxChangeRatio, expectedGuard] of [
      [100, 1, "source_rows_below_minimum:"],
      [2, 1, "source_rows_below_minimum:"],
      [1, 0, "change_ratio_exceeded:"],
      [1, 0.75, "change_ratio_exceeded:"],
    ] as const
  ) {
    runId = await seed(duplicateRows, minimumRows, maxChangeRatio);
    await prepareBatches(runId, duplicateRows);
    const result = (await db.query(
      "select public.finalize_act_master_fields_sync_batches($1) as result",
      [runId],
    )).rows[0].result;
    assert.equal(result.status, "BLOCKED");
    assert.ok(
      result.summary.guard_errors.some((error: string) =>
        error.startsWith(expectedGuard)
      ),
    );
    console.log(`ok - resolving duplicates preserves guard ${expectedGuard}`);
    passed++;
  }

  runId = await seed(duplicateRows);
  await db.exec(
    "insert into public.master_fields (field_number) values ('DUP001'), (' dup001 ')",
  );
  await prepareBatches(runId, duplicateRows);
  const kcConflict = (await db.query(
    "select public.finalize_act_master_fields_sync_batches($1) as result",
    [runId],
  )).rows[0].result;
  assert.equal(kcConflict.status, "BLOCKED");
  assert.equal(kcConflict.summary.conflict_kc_duplicate, 1);
  console.log(
    "ok - normalized KC duplicates remain blocked without a batch upsert error",
  );
  passed++;

  // Exercise a full-sized nightly snapshot using the same normalized FN index
  // as production, without ACT access or writes to the linked Supabase project.
  runId = await seed(duplicateRows, 30000);
  await db.query(
    `insert into public.act_sync_rows
    (run_id, source_type, source_row, field_number_raw, field_number_norm,
      source_payload, row_hash)
    select $1, 'FC', n + 3, 'PERF' || n, 'PERF' || n,
      jsonb_build_object('field_number', 'PERF' || n, 'type', 'Field Corn',
        'planting_date_pdn', '2026-06-11', 'hybrid', 'AX09', 'total_area_planted_ha', 0.2),
      md5(n::text)
    from generate_series(1,34590) n`,
    [runId],
  );
  await db.query(
    "update public.act_sync_runs set source_counts='{\"FC\":34592}' where id=$1",
    [runId],
  );
  await db.exec(`insert into public.master_fields
    (field_number, type, hybrid, planting_date_pdn, total_area_planted_ha,
      farmer_name, grower, village_desa)
    select distinct on (field_number_norm) field_number_norm, source_payload ->> 'type',
      source_payload ->> 'hybrid', (source_payload ->> 'planting_date_pdn')::date,
      (source_payload ->> 'total_area_planted_ha')::numeric,
      source_payload ->> 'farmer_name', source_payload ->> 'grower', source_payload ->> 'village_desa'
    from public.act_sync_rows order by field_number_norm, source_row desc`);
  const started = Date.now();
  for (let start = 1; start <= 34593; start += 2000) {
    await db.query(
      "select public.prepare_act_master_fields_sync_batch($1,'FC',$2,$3)",
      [runId, start, Math.min(start + 1999, 34593)],
    );
  }
  const fullSnapshot = (await db.query(
    "select public.finalize_act_master_fields_sync_batches($1) as result",
    [runId],
  )).rows[0].result;
  assert.equal(fullSnapshot.status, "READY");
  assert.equal(fullSnapshot.summary.source_rows, 34592);
  assert.equal(fullSnapshot.summary.source_rows_after_deduplication, 34591);
  assert.equal(fullSnapshot.summary.unchanged, 34591);
  assert.equal(fullSnapshot.summary.resolved_source_duplicate, 1);
  console.log(
    `ok - 34,592-row snapshot resolves one duplicate in ${
      Date.now() - started
    }ms locally`,
  );
  passed++;
  const scopedIds = (await db.query(
    "select * from public.act_sync_reconciliation_row_ids($1,$2)",
    [runId, ["DUP001", "PERF1", "MISSING_FN"]],
  )).rows;
  assert.equal(scopedIds.length, 2);
  assert.deepEqual(
    scopedIds.map((item: { field_number_norm: string }) =>
      item.field_number_norm
    ).sort(),
    ["DUP001", "PERF1"],
  );
  const unrelatedDuplicate = (await db.query(
    "select * from public.act_sync_source_duplicate_choices_for_fields($1,$2)",
    [runId, ["PERF1"]],
  )).rows;
  assert.equal(unrelatedDuplicate.length, 0);
  const emptyScope = (await db.query(
    "select * from public.act_sync_reconciliation_row_ids($1,null)",
    [runId],
  )).rows;
  assert.equal(emptyScope.length, 0);
  console.log(
    "ok - scoped selection returns only affected FN IDs and never unrelated duplicates",
  );
  passed++;

  // The previous implementation returned every full Planting JSON row before
  // filtering the Harvest batch. Include large polygons on unrelated FN so
  // this exercises the real production shape, not only tiny source payloads.
  await db.query(
    `update public.act_sync_rows set source_payload = source_payload ||
    jsonb_build_object('geometry_wkt', 'POLYGON((' || repeat('112.123456 -7.123456,',250) ||
      '112.123456 -7.123456))') where run_id=$1 and field_number_norm like 'PERF%'`,
    [runId],
  );
  await db.query(
    "update public.act_sync_runs set status='EXTRACTING' where id=$1",
    [runId],
  );
  const fullHarvestPage = JSON.stringify(
    Array.from({ length: 2000 }, (_, index) => ({
      source_row: index + 1,
      harvest_date: "2026-10-12",
      field_number_norm: index === 0 ? "DUP001" : `PERF${index}`,
      harvested_area_ha: 0.1,
      harvested_qty_kg: 10,
    })),
  );
  const harvestStarted = Date.now();
  for (let retry = 0; retry < 2; retry++) {
    const merged = (await db.query(
      "select public.merge_act_sync_harvest_page($1,$2) as result",
      [runId, fullHarvestPage],
    )).rows[0].result;
    assert.equal(merged.received, 2000);
    assert.equal(merged.matched_events, 2000);
    assert.equal(merged.needs_review, 0);
  }
  const unaffected = (await db.query(
    `select source_payload from public.act_sync_rows
    where run_id=$1 and field_number_norm='PERF34590'`,
    [runId],
  )).rows[0].source_payload;
  assert.equal("harvested_qty_kg" in unaffected, false);
  const affected = (await db.query(
    `select source_payload from public.act_sync_rows
    where run_id=$1 and field_number_norm='PERF1'`,
    [runId],
  )).rows[0].source_payload;
  assert.equal(affected.harvested_qty_kg, 10);
  assert.equal(affected.geometry_wkt, unaffected.geometry_wkt);
  console.log(
    `ok - 2,000 Harvest events on 34,592 polygon payloads remain scoped and idempotent in ${
      Date.now() - harvestStarted
    }ms locally`,
  );
  passed++;
  console.log(`${passed} PostgreSQL integration checks passed`);
} finally {
  await db.close();
}
