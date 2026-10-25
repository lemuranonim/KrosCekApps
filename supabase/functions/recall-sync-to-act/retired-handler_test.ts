import assert from "node:assert/strict";
import { retiredRecallHandler } from "./retired-handler.ts";

Deno.test("retired recall never processes anonymous or authenticated requests", async () => {
  for (const method of ["GET", "POST", "OPTIONS", "PATCH"]) {
    for (const authorization of ["", "Bearer public-anon", "Bearer administrator"]) {
      const response = retiredRecallHandler(new Request("https://example.test", {
        method, headers: { Authorization: authorization },
      }));
      assert.equal(response.status, 410);
      assert.match((await response.json()).error, /disabled/);
    }
  }
});
