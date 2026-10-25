import { retiredRecallHandler } from "./retired-handler.ts";

// Retire the unprotected bulk replay endpoint. Never create an admin client or
// contact ACT here; old callers must fail without any side effects.
Deno.serve(retiredRecallHandler);
