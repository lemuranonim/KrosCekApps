export type SourceType = "FC" | "PS" | "SC";

export const MANAGED_FIELDS = [
  "field_number",
  "farmer_name",
  "grower",
  "hybrid",
  "total_area_planted_ha",
  "discard_area_ha",
  "effective_area_ha",
  "harvested_area_ha",
  "harvested_qty_kg",
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
] as const;

export type ManagedField = (typeof MANAGED_FIELDS)[number];
export type CanonicalPayload =
  & Partial<Record<ManagedField, string | number>>
  & {
    field_number: string;
  };

export interface ParsedSourceRow {
  sourceType: SourceType;
  sourceRow: number;
  fieldNumberRaw: string;
  fieldNumberNorm: string;
  rawPayload: Record<string, unknown>;
  sourcePayload: CanonicalPayload;
  validationErrors: string[];
}

export type ChangeKind =
  | "INSERT"
  | "UPDATE"
  | "UNCHANGED"
  | "INVALID"
  | "CONFLICT_SOURCE_DUPLICATE"
  | "CONFLICT_KC_DUPLICATE"
  | "MISSING_SOURCE";

export interface SyncChange {
  fieldNumberNorm: string;
  sourceType: SourceType | null;
  changeKind: ChangeKind;
  currentPayload: Record<string, unknown> | null;
  sourcePayload: CanonicalPayload | null;
  changedColumns: Record<string, { old: unknown; new: unknown }>;
  validationErrors: string[];
}

export interface ReconciliationResult {
  changes: SyncChange[];
  summary: Record<string, number>;
  sourceDuplicateResolutions: SourceDuplicateResolution[];
}

export interface SourceDuplicateResolution {
  field_number: string;
  selected_source_type: SourceType;
  selected_source_row: number;
  ignored_source_rows: Array<{ source_type: SourceType; source_row: number }>;
  reason: "ADVANCE_STATUS" | "MOST_COMPLETE_COMPATIBLE_ROW";
}

const HEADER_ALIASES: Record<ManagedField, string[]> = {
  field_number: [
    "field number",
    "field number fn",
    "field no",
    "fieldnumber",
    "fn",
    "fn field number",
    "nomor fn",
    "planting nomor",
    "planting_nomor",
  ],
  farmer_name: ["farmer", "petani", "planting petani", "planting_petani"],
  grower: ["organizer", "grower", "planting grower", "planting_grower"],
  hybrid: [
    "hybrid",
    "hibrida",
    "produk jenis sub",
    "planting produk jenis sub",
    "planting_produk_jenis_sub",
  ],
  total_area_planted_ha: [
    "planted area ha",
    "planted area",
    "luas ha",
    "luas area",
    "planting area ha",
    "planting_area_ha",
  ],
  discard_area_ha: [
    "pld area ha",
    "pld area",
    "discarded",
    "discarded area",
    "planting discard area",
    "planting_discard_area",
  ],
  effective_area_ha: [
    "effective area ha",
    "effective area",
    "nett",
    "net area",
    "planting efective area",
    "planting effective area",
    "planting_efective_area",
  ],
  harvested_area_ha: [
    "harvested area",
    "harvested area ha",
    "harvest area",
  ],
  harvested_qty_kg: [
    "weight",
    "harvested weight",
    "harvested qty",
    "harvested quantity",
  ],
  planting_date_pdn: [
    "female date",
    "planting date",
    "tanggal",
    "planting female date",
    "planting_female_date",
  ],
  hamlet_dusun: [
    "hemlet",
    "hamlet",
    "dusun",
    "planting dusun",
    "planting_dusun",
  ],
  village_desa: [
    "village",
    "desa",
    "planting desa nama",
    "planting_desa_nama",
  ],
  sub_district_kec: [
    "sub district",
    "subdistrict",
    "kecamatan",
    "planting kecamatan nama",
    "planting_kecamatan_nama",
  ],
  district_kab: [
    "district",
    "kabupaten",
    "planting kabupaten nama",
    "planting_kabupaten_nama",
  ],
  fa: [
    "field assistant",
    "field assistant now",
    "fa",
    "planting fa",
    "planting_fa",
    "planting_fa_now",
  ],
  field_spv: [
    "supervisor",
    "spv",
    "planting spv",
    "planting_spv",
  ],
  region: ["region", "planting region", "planting_region"],
  area_manager: [
    "manager",
    "area manager",
    "planting manager",
    "planting_manager",
  ],
  type: ["type", "crop type"],
  prov: [
    "province",
    "propinsi",
    "provinsi",
    "planting propinsi nama",
    "planting_propinsi_nama",
  ],
  planting_ratio: ["planting ratio", "planting_ratio"],
  planting_space: ["planting space", "planting_space"],
  geometry_wkt: [
    "geometry wkt",
    "geometry",
    "planting geo",
    "planting_geo",
  ],
};

