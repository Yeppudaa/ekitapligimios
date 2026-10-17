#!/usr/bin/env bash
set -euo pipefail

# Manual diagnostic only. This is not the full parity gate, a release build, or publishing.
EVIDENCE="$PWD/build/native-audio-diagnostic"
ARCHIVES="$PWD/build/native-audio-archives"
mkdir -p "$EVIDENCE"
test_status=0
result=0
finish_evidence() {
  local command_status="$1" final_status="$1" packaging_status=0
  trap - EXIT
  set +e
  if [ "$result" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  python3 "$PWD/Scripts/package-modern-parity-evidence.py" \
    --evidence-root "$EVIDENCE" --output-root "$ARCHIVES" \
    > "$PWD/build/native-audio-packaging.log" 2>&1 || packaging_status=$?
  cat "$PWD/build/native-audio-packaging.log"
  if [ "$packaging_status" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  mkdir -p "$ARCHIVES"
  printf '{"scope":"native-audio-diagnostic-only","commandExit":%s,"testExit":%s,"packagingExit":%s,"finalExit":%s}\n' \
    "$command_status" "$test_status" "$packaging_status" "$final_status" > "$ARCHIVES/packaging-status.json"
  printf '\nAUDIO DIAGNOSTIC PACKAGING exit: %s; final exit: %s\n' "$packaging_status" "$final_status"
  exit "$final_status"
}
trap 'finish_evidence "$?"' EXIT

printf '%s\n' 'Only AudioPlaybackRuntimeTests; no UI, Core suite, release build, signing profiles or publishing.' > "$EVIDENCE/scope.txt"
git rev-parse HEAD > "$EVIDENCE/revision.txt"
xcodebuild -version | tee "$EVIDENCE/xcode-version.txt"
xcrun xcresulttool version > "$EVIDENCE/xcresulttool-version.txt"
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen generate
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme EkitapligimModernUnit \
  -clonedSourcePackagesDirPath .build/xcode-packages 2>&1 | tee "$EVIDENCE/package-resolution.log"
xcrun simctl list devices available --json > "$EVIDENCE/available-simulators.json"
python3 - "$EVIDENCE" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
devices = json.loads((root / 'available-simulators.json').read_text())['devices']
runtimes = sorted((key for key in devices if 'iOS' in key), reverse=True)
if not runtimes:
    raise SystemExit('No available iOS simulator runtime')
phones = [device for device in devices[runtimes[0]] if device['name'].startswith('iPhone')]
if not phones:
    raise SystemExit('Native audio diagnostic requires an iPhone simulator')
phone = next((device for device in phones if 'SE' in device['name'] or 'mini' in device['name']), None)
phone = phone or next((device for device in phones if not any(word in device['name'] for word in ('Pro', 'Max', 'Plus', 'Air'))), phones[0])
(root / 'selected-simulator.json').write_text(json.dumps(phone, indent=2))
(root / 'simulator-id.txt').write_text(phone['udid'] + '\n')
PY
device="$(cat "$EVIDENCE/simulator-id.txt")"
xcodebuild test -project Ekitapligim.xcodeproj -scheme EkitapligimModernUnit \
  -configuration Development -destination "platform=iOS Simulator,id=$device" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests \
  -resultBundlePath "$EVIDENCE/native-audio.xcresult" \
  -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
  2>&1 | tee "$EVIDENCE/native-audio-tests.log" || test_status=$?
printf '%s\n' "$test_status" > "$EVIDENCE/native-audio-status.txt"
if [ "$test_status" -ne 0 ]; then result=1; fi
evidence_status=0
if [ -d "$EVIDENCE/native-audio.xcresult" ]; then
  xcrun xcresulttool get test-results summary --path "$EVIDENCE/native-audio.xcresult" \
    > "$EVIDENCE/native-audio-summary.json" 2> "$EVIDENCE/native-audio-summary-export.log" || evidence_status=$?
  xcrun xcresulttool get test-results tests --path "$EVIDENCE/native-audio.xcresult" \
    > "$EVIDENCE/native-audio-tests.json" 2> "$EVIDENCE/native-audio-tests-export.log" || evidence_status=$?
  mkdir -p "$EVIDENCE/native-audio-screenshots"
  xcrun xcresulttool export attachments --path "$EVIDENCE/native-audio.xcresult" \
    --output-path "$EVIDENCE/native-audio-screenshots" \
    2>&1 | tee "$EVIDENCE/native-audio-attachments-export.log" || evidence_status=$?
else
  printf 'Missing native audio result bundle (test exit %s)\n' "$test_status" | tee "$EVIDENCE/native-audio-attachments-export.log"
  evidence_status=1
fi
printf '%s\n' "$evidence_status" > "$EVIDENCE/native-audio-evidence-status.txt"
if [ "$evidence_status" -ne 0 ]; then result=1; fi
printf '\nNATIVE AUDIO DIAGNOSTIC SUMMARY (not full parity validation)\nTest exit: %s\nEvidence exit: %s\n' "$test_status" "$evidence_status"
grep -E 'MODERN_AUDIO_|error:|Test Case|Executed [0-9]+ tests|exceeded execution|\*\* TEST.* (FAILED|SUCCEEDED)' \
  "$EVIDENCE/native-audio-tests.log" | tail -n 160 || true
exit "$result"
