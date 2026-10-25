"""Read public Supabase API metadata without reading application records.

Uses only SUPABASE_URL and SUPABASE_ANON_KEY from the client .env. Never reads
server secrets. Sends two GET requests: OpenAPI metadata and public Auth settings.
Advertised methods are grant evidence, not proof of an RLS bypass.
"""

import argparse
import base64
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    values = {}
    for line in (args.root / ".env").read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*(SUPABASE_URL|SUPABASE_ANON_KEY)\s*=\s*(.*)$", line)
        if match:
            values[match[1]] = match[2].strip().strip("\"'")
    url = values["SUPABASE_URL"].rstrip("/")
    key = values["SUPABASE_ANON_KEY"]
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not (parsed.hostname or "").endswith(".supabase.co") or parsed.username or parsed.password:
        raise ValueError("Expected HTTPS Supabase project URL")
    # This check is an output guard, not server authentication.
    segment = key.split(".")[1]
    role = json.loads(base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))).get("role")
    if role != "anon":
        raise ValueError("This probe accepts only the public legacy anon key")
    report = {"checked_at_utc": datetime.now(timezone.utc).isoformat(), "requests": []}
    for endpoint in ["/rest/v1/", "/auth/v1/settings"]:
        headers = {"apikey": key, "Authorization": "Bearer " + key}
        if endpoint == "/rest/v1/":
            headers["Accept"] = "application/openapi+json"
        result = {"endpoint": endpoint, "method": "GET"}
        request = urllib.request.Request(url + endpoint, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                result["status"] = response.status
                payload = json.load(response)
            if endpoint == "/rest/v1/":
                tables = ["app_config", "app_users", "master_fields", "attendance_header",
                          "attendance_activity", "master_qa_mapping", "got_fet_sample_tracking",
                          "got_fet_got_observation", "got_fet_fet_observation", "got_fet_photo_evidence",
                          "got_fet_review_history", "got_fet_final_decision"]
                result["advertised_table_methods"] = {t: [m for m in payload.get("paths", {}).get("/" + t, {})
                    if m in {"get", "post", "patch", "delete"}] for t in tables}
                result["interpretation"] = "Methods reflect API metadata/grants; actual row access still depends on RLS. No application rows fetched or mutations attempted."
            else:
                result["public_settings"] = {k: payload[k] for k in
                    ["disable_signup", "mailer_autoconfirm", "phone_autoconfirm"] if k in payload}
        except urllib.error.HTTPError as error:
            result["status"] = error.code
        except (urllib.error.URLError, ValueError) as error:
            result["error_type"] = type(error).__name__
        report["requests"].append(result)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    return int(any("error_type" in r or r.get("status") != 200 for r in report["requests"]))


if __name__ == "__main__":
    raise SystemExit(main())
