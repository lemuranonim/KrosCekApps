import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const CACHE_NAMESPACE = "master_fields_map";
const CACHE_TTL_SECONDS = 3600;
const MAX_CACHE_VALUE_BYTES = 7_500_000;
const PAGE_SIZE = 1000;
const PARALLEL_PAGES = 3;

const MAP_SELECT = `
  field_number,
  season,
  farmer_name,
  grower,
  hybrid,
  total_area_planted_ha,
  discard_area_ha,
  effective_area_ha,
  planting_date_pdn,
  hamlet_dusun,
  village_desa,
  sub_district_kec,
  district_kab,
  fa,
  field_spv,
  coordinate,
  correction_tagging,
  region,
  area_manager,
  harvested_area_ha,
  harvested_qty_kg,
  previous_crop_data_a_b,
  standing_crops,
  type,
  prov,
  planting_date_rev,
  is_active,
  qa_fi,
  qa_spv,
  planting_ratio,
  planting_space,
  flagging_final,
  target_dt_date,
  season_id,
  geometry_wkt,
  correction_geometry_wkt,
  geometry_area_ha,
  geometry_source,
  geometry_updated_at,
  corr_field_size_ha,
  corr_field_size_source,
  corr_field_size_updated_at,
  audit_vegetative(
    date_of_audit,
    rev_planting_date,
    co_detasseling,
    correction_tagging,
    decision,
    action_needed,
    date_of_inspeksi_roguing_1,
    date_of_inspeksi_roguing_2,
    date_of_inspeksi_roguing_3,
    date_of_inspeksi_roguing_4
  ),
  audit_generative(
    date_of_audit_1,
    date_of_audit_2,
    date_of_audit_3,
    date_of_audit_4,
    date_of_audit_5,
    action_needed_1,
    action_needed_2,
    action_needed_3,
    action_needed_4,
    final_decision_3,
    final_decision_5,
    detasseling_assesment_3,
    detasseling_assesment_5
  ),
  audit_pre_harvest(
    audit_date,
    final_decision,
    final_flagging
  ),
  audit_harvest(
    date_of_audit,
    final_flagging,
    status_downgrade,
    downgrade_flagging
  )
`;

