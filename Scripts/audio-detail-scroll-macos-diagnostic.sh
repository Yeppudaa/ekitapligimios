#!/usr/bin/env bash
set -euo pipefail

# Manual, partial UI diagnostic only. No audio playback, full parity gate or distribution.
EVIDENCE="$PWD/build/audio-detail-scroll-diagnostic"
ARCHIVES="$PWD/build/audio-detail-scroll-archives"
mkdir -p "$EVIDENCE"
test_status=0
result=0
watchdog_pid=""
watchdog_status=0

stop_watchdog() {
  if [ -z "$watchdog_pid" ]; then return; fi
  if kill -0 "$watchdog_pid" 2>/dev/null; then
    kill -TERM "$watchdog_pid" 2>/dev/null || true
    for attempt in {1..48}; do
      if ! kill -0 "$watchdog_pid" 2>/dev/null; then break; fi
      sleep 0.25
    done
    if kill -0 "$watchdog_pid" 2>/dev/null; then
      kill -KILL "$watchdog_pid" 2>/dev/null || true
      watchdog_status=1
    fi
  fi
  wait "$watchdog_pid" || watchdog_status=$?
  watchdog_pid=""
  printf '%s\n' "$watchdog_status" > "$EVIDENCE/watchdog-exit.txt"
  if [ "$watchdog_status" -ne 0 ]; then result=1; fi
}

finish_evidence() {
  local command_status="$1" final_status="$1" packaging_status=0
  trap - EXIT
  set +e
  stop_watchdog
  if [ "$result" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  python3 "$PWD/Scripts/package-modern-parity-evidence.py" \
    --evidence-root "$EVIDENCE" --output-root "$ARCHIVES" \
    > "$PWD/build/audio-detail-scroll-packaging.log" 2>&1 || packaging_status=$?
  cat "$PWD/build/audio-detail-scroll-packaging.log"
  if [ "$packaging_status" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  mkdir -p "$ARCHIVES"
  printf '{"scope":"audio-detail-scroll-diagnostic-only","commandExit":%s,"testExit":%s,"watchdogExit":%s,"packagingExit":%s,"finalExit":%s}\n' \
    "$command_status" "$test_status" "$watchdog_status" "$packaging_status" "$final_status" > "$ARCHIVES/packaging-status.json"
  printf '\nAUDIO DETAIL SCROLL PACKAGING exit: %s; final exit: %s\n' "$packaging_status" "$final_status"
  exit "$final_status"
}
trap 'finish_evidence "$?"' EXIT

printf '%s\n' 'Only two offline AudioBookDetailView scroll UI tests. No playback, Core suite, full UI suite, release build, Apple account or publishing. Host stack samples target only this selected simulator Ekitapligim app.' > "$EVIDENCE/scope.txt"
git rev-parse HEAD > "$EVIDENCE/revision.txt"
xcodebuild -version | tee "$EVIDENCE/xcode-version.txt"
xcrun xcresulttool version > "$EVIDENCE/xcresulttool-version.txt"
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen generate
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
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
    raise SystemExit('Audio detail scroll diagnostic requires an iPhone simulator')
phone = next((device for device in phones if 'SE' in device['name'] or 'mini' in device['name']), None)
phone = phone or next((device for device in phones if not any(word in device['name'] for word in ('Pro', 'Max', 'Plus', 'Air'))), phones[0])
(root / 'selected-simulator.json').write_text(json.dumps(phone, indent=2))
(root / 'simulator-id.txt').write_text(phone['udid'] + '\n')
PY
device="$(cat "$EVIDENCE/simulator-id.txt")"
python3 "$PWD/Scripts/audio-detail-scroll-diagnostic.py" watch --device-udid "$device" \
  --output "$EVIDENCE/app-stack-samples" > "$EVIDENCE/watchdog-console.log" 2>&1 &
watchdog_pid=$!
xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -configuration Development -destination "platform=iOS Simulator,id=$device" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -only-testing:EkitapligimUITests/ModernParityUITests/testA00AudioDetailAppSwipeReachesItsChapterWithoutPlayback \
  -only-testing:EkitapligimUITests/ModernParityUITests/testA01AudioDetailTargetedDragReachesItsChapterWithoutPlayback \
  -resultBundlePath "$EVIDENCE/audio-detail-scroll.xcresult" \
  -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
  2>&1 | tee "$EVIDENCE/audio-detail-scroll-tests.log" || test_status=$?
stop_watchdog
printf '%s\n' "$test_status" > "$EVIDENCE/audio-detail-scroll-status.txt"
if [ "$test_status" -ne 0 ]; then result=1; fi
evidence_status=0
if [ -d "$EVIDENCE/audio-detail-scroll.xcresult" ]; then
  xcrun xcresulttool get test-results summary --path "$EVIDENCE/audio-detail-scroll.xcresult" \
    > "$EVIDENCE/audio-detail-scroll-summary.json" 2> "$EVIDENCE/audio-detail-scroll-summary-export.log" || evidence_status=$?
  xcrun xcresulttool get test-results tests --path "$EVIDENCE/audio-detail-scroll.xcresult" \
    > "$EVIDENCE/audio-detail-scroll-tests.json" 2> "$EVIDENCE/audio-detail-scroll-tests-export.log" || evidence_status=$?
  python3 "$PWD/Scripts/audio-detail-scroll-diagnostic.py" verify \
    --summary "$EVIDENCE/audio-detail-scroll-summary.json" --tests "$EVIDENCE/audio-detail-scroll-tests.json" \
    --output "$EVIDENCE/exact-two-tests-gate.json" \
    2>&1 | tee "$EVIDENCE/exact-two-tests-gate.log" || evidence_status=$?
  mkdir -p "$EVIDENCE/audio-detail-scroll-screenshots"
  xcrun xcresulttool export attachments --path "$EVIDENCE/audio-detail-scroll.xcresult" \
    --output-path "$EVIDENCE/audio-detail-scroll-screenshots" \
    2>&1 | tee "$EVIDENCE/audio-detail-scroll-attachments-export.log" || evidence_status=$?
else
  printf 'Missing audio detail scroll result bundle (test exit %s)\n' "$test_status" | tee "$EVIDENCE/audio-detail-scroll-attachments-export.log"
  evidence_status=1
fi
printf '%s\n' "$evidence_status" > "$EVIDENCE/audio-detail-scroll-evidence-status.txt"
if [ "$evidence_status" -ne 0 ]; then result=1; fi
printf '\nAUDIO DETAIL SCROLL DIAGNOSTIC SUMMARY (not full parity validation)\nTest exit: %s\nEvidence exit: %s\nWatchdog exit: %s\n' "$test_status" "$evidence_status" "$watchdog_status"
grep -E 'MODERN_DETAIL_|AUDIO_DETAIL_UI|error:|Test Case|Executed [0-9]+ tests|exceeded execution|\*\* TEST.* (FAILED|SUCCEEDED)' \
  "$EVIDENCE/audio-detail-scroll-tests.log" | tail -n 160 || true
for sample_file in "$EVIDENCE"/app-stack-samples/app-*-sample-*.txt; do
  if [ ! -f "$sample_file" ]; then continue; fi
  printf '\nSELECTED APP STACK SAMPLE %s (first 160 lines; full text retained in evidence)\n' "$(basename "$sample_file")"
  head -n 160 "$sample_file" || true
done
exit "$result"
