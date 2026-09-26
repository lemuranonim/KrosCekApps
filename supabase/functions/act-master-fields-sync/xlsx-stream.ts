export interface XlsxRow {
  rowNumber: number;
  values: Map<number, unknown>;
}

export interface XlsxRowChunk {
  headers: Map<number, string>;
  rows: XlsxRow[];
  processedRows: number;
  nextCursor: number;
  complete: boolean;
}

interface CellToken {
  column: number;
  type: string;
  valueXml: string | undefined;
  xml: string;
}

interface ZipEntry {
  compressionMethod: number;
  compressedStart: number;
  compressedSize: number;
}

const ZIP_LOCAL_FILE = 0x04034b50;
const ZIP_CENTRAL_FILE = 0x02014b50;
const ZIP_END = 0x06054b50;

function findZipEntry(bytes: Uint8Array, wantedName: string): ZipEntry {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  let endOffset = -1;
  const minimum = Math.max(0, bytes.length - 65_557);
  for (let offset = bytes.length - 22; offset >= minimum; offset--) {
    if (view.getUint32(offset, true) === ZIP_END) {
      endOffset = offset;
      break;
    }
  }
  if (endOffset < 0) throw new Error("XLSX ZIP end record was not found");

  const entryCount = view.getUint16(endOffset + 10, true);
  let offset = view.getUint32(endOffset + 16, true);
  const decoder = new TextDecoder();
  for (let index = 0; index < entryCount; index++) {
    if (view.getUint32(offset, true) !== ZIP_CENTRAL_FILE) {
      throw new Error("XLSX ZIP central directory is invalid");
    }
    const compressionMethod = view.getUint16(offset + 10, true);
    const compressedSize = view.getUint32(offset + 20, true);
    const nameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    const localOffset = view.getUint32(offset + 42, true);
    const name = decoder.decode(bytes.subarray(offset + 46, offset + 46 + nameLength));
    if (name === wantedName) {
      if (view.getUint32(localOffset, true) !== ZIP_LOCAL_FILE) {
        throw new Error(`XLSX ZIP local header is invalid for ${wantedName}`);
      }
      const localNameLength = view.getUint16(localOffset + 26, true);
      const localExtraLength = view.getUint16(localOffset + 28, true);
      return {
        compressionMethod,
        compressedStart: localOffset + 30 + localNameLength + localExtraLength,
        compressedSize,
      };
    }
    offset += 46 + nameLength + extraLength + commentLength;
  }
  throw new Error(`XLSX ZIP entry was not found: ${wantedName}`);
}

async function* zipEntryText(
  bytes: Uint8Array,
  name: string,
): AsyncGenerator<string> {
  const entry = findZipEntry(bytes, name);
  const compressed = bytes.subarray(
    entry.compressedStart,
    entry.compressedStart + entry.compressedSize,
  );
  let stream: ReadableStream<Uint8Array> = new Blob([compressed]).stream();
  if (entry.compressionMethod === 8) {
    stream = stream.pipeThrough(new DecompressionStream("deflate-raw"));
  } else if (entry.compressionMethod !== 0) {
    throw new Error(`Unsupported XLSX ZIP compression method: ${entry.compressionMethod}`);
  }

  const reader = stream.getReader();
  const decoder = new TextDecoder();
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    if (value) yield decoder.decode(value, { stream: true });
  }
  const tail = decoder.decode();
  if (tail) yield tail;
}

async function* xmlElements(
  chunks: AsyncIterable<string>,
  element: string,
): AsyncGenerator<string> {
  const opening = `<${element}`;
  const closing = `</${element}>`;
  let buffer = "";
  for await (const chunk of chunks) {
    buffer += chunk;
    while (true) {
      const start = buffer.indexOf(opening);
      if (start < 0) {
        buffer = buffer.slice(-opening.length);
        break;
      }
      const end = buffer.indexOf(closing, start);
      if (end < 0) {
        if (start > 0) buffer = buffer.slice(start);
        break;
      }
      const after = end + closing.length;
      yield buffer.slice(start, after);
      buffer = buffer.slice(after);
    }
  }
}

export function decodeXmlEntities(value: string): string {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, decimal) => String.fromCodePoint(Number(decimal)))
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/_x([0-9a-f]{4})_/gi, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)));
}

function textNodes(xml: string): string {
  let result = "";
  const matcher = /<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g;
  for (let match = matcher.exec(xml); match; match = matcher.exec(xml)) {
    result += decodeXmlEntities(match[1]);
  }
  return result;
}

async function readSharedStrings(bytes: Uint8Array): Promise<string[]> {
  const values: string[] = [];
  for await (
    const xml of xmlElements(zipEntryText(bytes, "xl/sharedStrings.xml"), "si")
  ) {
    values.push(textNodes(xml));
  }
  return values;
}

