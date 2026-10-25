// @deno-types="../_shared/vendor/sheetjs/index.d.ts"
import * as XLSX from "../_shared/vendor/sheetjs/xlsx-0.20.3.mjs";
import { mapExportRow, normalizeHeader, type ParsedSourceRow, type SourceType } from "./sync-core.ts";

export function parseWorkbook(bytes: Uint8Array, sourceType: SourceType): ParsedSourceRow[] {
  const workbook = XLSX.read(bytes, { type: "array", cellDates: true, dense: true });
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) throw new Error(`ACT ${sourceType} workbook has no sheet`);
  const sheet = workbook.Sheets[sheetName];
  const dense = sheet["!data"] as Array<Array<{ v?: unknown } | undefined>> | undefined;
  const reference = String((sheet as Record<string, unknown>)["!ref"] ?? "");
  if (!reference) throw new Error(`ACT ${sourceType} workbook has no cells`);
  const range = XLSX.utils.decode_range(reference);
  const cellValue = (row: number, column: number): unknown => {
    const denseCell = dense?.[row]?.[column];
    const sparseCell = sheet[XLSX.utils.encode_cell({ r: row, c: column })];
    const cell = (denseCell ?? sparseCell) as { v?: unknown } | undefined;
    return cell?.v ?? null;
  };
  let headerIndex = -1;
  for (
    let row = range.s.r;
    row <= Math.min(range.e.r, range.s.r + 24) && headerIndex < 0;
    row++
  ) {
    for (let column = range.s.c; column <= range.e.c; column++) {
      const header = normalizeHeader(cellValue(row, column));
      if (header === "field number" || header === "field no" || header === "fn") {
        headerIndex = row;
        break;
      }
    }
  }
  if (headerIndex < 0) throw new Error(`ACT ${sourceType} workbook has no Field Number header`);

  const headers: string[] = [];
  for (let column = range.s.c; column <= range.e.c; column++) {
    headers.push(String(cellValue(headerIndex, column) ?? `column_${column + 1}`).trim());
  }
  const rows: ParsedSourceRow[] = [];
  for (let row = headerIndex + 1; row <= range.e.r; row++) {
    const values = headers.map((_, offset) => cellValue(row, range.s.c + offset));
    if (values.every((value) => value === null || String(value).trim() === "")) {
      continue;
    }
    const raw: Record<string, unknown> = {};
    headers.forEach((header, column) => {
      raw[header] = values[column] ?? null;
    });
    rows.push(mapExportRow(raw, sourceType, row + 1));
  }
  return rows;
}
