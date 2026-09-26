import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import * as XLSX from "npm:xlsx@0.18.5";
import {
  mapExportRow,
  normalizeFieldNumber,
  normalizeHeader,
  reconcile,
  sha256,
  type ParsedSourceRow,
  type SourceType,
} from "./sync-core.ts";
import { iterateFirstSheetRows } from "./xlsx-stream.ts";

const ACT_ORIGIN = (Deno.env.get("ACT_SYNC_ORIGIN") ?? "https://act.advantaseeds.com")
  .replace(/\/$/, "");
const ACT_APP_ROOT = `${ACT_ORIGIN}/act/`;
const ACT_INDEX_ROOT = `${ACT_APP_ROOT}index.php/`;
const EXPORT_COLUMNS = [
  "planting_petani",
  "planting_grower",
  "planting_produk_jenis_sub",
  "planting_area_ha",
  "planting_discard_area",
  "planting_efective_area",
  "planting_prev_crop",
  "planting_ratio",
  "planting_space",
  "planting_female_date",
  "planting_dusun",
  "planting_desa_nama",
  "planting_kecamatan_nama",
  "planting_kabupaten_nama",
  "planting_propinsi_nama",
  "planting_fa",
  "planting_spv",
  "planting_manager",
  "planting_region",
  "planting_lat",
  "planting_long",
  "planting_geo",
  "planting_fa_now",
] as const;

const EXPORT_KIND: Record<SourceType, string> = {
  FC: "HSP",
  PS: "PSP",
  SC: "SC",
};

const PLANTING_TABLE_ROUTE: Record<SourceType, string> = {
  FC: "planting/table",
  PS: "planting/Planting_ps/table",
  SC: "planting/Planting_sc/table",
};

const MASTER_FIELDS_SELECT = [
  "field_number",
  "farmer_name",
  "grower",
  "hybrid",
  "total_area_planted_ha",
  "discard_area_ha",
  "effective_area_ha",
  "planting_date_pdn",
  "hamlet_dusun",
  "village_desa",
  "sub_district_kec",
  "district_kab",
  "fa",
  "field_spv",
  "region",
  "area_manager",
  "type",
  "prov",
  "planting_ratio",
  "planting_space",
  "geometry_wkt",
  "geometry_source",
  "is_active",
].join(",");

const JSON_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SyncRequest {
  runId?: string;
  inspectSource?: SourceType;
  inspectExportJobId?: string;
  inspectPlantingPage?: boolean;
  inspectPlantingTable?: boolean;
  inspectPldTable?: boolean;
  from?: string;
  to?: string;
  apply?: boolean;
  sources?: SourceType[];
  exportMode?: "table" | "background" | "sync";
  includeWkt?: boolean;
  minimumRows?: number;
  maxChangeRatio?: number;
}

interface ValidatedSyncRequest {
  from: string;
  to: string;
  apply: boolean;
  sources: SourceType[];
  exportMode: "table" | "background" | "sync";
  includeWkt: boolean;
  minimumRows: number;
  maxChangeRatio: number;
}

interface ExportJob {
  id: string;
  kind: string;
  from: string;
  to: string;
  status: string;
  createdAt: string;
}

interface ExportArtifact {
  sourceType: SourceType;
  exportKind: string;
  bytes: Uint8Array;
  fileUrl: string;
  fileHash: string;
}

interface PlantingTablePage {
  total: number;
  rows: unknown[][];
}

class HttpError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

class ActClient {
  private cookie = "";