const NUMERIC_FIELDS = new Set<ManagedField>([
  "total_area_planted_ha",
  "discard_area_ha",
  "effective_area_ha",
  "harvested_area_ha",
  "harvested_qty_kg",
]);

const SOURCE_DB_TYPE: Record<SourceType, string> = {
  FC: "Field Corn",
  PS: "Parent Seed",
  SC: "Sweet Corn",
};

export function normalizeFieldNumber(value: unknown): string {
  return cleanText(value)
    .replace(/\u00a0/g, " ")
    .replace(/\s+/g, "")
    .toUpperCase();
}

export function normalizeHeader(value: unknown): string {
  return cleanText(value)
    .toLowerCase()
    .replace(/[_/()\-.]+/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function cleanText(value: unknown): string {
  if (value === null || value === undefined) return "";
  const text = String(value)
    .replace(/\u00a0/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!text || /^(null|undefined|n\/a|-)$/i.test(text)) return "";
  return text;
}

export function parseNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;

  let text = cleanText(value).replace(/\s/g, "");
  if (!text) return null;

  const comma = text.lastIndexOf(",");
  const dot = text.lastIndexOf(".");
  if (comma >= 0 && dot >= 0) {
    if (comma > dot) text = text.replace(/\./g, "").replace(",", ".");
    else text = text.replace(/,/g, "");
  } else if (comma >= 0) {
    text = text.replace(",", ".");
  }

  text = text.replace(/[^0-9+\-.]/g, "");
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : null;
}

export function mapFinalPldAreas(row: unknown[]): {
  plantedAreaHa: number | null;
  discardAreaHa: number | null;
  effectiveAreaHa: number | null;
} {
  return {
    plantedAreaHa: parseNumber(row[12]),
    discardAreaHa: parseNumber(row[13]),
    effectiveAreaHa: parseNumber(row[14]),
  };
}

export function normalizeDate(value: unknown): string | null {
  if (value === null || value === undefined || value === "") return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    const excelEpoch = Date.UTC(1899, 11, 30);
    const date = new Date(excelEpoch + Math.round(value) * 86_400_000);
    return date.toISOString().slice(0, 10);
  }

  const text = cleanText(value);
  if (!text) return null;
  const iso = text.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})/);
  if (iso) {
    return `${iso[1]}-${iso[2].padStart(2, "0")}-${iso[3].padStart(2, "0")}`;
  }
  const local = text.match(/^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$/);
  if (local) {
    return `${local[3]}-${local[2].padStart(2, "0")}-${
      local[1].padStart(2, "0")
    }`;
  }

  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime())
    ? null
    : parsed.toISOString().slice(0, 10);
}

function buildLookup(row: Record<string, unknown>): Map<string, unknown> {
  const lookup = new Map<string, unknown>();
  for (const [key, value] of Object.entries(row)) {
    lookup.set(normalizeHeader(key), value);
  }
  return lookup;
}

function readAlias(
  lookup: Map<string, unknown>,
  field: ManagedField,
): unknown {
  for (const alias of HEADER_ALIASES[field]) {
    const value = lookup.get(normalizeHeader(alias));
    if (value !== null && value !== undefined && cleanText(value) !== "") {
      return value;
    }
  }
  return null;
}

