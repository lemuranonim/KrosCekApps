import assert from "node:assert/strict";
import * as XLSX from "npm:xlsx@0.18.5";
import { readFirstSheetRowsChunk } from "./xlsx-stream.ts";

function workbookBytes(): Uint8Array {
  const worksheet = XLSX.utils.aoa_to_sheet([
    ["ACT Planting Geometry Export"],
    ["Field Number", "Hybrid", "Geometry WKT", "Notes"],
    ["FN001", "AX01", "POLYGON((1 1,2 1,2 2,1 1))", "skip one"],
    ["FN002", "AX02", "POLYGON((2 2,3 2,3 3,2 2))", "skip two"],
    ["FN003", "AX03", "POLYGON((3 3,4 3,4 4,3 3))", "take three"],
    ["FN004", "AX04", "POLYGON((4 4,5 4,5 5,4 4))", "take four"],
    ["FN005", "AX05", "POLYGON((5 5,6 5,6 6,5 5))", "take five"],
  ]);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, "Geometry");
  const output = XLSX.write(workbook, {
    type: "array",
    bookType: "xlsx",
    bookSST: true,
  }) as ArrayBuffer | Uint8Array;
  return output instanceof Uint8Array ? output : new Uint8Array(output);
}

const normalize = (value: unknown) => String(value ?? "").trim().toLowerCase();
const isHeader = (values: ReadonlyMap<number, unknown>) =>
  [...values.values()].some((value) => normalize(value) === "field number");
const includeHeader = (value: unknown) =>
  new Set(["field number", "geometry wkt"]).has(normalize(value));

Deno.test("reads only the requested resumable XLSX rows and columns", async () => {
  const chunk = await readFirstSheetRowsChunk(
    workbookBytes(),
    2,
    2,
    isHeader,
    includeHeader,
  );

  assert.equal(chunk.processedRows, 2);
  assert.equal(chunk.nextCursor, 4);
  assert.equal(chunk.complete, false);
  assert.deepEqual([...chunk.headers.values()], ["Field Number", "Geometry WKT"]);
  assert.equal(chunk.rows[0].values.get(0), "FN003");
  assert.equal(chunk.rows[0].values.get(2), "POLYGON((3 3,4 3,4 4,3 3))");
  assert.equal(chunk.rows[0].values.has(1), false);
  assert.equal(chunk.rows[1].values.get(0), "FN004");
});

Deno.test("marks the final XLSX slice complete", async () => {
  const chunk = await readFirstSheetRowsChunk(
    workbookBytes(),
    4,
    2,
    isHeader,
    includeHeader,
  );

  assert.equal(chunk.processedRows, 1);
  assert.equal(chunk.nextCursor, 5);
  assert.equal(chunk.complete, true);
  assert.equal(chunk.rows[0].values.get(0), "FN005");
});