// Coverage intentionally has its own Redis keyspace because its nested audit
// payload is much larger than the map payload. Both datasets share the same
// database generation counter, so an audit/master-field write invalidates
// them together without waiting for the TTL.
const COVERAGE_SELECT = `
  field_number,
  season,
  farmer_name,
  grower,
  hybrid,
  total_area_planted_ha,
  discard_area_ha,
  effective_area_ha,
  planting_date_pdn,
  hamlet_dusun,
  village_desa,
  sub_district_kec,
  district_kab,
  fa,
  field_spv,
  coordinate,
  correction_tagging,
  region,
  area_manager,
  harvested_area_ha,
  harvested_qty_kg,
  previous_crop_data_a_b,
  standing_crops,
  type,
  prov,
  planting_date_rev,
  is_active,
  qa_fi,
  qa_spv,
  planting_ratio,
  planting_space,
  flagging_final,
  target_dt_date,
  season_id,
  audit_vegetative(
    date_of_audit,
    audit_date_user,
    audit_week,
    qa_fi,
    rev_planting_date,
    field_size_by_audit_ha,
    correction_tagging,
    decision,
    action_needed,
    flagging,
    co_detasseling,
    roguing_status,
    lsv_status,
    isolation_problem_by_audit,
    crop_uniformity,
    crop_health,
    date_of_inspeksi_roguing_1,
    date_of_inspeksi_roguing_2,
    date_of_inspeksi_roguing_3,
    date_of_inspeksi_roguing_4,
    audit_lsv_roguing_2,
    audit_lsv_roguing_3,
    audit_lsv_roguing_4,
    crop_health_roguing_1,
    crop_uniformity_roguing_1,
    crop_health_roguing_2,
    crop_uniformity_roguing_2,
    crop_health_roguing_3,
    crop_uniformity_roguing_3,
    crop_health_roguing_4,
    crop_uniformity_roguing_4,
    isolation_audit_roguing_1
  ),
  audit_generative(
    date_of_audit_1,
    week_of_audit_1,
    qa_fi_1,
    roguing_status_1,
    lsv_status_1,
    crop_uniformity_1,
    crop_health_1,
    date_of_audit_2,
    week_of_audit_2,
    qa_fi_2,
    roguing_status_2,
    lsv_status_2,
    crop_uniformity_2,
    crop_health_2,
    date_of_audit_3,
    week_of_audit_3,
    qa_fi_3,
    lsv_status_3,
    crop_uniformity_3,
    crop_health_3,
    date_of_audit_4,
    week_of_audit_4,
    qa_fi_4,
    roguing_status_4,
    lsv_status_4,
    crop_uniformity_4,
    crop_health_4,
    date_of_audit_5,
    week_of_audit_5,
    qa_fi_5,
    lsv_status_5,
    crop_uniformity_5,
    crop_health_5,
    action_needed_1,
    action_needed_2,
    action_needed_3,
    action_needed_4,
    final_decision_3,
    final_decision_5,
    flagging,
    final_flagging_5,
    detasseling_assesment_3,
    detasseling_assesment_5,
    isolation_problem_5,
    submitted_at_5,
    date_of_inspeksi_roguing_5,
    audit_lsv_roguing_5,
    crop_uniformity_roguing_5,
    crop_health_roguing_5,
    isolation_audit_roguing_5,
    flagging_roguing_5,
    date_of_inspeksi_roguing_6,
    audit_lsv_roguing_6,
    crop_uniformity_roguing_6,
    crop_health_roguing_6,
    isolation_audit_roguing_6,
    flagging_roguing_6
  ),
  audit_pre_harvest(
    audit_date,
    audit_week,
    qa_fi,
    final_decision,
    final_flagging,
    male_chopping_rows,
    crop_uniformity,
    crop_health
  ),
  audit_harvest(
    date_of_audit,
    audit_week,
    qa_fi,
    final_flagging,
    status_downgrade,
    downgrade_flagging,
    crop_uniformity,
    crop_health
  )
`;

type JsonMap = Record<string, unknown>;

interface CacheRequest {
  dataset?: unknown;
  season?: unknown;
  region?: unknown;
  district?: unknown;
  bypassCache?: unknown;
  healthCheck?: unknown;
}

