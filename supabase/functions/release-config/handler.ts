import { isServerToken } from "../_shared/admin-auth.ts";

export interface ReleaseConfiguration {
  latest_version: string;
  min_version: string;
  apk_url: string;
  force_update: true;
}

export function releaseHandler(options: {
  token: string | undefined;
  publish(config: ReleaseConfiguration): Promise<void>;
}) {
  return async (request: Request): Promise<Response> => {
    const reply = (status: number, message: string) => Response.json({ message }, { status });
    if (request.method !== "POST") return reply(405, "POST required");
    if (!options.token) return reply(503, "Release publisher is not configured");
    if (!await isServerToken(request.headers.get("X-Release-Token"), options.token)) {
      return reply(401, "Invalid release credential");
    }
    const body = await request.text();
    if (body.length > 256) return reply(413, "Request too large");
    let input: unknown;
    try { input = JSON.parse(body); } catch { return reply(400, "Invalid JSON"); }
    if (!input || typeof input !== "object" || Array.isArray(input)
      || Object.keys(input).some(key => key !== "version")) return reply(400, "Only version is accepted");
    const version = (input as Record<string, unknown>).version;
    if (typeof version !== "string" || !/^\d{1,4}\.\d{1,4}\.\d{1,4}$/.test(version)) {
      return reply(400, "Invalid release version");
    }
    try {
      await options.publish({
        latest_version: version, min_version: version, force_update: true,
        apk_url: `https://github.com/lemuranonim/KrosCekApps/releases/download/v${version}/app-release.apk`,
      });
      return reply(200, "Release configuration published");
    } catch {
      return reply(409, "Release could not be published; verify the version and existing configuration");
    }
  };
}
