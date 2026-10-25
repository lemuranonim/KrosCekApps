#!/usr/bin/env bash
set -euo pipefail
: "${API:?}" "${ARCH:?}" "${RUNNER_TEMP:?}" "${ANDROID_HOME:?}"
export ANDROID_AVD_HOME="$RUNNER_TEMP/kroscek-avd"
export ANDROID_USER_HOME="$RUNNER_TEMP/kroscek-android-user"
mkdir -p "$ANDROID_AVD_HOME" "$ANDROID_USER_HOME" security-test
IMAGE="system-images;android-${API};google_apis;${ARCH}"
sdkmanager "$IMAGE" 'build-tools;36.0.0'
AVD_PATH="$ANDROID_AVD_HOME/security-signing.avd"
echo no | avdmanager create avd --name security-signing --package "$IMAGE" --path "$AVD_PATH" --force
test -f "$AVD_PATH/config.ini"
# Keep the registry location explicit across cmdline-tools/emulator versions.
printf 'avd.ini.encoding=UTF-8\npath=%s\ntarget=android-%s\n' "$AVD_PATH" "$API" > "$ANDROID_AVD_HOME/security-signing.ini"
"$ANDROID_HOME/emulator/emulator" -list-avds | grep -x security-signing
sudo setfacl -m "u:${USER}:rw" /dev/kvm
"$ANDROID_HOME/emulator/emulator" -avd security-signing -port 5554 \
  -no-window -no-audio -no-snapshot -gpu swiftshader_indirect \
  -memory 2048 -cores 2 > security-test/emulator.log 2>&1 &
for attempt in $(seq 1 120); do
  if [[ "$(adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then exit 0; fi
  sleep 3
done
tail -80 security-test/emulator.log
exit 1
