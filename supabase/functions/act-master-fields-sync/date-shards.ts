export const PLANTING_EXPORT_SHARD_DAYS = 7;
export const PLANTING_HISTORY_SHARDS_PER_RUN = 1;

const DAY_MILLISECONDS = 86_400_000;

export type PlantingDateShard = Record<string, unknown> & {
  from: string;
  to: string;
  job_id: null;
  row_cursor: number;
  processed_rows: number;
  geometry_rows: number;
  matched_rows: number;
  complete: boolean;
};

function isoDate(value: Date): string {
  return value.toISOString().slice(0, 10);
}

/**
 * Splits an inclusive ACT Planting export range into bounded UTC date shards.
 * Seven calendar days is deliberately conservative: ACT may fail while
 * generating long-range Planting workbooks even when the HTTP request itself
 * succeeds.
 */
export function buildPlantingDateShards(
  from: string,
  to: string,
  shardDays = PLANTING_EXPORT_SHARD_DAYS,
): PlantingDateShard[] {
  if (!Number.isInteger(shardDays) || shardDays < 1) {
    throw new RangeError("shardDays must be a positive integer");
  }

  const rangeEnd = new Date(`${to}T00:00:00Z`);
  let cursor = new Date(`${from}T00:00:00Z`);
  if (
    Number.isNaN(cursor.getTime()) ||
    Number.isNaN(rangeEnd.getTime()) ||
    cursor > rangeEnd
  ) {
    throw new RangeError("from/to must be a valid ascending date range");
  }

  const shards: PlantingDateShard[] = [];
  while (cursor <= rangeEnd) {
    const candidateEnd = new Date(cursor);
    candidateEnd.setUTCDate(candidateEnd.getUTCDate() + shardDays - 1);
    const shardEnd = candidateEnd < rangeEnd ? candidateEnd : rangeEnd;
    shards.push({
      from: isoDate(cursor),
      to: isoDate(shardEnd),
      job_id: null,
      row_cursor: 0,
      processed_rows: 0,
      geometry_rows: 0,
      matched_rows: 0,
      complete: false,
    });
    cursor = new Date(shardEnd);
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return shards;
}

/**
 * Builds the small WKT export set used by a daily sync. The latest seven days
 * are always refreshed. One older seven-day shard rotates deterministically by
 * source date, so historical geometry corrections are eventually revisited
 * without exporting the full season every night.
 */
export function buildDailyPlantingDateShards(
  from: string,
  to: string,
  historyShardsPerRun = PLANTING_HISTORY_SHARDS_PER_RUN,
): PlantingDateShard[] {
  if (!Number.isInteger(historyShardsPerRun) || historyShardsPerRun < 0) {
    throw new RangeError("historyShardsPerRun must be a non-negative integer");
  }

  // Also validates the complete input range.
  const fullRange = buildPlantingDateShards(from, to);
  if (fullRange.length <= 1) return fullRange;

  const rangeStart = new Date(`${from}T00:00:00Z`);
  const rangeEnd = new Date(`${to}T00:00:00Z`);
  const recentStartCandidate = new Date(rangeEnd);
  recentStartCandidate.setUTCDate(
    recentStartCandidate.getUTCDate() - PLANTING_EXPORT_SHARD_DAYS + 1,
  );
  const recentStart = recentStartCandidate < rangeStart
    ? rangeStart
    : recentStartCandidate;
  const recentShards = buildPlantingDateShards(isoDate(recentStart), to);

  const historyEnd = new Date(recentStart);
  historyEnd.setUTCDate(historyEnd.getUTCDate() - 1);
  if (historyEnd < rangeStart || historyShardsPerRun === 0) {
    return recentShards;
  }

  const historicalShards = buildPlantingDateShards(from, isoDate(historyEnd));
  const rotationSeed = Math.floor(rangeEnd.getTime() / DAY_MILLISECONDS);
  const selectedCount = Math.min(historyShardsPerRun, historicalShards.length);
  const selectedHistorical: PlantingDateShard[] = [];
  for (let offset = 0; offset < selectedCount; offset++) {
    const index = (rotationSeed + offset) % historicalShards.length;
    selectedHistorical.push(historicalShards[index]);
  }

  return [...selectedHistorical, ...recentShards].sort((left, right) =>
    left.from.localeCompare(right.from)
  );
}