export function mapExportRow(
  row: Record<string, unknown>,
  sourceType: SourceType,
  sourceRow: number,
): ParsedSourceRow {
  const lookup = buildLookup(row);
  const rawFieldNumber = cleanText(readAlias(lookup, "field_number"));
  const fieldNumber = normalizeFieldNumber(rawFieldNumber);
  const validationErrors: string[] = [];
  if (!fieldNumber) validationErrors.push("missing_field_number");

  const payload: Record<string, string | number> = {};
  if (fieldNumber) payload.field_number = fieldNumber;

  const textFields: ManagedField[] = [
    "farmer_name",
    "grower",
    "hamlet_dusun",
    "village_desa",
    "sub_district_kec",
    "district_kab",
    "field_spv",
    "region",
    "area_manager",
    "prov",
    "planting_ratio",
    "planting_space",
    "geometry_wkt",
  ];
  for (const field of textFields) {
    const value = cleanText(readAlias(lookup, field));
    if (value) payload[field] = value;
  }

  const hybrid = cleanText(readAlias(lookup, "hybrid"));
  if (hybrid) payload.hybrid = hybrid.toUpperCase();

  const fieldAssistantNow = lookup.get(normalizeHeader("field assistant now"));
  const fa = cleanText(fieldAssistantNow) || cleanText(readAlias(lookup, "fa"));
  if (fa) payload.fa = fa;

  for (const field of NUMERIC_FIELDS) {
    const raw = readAlias(lookup, field);
    const parsed = parseNumber(raw);
    if (parsed !== null) payload[field] = parsed;
    else if (cleanText(raw)) validationErrors.push(`invalid_number:${field}`);
  }

  const dateRaw = readAlias(lookup, "planting_date_pdn");
  const date = normalizeDate(dateRaw);
  if (date) payload.planting_date_pdn = date;
  else if (cleanText(dateRaw)) {
    validationErrors.push("invalid_date:planting_date_pdn");
  }

  payload.type = SOURCE_DB_TYPE[sourceType];

  const planted = payload.total_area_planted_ha as number | undefined;
  const discard = payload.discard_area_ha as number | undefined;
  const effective = payload.effective_area_ha as number | undefined;
  const harvestedArea = payload.harvested_area_ha as number | undefined;
  const harvestedQty = payload.harvested_qty_kg as number | undefined;
  for (
    const [name, value] of [
      ["total_area_planted_ha", planted],
      ["discard_area_ha", discard],
      ["effective_area_ha", effective],
      ["harvested_area_ha", harvestedArea],
      ["harvested_qty_kg", harvestedQty],
    ] as const
  ) {
    if (value !== undefined && value < 0) {
      validationErrors.push(`negative_area:${name}`);
    }
  }
  if (
    planted !== undefined && discard !== undefined && discard - planted > 0.01
  ) {
    validationErrors.push("discard_exceeds_planted");
  }
  if (
    planted !== undefined &&
    discard !== undefined &&
    effective !== undefined &&
    Math.abs(planted - discard - effective) > 0.01
  ) {
    validationErrors.push("area_reconciliation_mismatch");
  }

  return {
    sourceType,
    sourceRow,
    fieldNumberRaw: rawFieldNumber,
    fieldNumberNorm: fieldNumber,
    rawPayload: row,
    sourcePayload: payload as CanonicalPayload,
    validationErrors,
  };
}

export function pickManagedFields(
  row: Record<string, unknown>,
): Record<string, unknown> {
  const picked: Record<string, unknown> = {};
  for (const field of MANAGED_FIELDS) {
    if (Object.hasOwn(row, field)) picked[field] = row[field];
  }
  return picked;
}

function comparable(field: ManagedField, value: unknown): unknown {
  if (value === null || value === undefined) return null;
  if (NUMERIC_FIELDS.has(field)) return parseNumber(value);
  const text = cleanText(value);
  if (field === "field_number" || field === "hybrid" || field === "type") {
    return text.toUpperCase();
  }
  if (field === "planting_date_pdn") return normalizeDate(value) ?? text;
  return text;
}

const DUPLICATE_IDENTITY_FIELDS: ManagedField[] = [
  "planting_date_pdn",
  "hybrid",
  "total_area_planted_ha",
];

function hasSourceValue(value: unknown): boolean {
  return value !== null && value !== undefined && cleanText(value) !== "";
}

export function normalizeActAdvanceStatus(value: unknown): 1 | 2 | 3 | null {
  switch (cleanText(value).toLowerCase()) {
    case "1":
    case "advance":
      return 1;
    case "2":
    case "no advance":
      return 2;
    case "3":
    case "custom advance":
      return 3;
    default:
      return null;
  }
}

export function mapPlantingTableRow(
  row: unknown[],
  sourceType: SourceType,
  sourceRow: number,
): ParsedSourceRow {
  return mapExportRow(
    {
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
      "_act_planting_id": cleanText(row[0]),
      "_act_advance_status": normalizeActAdvanceStatus(row[12]),
    },
    sourceType,
    sourceRow,
  );
}

