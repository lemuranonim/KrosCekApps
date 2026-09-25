export interface XlsxRow {
  rowNumber: number;
  values: Map<number, unknown>;
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
