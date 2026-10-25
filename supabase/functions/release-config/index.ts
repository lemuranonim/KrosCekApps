import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";
import { releaseHandler } from "./handler.ts";

Deno.serve(releaseHandler({
  token: Deno.env.get("KROSCEK_RELEASE_TOKEN"),
  async publish(config) {
    const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: current, error: readError } = await client.from("app_config")
      .select("latest_version").eq("id", "kroscek").single();
    if (readError || !current || typeof current.latest_version !== "string") throw new Error("Missing config");
    const before = current.latest_version.split(".").map(Number);
    const after = config.latest_version.split(".").map(Number);
    if (before.length !== 3 || before.some(n => !Number.isFinite(n))) throw new Error("Invalid existing version");
    let comparison = 0;
    for (let i = 0; i < 3; i++) {
      if (after[i] !== before[i]) { comparison = Math.sign(after[i] - before[i]); break; }
    }
    if (comparison <= 0) throw new Error("Release version must increase");
    const { data, error } = await client.from("app_config").update(config)
      .eq("id", "kroscek").eq("latest_version", current.latest_version).select("id").single();
    if (error || !data) throw new Error("Configuration changed concurrently");
  },
}));
