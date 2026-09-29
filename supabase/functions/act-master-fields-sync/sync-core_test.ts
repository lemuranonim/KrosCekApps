import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { mapExportRow, normalizeFieldNumber, reconcile } from "./sync-core.ts";

function test(name: string, body: () => void) {
  try {
    body();
    console.log(`ok - ${name}`);
  } catch (error) {
    console.error(`not ok - ${name}`);
    throw error;
  }
}

test("normalizes field numbers without changing internal punctuation", () => {
  assert.equal(normalizeFieldNumber("  dc6 fhk045\u00a0"), "DC6FHK045");
  assert.equal(normalizeFieldNumber("dc6-fhk045"), "DC6-FHK045");
});

test("maps the ACT export headers used by Planting", () => {
  const row = mapExportRow(
    {
      "Field Number": "DC6FHK045",
      Farmer: "Farmer A",
      Organizer: "Grower A",
      Hybrid: "ax04",
      "Planted Area(Ha)": "1,25",
      "PLD Area(Ha)": 0.25,
      "Effective Area(Ha)": 1,
      "Female Date": "2026-08-31",
      "Field Assistant": "FA Lama",
      "Field Assistant Now": "FA Baru",
      "Geometry WKT": "POLYGON((112 -7,113 -7,113 -8,112 -7))",
    },
    "SC",
    2,
  );

  assert.deepEqual(row.validationErrors, []);
  assert.equal(row.sourcePayload.field_number, "DC6FHK045");
  assert.equal(row.sourcePayload.hybrid, "AX04");
  assert.equal(row.sourcePayload.type, "Sweet Corn");
  assert.equal(row.sourcePayload.total_area_planted_ha, 1.25);
  assert.equal(row.sourcePayload.fa, "FA Baru");
  assert.equal(
    row.sourcePayload.geometry_wkt,
    "POLYGON((112 -7,113 -7,113 -8,112 -7))",
  );
  assert.equal("coordinate" in row.sourcePayload, false);
});

test("detects the reported DC6FHK045 hybrid change", () => {
  const source = mapExportRow(
    {
      FN: "DC6FHK045",
      Hybrid: "AX04",
      "Planted Area(Ha)": 0.5,
    },
    "SC",
    2,
  );
  const result = reconcile(
    [source],
    [{
      field_number: "DC6FHK045",
      hybrid: "AX01",
      total_area_planted_ha: 0.5,
      type: "Field Corn",
    }],
  );

  const change = result.changes.find((item) => item.fieldNumberNorm === "DC6FHK045");
  assert.equal(change?.changeKind, "UPDATE");
  assert.deepEqual(change?.changedColumns.hybrid, { old: "AX01", new: "AX04" });
  assert.deepEqual(change?.changedColumns.type, { old: "Field Corn", new: "Sweet Corn" });
  assert.equal(result.summary.update, 1);
});

test("classifies a new ACT field as insert", () => {
  const source = mapExportRow({ FN: "DC6NEW001", Hybrid: "AX05" }, "FC", 2);
  const result = reconcile([source], []);
  assert.equal(result.changes[0].changeKind, "INSERT");
  assert.equal(result.summary.insert, 1);
});

test("blocks duplicate field numbers across ACT source files", () => {
  const fc = mapExportRow({ FN: "DUP001", Hybrid: "ADV01" }, "FC", 2);
  const sc = mapExportRow({ FN: "dup001", Hybrid: "AX04" }, "SC", 2);
  const result = reconcile([fc, sc], [{ field_number: "DUP001", hybrid: "OLD" }]);
  assert.equal(result.changes[0].changeKind, "CONFLICT_SOURCE_DUPLICATE");
  assert.equal(result.changes.filter((item) => item.fieldNumberNorm === "DUP001").length, 1);
  assert.equal(result.summary.blockers, 1);
});

test("blocks inconsistent planted, discarded and effective areas", () => {
  const row = mapExportRow(
    {
      FN: "AREA001",
      "Planted Area(Ha)": 1,
      "PLD Area(Ha)": 0.2,
      "Effective Area(Ha)": 0.7,
    },
    "FC",
    2,
  );
  assert.ok(row.validationErrors.includes("area_reconciliation_mismatch"));
  const result = reconcile([row], []);
  assert.equal(result.changes[0].changeKind, "INVALID");
});

test("maps ACT Harvest values into the managed harvest fields", () => {
  const row = mapExportRow(
    {
      "Field Number": "DC6HAR001",
      "Planted Area(Ha)": 0.75,
      "Harvested Area": "0,50",
      Weight: "1.250,75",
    },
    "FC",
    2,
  );

  assert.deepEqual(row.validationErrors, []);
  assert.equal(row.sourcePayload.harvested_area_ha, 0.5);
  assert.equal(row.sourcePayload.harvested_qty_kg, 1250.75);
});

