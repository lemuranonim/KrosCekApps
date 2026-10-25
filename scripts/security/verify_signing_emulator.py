"""Verify approved APKs and upgrade behavior on a disposable Android emulator."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = 'com.example.kroscek.signingrotationtest'
OLD = 'bbd8121e34858a9e2e842bbaa495d285d7cbb2b5b43e7fd5b71b2483e6bba8af'
NEW = '037f78c609ad080f21de6dd6487b7b337c0e24e2269fb7c93d0f2fbfcd3294b7'

def run(args, check=True):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, timeout=180)
    if check and result.returncode:
        raise RuntimeError('Emulator check failed: '+result.stdout[-800:]+result.stderr[-800:])
    return result

def permission_granted_from_dump(dump,package,permission):
    if f'Package [{package}]' not in dump or permission not in dump:
        raise RuntimeError('Expected package/permission missing from Package Manager dump')
    grants=re.findall(r'(?m)^\s*'+re.escape(permission)+r':\s*granted=(true|false)\b',dump)
    return 'true' in grants

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', default='emulator-5554', choices=['emulator-5554'])
    parser.add_argument('--old-apk', type=Path, required=True)
    parser.add_argument('--new-apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ['ANDROID_HOME'])
    adb = [sdk/'platform-tools/adb', '-s',args.serial]
    if run([*adb,'shell','getprop','ro.kernel.qemu']).stdout.strip() != '1':
        raise RuntimeError('A disposable emulator is required')
    if run([*adb,'shell','getprop','sys.boot_completed']).stdout.strip() != '1':
        raise RuntimeError('Emulator boot incomplete')
    api = int(run([*adb,'shell','getprop','ro.build.version.sdk']).stdout.strip())
    signer = sdk/'build-tools/36.0.0/apksigner'
    def verify_certificate(path, expected):
        output = run([signer,'verify','--min-sdk-version',str(api),'--max-sdk-version',str(api),
            '--print-certs',path]).stdout
        fingerprints = re.findall(r'certificate SHA-256 digest: ([0-9a-fA-F]+)',output)
        if not fingerprints or fingerprints[0].lower() != expected:
            raise RuntimeError('Unexpected signing certificate')
    fixtures = ROOT/'test/fixtures/signing'
    manifest = json.loads((fixtures/'manifest.json').read_text(encoding='utf-8'))
    for name,expected in [('legacy-v1.apk',OLD),('rotated-v2.apk',NEW),('legacy-v3.apk',OLD)]:
        path=fixtures/name
        if hashlib.sha256(path.read_bytes()).hexdigest()!=manifest['sha256'][name]:
            raise RuntimeError('Fixture integrity mismatch')
        with zipfile.ZipFile(path) as archive:
            if any(name.endswith('.dex') for name in archive.namelist()):
                raise RuntimeError('Diagnostic fixtures must contain no executable code')
        verify_certificate(path,expected)
    verify_certificate(args.old_apk,OLD)
    verify_certificate(args.new_apk,NEW)
    for name in ['legacy-app-replay.apk','legacy-permission-probe.apk']:
        path=fixtures/name
        if hashlib.sha256(path.read_bytes()).hexdigest()!=manifest['sha256'][name]:
            raise RuntimeError('Additional fixture integrity mismatch')
        verify_certificate(path,OLD)
    # This package and the production package exist only in this fresh CI emulator.
    run([*adb,'uninstall',PACKAGE],False)
    run([*adb,'install','--no-streaming',fixtures/'legacy-v1.apk'])
    run([*adb,'shell','run-as',PACKAGE,'mkdir','-p','files'])
    run([*adb,'shell','run-as',PACKAGE,'touch','files/migration-proof'])
    run([*adb,'install','--no-streaming','-r',fixtures/'rotated-v2.apk'])
    marker=run([*adb,'shell','run-as',PACKAGE,'ls','files/migration-proof']).stdout
    replay=run([*adb,'install','--no-streaming','-r',fixtures/'legacy-v3.apk'],False)
    blocked=replay.returncode!=0 and 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' in replay.stdout+replay.stderr
    if not blocked or 'migration-proof' not in marker:
        raise RuntimeError('Old signer rejection or data preservation failed')
    run([*adb,'install','--no-streaming',args.old_apk])
    run([*adb,'install','--no-streaming','-r',args.new_apk])
    permission='com.example.kroscek.KROSCEK_RECEIVER_NOT_EXPORTED_PERMISSION'
    current_dump=run([*adb,'shell','dumpsys','package','com.example.kroscek']).stdout
    if not permission_granted_from_dump(current_dump,'com.example.kroscek',permission):
        raise RuntimeError('The new app cannot use its own receiver permission')
    run([*adb,'install','--no-streaming',fixtures/'legacy-permission-probe.apk'])
    probe_package='com.example.kroscek.signingpermissionprobe'
    probe_dump=run([*adb,'shell','dumpsys','package',probe_package]).stdout
    if permission_granted_from_dump(probe_dump,probe_package,permission):
        raise RuntimeError('Compromised signer retained internal receiver access')
    real_replay=run([*adb,'install','--no-streaming','-r',fixtures/'legacy-app-replay.apk'],False)
    if real_replay.returncode==0 or 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' not in real_replay.stdout+real_replay.stderr:
        raise RuntimeError('Real application accepted a higher-version APK signed by the old key')
    report={'api':api,'old_key_initial_install':True,'new_key_lineage_upgrade':True,
        'application_data_preserved':True,'old_key_higher_version_rejected':True,
        'distributed_v4_9_8_certificate_matches_compromised_key':True,
        'real_app_upgrade_from_v4_9_8':True,'installed_on_user_device':False,
        'real_app_old_key_higher_version_rejected':True,'old_key_receiver_permission_denied':True,
        'new_app_receiver_permission_granted':True,
        'release_apk_sha256':hashlib.sha256(args.new_apk.read_bytes()).hexdigest(),
        'release_tag':os.environ.get('RELEASE_TAG'),
        'source_build_run_id':os.environ.get('BUILD_RUN_ID')}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('w',encoding='utf-8') as handle:
        json.dump(report,handle,indent=2); handle.write('\n'); handle.flush(); os.fsync(handle.fileno())
    print(json.dumps(report))
    run([*adb,'uninstall',PACKAGE])
    run([*adb,'uninstall','com.example.kroscek'])
    run([*adb,'uninstall','com.example.kroscek.signingpermissionprobe'])

if __name__ == '__main__': main()
