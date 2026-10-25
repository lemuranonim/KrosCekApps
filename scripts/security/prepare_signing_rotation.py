"""Prepare a new private signing key and lineage; never replace/publish a key.

Private artifacts stay in the git-ignored .security folder. This prepares an
Android 9+ migration; legacy Android devices need a separate distribution plan.
"""
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess


def run(arguments, env):
    result = subprocess.run([str(a) for a in arguments], env=env, capture_output=True)
    if result.returncode:
        raise RuntimeError("Signing operation failed: " + result.stderr.decode(errors="replace")[-700:])
    return result.stdout


def main():
    root = Path(__file__).resolve().parents[2]
    destination = root / ".security/signing-20261024"
    destination.mkdir(parents=True, exist_ok=True)
    user = subprocess.check_output(["whoami"], text=True).strip()
    run(["icacls", destination, "/inheritance:r", "/grant:r", user + ":(OI)(CI)F",
         "*S-1-5-18:(OI)(CI)F"], os.environ.copy())
    credentials = destination / "credentials.json"
    if credentials.exists():
        data = json.loads(credentials.read_text())
    else:
        data = {"alias": "kroscek-release-20261024", "password": secrets.token_urlsafe(36)}
        with credentials.open("x") as handle:
            json.dump(data, handle)
    env = os.environ.copy()
    env["KROSCEK_NEW_SIGNING_PASSWORD"] = data["password"]
    keytool = shutil.which("keytool")
    if not keytool:
        raise RuntimeError("keytool is required")
    key = destination / "release-20261024.p12"
    if not key.exists():
        run([keytool, "-genkeypair", "-noprompt", "-storetype", "PKCS12", "-keystore", key,
             "-alias", data["alias"], "-keyalg", "RSA", "-keysize", "3072", "-validity", "10000",
             "-dname", "CN=Kroscek Release 2026,O=Kroscek,C=ID", "-storepass:env",
             "KROSCEK_NEW_SIGNING_PASSWORD", "-keypass:env", "KROSCEK_NEW_SIGNING_PASSWORD"], env)
    certificate = run([keytool, "-exportcert", "-keystore", key, "-alias", data["alias"],
                       "-storepass:env", "KROSCEK_NEW_SIGNING_PASSWORD"], env)
    new_digest = hashlib.sha256(certificate).hexdigest()
    denied = json.loads((root / "security_audit/compromised_signers.json").read_text())["sha256_certificates"]
    if new_digest in denied:
        raise RuntimeError("Replacement key matches a compromised certificate")
    properties = {}
    for line in (root / "android/key.properties").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            properties[k.strip()] = v.strip()
    env["KROSCEK_OLD_STORE_PASSWORD"] = properties["storePassword"]
    env["KROSCEK_OLD_KEY_PASSWORD"] = properties["keyPassword"]
    sdk = Path("C:/Users/ahmad/AppData/Local/Android/Sdk/build-tools/36.0.0")
    signer = sdk / "apksigner.bat"
    lineage = destination / "rotation.lineage"
    if not lineage.exists():
        run([signer, "rotate", "--out", lineage,
             "--old-signer", "--ks", root / "my-release-key.jks", "--ks-key-alias", properties["keyAlias"],
             "--ks-pass", "env:KROSCEK_OLD_STORE_PASSWORD", "--key-pass", "env:KROSCEK_OLD_KEY_PASSWORD",
             "--new-signer", "--ks", key, "--ks-key-alias", data["alias"],
             "--ks-pass", "env:KROSCEK_NEW_SIGNING_PASSWORD", "--key-pass", "env:KROSCEK_NEW_SIGNING_PASSWORD"], env)
    report = {"replacement_key_created": True, "replacement_certificate_sha256": new_digest,
              "replacement_is_compromised": False, "lineage_created": lineage.is_file(),
              "private_artifact_directory": str(destination), "existing_signing_config_changed": False,
              "published": False, "legacy_android_migration_required": True}
    (root / "security_audit/2026-10-24/signing_preparation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
