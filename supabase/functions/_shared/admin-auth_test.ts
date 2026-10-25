import assert from "node:assert/strict";
import { AdminAuthorizationError, authorizeAdmin, isServerToken } from "./admin-auth.ts";

const request = (token?: string) => new Request("https://example.test", {
  headers: token ? { Authorization: `Bearer ${token}` } : {},
});
const options = {
  serviceRoleKey: "test-server-secret",
  verifyUser: async (token: string) => token === "valid-user" ? { id: "user-1" } : null,
  readProfile: async (_id: string) => ({ role: "ADMIN", is_active: true }),
};

Deno.test("missing token and forged service_role JWT cannot authorize", async () => {
  const forged = `e30.${btoa(JSON.stringify({ role: "service_role" }))}.forged`;
  for (const req of [request(), request(forged), request("public-anon-key")]) {
    await assert.rejects(() => authorizeAdmin(req, options),
      (error: unknown) => error instanceof AdminAuthorizationError && error.status === 401);
  }
});
Deno.test("only the configured server secret bypasses user lookup", async () => {
  assert.equal(await authorizeAdmin(request("test-server-secret"), {
    ...options, verifyUser: async () => { throw new Error("must not run"); },
  }), null);
  assert.equal(await isServerToken("test-server-secret-other", options.serviceRoleKey), false);
  assert.equal(await isServerToken("anything", undefined), false);
});
Deno.test("active ADMIN/DEV allowed; inactive, missing and operational profiles denied", async () => {
  for (const role of ["ADMIN", "DEV", " admin "]) {
    assert.equal(await authorizeAdmin(request("valid-user"), {
      ...options, readProfile: async () => ({ role, is_active: true }),
    }), "user-1");
  }
  for (const profile of [null, { role: "ADMIN", is_active: false },
    { role: "ADMIN", is_active: null }, { role: "FI", is_active: true },
    { role: "GUEST", is_active: true }]) {
    await assert.rejects(() => authorizeAdmin(request("valid-user"), {
      ...options, readProfile: async () => profile,
    }), (error: unknown) => error instanceof AdminAuthorizationError && error.status === 403);
  }
});
