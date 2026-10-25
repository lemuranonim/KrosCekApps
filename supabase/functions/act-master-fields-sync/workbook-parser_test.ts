import assert from "node:assert/strict";
// @deno-types="../_shared/vendor/sheetjs/index.d.ts"
import * as XLSX from "../_shared/vendor/sheetjs/xlsx-0.20.3.mjs";
import { parseWorkbook } from "./workbook-parser.ts";

for (const bookType of ["xlsx", "xls"] as const) {
  Deno.test(`patched SheetJS reads ${bookType} exports including dense cells`, () => {
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet([
      ["ACT Planting Export"],
      ["Field Number", "Farmer", "Hybrid", "Planted Area(Ha)"],
      ["FN001", "Test Farmer", "AX01", 1.25],
      ["FN002", "Other Farmer", "AX02", 2.5],
    ]), "Planting");
    const buffer = XLSX.write(workbook, { type: "array", bookType });
    const rows = parseWorkbook(new Uint8Array(buffer), "FC");
    assert.equal(rows.length, 2);
    assert.equal(rows[0].fieldNumberRaw, "FN001");
    assert.equal(rows[1].fieldNumberRaw, "FN002");
  });
}
