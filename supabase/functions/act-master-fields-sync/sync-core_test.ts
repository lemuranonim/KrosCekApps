import assert from "node:assert/strict";
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

test("missing ACT rows are informational and never actionable", () => {
  const result = reconcile([], [{ field_number: "KC_ONLY_001", hybrid: "AX01" }]);
  assert.equal(result.changes[0].changeKind, "MISSING_SOURCE");
  assert.equal(result.summary.actionable, 0);
});
