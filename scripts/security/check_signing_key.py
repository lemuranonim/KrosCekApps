"""Reject compromised signing certificates without printing credentials."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def signing_digest(keystore, alias, password_env):
    keytool = shutil.which("keytool")
    if not keytool:
        raise RuntimeError("keytool is required")
    result = subprocess.run([keytool, "-exportcert", "-keystore", str(keystore),
        "-alias", alias, "-storepass:env", password_env], capture_output=True)
    if result.returncode:
        raise RuntimeError("Unable to read signing certificate")
    return hashlib.sha256(result.stdout).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keystore", type=Path, required=True)
    parser.add_argument("--alias", required=True)
    parser.add_argument("--password-env", required=True)
    parser.add_argument("--denylist", type=Path, default=Path(__file__).resolve().parents[2] /
                        "security_audit/compromised_signers.json")
    args = parser.parse_args()
    if not os.environ.get(args.password_env):
        raise SystemExit("Signing password environment variable is missing")
    digest = signing_digest(args.keystore, args.alias, args.password_env)
    denied = json.loads(args.denylist.read_text())["sha256_certificates"]
    if digest in denied:
        raise SystemExit("Release blocked: signing certificate is compromised. Complete the signing migration first.")
    print("Signing certificate is outside the compromised-certificate denylist.")


if __name__ == "__main__":
    main()