test("missing ACT rows are informational and never actionable", () => {
  const result = reconcile([], [{ field_number: "KC_ONLY_001", hybrid: "AX01" }]);
  assert.equal(result.changes[0].changeKind, "MISSING_SOURCE");
  assert.equal(result.summary.actionable, 0);
});

test("sync migrations preserve PLD actual area and review unsafe Harvest area", () => {
  const mergeSql = readFileSync(
    new URL("../../migrations/20260928100000_fix_pld_and_add_harvest_sync.sql", import.meta.url),
    "utf8",
  );
  const scheduleSql = readFileSync(
    new URL("../../migrations/20260928102000_schedule_act_season_ranges.sql", import.meta.url),
    "utf8",
  );
  const reviewFallbackSql = readFileSync(
    new URL(
      "../../migrations/20260928103000_fix_harvest_review_area_fallback.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const monitorSql = readFileSync(
    new URL(
      "../../migrations/20260929010000_add_act_data_monitor_rpc.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const plantingMonitorSql = readFileSync(
    new URL(
      "../../migrations/20260929013000_split_act_and_planting_monitor.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const scopedPlantingMonitorSql = readFileSync(
    new URL(
      "../../migrations/20260929014500_scope_planting_monitor_by_role.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const scopedDailySyncSql = readFileSync(
    new URL(
      "../../migrations/20260929021500_add_scoped_daily_act_sync_results.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const pldLifecycleSql = readFileSync(
    new URL(
      "../../migrations/20260929033000_add_audit_pld_lifecycle_and_revision_history.sql",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(mergeSql, /p\.actual_planted_area_ha - p\.final_nett_area_ha/);
  assert.match(mergeSql, /coalesce\(max\(h\.harvested_area_ha\), 0\)/);
  assert.match(mergeSql, /REPORTED_AREA_EXCEEDS_EFFECTIVE_AREA/);
  assert.match(mergeSql, /NEEDS_CONFIRMATION/);
  assert.match(reviewFallbackSql, /refresh_act_sync_harvest_reviews/);
  assert.match(
    reviewFallbackSql,
    /source_payload ->> 'effective_area_ha'[\s\S]*source_payload ->> 'total_area_planted_ha'/,
  );
  assert.match(scheduleSql, /make_date\(v_season_year, 3, 1\)/);
  assert.match(scheduleSql, /make_date\(v_season_year, 5, 1\)/);
  assert.match(monitorSql, /get_act_sync_public_history/);
  assert.match(monitorSql, /r\.status = 'COMPLETED'/);
  assert.match(monitorSql, /mf\.qa_fi/);
  assert.match(plantingMonitorSql, /get_planting_data_monitor_summary/);
  assert.match(
    plantingMonitorSql,
    /planted_area_ha - a\.effective_area_ha/,
  );
  assert.match(
    plantingMonitorSql,
    /effective_area_ha - a\.harvested_area_ha/,
  );
  assert.match(plantingMonitorSql, /least\(raw_harvested_area_ha, effective_area_ha\)/);
  assert.match(scopedPlantingMonitorSql, /u\.id = auth\.uid\(\)/);
  assert.match(scopedPlantingMonitorSql, /scope\.role = 'SPV'/);
  assert.match(scopedPlantingMonitorSql, /scope\.role = 'FI'/);
  assert.match(scopedPlantingMonitorSql, /act_monitor_name_matches\(mf\.qa_fi/);
  assert.match(scopedPlantingMonitorSql, /auth\.role\(\) = 'service_role'/);
  assert.match(scopedDailySyncSql, /get_act_sync_scoped_daily_summary/);
  assert.match(scopedDailySyncSql, /get_act_sync_scoped_daily_changes/);
  assert.match(scopedDailySyncSql, /u\.id = auth\.uid\(\)/);
  assert.match(scopedDailySyncSql, /act_monitor_name_matches\(field_data\.qa_spv/);
  assert.match(scopedDailySyncSql, /act_monitor_name_matches\(field_data\.qa_fi/);
  assert.match(scopedDailySyncSql, /least\(greatest\(coalesce\(p_limit, 20\), 1\), 50\)/);
  assert.match(scopedDailySyncSql, /latest\.status = 'COMPLETED'/);
  assert.match(pldLifecycleSql, /create table if not exists public\.audit_pld_lifecycle/);
  assert.match(pldLifecycleSql, /create table if not exists public\.audit_revision_history/);
  assert.match(pldLifecycleSql, /PLD_ACT_CONFIRMED_LOCKED/);
  assert.match(pldLifecycleSql, /before update or delete/);
  assert.match(pldLifecycleSql, /status in \('PENDING', 'CONFIRMED', 'UPDATED'\)/);
  assert.match(pldLifecycleSql, /v_effective is not null and v_effective <= 0/);
  assert.match(pldLifecycleSql, /run\.status in \('APPLYING', 'COMPLETED'\)/);
  assert.match(pldLifecycleSql, /get_field_pld_audit_lifecycle/);
});
