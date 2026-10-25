"""Validate rotation on a dedicated emulator with a disposable code-free APK.

No production application or user device is touched. Private inputs stay local.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SDK = Path(os.environ.get('ANDROID_SDK_ROOT', 'C:/Users/ahmad/AppData/Local/Android/Sdk'))
TOOLS = SDK / 'build-tools/36.0.0'
PRIVATE = ROOT / '.security/signing-20261024'
PACKAGE = 'com.example.kroscek.signingrotationtest'

def run(args, env, check=True):
    result = subprocess.run([str(a) for a in args], env=env, capture_output=True, text=True, timeout=90)
    if check and result.returncode:
        raise RuntimeError('Test command failed: ' + result.stdout[-400:] + result.stderr[-400:])
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', choices=['emulator-5570', 'emulator-5572'], required=True)
    parser.add_argument('--reuse-built', action='store_true')
    args = parser.parse_args()
    env = os.environ.copy()
    env['JAVA_HOME'] = 'C:/Program Files/Eclipse Adoptium/jdk-17.0.18.8-hotspot'
    env['PATH'] = env['JAVA_HOME'] + '/bin;' + env['PATH']
    properties = dict(line.split('=', 1) for line in (ROOT/'android/key.properties').read_text().splitlines()
        if '=' in line and not line.lstrip().startswith('#'))
    new = json.loads((PRIVATE/'credentials.json').read_text())
    env['KROSCEK_OLD_STORE_PASSWORD'] = properties['storePassword']
    env['KROSCEK_OLD_KEY_PASSWORD'] = properties['keyPassword']
    env['KROSCEK_NEW_SIGNING_PASSWORD'] = new['password']
    signer = TOOLS/'apksigner.bat'
    hardened = PRIVATE/'rotation-hardened.lineage'
    old = ['--ks',ROOT/'my-release-key.jks','--ks-key-alias',properties['keyAlias'],
        '--ks-pass','env:KROSCEK_OLD_STORE_PASSWORD','--key-pass','env:KROSCEK_OLD_KEY_PASSWORD']
    run([signer,'lineage','--in',PRIVATE/'rotation.lineage','--out',hardened,'--signer',*old,
        '--set-installed-data','true','--set-shared-uid','false','--set-permission','false',
        '--set-auth','false','--set-rollback','false'],env)
    target = PRIVATE/'install-test'
    target.mkdir(exist_ok=True)
    signed = []
    for version in (1,2,3):
        manifest = target/f'manifest-{version}.xml'
        manifest.write_text(f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
package="{PACKAGE}" android:versionCode="{version}" android:versionName="{version}">
<uses-sdk android:minSdkVersion="28" android:targetSdkVersion="28"/>
<application android:hasCode="false" android:debuggable="true" android:label="Signing rotation test"/>
</manifest>''')
        unsigned = target/f'unsigned-{version}.apk'
        apk = target/f'signed-{version}.apk'
        if args.reuse_built and apk.exists():
            signed.append(apk)
            continue
        run([TOOLS/'aapt2.exe','link','--manifest',manifest,'-I',SDK/'platforms/android-36/android.jar',
             '-o',unsigned],env)
        options = old if version != 2 else [
            '--ks',PRIVATE/'release-20261024.p12','--ks-key-alias',new['alias'],
            '--ks-pass','env:KROSCEK_NEW_SIGNING_PASSWORD','--key-pass','env:KROSCEK_NEW_SIGNING_PASSWORD',
            '--lineage',hardened,'--rotation-min-sdk-version','28',
            '--v1-signing-enabled','false','--v2-signing-enabled','false','--v4-signing-enabled','false']
        run([signer,'sign','--min-sdk-version','28',*options,'--out',apk,unsigned],env)
        run([signer,'verify','--min-sdk-version','28',apk],env)
        signed.append(apk)
    adb = [SDK/'platform-tools/adb.exe','-s',args.serial]
    if run([*adb,'shell','getprop','sys.boot_completed'],env).stdout.strip() != '1':
        raise RuntimeError('Dedicated emulator has not completed boot')
    api = run([*adb,'shell','getprop','ro.build.version.sdk'],env).stdout.strip()
    run([*adb,'uninstall',PACKAGE],env,False)
    first = run([*adb,'install','--no-streaming',signed[0]],env)
    run([*adb,'shell','run-as',PACKAGE,'mkdir','-p','files'],env)
    run([*adb,'shell','run-as',PACKAGE,'touch','files/migration-proof'],env)
    upgrade = run([*adb,'install','--no-streaming','-r',signed[1]],env)
    data = run([*adb,'shell','run-as',PACKAGE,'ls','files/migration-proof'],env)
    replay = run([*adb,'install','--no-streaming','-r',signed[2]],env,False)
    blocked = replay.returncode != 0 and 'INSTALL_FAILED_UPDATE_INCOMPATIBLE' in replay.stdout+replay.stderr
    report = {'api':int(api),'test_package':PACKAGE,'code_free_test_apk':True,
        'old_key_initial_install': 'Success' in first.stdout,
        'new_key_lineage_upgrade':'Success' in upgrade.stdout,
        'application_data_preserved':'migration-proof' in data.stdout,
        'old_key_higher_version_rejected':blocked,
        'old_signer_rollback_capability':False,'production_app_installed':False}
    (ROOT/f'security_audit/2026-10-24/signing_install_api{api}.json').write_text(json.dumps(report,indent=2)+'\n')
    run([*adb,'uninstall',PACKAGE],env)
    print(json.dumps(report))
    if not all(report[k] for k in ['old_key_initial_install','new_key_lineage_upgrade',
        'application_data_preserved','old_key_higher_version_rejected']):
        raise RuntimeError('Signing rotation validation failed')

if __name__ == '__main__': main()
