"""Inventory exact Dart/npm versions and check public OSV advisories.

Only package names and versions are sent to api.osv.dev. No application files,
credentials, project URLs, or environment variables are read or transmitted.
Exit 0: no advisories, 1: advisories, 2: incomplete check, 3: inventory only.
"""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import urllib.error
import urllib.request


def inventory(root):
    packages = {}
    lock = (root / "pubspec.lock").read_text(encoding="utf-8")
    for match in re.finditer(r"^  ([\w]+):\n(.*?)(?=^  [\w]+:|^sdks:|\Z)", lock, re.M | re.S):
        name, block = match.groups()
        version = re.search(r'^    version: "([^"]+)"$', block, re.M)
        if version and re.search(r"^    source: hosted$", block, re.M):
            packages[("Pub", name, version[1])] = {"ecosystem": "Pub", "name": name,
                                                     "version": version[1], "sources": ["pubspec.lock"]}
    unresolved = []
    for path in sorted((root / "supabase/functions").rglob("*")):
        if not path.is_file() or path.suffix not in {".ts", ".json"}:
            continue
        for match in re.finditer(r"npm:((?:@[^/\s\"']+/)?[^@\s\"']+)@([^\s\"']+)", path.read_text(encoding="utf-8")):
            name, version = match.groups()
            source = path.relative_to(root).as_posix()
            if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[\w.-]+)?", version):
                unresolved.append({"specifier": match[0], "source": source})
                continue
            package = packages.setdefault(("npm", name, version),
                {"ecosystem": "npm", "name": name, "version": version, "sources": []})
            if source not in package["sources"]:
                package["sources"].append(source)
        # SheetJS fixes are published by the vendor, not the obsolete npm xlsx
        # package. Still query its package/version in OSV rather than omitting it.
        for match in re.finditer(r"https://cdn\.sheetjs\.com/xlsx-(\d+\.\d+\.\d+)/package/xlsx\.mjs", path.read_text(encoding="utf-8")):
            version = match[1]
            source = path.relative_to(root).as_posix()
            package = packages.setdefault(("npm", "xlsx", version),
                {"ecosystem": "npm", "name": "xlsx", "version": version, "sources": []})
            if source not in package["sources"]:
                package["sources"].append(source)
    return list(packages.values()), unresolved


def query_batch(packages):
    payload = {"queries": [{"package": {"ecosystem": p["ecosystem"], "name": p["name"]},
                             "version": p["version"]} for p in packages]}
    request = urllib.request.Request("https://api.osv.dev/v1/querybatch",
        data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=25) as response:
        results = json.load(response)["results"]
    if len(results) != len(packages):
        raise ValueError("Incomplete advisory response")
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--inventory-only", action="store_true")
    args = parser.parse_args()
    packages, unresolved = inventory(args.root)
    report = {"checked_at_utc": datetime.now(timezone.utc).isoformat(),
              "status": "inventory_only" if args.inventory_only else "complete",
              "coverage": "Exact hosted Dart lockfile versions and direct exact npm imports only; excludes npm transitive, JSR, native Android/iOS and SDK advisories.",
              "packages": packages, "unresolved_imports": unresolved, "errors": []}
    if not args.inventory_only:
        for offset in range(0, len(packages), 100):
            batch = packages[offset:offset + 100]
            try:
                results = query_batch(batch)
            except (urllib.error.URLError, ValueError, KeyError) as error:
                report["status"] = "incomplete"
                report["errors"].append({"offset": offset, "type": type(error).__name__,
                                         "reason": str(error)})
                break
            for package, result in zip(batch, results):
                package["advisories"] = [v["id"] for v in result.get("vulns", [])]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    affected = sum(bool(p.get("advisories")) for p in packages)
    print(json.dumps({"status": report["status"], "packages": len(packages),
                      "packages_with_advisories": affected, "unresolved_imports": len(unresolved),
                      "output": str(args.output)}))
    return 3 if args.inventory_only else 2 if report["status"] == "incomplete" else int(affected > 0)


if __name__ == "__main__":
    raise SystemExit(main())