interface Scope {
  season: string | null;
  region: string | null;
  district: string | null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function optionalScopeValue(value: unknown, field: string): string | null {
  if (value == null) return null;
  if (typeof value !== "string") throw new Error(`${field} must be a string`);
  const normalized = value.trim();
  if (!normalized) return null;
  if (normalized.length > 160) throw new Error(`${field} is too long`);
  return normalized;
}

function jwtRole(token: string): string | null {
  try {
    const payload = token.split(".")[1];
    if (!payload) return null;
    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    const claims = JSON.parse(atob(padded)) as { role?: unknown };
    return typeof claims.role === "string" ? claims.role : null;
  } catch (_) {
    return null;
  }
}

async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function bytesToBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

async function compressJson(value: unknown): Promise<string> {
  const source = new TextEncoder().encode(JSON.stringify(value));
  const stream = new Blob([source]).stream().pipeThrough(new CompressionStream("gzip"));
  const compressed = new Uint8Array(await new Response(stream).arrayBuffer());
  return bytesToBase64(compressed);
}

async function decompressJson(value: string): Promise<unknown> {
  const compressed = base64ToBytes(value);
  const stream = new Blob([compressed]).stream().pipeThrough(
    new DecompressionStream("gzip"),
  );
  return JSON.parse(await new Response(stream).text());
}

async function redisCommand(
  redisUrl: string,
  redisToken: string,
  command: string[],
): Promise<unknown> {
  const response = await fetch(redisUrl.replace(/\/$/, ""), {
    method: "POST",
    headers: {
      Authorization: `Bearer ${redisToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(command),
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error(`Redis HTTP ${response.status}`);
  const body = await response.json() as { result?: unknown; error?: string };
  if (body.error) throw new Error(body.error);
  return body.result;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "POST required" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) {
    return jsonResponse({ error: "Supabase runtime is not configured" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) return jsonResponse({ error: "Missing authorization" }, 401);

  let input: CacheRequest;
  try {
    input = await req.json() as CacheRequest;
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const redisUrl = Deno.env.get("UPSTASH_REDIS_REST_URL")?.trim();
  const redisToken = Deno.env.get("UPSTASH_REDIS_REST_TOKEN")?.trim();
  const redisEnabled = Boolean(redisUrl && redisToken);

  // Operational probe for deployments. It is protected by the service-role
  // JWT (whose signature is verified by the Edge gateway) and never returns
  // endpoint or token values.
  if (input.healthCheck === true) {
    if (jwtRole(token) !== "service_role") {
      return jsonResponse({ error: "Service role required" }, 403);
    }
    if (!redisEnabled) {
      return jsonResponse({ ok: false, redis: "not_configured" }, 503);
    }
    try {
      const pong = await redisCommand(redisUrl!, redisToken!, ["PING"]);
      const probeKey = `kc:healthcheck:${crypto.randomUUID()}`;
      const probeValue = { value: crypto.randomUUID() };
      const encoded = await compressJson(probeValue);
      const stored = await redisCommand(redisUrl!, redisToken!, [
        "SET",
        probeKey,
        encoded,
        "EX",
        "30",
      ]);
      const cached = await redisCommand(redisUrl!, redisToken!, ["GET", probeKey]);
      const decoded = typeof cached === "string" ? await decompressJson(cached) : null;
      const roundTripOk = JSON.stringify(decoded) === JSON.stringify(probeValue);
      const ok = pong === "PONG" && stored === "OK" && roundTripOk;
      return jsonResponse({
        ok,
        redis: ok ? "connected" : "unexpected_response",
        readWrite: roundTripOk,
      }, ok ? 200 : 502);
    } catch (error) {
      console.error("Redis health check failed:", error instanceof Error ? error.message : error);
      return jsonResponse({ ok: false, redis: "unreachable" }, 502);
    }
  }

  let scope: Scope;
  try {
    scope = {
      season: optionalScopeValue(input.season, "season"),
      region: optionalScopeValue(input.region, "region"),
      district: optionalScopeValue(input.district, "district"),
    };
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "Invalid scope" }, 400);
  }

  const dataset = input.dataset == null ? "map" : input.dataset;
  if (dataset !== "map" && dataset !== "coverage") {
    return jsonResponse({ error: "dataset must be map or coverage" }, 400);
  }
  const cacheNamespace = dataset === "coverage"
    ? "master_fields_coverage"
    : CACHE_NAMESPACE;
  const selectColumns = dataset === "coverage" ? COVERAGE_SELECT : MAP_SELECT;

  const client = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: userData, error: userError } = await client.auth.getUser(token);
  if (userError || !userData.user) {
    return jsonResponse({ error: "Invalid authorization" }, 401);
  }

  const { data: profile, error: profileError } = await client
    .from("app_users")
    .select("name, role, action, is_active")
    .eq("id", userData.user.id)
    .maybeSingle();
  if (profileError) return jsonResponse({ error: "Unable to read user access" }, 500);
  if (!profile || profile.is_active == false) {
    return jsonResponse({ error: "User is not active" }, 403);
  }

  const action = String(profile.action ?? "").trim().toLowerCase();
  const role = String(profile.role ?? "").trim().toUpperCase();
  const name = String(profile.name ?? "").trim();
  const qaFi = action === "audit" && role === "FI" ? name : null;
  const qaSpv = action === "audit" && role === "SPV" ? name : null;
  const hasCacheScope = Boolean(
    qaFi || qaSpv || scope.season || scope.region || scope.district,
  );
  if (!hasCacheScope) {
    return jsonResponse({ error: "A scoped map request is required" }, 400);
  }

  const { data: versionRow, error: versionError } = await client
    .from("app_cache_versions")
    .select("version")
    .eq("namespace", CACHE_NAMESPACE)
    .single();
  if (versionError) {
    return jsonResponse({ error: "Unable to read cache version" }, 500);
  }
  const version = Number(versionRow.version);

  const cacheIdentity = JSON.stringify({
    version,
    userId: userData.user.id,
    scope,
  });
  const cacheKey = `kc:${cacheNamespace}:v${version}:${await sha256(cacheIdentity)}`;
  const bypassCache = input.bypassCache === true;

  if (redisEnabled && !bypassCache) {
    try {
      const cached = await redisCommand(redisUrl!, redisToken!, ["GET", cacheKey]);
      if (typeof cached === "string" && cached) {
        const rows = await decompressJson(cached);
        if (Array.isArray(rows)) {
          return jsonResponse({
            data: rows,
            cache: { status: "hit", version, ttlSeconds: CACHE_TTL_SECONDS },
          });
        }
      }
    } catch (error) {
      console.warn("Map cache read skipped:", error instanceof Error ? error.message : error);
    }
  }

  const fetchPage = async (from: number): Promise<JsonMap[]> => {
    let query = client
      .from("master_fields")
      .select(selectColumns)
      .eq("is_active", true);
    if (qaFi) query = query.ilike("qa_fi", `%${qaFi}%`);
    if (qaSpv) query = query.ilike("qa_spv", `%${qaSpv}%`);
    if (scope.season) query = query.eq("season", scope.season);
    if (scope.region) query = query.eq("region", scope.region);
    if (scope.district) query = query.eq("district_kab", scope.district);

    const { data, error } = await query
      .order("field_number", { ascending: true })
      .order("season", { ascending: true })
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw error;
    return (data ?? []) as unknown as JsonMap[];
  };

  try {
    const rows: JsonMap[] = [];
    const firstPage = await fetchPage(0);
    rows.push(...firstPage);

    if (firstPage.length === PAGE_SIZE) {
      for (let from = PAGE_SIZE; ; from += PARALLEL_PAGES * PAGE_SIZE) {
        const pages = await Promise.all(
          Array.from({ length: PARALLEL_PAGES }, (_, index) =>
            fetchPage(from + index * PAGE_SIZE)
          ),
        );
        let reachedLastPage = false;
        for (const page of pages) {
          rows.push(...page);
          if (page.length < PAGE_SIZE) {
            reachedLastPage = true;
            break;
          }
        }
        if (reachedLastPage) break;
      }
    }

    let cacheStatus = redisEnabled ? "miss" : "disabled";
    if (redisEnabled) {
      try {
        const encoded = await compressJson(rows);
        if (new TextEncoder().encode(encoded).byteLength <= MAX_CACHE_VALUE_BYTES) {
          await redisCommand(redisUrl!, redisToken!, [
            "SET",
            cacheKey,
            encoded,
            "EX",
            String(CACHE_TTL_SECONDS),
          ]);
          cacheStatus = bypassCache ? "refresh" : "stored";
        } else {
          cacheStatus = "oversize";
        }
      } catch (error) {
        cacheStatus = "write_failed";
        console.warn("Map cache write skipped:", error instanceof Error ? error.message : error);
      }
    }

    return jsonResponse({
      data: rows,
      cache: {
        status: cacheStatus,
        dataset,
        version,
        ttlSeconds: CACHE_TTL_SECONDS,
      },
    });
  } catch (error) {
    console.error("Map query failed:", error instanceof Error ? error.message : error);
    return jsonResponse({ error: "Unable to load map fields" }, 500);
  }
});
