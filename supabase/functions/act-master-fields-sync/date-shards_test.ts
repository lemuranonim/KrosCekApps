import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  buildDailyPlantingDateShards,
  buildPlantingDateShards,
  PLANTING_EXPORT_SHARD_DAYS,
} from "./date-shards.ts";

Deno.test("Planting export shards never exceed seven inclusive days", () => {
  const shards = buildPlantingDateShards("2026-03-01", "2026-03-20");

  assertEquals(PLANTING_EXPORT_SHARD_DAYS, 7);
  assertEquals(
    shards.map(({ from, to }) => ({ from, to })),
    [
      { from: "2026-03-01", to: "2026-03-07" },
      { from: "2026-03-08", to: "2026-03-14" },
      { from: "2026-03-15", to: "2026-03-20" },
    ],
  );
});

Deno.test("Planting export shards remain contiguous across months", () => {
  const shards = buildPlantingDateShards("2026-03-29", "2026-04-10");

  assertEquals(
    shards.map(({ from, to }) => ({ from, to })),
    [
      { from: "2026-03-29", to: "2026-04-04" },
      { from: "2026-04-05", to: "2026-04-10" },
    ],
  );
});

Deno.test("Planting export shard validates its range", () => {
  assertThrows(
    () => buildPlantingDateShards("2026-04-10", "2026-04-01"),
    RangeError,
  );
  assertThrows(
    () => buildPlantingDateShards("2026-04-01", "2026-04-10", 0),
    RangeError,
  );
});

Deno.test("daily Planting exports always include the latest seven days", () => {
  const shards = buildDailyPlantingDateShards("2026-03-01", "2026-10-05");

  assertEquals(shards.length, 2);
  assertEquals(shards.at(-1)?.from, "2026-09-29");
  assertEquals(shards.at(-1)?.to, "2026-10-05");
});

Deno.test("daily Planting historical refresh rotates by source date", () => {
  const first = buildDailyPlantingDateShards("2026-03-01", "2026-10-05");
  const next = buildDailyPlantingDateShards("2026-03-01", "2026-10-06");

  assertEquals(first.length, 2);
  assertEquals(next.length, 2);
  assertEquals(first[0].from === next[0].from, false);
});