function isAdvance(row: ParsedSourceRow): boolean {
  return normalizeActAdvanceStatus(
    row.rawPayload._act_advance_status ?? row.rawPayload.Advance,
  ) === 1;
}

// Advance has authority within the same planting. Among equal-priority rows,
// a winner must contain every populated value from the others. Column counts
// alone could discard a conflicting value; never manufacture a merged row.
function mostCompleteCompatibleSourceRow(
  rows: ParsedSourceRow[],
): ParsedSourceRow | null {
  const first = rows[0];
  if (
    rows.some((row) =>
      row.sourceType !== first.sourceType || row.validationErrors.length > 0 ||
      DUPLICATE_IDENTITY_FIELDS.some((field) =>
        !hasSourceValue(row.sourcePayload[field]) ||
        comparable(field, row.sourcePayload[field]) !==
          comparable(field, first.sourcePayload[field])
      )
    )
  ) return null;

  const advanceRows = rows.filter(isAdvance);
  const pool = advanceRows.length > 0 ? advanceRows : rows;
  const candidates = pool.filter((candidate) =>
    pool.every((other) =>
      Object.entries(other.sourcePayload).every(([key, value]) =>
        !hasSourceValue(value) ||
        (hasSourceValue(candidate.sourcePayload[key as ManagedField]) &&
          comparable(
              key as ManagedField,
              candidate.sourcePayload[key as ManagedField],
            ) ===
            comparable(key as ManagedField, value))
      )
    )
  );
  // Equal complete rows are interchangeable; retain a stable source position.
  return candidates.sort((left, right) =>
    left.sourceRow - right.sourceRow
  )[0] ?? null;
}

export function changedColumns(
  current: Record<string, unknown>,
  incoming: CanonicalPayload,
): Record<string, { old: unknown; new: unknown }> {
  const changes: Record<string, { old: unknown; new: unknown }> = {};
  for (const field of MANAGED_FIELDS) {
    if (field === "field_number" || !Object.hasOwn(incoming, field)) continue;
    const before = comparable(field, current[field]);
    const after = comparable(field, incoming[field]);
    if (typeof before === "number" && typeof after === "number") {
      if (Math.abs(before - after) <= 0.0001) continue;
    } else if (before === after) {
      continue;
    }
    changes[field] = {
      old: current[field] ?? null,
      new: incoming[field] ?? null,
    };
  }
  return changes;
}

