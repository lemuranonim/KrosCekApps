// Uses the current local service-account credential only. Never authenticates
// with the historical leaked key or prints credentials/access tokens.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createSign } from 'node:crypto';

const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const report = { historicalKeyChecked: false, historicalKeyDisabled: false };
try {
  const current = JSON.parse(readFileSync('assets/credentials.json', 'utf8'));
  const revisions = execFileSync('git', ['log', '--all', '--format=%H', '--', 'assets/credentials.json'],
    { encoding: 'utf8' }).trim().split(/\r?\n/);
  let old;
  for (const revision of revisions) {
    try {
      const candidate = JSON.parse(execFileSync('git', ['show', `${revision}:assets/credentials.json`],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }));
      if (candidate.private_key) { old = candidate; break; }
    } catch { /* deleted file in this revision */ }
  }
  if (!old || old.private_key_id === current.private_key_id) throw new Error('Cannot isolate historical key');
  const now = Math.floor(Date.now() / 1000);
  const input = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: current.client_email, scope: 'https://www.googleapis.com/auth/cloud-platform',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 600,
  })}`;
  const signature = createSign('RSA-SHA256').update(input).sign(current.private_key, 'base64url');
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${input}.${signature}` }), signal: AbortSignal.timeout(20000),
  });
  report.currentCredentialAuthenticationStatus = tokenResponse.status;
  if (tokenResponse.ok) {
    const { access_token } = await tokenResponse.json();
    const headers = { Authorization: `Bearer ${access_token}` };
    const resource = `projects/-/serviceAccounts/${encodeURIComponent(old.client_email)}/keys`;
    const listResponse = await fetch(`https://iam.googleapis.com/v1/${resource}?keyTypes=USER_MANAGED`,
      { headers, signal: AbortSignal.timeout(20000) });
    report.keyMetadataStatus = listResponse.status;
    if (listResponse.ok) {
      report.historicalKeyChecked = true;
      const payload = await listResponse.json();
      const target = (payload.keys ?? []).find((key) => key.name.endsWith(`/${old.private_key_id}`));
      report.historicalKeyAbsent = !target;
      report.historicalKeyDisabled = target?.disabled === true;
      if (target && !target.disabled && process.argv.includes('--disable-compromised')) {
        const response = await fetch(`https://iam.googleapis.com/v1/${target.name}:disable`, {
          method: 'POST', headers: { ...headers, 'Content-Type': 'application/json' }, body: '{}',
          signal: AbortSignal.timeout(20000),
        });
        report.disableStatus = response.status;
        report.historicalKeyDisabled = response.ok;
      }
    } else report.requiresGoogleIamOwner = true;
  } else report.requiresGoogleIamOwner = true;
} catch (error) {
  report.errorType = error.name;
  report.requiresGoogleIamOwner = true;
}
writeFileSync('security_audit/2026-10-24/google_key_status.json', JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report));
