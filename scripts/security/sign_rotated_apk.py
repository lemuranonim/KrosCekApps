"""Sign and verify an Android 9+ APK with the approved replacement key/lineage."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from check_signing_key import signing_digest

ROOT = Path(__file__).resolve().parents[2]

def execute(arguments):
    result = subprocess.run([str(a) for a in arguments], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError('APK signing/verification failed: ' + result.stderr[-600:])
    return result.stdout

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--keystore', type=Path, required=True)
    parser.add_argument('--alias', required=True)
    parser.add_argument('--password-env', required=True)
    args = parser.parse_args()
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or
               'C:/Users/ahmad/AppData/Local/Android/Sdk')
    build_tools = sdk/'build-tools/36.0.0'
    signer = build_tools/('apksigner.bat' if os.name == 'nt' else 'apksigner')
    aapt = build_tools/('aapt2.exe' if os.name == 'nt' else 'aapt2')
    expected = json.loads((ROOT/'security_audit/signing/replacement.json').read_text())['sha256']
    digest = signing_digest(args.keystore,args.alias,args.password_env)
    if digest != expected: raise RuntimeError('The key is not the approved replacement')
    badging = execute([aapt,'dump','badging',args.apk])
    minimum = re.search(r"sdkVersion:'(\d+)'", badging)
    if not minimum or int(minimum.group(1)) < 28: raise RuntimeError('Release must require Android 9+')
    if "package: name='com.example.kroscek'" not in badging:
        raise RuntimeError('Unexpected release package')
    if 'application-debuggable' in badging: raise RuntimeError('Debuggable release rejected')
    temporary = args.apk.with_name(args.apk.stem+'.rotated.apk')
    execute([signer,'sign','--ks',args.keystore,'--ks-key-alias',args.alias,
        '--ks-pass','env:'+args.password_env,'--key-pass','env:'+args.password_env,
        '--lineage',ROOT/'security_audit/signing/rotation.lineage',
        '--rotation-min-sdk-version','28','--min-sdk-version','28',
        '--v1-signing-enabled','false','--v2-signing-enabled','false',
        '--v3-signing-enabled','true','--v4-signing-enabled','false',
        '--out',temporary,args.apk])
    for api in [28,31,33,36]:
        execute([signer,'verify','--min-sdk-version',str(api),'--max-sdk-version',str(api),temporary])
    details = execute([signer,'verify','--print-certs',temporary])
    fingerprints = re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]+)', details)
    if not fingerprints or fingerprints[0].lower() != expected:
        raise RuntimeError('APK does not have the approved signing certificate')
    temporary.replace(args.apk)
    print('APK signed with approved key/lineage; verified for API 28, 31, 33 and 36.')

if __name__ == '__main__': main()