  async login(username: string, password: string): Promise<void> {
    const body = new URLSearchParams();
    body.set("user_username", username);
    body.set("user_password", password);
    body.set("pas_cek", "1");

    const response = await fetchWithTimeout(`${ACT_INDEX_ROOT}login/auth`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "User-Agent": "KC-ACT-Sync/1.0",
      },
      body,
      redirect: "manual",
    }, 30_000);
    this.captureCookies(response);

    if (!this.cookie) {
      throw new Error("ACT login did not return a session cookie");
    }

    const verify = await this.request(`${ACT_INDEX_ROOT}planting`, { method: "GET" }, 30_000);
    const html = await verify.text();
    if (!verify.ok || !/Data Planting|Planting & PS Usage/i.test(html)) {
      throw new Error("ACT login failed or the account cannot access Planting");
    }
  }

  async request(
    url: string,
    init: RequestInit,
    timeoutMs = 60_000,
  ): Promise<Response> {
    const headers = new Headers(init.headers);
    if (this.cookie) headers.set("Cookie", this.cookie);
    headers.set("User-Agent", "KC-ACT-Sync/1.0");
    headers.set("X-Requested-With", "XMLHttpRequest");
    const response = await fetchWithTimeout(url, { ...init, headers }, timeoutMs);
    this.captureCookies(response);
    return response;
  }

  async postForm(path: string, form: URLSearchParams, timeoutMs = 60_000): Promise<Response> {
    return await this.request(`${ACT_INDEX_ROOT}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8" },
      body: form,
    }, timeoutMs);
  }

  async readPlantingTablePage(
    sourceType: SourceType,
    year: string,
    start: number,
    length: number,
  ): Promise<PlantingTablePage> {
    const query = new URLSearchParams({
      draw: "1",
      start: String(start),
      length: String(length),
      "search[value]": "",
      "search[regex]": "false",
      "order[0][column]": "2",
      "order[0][dir]": "asc",
    });
    const response = await this.request(
      `${ACT_INDEX_ROOT}${PLANTING_TABLE_ROUTE[sourceType]}/${year}?${query}`,
      { method: "GET" },
      60_000,
    );
    if (!response.ok) {
      throw new Error(`ACT ${sourceType} planting table returned HTTP ${response.status}`);
    }
    const payload = await response.json();
    if (!Array.isArray(payload?.data)) {
      throw new Error(`ACT ${sourceType} planting table returned invalid JSON`);
    }
    return {
      total: Number(payload.recordsFiltered ?? payload.recordsTotal ?? payload.data.length),
      rows: payload.data as unknown[][],
    };
  }

  async readFinalPldPage(
    year: string,
    start: number,
    length: number,
  ): Promise<PlantingTablePage> {
    const query = new URLSearchParams({
      draw: "1",
      start: String(start),
      length: String(length),
      "search[value]": "",
      "search[regex]": "false",
      "order[0][column]": "2",
      "order[0][dir]": "desc",
      status: "3",
    });
    const response = await this.request(
      `${ACT_INDEX_ROOT}rekomendasi_pld/datatable/${year}?${query}`,
      { method: "GET" },
      60_000,
    );
    if (!response.ok) throw new Error(`ACT PLD table returned HTTP ${response.status}`);
    const payload = await response.json();
    if (!Array.isArray(payload?.data)) throw new Error("ACT PLD table returned invalid JSON");
    return {
      total: Number(payload.recordsFiltered ?? payload.recordsTotal ?? payload.data.length),
      rows: payload.data as unknown[][],
    };
  }

  async listExportJobs(): Promise<ExportJob[]> {
    const query = new URLSearchParams({
      draw: "1",
      start: "0",
      length: "100",
      "search[value]": "",
      "search[regex]": "false",
      "order[0][column]": "5",
      "order[0][dir]": "desc",
    });
    for (let index = 0; index < 7; index++) {
      query.set(`columns[${index}][data]`, String(index));
      query.set(`columns[${index}][name]`, "");
      query.set(`columns[${index}][searchable]`, "true");
      query.set(`columns[${index}][orderable]`, "true");
      query.set(`columns[${index}][search][value]`, "");
      query.set(`columns[${index}][search][regex]`, "false");
    }
    const response = await this.request(
      `${ACT_INDEX_ROOT}laporan_export_planting/table?${query}`,
      { method: "GET" },
      30_000,
    );
    if (!response.ok) throw new Error(`ACT export queue returned HTTP ${response.status}`);
    const payload = await response.json();
    const rows = Array.isArray(payload?.data) ? payload.data : [];
    return rows.map(parseExportJob).filter((job): job is ExportJob => job !== null);
  }

  async startBackgroundExport(
    sourceType: SourceType,
    from: string,
    to: string,
  ): Promise<void> {
    const form = buildExportForm(EXPORT_KIND[sourceType], from, to);
    const response = await this.postForm("planting/get_report_mobile_background", form, 60_000);
    if (!response.ok) {
      throw new Error(`ACT ${sourceType} background export returned HTTP ${response.status}`);
    }
    const text = await response.text();
    if (/error|gagal|failed/i.test(text) && !/success/i.test(text)) {
      throw new Error(`ACT ${sourceType} background export was rejected`);
    }
  }

  async waitForBackgroundExports(
    sources: SourceType[],
    from: string,
    to: string,
    existingIds: Set<string>,
  ): Promise<ExportArtifact[]> {
    const deadline = Date.now() + Number(Deno.env.get("ACT_SYNC_EXPORT_WAIT_MS") ?? 300_000);
    const resolved = new Map<SourceType, ExportArtifact>();

    while (Date.now() < deadline) {
      const jobs = await this.listExportJobs();
      for (const sourceType of sources) {
        if (resolved.has(sourceType)) continue;
        const kind = EXPORT_KIND[sourceType];
        const matches = jobs
          .filter((job) =>
            !existingIds.has(job.id) &&
            jobMatches(job, kind, from, to)
          )
          .sort((a, b) => compareJobIds(b.id, a.id));
        const job = matches[0];
        if (!job) continue;
        if (/fail|error|gagal/i.test(job.status)) {
          throw new Error(`ACT ${sourceType} background export failed`);
        }
        if (!/success|complete|selesai/i.test(job.status)) continue;

        const fileUrl = await this.readExportFileUrl(job.id);
        const bytes = await this.downloadFile(fileUrl);
        resolved.set(sourceType, {
          sourceType,
          exportKind: kind,
          bytes,
          fileUrl,
          fileHash: await sha256Bytes(bytes),
        });
      }
      if (resolved.size === sources.length) {
        return sources.map((source) => resolved.get(source)!);
      }
      await delay(5_000);
    }

    const pending = sources.filter((source) => !resolved.has(source)).join(", ");
    throw new Error(`ACT background export timed out for: ${pending}`);
  }

  async findBackgroundJobs(
    sources: SourceType[],
    from: string,
    to: string,
    existingIds: Set<string>,
  ): Promise<{
    ready: Partial<Record<SourceType, ExportJob>>;
    pending: SourceType[];
    observed: ExportJob[];
  }> {
    const jobs = await this.listExportJobs();
    const ready: Partial<Record<SourceType, ExportJob>> = {};
    const pending: SourceType[] = [];

    for (const sourceType of sources) {
      const kind = EXPORT_KIND[sourceType];
      const matches = jobs
        .filter((job) => !existingIds.has(job.id) && jobMatches(job, kind, from, to))
        .sort((a, b) => compareJobIds(b.id, a.id));
      const job = matches.find((candidate) =>
        /success|complete|selesai/i.test(candidate.status)
      );
      if (!job) {
        const newest = matches[0];
        if (newest && /fail|error|gagal/i.test(newest.status)) {
          throw new Error(`ACT ${sourceType} background export failed`);
        }
        pending.push(sourceType);
        continue;
      }
      ready[sourceType] = job;
    }

    return { ready, pending, observed: jobs.slice(0, 15) };
  }

  async downloadBackgroundExport(
    sourceType: SourceType,
    job: ExportJob,
  ): Promise<ExportArtifact> {
    const fileUrl = await this.readExportFileUrl(job.id);
    const bytes = await this.downloadFile(fileUrl);
    return {
      sourceType,
      exportKind: EXPORT_KIND[sourceType],
      bytes,
      fileUrl,
      fileHash: await sha256Bytes(bytes),
    };
  }

  async inspectExportFileUrl(id: string): Promise<string> {
    return await this.readExportFileUrl(id);
  }

  async exportSynchronously(
    sourceType: SourceType,
    from: string,
    to: string,
  ): Promise<ExportArtifact> {
    const kind = EXPORT_KIND[sourceType];
    const response = await this.postForm(
      "planting/get_report_mobile",
      buildExportForm(kind, from, to),
      Number(Deno.env.get("ACT_SYNC_DIRECT_EXPORT_TIMEOUT_MS") ?? 300_000),
    );
    if (!response.ok) throw new Error(`ACT ${sourceType} export returned HTTP ${response.status}`);
    const text = await response.text();
    const parsed = parsePossiblyEncodedJson(text);
    const fileUrl = absoluteActFileUrl(String(parsed?.file ?? ""));
    if (!fileUrl) throw new Error(`ACT ${sourceType} export did not return a file`);
    const bytes = await this.downloadFile(fileUrl);
    return {
      sourceType,
      exportKind: kind,
      bytes,
      fileUrl,
      fileHash: await sha256Bytes(bytes),
    };
  }

  private async readExportFileUrl(id: string): Promise<string> {
    const form = new URLSearchParams({ id });
    const response = await this.postForm("laporan_export_planting/read", form, 30_000);
    if (!response.ok) throw new Error(`ACT export detail returned HTTP ${response.status}`);
    const payload = parsePossiblyEncodedJson(await response.text());
    const path = payload?.data?.[0]?.file_path ?? payload?.file_path ?? payload?.file;
    const url = absoluteActFileUrl(String(path ?? ""));
    if (!url) throw new Error(`ACT export ${id} has no downloadable file`);
    return url;
  }

  private async downloadFile(url: string): Promise<Uint8Array> {
    const response = await this.request(url, { method: "GET" }, 120_000);
    if (!response.ok) throw new Error(`ACT file download returned HTTP ${response.status}`);
    const bytes = new Uint8Array(await response.arrayBuffer());
    const isXlsx = bytes.length >= 4 && bytes[0] === 0x50 && bytes[1] === 0x4b;
    const isXls = bytes.length >= 8 &&
      bytes[0] === 0xd0 && bytes[1] === 0xcf && bytes[2] === 0x11 && bytes[3] === 0xe0;
    if (!isXlsx && !isXls) {
      throw new Error("ACT export is not a valid Excel file");
    }
    return bytes;
  }

  private captureCookies(response: Response): void {
    const values = typeof response.headers.getSetCookie === "function"
      ? response.headers.getSetCookie()
      : splitSetCookie(response.headers.get("set-cookie") ?? "");
    const pairs = values.map((value) => value.split(";", 1)[0]).filter(Boolean);
    if (pairs.length) this.cookie = mergeCookies(this.cookie, pairs);
  }
}

function buildExportForm(kind: string, from: string, to: string): URLSearchParams {
  const form = new URLSearchParams();
  form.set("jenis", kind);
  form.set("mulai", from);
  form.set("sampai", to);
  form.set("region", "");
  for (const column of EXPORT_COLUMNS) form.append("kolom[]", column);
  return form;
}

function parseExportJob(row: unknown): ExportJob | null {
  if (Array.isArray(row)) {
    if (row.length < 5) return null;
    return {
      id: String(row[0] ?? ""),
      kind: String(row[1] ?? ""),
      from: String(row[2] ?? ""),
      to: String(row[3] ?? ""),
      status: String(row[4] ?? ""),
      createdAt: String(row[5] ?? ""),
    };
  }
  if (row && typeof row === "object") {
    const value = row as Record<string, unknown>;
    const id = value.id ?? value.export_id ?? value.report_id;
    if (id === null || id === undefined) return null;
    return {
      id: String(id),
      kind: String(value.jenis ?? value.type ?? value.report_type ?? ""),
      from: String(value.mulai ?? value.start_date ?? value.from ?? ""),
      to: String(value.sampai ?? value.end_date ?? value.to ?? ""),
      status: String(value.status ?? ""),
      createdAt: String(value.date ?? value.created_at ?? ""),
    };
  }
  return null;
}

function jobMatches(job: ExportJob, kind: string, from: string, to: string): boolean {
  const normalizedKind = job.kind.toUpperCase();
  return normalizedKind.includes(kind.toUpperCase()) &&
    normalizeLooseDate(job.from) === from &&
    normalizeLooseDate(job.to) === to;
}

function compareJobIds(a: string, b: string): number {
  const aNumber = Number(a);
  const bNumber = Number(b);
  if (Number.isFinite(aNumber) && Number.isFinite(bNumber)) return aNumber - bNumber;
  return a.localeCompare(b);
}

function normalizeLooseDate(value: string): string {
  const match = value.match(/(\d{4})[-/](\d{1,2})[-/](\d{1,2})/);
  if (match) return `${match[1]}-${match[2].padStart(2, "0")}-${match[3].padStart(2, "0")}`;
  const local = value.match(/(\d{1,2})[-/](\d{1,2})[-/](\d{4})/);
  if (local) return `${local[3]}-${local[2].padStart(2, "0")}-${local[1].padStart(2, "0")}`;
  return value.trim();
}

function parseWorkbook(bytes: Uint8Array, sourceType: SourceType): ParsedSourceRow[] {
  const workbook = XLSX.read(bytes, { type: "array", cellDates: true, dense: true });
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) throw new Error(`ACT ${sourceType} workbook has no sheet`);
  const sheet = workbook.Sheets[sheetName] as unknown as Record<string, unknown> & unknown[][];
  const reference = String((sheet as Record<string, unknown>)["!ref"] ?? "");
  if (!reference) throw new Error(`ACT ${sourceType} workbook has no cells`);
  const range = XLSX.utils.decode_range(reference);
  const cellValue = (row: number, column: number): unknown => {
    const denseCell = Array.isArray(sheet) ? sheet[row]?.[column] : undefined;
    const sparseCell = !Array.isArray(sheet)
      ? (sheet as Record<string, unknown>)[XLSX.utils.encode_cell({ r: row, c: column })]
      : undefined;
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

async function fetchAllMasterFields(supabase: SupabaseClient): Promise<Record<string, unknown>[]> {
  const rows: Record<string, unknown>[] = [];
  const pageSize = 1_000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase
      .from("master_fields")
      .select(MASTER_FIELDS_SELECT)
      .order("field_number", { ascending: true })
      .range(from, from + pageSize - 1);
    if (error) throw new Error(`Cannot read KC master_fields: ${error.message}`);
    const page = (data ?? []) as Record<string, unknown>[];
    rows.push(...page);
    if (page.length < pageSize) break;
  }
  return rows;
}

async function insertChunks(
  supabase: SupabaseClient,
  table: string,
  rows: Record<string, unknown>[],
  size = 500,
): Promise<void> {
  for (let index = 0; index < rows.length; index += size) {
    const { error } = await supabase.from(table).insert(rows.slice(index, index + size));
    if (error) throw new Error(`Cannot write ${table}: ${error.message}`);
  }
}

async function upsertChunks(
  supabase: SupabaseClient,
  table: string,
  rows: Record<string, unknown>[],
  onConflict: string,
  size = 500,
): Promise<void> {
  for (let index = 0; index < rows.length; index += size) {
    const { error } = await supabase
      .from(table)
      .upsert(rows.slice(index, index + size), { onConflict });
    if (error) throw new Error(`Cannot write ${table}: ${error.message}`);
  }
}

async function stageParsedRows(
  supabase: SupabaseClient,
  runId: string,
  rows: ParsedSourceRow[],
): Promise<void> {
  for (let index = 0; index < rows.length; index += 500) {
    const batch = rows.slice(index, index + 500);
    const hashes = await Promise.all(batch.map((row) => sha256(row.sourcePayload)));
    await upsertChunks(
      supabase,
      "act_sync_rows",
      batch.map((row, rowIndex) => ({
        run_id: runId,
        source_type: row.sourceType,
        source_row: row.sourceRow,
        field_number_raw: row.fieldNumberRaw,
        field_number_norm: row.fieldNumberNorm,
        raw_payload: JSON.parse(JSON.stringify(row.rawPayload)),
        source_payload: row.sourcePayload,
        row_hash: hashes[rowIndex],
        validation_errors: row.validationErrors,
      })),
      "run_id,source_type,source_row",
    );
  }
}

function mapPlantingTableRow(
  row: unknown[],
  sourceType: SourceType,
  sourceRow: number,
): ParsedSourceRow {
  return mapExportRow({
    "Female Date": row[1] ?? null,
    "Field Number": row[2] ?? null,
    "Farmer": row[3] ?? null,
    "Organizer": row[4] ?? null,
    "Field Assistant": row[5] ?? null,
    "Planted Area(Ha)": row[6] ?? null,
    "Hybrid": row[7] ?? null,
    "Village": row[8] ?? null,
    "Sub District": row[9] ?? null,
    "District": row[10] ?? null,
    "Province": row[11] ?? null,
  }, sourceType, sourceRow);
}

async function stageArtifact(
  supabase: SupabaseClient,
  runId: string,
  artifact: ExportArtifact,
): Promise<{ rowCount: number; fileHash: string }> {
  const { error: resetError } = await supabase
    .from("act_sync_rows")
    .delete()
    .eq("run_id", runId)
    .eq("source_type", artifact.sourceType);
  if (resetError) throw new Error(`Cannot reset staged ACT rows: ${resetError.message}`);

  let rowCount = 0;
  let batch: ParsedSourceRow[] = [];
  const writeBatch = async (): Promise<void> => {
    if (batch.length === 0) return;
    await stageParsedRows(supabase, runId, batch);
    rowCount += batch.length;
    batch = [];
  };

  const isXlsx = artifact.bytes.length >= 4 &&
    artifact.bytes[0] === 0x50 && artifact.bytes[1] === 0x4b;
  if (isXlsx) {
    let headers: Map<number, string> | null = null;
    for await (const row of iterateFirstSheetRows(artifact.bytes)) {
      if (!headers) {
        const hasFieldNumber = [...row.values.values()].some((value) => {
          const header = normalizeHeader(value);
          return header === "field number" || header === "field no" || header === "fn";
        });
        if (row.rowNumber <= 25 && hasFieldNumber) {
          headers = new Map(
            [...row.values.entries()].map(([column, value]) => [
              column,
              String(value ?? `column_${column + 1}`).trim(),
            ]),
          );
        }
        continue;
      }

      const raw: Record<string, unknown> = {};
      let hasValue = false;
      for (const [column, header] of headers) {
        const value = row.values.get(column) ?? null;
        raw[header] = value;
        if (value !== null && String(value).trim() !== "") hasValue = true;
      }
      if (!hasValue) continue;
      batch.push(mapExportRow(raw, artifact.sourceType, row.rowNumber));
      if (batch.length >= 250) await writeBatch();
    }
    if (!headers) throw new Error(`ACT ${artifact.sourceType} workbook has no Field Number header`);
    await writeBatch();
  } else {
    const sourceRows = parseWorkbook(artifact.bytes, artifact.sourceType);
    for (let index = 0; index < sourceRows.length; index += 500) {
      batch.push(...sourceRows.slice(index, index + 500));
      await writeBatch();
    }
  }
  return { rowCount, fileHash: artifact.fileHash };
}

async function mergeGeometryArtifactChunk(
  supabase: SupabaseClient,
  runId: string,
  artifact: ExportArtifact,
  cursor: number,
  maxRows: number,
): Promise<{
  processedRows: number;
  nextCursor: number;
  geometryRows: number;
  matchedRows: number;
  complete: boolean;
}> {
  const isXlsx = artifact.bytes.length >= 4 &&
    artifact.bytes[0] === 0x50 && artifact.bytes[1] === 0x4b;
  if (!isXlsx) {
    throw new Error(`ACT ${artifact.sourceType} WKT export must be an XLSX workbook`);
  }

  let headers: Map<number, string> | null = null;
  let seenRows = 0;
  let processedRows = 0;
  let geometryRows = 0;
  let matchedRows = 0;
  let complete = true;
  let mergeBatch: Array<{ field_number_norm: string; geometry_wkt: string }> = [];

  const flush = async (): Promise<void> => {
    if (mergeBatch.length === 0) return;
    const { data, error } = await supabase.rpc("merge_act_sync_geometry_page", {
      p_run_id: runId,
      p_source_type: artifact.sourceType,
      p_rows: mergeBatch,
    });
    if (error) throw new Error(`Cannot merge ACT WKT page: ${error.message}`);
    matchedRows += Number(recordValue(data).matched ?? 0);
    mergeBatch = [];
  };

  for await (const row of iterateFirstSheetRows(artifact.bytes)) {
    if (!headers) {
      const hasFieldNumber = [...row.values.values()].some((value) => {
        const header = normalizeHeader(value);
        return header === "field number" || header === "field no" || header === "fn";
      });
      if (row.rowNumber <= 25 && hasFieldNumber) {
        headers = new Map(
          [...row.values.entries()].map(([column, value]) => [
            column,
            String(value ?? `column_${column + 1}`).trim(),
          ]),
        );
      }
      continue;
    }

    const raw: Record<string, unknown> = {};
    let hasValue = false;
    for (const [column, header] of headers) {
      const value = row.values.get(column) ?? null;
      raw[header] = value;
      if (value !== null && String(value).trim() !== "") hasValue = true;
    }
    if (!hasValue) continue;
    if (seenRows < cursor) {
      seenRows++;
      continue;
    }
    if (processedRows >= maxRows) {
      complete = false;
      break;
    }

    seenRows++;
    processedRows++;
    const mapped = mapExportRow(raw, artifact.sourceType, row.rowNumber);
    const geometryWkt = String(mapped.sourcePayload.geometry_wkt ?? "").trim();
    if (!mapped.fieldNumberNorm || !geometryWkt) continue;
    if (!/^POLYGON\s*\(\(/i.test(geometryWkt)) {
      throw new Error(
        `ACT ${artifact.sourceType} returned invalid Geometry WKT for ${mapped.fieldNumberNorm}`,
      );
    }
    geometryRows++;
    mergeBatch.push({
      field_number_norm: mapped.fieldNumberNorm,
      geometry_wkt: geometryWkt,
    });
    if (mergeBatch.length >= 250) await flush();
  }

  if (!headers) throw new Error(`ACT ${artifact.sourceType} workbook has no Field Number header`);
  await flush();
  return {
    processedRows,
    nextCursor: cursor + processedRows,
    geometryRows,
    matchedRows,
    complete,
  };
}

async function fetchAllStagedRows(
  supabase: SupabaseClient,
  runId: string,
): Promise<ParsedSourceRow[]> {
  const rows: ParsedSourceRow[] = [];
  const pageSize = 1_000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase
      .from("act_sync_rows")
      .select(
        "source_type,source_row,field_number_raw,field_number_norm,raw_payload,source_payload,validation_errors",
      )
      .eq("run_id", runId)
      .order("source_type", { ascending: true })
      .order("source_row", { ascending: true })
      .range(from, from + pageSize - 1);
    if (error) throw new Error(`Cannot read staged ACT rows: ${error.message}`);
    const page = (data ?? []) as Record<string, unknown>[];
    for (const row of page) {
      rows.push({
        sourceType: String(row.source_type) as SourceType,
        sourceRow: Number(row.source_row),
        fieldNumberRaw: String(row.field_number_raw ?? ""),
        fieldNumberNorm: String(row.field_number_norm ?? ""),
        rawPayload: (row.raw_payload ?? {}) as Record<string, unknown>,
        sourcePayload: (row.source_payload ?? {}) as ParsedSourceRow["sourcePayload"],
        validationErrors: Array.isArray(row.validation_errors)
          ? row.validation_errors.map(String)
          : [],
      });
    }
    if (page.length < pageSize) break;
  }
  return rows;
}

async function finalizeStagedRun(
  service: SupabaseClient,
  runId: string,
  input: ValidatedSyncRequest,
  sourceCounts: Record<string, number>,
  sourceMeta: Record<string, unknown>,
): Promise<Response> {
  const sourceRows = await fetchAllStagedRows(service, runId);
  const currentRows = await fetchAllMasterFields(service);
  const result = reconcile(sourceRows, currentRows);

  const { error: clearError } = await service
    .from("act_sync_changes")
    .delete()
    .eq("run_id", runId);
  if (clearError) throw new Error(`Cannot reset staged ACT changes: ${clearError.message}`);

  await insertChunks(
    service,
    "act_sync_changes",
    result.changes.map((change) => ({
      run_id: runId,
      field_number_norm: change.fieldNumberNorm,
      source_type: change.sourceType,
      change_kind: change.changeKind,
      current_payload: change.currentPayload,
      source_payload: change.sourcePayload,
      changed_columns: change.changedColumns,
      validation_errors: change.validationErrors,
    })),
  );

  const guardErrors: string[] = [];
  if (sourceRows.length < input.minimumRows) {
    guardErrors.push(`source_rows_below_minimum:${sourceRows.length}<${input.minimumRows}`);
  }
  for (const source of input.sources) {
    if ((sourceCounts[source] ?? 0) === 0) guardErrors.push(`empty_source:${source}`);
  }
  const changeRatio = result.summary.actionable / Math.max(sourceRows.length, 1);
  if (input.apply && changeRatio > input.maxChangeRatio) {
    guardErrors.push(`change_ratio_exceeded:${changeRatio.toFixed(4)}>${input.maxChangeRatio}`);
  }
  const blocked = result.summary.blockers > 0 || guardErrors.length > 0;
  const summary = {
    ...result.summary,
    source_counts: sourceCounts,
    change_ratio: changeRatio,
    guard_errors: guardErrors,
  };
  const readyStatus = blocked ? "BLOCKED" : "READY";
  const { error: finalizeError } = await service
    .from("act_sync_runs")
    .update({
      status: readyStatus,
      source_counts: sourceCounts,
      source_meta: sourceMeta,
      summary,
      completed_at: input.apply && !blocked ? null : new Date().toISOString(),
    })
    .eq("id", runId);
  if (finalizeError) throw new Error(`Cannot finalize ACT sync run: ${finalizeError.message}`);

  if (blocked) {
    return jsonResponse({ run_id: runId, status: "BLOCKED", summary }, 409);
  }
  if (input.apply) {
    const { data: applied, error: applyError } = await service.rpc(
      "apply_act_master_fields_sync",
      { p_run_id: runId },
    );
    if (applyError) throw new Error(`ACT sync apply failed: ${applyError.message}`);
    return jsonResponse({ run_id: runId, status: "COMPLETED", summary, applied });
  }
  return jsonResponse({ run_id: runId, status: "READY", dry_run: true, summary });
}

async function prepareRunInDatabase(
  service: SupabaseClient,
  runId: string,
  input: ValidatedSyncRequest,
): Promise<Response> {
  const { data, error } = await service.rpc(
    "prepare_act_master_fields_sync",
    { p_run_id: runId },
  );
  if (error) throw new Error(`ACT sync reconciliation failed: ${error.message}`);
  const result = recordValue(data);
  if (result.status === "BLOCKED") return jsonResponse(result, 409);
  if (input.apply && result.status === "READY") {
    const { data: applied, error: applyError } = await service.rpc(
      "apply_act_master_fields_sync",
      { p_run_id: runId },
    );
    if (applyError) throw new Error(`ACT sync apply failed: ${applyError.message}`);
    return jsonResponse({
      run_id: runId,
      status: "COMPLETED",
      summary: result.summary,
      applied,
    });
  }
  return jsonResponse(result);
}

function recordValue(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

async function authorize(req: Request, service: SupabaseClient): Promise<string | null> {
  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new HttpError("Missing authorization", 401);

  const claims = decodeJwtClaims(token);
  if (claims?.role === "service_role") return null;

  const { data: userData, error: userError } = await service.auth.getUser(token);
  if (userError || !userData.user) throw new HttpError("Invalid authorization", 401);
  const { data: profile, error: profileError } = await service
    .from("app_users")
    .select("id, role, is_active")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (profileError || !profile || profile.is_active === false) {
    throw new HttpError("Active KC profile required", 403);
  }
  const role = String(profile.role ?? "").trim().toUpperCase();
  if (!new Set(["ADMIN", "DEV"]).has(role)) {
    throw new HttpError("Only KC ADMIN or DEV can run ACT synchronization", 403);
  }
  return userData.user.id;
}

function decodeJwtClaims(token: string): Record<string, unknown> | null {
  try {
    const segment = token.split(".")[1];
    if (!segment) return null;
    const normalized = segment.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(atob(padded));
  } catch {
    return null;
  }
}

function validateRequest(input: SyncRequest): ValidatedSyncRequest {
  const today = new Date().toISOString().slice(0, 10);
  const currentYear = today.slice(0, 4);
  const from = input.from ?? `${currentYear}-01-01`;
  const to = input.to ?? today;
  if (!isIsoDate(from) || !isIsoDate(to) || from > to) {
    throw new HttpError("from/to must be valid YYYY-MM-DD dates", 400);
  }

  const sources = input.sources?.length ? [...new Set(input.sources)] : ["FC", "PS", "SC"];
  if (sources.some((source) => !new Set(["FC", "PS", "SC"]).has(source))) {
    throw new HttpError("sources may only contain FC, PS, SC", 400);
  }
  const minimumRows = input.minimumRows ?? Number(Deno.env.get("ACT_SYNC_MIN_TOTAL_ROWS") ?? 1_000);
  const maxChangeRatio = input.maxChangeRatio ?? Number(
    Deno.env.get("ACT_SYNC_MAX_CHANGE_RATIO") ?? 0.25,
  );
  if (!Number.isFinite(minimumRows) || minimumRows < 1) {
    throw new HttpError("minimumRows must be at least 1", 400);
  }
  if (!Number.isFinite(maxChangeRatio) || maxChangeRatio <= 0 || maxChangeRatio > 1) {
    throw new HttpError("maxChangeRatio must be greater than 0 and at most 1", 400);
  }
  return {
    from,
    to,
    apply: input.apply === true,
    sources: sources as SourceType[],
    exportMode: input.exportMode ?? "table",
    includeWkt: input.includeWkt !== false,
    minimumRows,
    maxChangeRatio,
  };
}

function isIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

function parsePossiblyEncodedJson(text: string): any {
  let value: any = JSON.parse(text.replace(/^\uFEFF/, ""));
  if (typeof value === "string") value = JSON.parse(value);
  return value;
}

function absoluteActFileUrl(path: string): string {
  const trimmed = path.trim();
  if (!trimmed) return "";
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return new URL(trimmed.replace(/^\/+/, ""), ACT_APP_ROOT).toString();
}

function splitSetCookie(value: string): string[] {
  if (!value) return [];
  return value.split(/,(?=\s*[^;,=]+=[^;,]+)/g).map((item) => item.trim());
}

function mergeCookies(existing: string, incoming: string[]): string {
  const map = new Map<string, string>();
  for (const pair of [...existing.split(";"), ...incoming]) {
    const trimmed = pair.trim();
    const separator = trimmed.indexOf("=");
    if (separator <= 0) continue;
    map.set(trimmed.slice(0, separator), trimmed.slice(separator + 1));
  }
  return [...map.entries()].map(([key, value]) => `${key}=${value}`).join("; ");
}

async function sha256Bytes(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

Deno.serve(async (req) => {
  let activeRunId: string | null = null;
  if (req.method === "OPTIONS") return new Response("ok", { headers: JSON_HEADERS });
  if (req.method !== "POST") return jsonResponse({ error: "POST required" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const actUsername = Deno.env.get("ACT_SYNC_USERNAME");
  const actPassword = Deno.env.get("ACT_SYNC_PASSWORD");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Supabase service configuration is incomplete" }, 500);
  }
  if (!actUsername || !actPassword) {
    return jsonResponse({ error: "ACT_SYNC_USERNAME and ACT_SYNC_PASSWORD must be configured" }, 500);
  }

  const service = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const requestedBy = await authorize(req, service);
    const requestInput = await req.json() as SyncRequest;

    if (requestInput.inspectExportJobId) {
      const act = new ActClient();
      await act.login(actUsername, actPassword);
      const fileUrl = await act.inspectExportFileUrl(String(requestInput.inspectExportJobId));
      return jsonResponse({
        job_id: String(requestInput.inspectExportJobId),
        file_url: fileUrl,
      });
    }

    if (requestInput.inspectPlantingPage) {
      const act = new ActClient();
      await act.login(actUsername, actPassword);
      const page = await act.request(`${ACT_INDEX_ROOT}planting`, { method: "GET" }, 30_000);
      const html = await page.text();
      const scripts = [...html.matchAll(/<script[^>]+src=["']([^"']+)["']/gi)]
        .map((match) => absoluteActFileUrl(match[1]));
      const snippets = [...html.matchAll(/.{0,180}(?:ajax|serverSide|planting\/[a-z0-9_/-]+).{0,260}/gi)]
        .slice(0, 30)
        .map((match) => match[0].replace(/\s+/g, " ").trim());
      const tableMarker = html.indexOf("planting/table/");
      const tableConfig = tableMarker >= 0
        ? html.slice(Math.max(0, tableMarker - 2_500), tableMarker + 8_000)
        : "";
      const areaAdjustment = [...html.matchAll(/.{0,220}(?:PLD|Area Adjustment).{0,420}/gi)]
        .slice(0, 20)
        .map((match) => match[0].replace(/\s+/g, " ").trim());
      const plantingLinks = [...html.matchAll(/<a[^>]+href=["']([^"']*planting[^"']*)["'][^>]*>([\s\S]*?)<\/a>/gi)]
        .slice(0, 30)
        .map((match) => ({
          href: absoluteActFileUrl(match[1]),
          label: match[2].replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim(),
        }));
      const pldPage = await act.postForm(
        "template/page",
        new URLSearchParams({ menu: "rekomendasi_pld" }),
        30_000,
      );
      const pldHtml = await pldPage.text();
      const pldSnippets = [...pldHtml.matchAll(/.{0,220}(?:ajax|serverSide|rekomendasi_pld\/[a-z0-9_/-]+).{0,500}/gi)]
        .slice(0, 30)
        .map((match) => match[0].replace(/\s+/g, " ").trim());
      const pldTableMarker = pldHtml.indexOf("rekomendasi_pld/datatable/");
      const pldTableConfig = pldTableMarker >= 0
        ? pldHtml.slice(Math.max(0, pldTableMarker - 3_000), pldTableMarker + 8_000)
        : "";
      const cropSnippets = [...html.matchAll(/.{0,180}(?:HSP|PSP|Sweet Corn|Field Corn|planting_produk_jenis).{0,360}/gi)]
        .slice(0, 30)
        .map((match) => match[0].replace(/\s+/g, " ").trim());
      const pageEndpoints = [...new Set(
        [...html.matchAll(/BASE_URL\s*\+\s*["']([^"']+)["']/g)].map((match) => match[1]),
      )];
      const loadPageMarker = Math.max(
        html.indexOf("function loadPage"),
        html.indexOf("loadPage ="),
      );
      const loadPageConfig = loadPageMarker >= 0
        ? html.slice(Math.max(0, loadPageMarker - 500), loadPageMarker + 5_000)
        : "";
      return jsonResponse({
        scripts,
        snippets,
        table_config: tableConfig,
        area_adjustment: areaAdjustment,
        planting_links: plantingLinks,
        pld_snippets: pldSnippets,
        pld_table_config: pldTableConfig,
        crop_snippets: cropSnippets,
        page_endpoints: pageEndpoints,
        load_page_config: loadPageConfig,
        pld_page: {
          status: pldPage.status,
          url: pldPage.url,
          length: pldHtml.length,
          start: pldHtml.slice(0, 2_000),
        },
      });
    }

    if (requestInput.inspectPlantingTable) {
      const act = new ActClient();
      await act.login(actUsername, actPassword);
      const year = String(requestInput.from ?? new Date().getUTCFullYear()).slice(0, 4);
      const query = new URLSearchParams({
        draw: "1",
        start: "0",
        length: "100",
        "search[value]": "",
        "search[regex]": "false",
      });
      const routes: Record<SourceType, string> = {
        FC: "planting/table",
        PS: "planting/Planting_ps/table",
        SC: "planting/Planting_sc/table",
      };
      const results: Record<string, unknown> = {};
      for (const [source, route] of Object.entries(routes)) {
        const response = await act.request(
          `${ACT_INDEX_ROOT}${route}/${year}?${query}`,
          { method: "GET" },
          60_000,
        );
        const text = await response.text();
        let body: unknown = text.slice(0, 30_000);
        try {
          const parsed = JSON.parse(text);
          body = {
            recordsTotal: parsed.recordsTotal,
            recordsFiltered: parsed.recordsFiltered,
            data: Array.isArray(parsed.data) ? parsed.data.slice(0, 2) : parsed.data,
          };
        } catch {
          // Keep the bounded response text for diagnostics.
        }
        results[source] = { http_status: response.status, body };
      }
      return jsonResponse(results);
    }

    if (requestInput.inspectPldTable) {
      const act = new ActClient();
      await act.login(actUsername, actPassword);
      const year = String(requestInput.from ?? new Date().getUTCFullYear()).slice(0, 4);
      const query = new URLSearchParams({
        draw: "1",
        start: "0",
        length: "100",
        "search[value]": "",
        "search[regex]": "false",
        status: "3",
      });
      const response = await act.request(
        `${ACT_INDEX_ROOT}rekomendasi_pld/datatable/${year}?${query}`,
        { method: "GET" },
        60_000,
      );
      const text = await response.text();
      const payload = parsePossiblyEncodedJson(text);
      const rows = Array.isArray(payload?.data) ? payload.data : [];
      return jsonResponse({
        http_status: response.status,
        records_total: payload?.recordsTotal,
        records_filtered: payload?.recordsFiltered,
        first_rows: rows.slice(0, 2),
        adjusted_example: rows.find((row: unknown[]) =>
          Number(row?.[14] ?? 0) !== 0 || Number(row?.[12] ?? 0) !== Number(row?.[13] ?? 0)
        ) ?? null,
      });
    }

    if (requestInput.runId) {
      activeRunId = String(requestInput.runId);
      const { data: storedRun, error: storedRunError } = await service
        .from("act_sync_runs")
        .select(
          "id,status,dry_run,source_from,source_to,requested_sources,source_counts,source_meta,summary,error_message",
        )
        .eq("id", activeRunId)
        .maybeSingle();
      if (storedRunError) throw new Error(`Cannot read ACT sync run: ${storedRunError.message}`);
      if (!storedRun) throw new HttpError("ACT sync run not found", 404);

      const storedStatus = String(storedRun.status);
      if (new Set(["READY", "BLOCKED", "COMPLETED", "FAILED"]).has(storedStatus)) {
        return jsonResponse({
          run_id: activeRunId,
          status: storedStatus,
          dry_run: storedRun.dry_run,
          summary: storedRun.summary,
          error: storedRun.error_message,
        });
      }

      const sourceMeta = recordValue(storedRun.source_meta);
      const syncConfig = recordValue(sourceMeta.sync_config);
      if (!sourceMeta.queued_at && storedStatus === "WAITING_EXPORT") {
        throw new Error("This run predates resumable export metadata; start a new run");
      }
      const input = validateRequest({
        from: String(storedRun.source_from),
        to: String(storedRun.source_to),
        apply: storedRun.dry_run === false,
        sources: Array.isArray(storedRun.requested_sources)
          ? storedRun.requested_sources.map(String) as SourceType[]
          : undefined,
        exportMode: String(syncConfig.export_mode ?? "table") as
          | "table"
          | "background"
          | "sync",
        includeWkt: syncConfig.include_wkt !== false,
        minimumRows: Number(syncConfig.minimum_rows ?? 1_000),
        maxChangeRatio: Number(syncConfig.max_change_ratio ?? 0.25),
      });
      const sourceCounts = Object.fromEntries(
        Object.entries(recordValue(storedRun.source_counts)).map(([key, value]) => [key, Number(value)]),
      );

      if (
        (storedStatus === "EXTRACTING" || storedStatus === "VALIDATING") &&
        input.exportMode === "table"
      ) {
        const tableState = recordValue(sourceMeta.table_state);
        const source = input.sources.find((candidate) =>
          recordValue(tableState[candidate]).complete !== true
        );
        if (!source) {
          const wktState = recordValue(sourceMeta.wkt_state);
          if (input.includeWkt && wktState.complete !== true) {
            if (!wktState.queued_at) {
              const act = new ActClient();
              await act.login(actUsername, actPassword);
              const existingJobs = await act.listExportJobs();
              const wktSources = Object.fromEntries(
                input.sources.map((candidate) => [
                  candidate,
                  {
                    job_id: null,
                    row_cursor: 0,
                    processed_rows: 0,
                    geometry_rows: 0,
                    matched_rows: 0,
                    complete: false,
                  },
                ]),
              );
              for (const candidate of input.sources) {
                await act.startBackgroundExport(candidate, input.from, input.to);
              }
              sourceMeta.wkt_state = {
                queued_at: new Date().toISOString(),
                existing_job_ids: existingJobs.map((job) => job.id),
                sources: wktSources,
                complete: false,
              };
              const { error: queueError } = await service
                .from("act_sync_runs")
                .update({ status: "EXTRACTING", source_meta: sourceMeta })
                .eq("id", activeRunId);
              if (queueError) throw new Error(`Cannot queue ACT WKT exports: ${queueError.message}`);
              return jsonResponse({
                run_id: activeRunId,
                status: "EXTRACTING",
                staged_source: "WKT_EXPORTS",
                pending_sources: input.sources,
              }, 202);
            }

            const wktSources = recordValue(wktState.sources);
            const wktSource = input.sources.find((candidate) =>
              recordValue(wktSources[candidate]).complete !== true
            );
            if (wktSource) {
              const sourceState = recordValue(wktSources[wktSource]);
              const act = new ActClient();
              await act.login(actUsername, actPassword);
              let jobId = String(sourceState.job_id ?? "");
              if (!jobId) {
                const existingIds = new Set(
                  Array.isArray(wktState.existing_job_ids)
                    ? wktState.existing_job_ids.map(String)
                    : [],
                );
                const lookup = await act.findBackgroundJobs(
                  [wktSource],
                  input.from,
                  input.to,
                  existingIds,
                );
                const readyJob = lookup.ready[wktSource];
                if (!readyJob) {
                  return jsonResponse({
                    run_id: activeRunId,
                    status: "EXTRACTING",
                    staged_source: "WKT_EXPORTS",
                    pending_sources: [wktSource],
                    observed_jobs: lookup.observed,
                  }, 202);
                }
                jobId = readyJob.id;
              }

              const artifact = await act.downloadBackgroundExport(wktSource, {
                id: jobId,
                kind: EXPORT_KIND[wktSource],
                from: input.from,
                to: input.to,
                status: "success",
                createdAt: "",
              });
              const cursor = Number(sourceState.row_cursor ?? 0);
              const chunkRows = Math.max(250, Number(syncConfig.wkt_chunk_rows ?? 2_000));
              const merged = await mergeGeometryArtifactChunk(
                service,
                activeRunId,
                artifact,
                cursor,
                chunkRows,
              );
              wktSources[wktSource] = {
                job_id: jobId,
                file_hash: artifact.fileHash,
                row_cursor: merged.nextCursor,
                processed_rows: Number(sourceState.processed_rows ?? 0) + merged.processedRows,
                geometry_rows: Number(sourceState.geometry_rows ?? 0) + merged.geometryRows,
                matched_rows: Number(sourceState.matched_rows ?? 0) + merged.matchedRows,
                complete: merged.complete,
                updated_at: new Date().toISOString(),
              };
              wktState.sources = wktSources;
              wktState.complete = input.sources.every((candidate) =>
                recordValue(wktSources[candidate]).complete === true
              );
              sourceMeta.wkt_state = wktState;
              const { error: wktUpdateError } = await service
                .from("act_sync_runs")
                .update({ status: "EXTRACTING", source_meta: sourceMeta })
                .eq("id", activeRunId);
              if (wktUpdateError) {
                throw new Error(`Cannot update ACT WKT cursor: ${wktUpdateError.message}`);
              }
              return jsonResponse({
                run_id: activeRunId,
                status: "EXTRACTING",
                staged_source: `${wktSource}_WKT`,
                staged_rows: merged.processedRows,
                geometry_rows: merged.geometryRows,
                matched_rows: merged.matchedRows,
                source_cursor: merged.nextCursor,
                source_complete: merged.complete,
              }, 202);
            }
            wktState.complete = true;
            wktState.completed_at = new Date().toISOString();
            sourceMeta.wkt_state = wktState;
          } else if (!input.includeWkt && wktState.complete !== true) {
            sourceMeta.wkt_state = {
              complete: true,
              skipped: true,
              completed_at: new Date().toISOString(),
            };
          }

          const pldState = recordValue(tableState.PLD);
          if (pldState.complete !== true) {
            const act = new ActClient();
            await act.login(actUsername, actPassword);
            const start = Number(pldState.next_start ?? 0);
            const pageSize = Number(syncConfig.pld_page_size ?? 1_000);
            const page = await act.readFinalPldPage(
              input.from.slice(0, 4),
              start,
              pageSize,
            );
            const numberOrNull = (value: unknown): number | null => {
              if (value === null || value === undefined || String(value).trim() === "") return null;
              const parsed = Number(value);
              return Number.isFinite(parsed) ? parsed : null;
            };
            const pldRows = page.rows.map((row, index) => ({
              field_number_norm: normalizeFieldNumber(row[3]),
              approved_at: String(row[2] ?? ""),
              source_row: start + index + 1,
              planted_area_ha: numberOrNull(row[12]),
              effective_area_ha: numberOrNull(row[13]),
              discard_area_ha: numberOrNull(row[14]),
            })).filter((row) => row.field_number_norm);
            const { data: merged, error: mergeError } = await service.rpc(
              "merge_act_sync_pld_page",
              { p_run_id: activeRunId, p_rows: pldRows },
            );
            if (mergeError) throw new Error(`Cannot merge ACT PLD page: ${mergeError.message}`);

            const nextStart = start + page.rows.length;
            const complete = page.rows.length === 0 || nextStart >= page.total;
            const mergeResult = recordValue(merged);
            const matched = Number(pldState.matched_rows ?? 0) + Number(mergeResult.matched ?? 0);
            tableState.PLD = {
              next_start: nextStart,
              processed_rows: Number(pldState.processed_rows ?? 0) + pldRows.length,
              matched_rows: matched,
              table_total: page.total,
              complete,
              status_filter: 3,
              updated_at: new Date().toISOString(),
            };
            sourceMeta.table_state = tableState;
            sourceMeta.pld_final_count = page.total;
            sourceMeta.pld_matched_count = matched;
            const { error: pldUpdateError } = await service
              .from("act_sync_runs")
              .update({ status: "EXTRACTING", source_meta: sourceMeta })
              .eq("id", activeRunId);
            if (pldUpdateError) {
              throw new Error(`Cannot update ACT PLD cursor: ${pldUpdateError.message}`);
            }
            return jsonResponse({
              run_id: activeRunId,
              status: "EXTRACTING",
              staged_source: "PLD",
              staged_rows: pldRows.length,
              matched_rows: Number(mergeResult.matched ?? 0),
              source_cursor: nextStart,
              source_total: page.total,
              source_complete: complete,
            }, 202);
          }

          const prepareState = recordValue(sourceMeta.prepare_state);
          if (!prepareState.initialized_at) {
            const { error: clearError } = await service
              .from("act_sync_changes")
              .delete()
              .eq("run_id", activeRunId);
            if (clearError) throw new Error(`Cannot reset ACT sync decisions: ${clearError.message}`);
            const prepareSources = Object.fromEntries(
              input.sources.map((candidate) => [
                candidate,
                {
                  next_row: 1,
                  max_row: Number(recordValue(tableState[candidate]).next_start ?? 0),
                  prepared_rows: 0,
                  complete: false,
                },
              ]),
            );
            sourceMeta.prepare_state = {
              initialized_at: new Date().toISOString(),
              sources: prepareSources,
              complete: false,
            };
            const { error: prepareInitError } = await service
              .from("act_sync_runs")
              .update({ status: "VALIDATING", source_meta: sourceMeta })
              .eq("id", activeRunId);
            if (prepareInitError) {
              throw new Error(`Cannot initialize ACT validation batches: ${prepareInitError.message}`);
            }
            return jsonResponse({
              run_id: activeRunId,
              status: "VALIDATING",
              staged_source: "RECONCILIATION",
            }, 202);
          }

          const prepareSources = recordValue(prepareState.sources);
          const prepareSource = input.sources.find((candidate) =>
            recordValue(prepareSources[candidate]).complete !== true
          );
          if (prepareSource) {
            const prepareSourceState = recordValue(prepareSources[prepareSource]);
            const fromRow = Number(prepareSourceState.next_row ?? 1);
            const maxRow = Number(prepareSourceState.max_row ?? 0);
            const batchRows = Math.max(250, Number(syncConfig.prepare_batch_rows ?? 2_000));
            const toRow = Math.min(maxRow, fromRow + batchRows - 1);
            const { data: prepared, error: prepareError } = await service.rpc(
              "prepare_act_master_fields_sync_batch",
              {
                p_run_id: activeRunId,
                p_source_type: prepareSource,
                p_from_row: fromRow,
                p_to_row: Math.max(fromRow, toRow),
              },
            );
            if (prepareError) {
              throw new Error(`Cannot prepare ACT validation batch: ${prepareError.message}`);
            }
            const prepareResult = recordValue(prepared);
            const complete = maxRow === 0 || toRow >= maxRow;
            prepareSources[prepareSource] = {
              next_row: toRow + 1,
              max_row: maxRow,
              prepared_rows: Number(prepareSourceState.prepared_rows ?? 0) +
                Number(prepareResult.prepared_rows ?? 0),
              complete,
              updated_at: new Date().toISOString(),
            };
            prepareState.sources = prepareSources;
            prepareState.complete = input.sources.every((candidate) =>
              recordValue(prepareSources[candidate]).complete === true
            );
            sourceMeta.prepare_state = prepareState;
            const { error: prepareUpdateError } = await service
              .from("act_sync_runs")
              .update({ status: "VALIDATING", source_meta: sourceMeta })
              .eq("id", activeRunId);
            if (prepareUpdateError) {
              throw new Error(`Cannot update ACT validation cursor: ${prepareUpdateError.message}`);
            }
            return jsonResponse({
              run_id: activeRunId,
              status: "VALIDATING",
              staged_source: `${prepareSource}_RECONCILIATION`,
              prepared_rows: Number(prepareResult.prepared_rows ?? 0),
              source_cursor: toRow + 1,
              source_total: maxRow,
              source_complete: complete,
            }, 202);
          }

          const { data: finalized, error: finalizeError } = await service.rpc(
            "finalize_act_master_fields_sync_batches",
            { p_run_id: activeRunId },
          );
          if (finalizeError) {
            throw new Error(`Cannot finalize ACT validation batches: ${finalizeError.message}`);
          }
          const finalResult = recordValue(finalized);
          if (String(finalResult.status) === "BLOCKED") {
            return jsonResponse(finalResult, 409);
          }
          if (input.apply && String(finalResult.status) === "READY") {
            const { data: applied, error: applyError } = await service.rpc(
              "apply_act_master_fields_sync",
              { p_run_id: activeRunId },
            );
            if (applyError) throw new Error(`ACT sync apply failed: ${applyError.message}`);
            return jsonResponse({
              run_id: activeRunId,
              status: "COMPLETED",
              summary: finalResult.summary,
              applied,
            });
          }
          return jsonResponse(finalResult);
        }

        const act = new ActClient();
        await act.login(actUsername, actPassword);
        const state = recordValue(tableState[source]);
        const start = Number(state.next_start ?? 0);
        const pageSize = Number(syncConfig.page_size ?? 5_000);
        const page = await act.readPlantingTablePage(
          source,
          input.from.slice(0, 4),
          start,
          pageSize,
        );
        const parsedRows = page.rows
          .map((row, index) => mapPlantingTableRow(row, source, start + index + 1))
          .filter((row) => {
            const plantingDate = String(row.sourcePayload.planting_date_pdn ?? "");
            return !isIsoDate(plantingDate) ||
              (plantingDate >= input.from && plantingDate <= input.to);
          });
        await stageParsedRows(service, activeRunId, parsedRows);

        const nextStart = start + page.rows.length;
        const processedRows = Number(state.processed_rows ?? 0) + parsedRows.length;
        const complete = page.rows.length === 0 || nextStart >= page.total;
        tableState[source] = {
          next_start: nextStart,
          processed_rows: processedRows,
          table_total: page.total,
          complete,
          updated_at: new Date().toISOString(),
        };
        sourceCounts[source] = processedRows;
        sourceMeta.table_state = tableState;
        const allComplete = input.sources.every((candidate) =>
          recordValue(tableState[candidate]).complete === true
        );
        const pldComplete = recordValue(tableState.PLD).complete === true;
        const nextStatus = allComplete && pldComplete ? "VALIDATING" : "EXTRACTING";
        const { error: pageUpdateError } = await service
          .from("act_sync_runs")
          .update({
            status: nextStatus,
            source_counts: sourceCounts,
            source_meta: sourceMeta,
          })
          .eq("id", activeRunId);
        if (pageUpdateError) {
          throw new Error(`Cannot update ACT table cursor: ${pageUpdateError.message}`);
        }
        return jsonResponse({
          run_id: activeRunId,
          status: nextStatus,
          staged_source: source,
          staged_rows: parsedRows.length,
          source_cursor: nextStart,
          source_total: page.total,
          source_complete: complete,
        }, 202);
      }

      if (storedStatus === "VALIDATING") {
        return await prepareRunInDatabase(service, activeRunId, input);
      }
      if (storedStatus !== "WAITING_EXPORT") {
        throw new HttpError(`Run cannot be resumed from status ${storedStatus}`, 409);
      }

      const act = new ActClient();
      await act.login(actUsername, actPassword);
      const existingIds = new Set(
        Array.isArray(sourceMeta.existing_job_ids)
          ? sourceMeta.existing_job_ids.map(String)
          : [],
      );
      const exportsMeta = recordValue(sourceMeta.exports);
      const unstagedSources = input.sources.filter((source) =>
        !recordValue(exportsMeta[source]).staged_at
      );
      const lookup = await act.findBackgroundJobs(
        unstagedSources,
        input.from,
        input.to,
        existingIds,
      );
      const readySource = unstagedSources.find((source) => lookup.ready[source]);
      if (!readySource) {
        return jsonResponse({
          run_id: activeRunId,
          status: "WAITING_EXPORT",
          pending_sources: unstagedSources,
          observed_jobs: lookup.observed,
        }, 202);
      }

      const job = lookup.ready[readySource]!;
      const artifact = await act.downloadBackgroundExport(readySource, job);
      if (requestInput.inspectSource === readySource) {
        return jsonResponse({
          run_id: activeRunId,
          status: "INSPECTED",
          source: readySource,
          job_id: job.id,
          file_url: artifact.fileUrl,
          byte_length: artifact.bytes.length,
          magic: Array.from(artifact.bytes.slice(0, 8)),
        });
      }
      const staged = await stageArtifact(service, activeRunId, artifact);
      sourceCounts[readySource] = staged.rowCount;
      exportsMeta[readySource] = {
        job_id: job.id,
        export_kind: artifact.exportKind,
        file_hash: staged.fileHash,
        row_count: staged.rowCount,
        staged_at: new Date().toISOString(),
      };
      sourceMeta.exports = exportsMeta;
      const remaining = input.sources.filter((source) =>
        !recordValue(exportsMeta[source]).staged_at
      );
      const nextStatus = remaining.length === 0 ? "VALIDATING" : "WAITING_EXPORT";
      const { error: stageUpdateError } = await service
        .from("act_sync_runs")
        .update({
          status: nextStatus,
          source_counts: sourceCounts,
          source_meta: sourceMeta,
        })
        .eq("id", activeRunId);
      if (stageUpdateError) {
        throw new Error(`Cannot update staged ACT source: ${stageUpdateError.message}`);
      }
      return jsonResponse({
        run_id: activeRunId,
        status: nextStatus,
        staged_source: readySource,
        staged_rows: staged.rowCount,
        pending_sources: remaining,
      }, 202);
    }

    const input = validateRequest(requestInput);
    const { data: run, error: runError } = await service
      .from("act_sync_runs")
      .insert({
        status: "EXTRACTING",
        dry_run: !input.apply,
        source_from: input.from,
        source_to: input.to,
        requested_sources: input.sources,
        requested_by: requestedBy,
      })
      .select("id")
      .single();
    if (runError || !run) throw new Error(`Cannot create ACT sync run: ${runError?.message}`);
    activeRunId = String(run.id);

    const act = new ActClient();
    await act.login(actUsername, actPassword);

    if (input.exportMode === "table") {
      const tableState = Object.fromEntries(
        input.sources.map((source) => [
          source,
          { next_start: 0, processed_rows: 0, table_total: null, complete: false },
        ]),
      );
      tableState.PLD = {
        next_start: 0,
        processed_rows: 0,
        matched_rows: 0,
        table_total: null,
        complete: false,
        status_filter: 3,
      };
      const sourceMeta = {
        data_source: "planting_datatable_json",
        initialized_at: new Date().toISOString(),
        sync_config: {
          export_mode: input.exportMode,
          include_wkt: input.includeWkt,
          minimum_rows: input.minimumRows,
          max_change_ratio: input.maxChangeRatio,
          requested_apply: input.apply,
          page_size: 5_000,
          pld_page_size: 1_000,
          wkt_chunk_rows: 2_000,
          prepare_batch_rows: 2_000,
        },
        table_state: tableState,
      };
      const { error: tableInitError } = await service
        .from("act_sync_runs")
        .update({ status: "EXTRACTING", source_meta: sourceMeta })
        .eq("id", activeRunId);
      if (tableInitError) {
        throw new Error(`Cannot initialize ACT table sync: ${tableInitError.message}`);
      }
      return jsonResponse({
        run_id: activeRunId,
        status: "EXTRACTING",
        pending_sources: input.sources,
      }, 202);
    }

    if (input.exportMode === "background") {
      const existingJobs = await act.listExportJobs();
      const existingIds = new Set(existingJobs.map((job) => job.id));
      const exportsMeta: Record<string, unknown> = {};
      for (const source of input.sources) {
        await act.startBackgroundExport(source, input.from, input.to);
        exportsMeta[source] = { requested_at: new Date().toISOString() };
      }
      const sourceMeta = {
        queued_at: new Date().toISOString(),
        existing_job_ids: [...existingIds],
        sync_config: {
          export_mode: input.exportMode,
          include_wkt: input.includeWkt,
          minimum_rows: input.minimumRows,
          max_change_ratio: input.maxChangeRatio,
          requested_apply: input.apply,
        },
        exports: exportsMeta,
      };
      const { error: queueUpdateError } = await service
        .from("act_sync_runs")
        .update({ status: "WAITING_EXPORT", source_meta: sourceMeta })
        .eq("id", activeRunId);
      if (queueUpdateError) {
        throw new Error(`Cannot persist ACT export queue: ${queueUpdateError.message}`);
      }
      return jsonResponse({
        run_id: activeRunId,
        status: "WAITING_EXPORT",
        pending_sources: input.sources,
      }, 202);
    }

    const artifacts: ExportArtifact[] = [];
    for (const source of input.sources) {
      artifacts.push(await act.exportSynchronously(source, input.from, input.to));
    }
    const sourceCounts: Record<string, number> = {};
    const sourceMeta: Record<string, unknown> = {
      sync_config: {
        export_mode: input.exportMode,
        include_wkt: input.includeWkt,
        minimum_rows: input.minimumRows,
        max_change_ratio: input.maxChangeRatio,
        requested_apply: input.apply,
      },
    };
    for (const artifact of artifacts) {
      const staged = await stageArtifact(service, activeRunId, artifact);
      sourceCounts[artifact.sourceType] = staged.rowCount;
      sourceMeta[artifact.sourceType] = {
        export_kind: artifact.exportKind,
        file_hash: staged.fileHash,
        row_count: staged.rowCount,
      };
    }
    const { error: validationUpdateError } = await service
      .from("act_sync_runs")
      .update({
        status: "VALIDATING",
        source_counts: sourceCounts,
        source_meta: sourceMeta,
      })
      .eq("id", activeRunId);
    if (validationUpdateError) {
      throw new Error(`Cannot prepare ACT validation: ${validationUpdateError.message}`);
    }
    return await prepareRunInDatabase(service, activeRunId, input);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (activeRunId) {
      await service
        .from("act_sync_runs")
        .update({
          status: "FAILED",
          error_message: message.slice(0, 2_000),
          completed_at: new Date().toISOString(),
        })
        .eq("id", activeRunId);
    }
    const status = error instanceof HttpError ? error.status : 500;
    return jsonResponse({ error: message, run_id: activeRunId }, status);
  }
});