function columnIndex(reference: string): number {
  const letters = reference.match(/^[A-Z]+/i)?.[0]?.toUpperCase() ?? "";
  let result = 0;
  for (const letter of letters) result = result * 26 + letter.charCodeAt(0) - 64;
  return result - 1;
}

function attribute(xml: string, name: string): string {
  const match = xml.match(new RegExp(`\\s${name}="([^"]*)"`));
  return match ? decodeXmlEntities(match[1]) : "";
}

function parseCellValue(cellXml: string, sharedStrings: string[]): unknown {
  const type = attribute(cellXml, "t");
  if (type === "inlineStr") return textNodes(cellXml);
  const valueXml = cellXml.match(/<v>([\s\S]*?)<\/v>/)?.[1];
  if (valueXml === undefined) return null;
  const decoded = decodeXmlEntities(valueXml);
  if (type === "s") return sharedStrings[Number(decoded)] ?? "";
  if (type === "str" || type === "e") return decoded;
  if (type === "b") return decoded === "1";
  const number = Number(decoded);
  return Number.isFinite(number) ? number : decoded;
}

function cellTokens(rowXml: string): CellToken[] {
  const tokens: CellToken[] = [];
  const matcher = /<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;
  for (let match = matcher.exec(rowXml); match; match = matcher.exec(rowXml)) {
    const cellXml = `<c${match[1]}>${match[2] ?? ""}</c>`;
    const opening = cellXml.slice(0, cellXml.indexOf(">") + 1);
    const reference = attribute(opening, "r");
    const column = columnIndex(reference);
    if (column < 0) continue;
    tokens.push({
      column,
      type: attribute(opening, "t"),
      valueXml: cellXml.match(/<v>([\s\S]*?)<\/v>/)?.[1],
      xml: cellXml,
    });
  }
  return tokens;
}

function sharedStringIndex(token: CellToken): number | null {
  if (token.type !== "s" || token.valueXml === undefined) return null;
  const value = Number(decodeXmlEntities(token.valueXml));
  return Number.isInteger(value) && value >= 0 ? value : null;
}

function parseCellToken(
  token: CellToken,
  sharedStrings: ReadonlyMap<number, string>,
): unknown {
  if (token.type === "inlineStr") return textNodes(token.xml);
  if (token.valueXml === undefined) return null;
  const decoded = decodeXmlEntities(token.valueXml);
  if (token.type === "s") return sharedStrings.get(Number(decoded)) ?? "";
  if (token.type === "str" || token.type === "e") return decoded;
  if (token.type === "b") return decoded === "1";
  const number = Number(decoded);
  return Number.isFinite(number) ? number : decoded;
}

function parseSelectiveRow(
  xml: string,
  sharedStrings: ReadonlyMap<number, string>,
  includedColumns?: ReadonlySet<number>,
): XlsxRow {
  const rowNumber = Number(attribute(xml.slice(0, xml.indexOf(">") + 1), "r")) || 0;
  const values = new Map<number, unknown>();
  for (const token of cellTokens(xml)) {
    if (includedColumns && !includedColumns.has(token.column)) continue;
    values.set(token.column, parseCellToken(token, sharedStrings));
  }
  return { rowNumber, values };
}

async function readSelectedSharedStrings(
  bytes: Uint8Array,
  indexes: ReadonlySet<number>,
): Promise<Map<number, string>> {
  const values = new Map<number, string>();
  if (indexes.size === 0) return values;

  const highestIndex = Math.max(...indexes);
  let index = 0;
  for await (
    const xml of xmlElements(zipEntryText(bytes, "xl/sharedStrings.xml"), "si")
  ) {
    if (indexes.has(index)) values.set(index, textNodes(xml));
    if (index >= highestIndex) break;
    index++;
  }
  return values;
}

function collectSharedStringIndexes(
  rowXml: string,
  indexes: Set<number>,
  includedColumns?: ReadonlySet<number>,
): void {
  for (const token of cellTokens(rowXml)) {
    if (includedColumns && !includedColumns.has(token.column)) continue;
    const index = sharedStringIndex(token);
    if (index !== null) indexes.add(index);
  }
}

function serializedRowHasValue(
  rowXml: string,
  includedColumns: ReadonlySet<number>,
): boolean {
  for (const token of cellTokens(rowXml)) {
    if (!includedColumns.has(token.column)) continue;
    if (token.type === "inlineStr") {
      if (textNodes(token.xml).trim() !== "") return true;
      continue;
    }
    if (token.valueXml === undefined) continue;
    if (token.type === "s" || decodeXmlEntities(token.valueXml).trim() !== "") return true;
  }
  return false;
}

