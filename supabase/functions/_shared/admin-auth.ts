export class AdminAuthorizationError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

interface AdminAuthOptions {
  serviceRoleKey: string | undefined;
  cronServiceKey?: string;
  verifyUser(token: string): Promise<{ id: string } | null>;
  readProfile(id: string): Promise<{ role: unknown; is_active: unknown } | null>;
}

export function bearerToken(request: Request): string | null {
  const match = /^Bearer\s+([^\s]+)$/i.exec(request.headers.get("Authorization") ?? "");
  return match?.[1] ?? null;
}

// Compare fixed-length digests rather than trusting an unverified JWT payload.
export async function isServerToken(token: string | null, expected: string | undefined): Promise<boolean> {
  if (!token || !expected) return false;
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(token)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const a = new Uint8Array(left), b = new Uint8Array(right);
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a[index] ^ b[index];
  return difference === 0;
}

export async function authorizeAdmin(request: Request, options: AdminAuthOptions): Promise<string | null> {
  const token = bearerToken(request);
  if (!token) throw new AdminAuthorizationError("Bearer authorization required", 401);
  if (await isServerToken(token, options.serviceRoleKey)) return null;
  if (await isServerToken(token, options.cronServiceKey)) return null;
  const user = await options.verifyUser(token);
  if (!user) throw new AdminAuthorizationError("Invalid user authorization", 401);
  const profile = await options.readProfile(user.id);
  if (!profile || profile.is_active !== true) {
    throw new AdminAuthorizationError("Active application profile required", 403);
  }
  const role = String(profile.role ?? "").trim().toUpperCase();
  if (role !== "ADMIN" && role !== "DEV") {
    throw new AdminAuthorizationError("Administrator access required", 403);
  }
  return user.id;
}
