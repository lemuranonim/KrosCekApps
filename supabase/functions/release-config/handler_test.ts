import { releaseHandler, type ReleaseConfiguration } from "./handler.ts";

Deno.test("release publisher authenticates before access and fixes table payload/source", async () => {
  let published: ReleaseConfiguration[] = [];
  const handler = releaseHandler({ token: "test-dedicated-release-token", async publish(config) { published.push(config); } });
  const request = (body: unknown, token?: string, method = "POST") => new Request("https://example.test", {
    method, headers: token ? { "X-Release-Token": token } : {},
    ...(method === "POST" ? { body: JSON.stringify(body) } : {}),
  });
  for (const token of [undefined, "anon", "eyJhbGciOiJub25lIn0.eyJyb2xlIjoic2VydmljZV9yb2xlIn0."]) {
    if ((await handler(request({ version: "4.9.9" }, token))).status !== 401) throw new Error("Public credential accepted");
  }
  if (published.length) throw new Error("Unauthorized request reached database");
  for (const body of [{ version: "4.9.9", apk_url: "https://evil.test/app.apk" }, { version: "../../other" },
    { version: "4.9.9\n" }, { version: 4.9 }, [], null]) {
    if ((await handler(request(body, "test-dedicated-release-token"))).status !== 400) throw new Error("Invalid payload accepted");
  }
  if ((await handler(request({}, "test-dedicated-release-token", "GET"))).status !== 405) throw new Error("GET allowed");
  if ((await handler(request({ version: "4.9.9" }, "test-dedicated-release-token"))).status !== 200) throw new Error("Valid release rejected");
  if (published.length !== 1 || published[0].apk_url !== "https://github.com/lemuranonim/KrosCekApps/releases/download/v4.9.9/app-release.apk"
    || published[0].min_version !== "4.9.9" || published[0].force_update !== true) throw new Error("Unsafe config");
  const unavailable = releaseHandler({ token: undefined, async publish() { throw new Error("Unreachable"); } });
  if ((await unavailable(request({ version: "4.9.9" }))).status !== 503) throw new Error("Missing credential did not fail closed");
});