function parseRow(xml: string, sharedStrings: string[]): XlsxRow {
  const rowNumber = Number(attribute(xml.slice(0, xml.indexOf(">") + 1), "r")) || 0;
  const values = new Map<number, unknown>();
  const matcher = /<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;
  for (let match = matcher.exec(xml); match; match = matcher.exec(xml)) {
    const cellXml = `<c${match[1]}>${match[2] ?? ""}</c>`;
    const reference = attribute(cellXml.slice(0, cellXml.indexOf(">") + 1), "r");
    const column = columnIndex(reference);
    if (column >= 0) values.set(column, parseCellValue(cellXml, sharedStrings));
  }
  return { rowNumber, values };
}

export async function* iterateFirstSheetRows(bytes: Uint8Array): AsyncGenerator<XlsxRow> {
  const sharedStrings = await readSharedStrings(bytes);
  for await (
    const xml of xmlElements(zipEntryText(bytes, "xl/worksheets/sheet1.xml"), "row")
  ) {
    yield parseRow(xml, sharedStrings);
  }
}

/**
 * Reads a resumable slice from the first worksheet without parsing the rows
 * before the cursor. XLSX shared strings are also resolved only for the header
 * and selected columns in the returned slice. This keeps CPU usage nearly
 * constant as the cursor advances through a large workbook.
 */
export async function readFirstSheetRowsChunk(
  bytes: Uint8Array,
  cursor: number,
  maxRows: number,
  isHeaderRow: (values: ReadonlyMap<number, unknown>) => boolean,
  includeHeader: (value: unknown) => boolean,
): Promise<XlsxRowChunk> {
  if (!Number.isInteger(cursor) || cursor < 0) throw new Error("XLSX cursor must be non-negative");
  if (!Number.isInteger(maxRows) || maxRows <= 0) throw new Error("XLSX chunk size must be positive");

  const iterator = xmlElements(zipEntryText(bytes, "xl/worksheets/sheet1.xml"), "row");
  const bufferedRows: string[] = [];
  const headerSharedIndexes = new Set<number>();

  while (bufferedRows.length < 25) {
    const next = await iterator.next();
    if (next.done) break;
    bufferedRows.push(next.value);
    collectSharedStringIndexes(next.value, headerSharedIndexes);
  }

  const headerSharedStrings = await readSelectedSharedStrings(bytes, headerSharedIndexes);
  let headerIndex = -1;
  let headerRow: XlsxRow | null = null;
  for (let index = 0; index < bufferedRows.length; index++) {
    const parsed = parseSelectiveRow(bufferedRows[index], headerSharedStrings);
    if (parsed.rowNumber <= 25 && isHeaderRow(parsed.values)) {
      headerIndex = index;
      headerRow = parsed;
      break;
    }
  }
  if (!headerRow) throw new Error("XLSX workbook has no Field Number header");

  const allHeaderColumns = new Set(headerRow.values.keys());
  const headers = new Map<number, string>();
  for (const [column, value] of headerRow.values) {
    if (includeHeader(value)) headers.set(column, String(value ?? "").trim());
  }
  if (headers.size === 0) throw new Error("XLSX workbook has no selected columns");
  const selectedColumns = new Set(headers.keys());

  async function* remainingRows(): AsyncGenerator<string> {
    for (let index = headerIndex + 1; index < bufferedRows.length; index++) {
      yield bufferedRows[index];
    }
    while (true) {
      const next = await iterator.next();
      if (next.done) break;
      yield next.value;
    }
  }

  let seenRows = 0;
  let complete = true;
  const selectedRowXml: string[] = [];
  for await (const rowXml of remainingRows()) {
    if (!serializedRowHasValue(rowXml, allHeaderColumns)) continue;
    if (seenRows < cursor) {
      seenRows++;
      continue;
    }
    if (selectedRowXml.length >= maxRows) {
      complete = false;
      break;
    }
    seenRows++;
    selectedRowXml.push(rowXml);
  }

  const selectedSharedIndexes = new Set<number>();
  for (const rowXml of selectedRowXml) {
    collectSharedStringIndexes(rowXml, selectedSharedIndexes, selectedColumns);
  }
  const selectedSharedStrings = await readSelectedSharedStrings(bytes, selectedSharedIndexes);
  const rows = selectedRowXml.map((rowXml) =>
    parseSelectiveRow(rowXml, selectedSharedStrings, selectedColumns)
  );

  return {
    headers,
    rows,
    processedRows: rows.length,
    nextCursor: cursor + rows.length,
    complete,
  };
}
