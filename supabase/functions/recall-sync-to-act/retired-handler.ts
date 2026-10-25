export function retiredRecallHandler(_request: Request): Response {
  return new Response(JSON.stringify({
    error: "Bulk audit recall is disabled. Use the authorized administrative reconciliation workflow.",
  }), {
    status: 410,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}