export function reconcile(
  sourceRows: ParsedSourceRow[],
  currentRows: Record<string, unknown>[],
): ReconciliationResult {
  const changes: SyncChange[] = [];
  const sourceDuplicateResolutions: SourceDuplicateResolution[] = [];
  const sourceGroups = new Map<string, ParsedSourceRow[]>();
  const currentGroups = new Map<string, Record<string, unknown>[]>();

  for (const row of sourceRows) {
    const key = row.fieldNumberNorm ||
      `__INVALID_SOURCE_${row.sourceType}_${row.sourceRow}`;
    const group = sourceGroups.get(key) ?? [];
    group.push(row);
    sourceGroups.set(key, group);
  }
  for (const row of currentRows) {
    const key = normalizeFieldNumber(row.field_number);
    if (!key) continue;
    const group = currentGroups.get(key) ?? [];
    group.push(row);
    currentGroups.set(key, group);
  }

  const seenValidSource = new Set<string>();
  for (const [key, rows] of sourceGroups) {
    const selected = rows.length > 1 && rows[0].fieldNumberNorm
      ? mostCompleteCompatibleSourceRow(rows)
      : null;
    const first = selected ?? rows[0];
    // A malformed or duplicate ACT row is still present in the snapshot. Mark
    // it as seen so the same FN is not also misclassified as MISSING_SOURCE.
    if (first.fieldNumberNorm) seenValidSource.add(first.fieldNumberNorm);
    if (
      !first.fieldNumberNorm ||
      (rows.length === 1 && first.validationErrors.length > 0)
    ) {
      changes.push({
        fieldNumberNorm: first.fieldNumberNorm || key,
        sourceType: first.sourceType,
        changeKind: "INVALID",
        currentPayload: null,
        sourcePayload: first.sourcePayload,
        changedColumns: {},
        validationErrors: [
          ...new Set(rows.flatMap((row) => row.validationErrors)),
        ],
      });
      continue;
    }
    if (rows.length > 1 && !selected) {
      changes.push({
        fieldNumberNorm: first.fieldNumberNorm,
        sourceType: first.sourceType,
        changeKind: "CONFLICT_SOURCE_DUPLICATE",
        currentPayload: null,
        sourcePayload: first.sourcePayload,
        changedColumns: {},
        validationErrors: [
          `duplicate_source_rows:${
            rows.map((row) => `${row.sourceType}:${row.sourceRow}`).join(",")
          }`,
        ],
      });
      continue;
    }
    if (selected) {
      sourceDuplicateResolutions.push({
        field_number: selected.fieldNumberNorm,
        selected_source_type: selected.sourceType,
        selected_source_row: selected.sourceRow,
        ignored_source_rows: rows.filter((row) => row !== selected).map((
          row,
        ) => ({
          source_type: row.sourceType,
          source_row: row.sourceRow,
        })).sort((left, right) => left.source_row - right.source_row),
        reason: isAdvance(selected)
          ? "ADVANCE_STATUS"
          : "MOST_COMPLETE_COMPATIBLE_ROW",
      });
    }
    const currentMatches = currentGroups.get(first.fieldNumberNorm) ?? [];
    if (currentMatches.length > 1) {
      changes.push({
        fieldNumberNorm: first.fieldNumberNorm,
        sourceType: first.sourceType,
        changeKind: "CONFLICT_KC_DUPLICATE",
        currentPayload: pickManagedFields(currentMatches[0]),
        sourcePayload: first.sourcePayload,
        changedColumns: {},
        validationErrors: [`duplicate_kc_rows:${currentMatches.length}`],
      });
      continue;
    }
    if (currentMatches.length === 0) {
      changes.push({
        fieldNumberNorm: first.fieldNumberNorm,
        sourceType: first.sourceType,
        changeKind: "INSERT",
        currentPayload: null,
        sourcePayload: first.sourcePayload,
        changedColumns: Object.fromEntries(
          Object.entries(first.sourcePayload).map((
            [field, value],
          ) => [field, { old: null, new: value }]),
        ),
        validationErrors: [],
      });
      continue;
    }

    const current = pickManagedFields(currentMatches[0]);
    const differences = changedColumns(current, first.sourcePayload);
    changes.push({
      fieldNumberNorm: first.fieldNumberNorm,
      sourceType: first.sourceType,
      changeKind: Object.keys(differences).length ? "UPDATE" : "UNCHANGED",
      currentPayload: current,
      sourcePayload: first.sourcePayload,
      changedColumns: differences,
      validationErrors: [],
    });
  }

  for (const [fieldNumber, rows] of currentGroups) {
    if (seenValidSource.has(fieldNumber) || rows.length > 1) continue;
    changes.push({
      fieldNumberNorm: fieldNumber,
      sourceType: null,
      changeKind: "MISSING_SOURCE",
      currentPayload: pickManagedFields(rows[0]),
      sourcePayload: null,
      changedColumns: {},
      validationErrors: [],
    });
  }

  const summary: Record<string, number> = {
    source_rows: sourceRows.length,
    current_rows: currentRows.length,
    resolved_source_duplicate: sourceDuplicateResolutions.length,
    ignored_source_duplicate_rows: sourceDuplicateResolutions.reduce(
      (total, resolution) => total + resolution.ignored_source_rows.length,
      0,
    ),
  };
  summary.source_rows_after_deduplication = sourceRows.length -
    summary.ignored_source_duplicate_rows;
  for (const change of changes) {
    summary[change.changeKind.toLowerCase()] =
      (summary[change.changeKind.toLowerCase()] ?? 0) + 1;
  }
  summary.blockers = (summary.invalid ?? 0) +
    (summary.conflict_source_duplicate ?? 0) +
    (summary.conflict_kc_duplicate ?? 0);
  summary.actionable = (summary.insert ?? 0) + (summary.update ?? 0);
  return { changes, summary, sourceDuplicateResolutions };
}

export function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(",")}]`;
  const object = value as Record<string, unknown>;
  return `{${
    Object.keys(object)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableStringify(object[key])}`)
      .join(",")
  }}`;
}

export async function sha256(value: unknown): Promise<string> {
  const bytes = new TextEncoder().encode(stableStringify(value));
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}
