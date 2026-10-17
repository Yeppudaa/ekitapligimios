#!/usr/bin/env bash
set -euo pipefail

# Manual selected UI regression only: no audio output, Core/native suite, Production or publishing.
EVIDENCE="$PWD/build/focused-visual-regression"
mkdir -p "$EVIDENCE"
result=0

# Package whatever was actually produced, including failures before the test loop finishes.
# Keep full result bundles separate from the compact screenshots/text archive. Nothing is sent.
finish_evidence() {
  local command_status="$1" final_status="$1" packaging_status=0
  trap - EXIT
  set +e
  if [ "$result" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  python3 "$PWD/Scripts/package-modern-parity-evidence.py" \
    --evidence-root "$EVIDENCE" --output-root "$PWD/build/focused-visual-regression-archives" \
    > "$PWD/build/focused-visual-regression-packaging.log" 2>&1 || packaging_status=$?
  cat "$PWD/build/focused-visual-regression-packaging.log"
  if [ "$packaging_status" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  mkdir -p "$PWD/build/focused-visual-regression-archives"
  printf '{"commandExit":%s,"validationResult":%s,"packagingExit":%s,"finalExit":%s}\n' \
    "$command_status" "$result" "$packaging_status" "$final_status" \
    > "$PWD/build/focused-visual-regression-archives/packaging-status.json"
  printf '\nEVIDENCE PACKAGING exit: %s; final validation exit: %s\n' "$packaging_status" "$final_status"
  exit "$final_status"
}
trap 'finish_evidence "$?"' EXIT

printf '%s\n' 'Nine selected offline UI cases on compact/large iPhone and iPad. Does not validate native audio output, all pages or purchase/auth services.' > "$EVIDENCE/scope.txt"
git rev-parse HEAD > "$EVIDENCE/revision.txt"
xcodebuild -version | tee "$EVIDENCE/xcode-version.txt"
xcrun xcresulttool version > "$EVIDENCE/xcresulttool-version.txt"
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen generate
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -clonedSourcePackagesDirPath .build/xcode-packages 2>&1 | tee "$EVIDENCE/package-resolution.log"

# Choose installed simulators rather than depending on an SDK-specific device name.
xcrun simctl list devices available --json > "$EVIDENCE/available-simulators.json"
python3 - "$EVIDENCE" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
devices = json.loads((root / 'available-simulators.json').read_text())['devices']
runtimes = sorted((k for k in devices if 'iOS' in k), reverse=True)
if not runtimes:
    raise SystemExit('No available iOS simulator runtime')
pool = devices[runtimes[0]]
phones = [d for d in pool if d['name'].startswith('iPhone')]
pads = [d for d in pool if d['name'].startswith('iPad')]
if len(phones) < 2 or not pads:
    raise SystemExit('Validation requires two iPhones and one iPad')
small = next((d for d in phones if 'SE' in d['name'] or 'mini' in d['name']), None)
small = small or next((d for d in phones if 'Pro' not in d['name'] and 'Max' not in d['name'] and 'Plus' not in d['name'] and 'Air' not in d['name']), phones[0])
large = next((d for d in phones if 'Pro Max' in d['name'] and d['udid'] != small['udid']), None)
large = large or next(d for d in phones if d['udid'] != small['udid'])
pad = next((d for d in pads if '13-inch' in d['name'] or '12.9' in d['name']), pads[0])
selected = [('iPhone-compact', small), ('iPhone-large', large), ('iPad', pad)]
(root / 'selected-simulators.json').write_text(json.dumps(selected, indent=2))
(root / 'simulators.tsv').write_text('\n'.join(f"{label}\t{device['udid']}" for label, device in selected) + '\n')
PY

while IFS=$'\t' read -r label device; do
  test_status=0
  scheme=Ekitapligim
  arguments=()
  while IFS= read -r method; do
    arguments+=("-only-testing:EkitapligimUITests/ModernParityUITests/$method")
  done < <(python3 -c 'import runpy; print("\n".join(sorted(runpy.run_path("Scripts/focused-visual-regression.py")["TEST_METHODS"])))')
  if [ "${#arguments[@]}" -ne 9 ]; then
    printf 'Expected exactly nine selectors; refusing to run an unbounded suite\n' >&2
    exit 1
  fi
  xcodebuild test -project Ekitapligim.xcodeproj -scheme "$scheme" \
    -configuration Development -destination "platform=iOS Simulator,id=$device" \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -resultBundlePath "$EVIDENCE/$label.xcresult" \
    -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
    "${arguments[@]}" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
    2>&1 | tee "$EVIDENCE/$label-tests.log" || test_status=$?
  printf '%s\n' "$test_status" > "$EVIDENCE/$label-status.txt"
  if [ "$test_status" -ne 0 ]; then result=1; fi
  evidence_status=0
  if [ -d "$EVIDENCE/$label.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$EVIDENCE/$label.xcresult" \
      > "$EVIDENCE/$label-summary.json" 2> "$EVIDENCE/$label-summary-export.log" || evidence_status=$?
    xcrun xcresulttool get test-results tests --path "$EVIDENCE/$label.xcresult" \
      > "$EVIDENCE/$label-tests.json" 2> "$EVIDENCE/$label-tests-export.log" || evidence_status=$?
    python3 "$PWD/Scripts/focused-visual-regression.py" \
      --summary "$EVIDENCE/$label-summary.json" --tests "$EVIDENCE/$label-tests.json" \
      --output "$EVIDENCE/$label-exact-selected-gate.json" \
      2>&1 | tee "$EVIDENCE/$label-exact-selected-gate.log" || evidence_status=$?
    mkdir -p "$EVIDENCE/$label-screenshots"
    xcrun xcresulttool export attachments --path "$EVIDENCE/$label.xcresult" \
      --output-path "$EVIDENCE/$label-screenshots" \
      2>&1 | tee "$EVIDENCE/$label-attachments-export.log" || evidence_status=$?
  else
    printf 'Missing result bundle for %s (test exit %s)\n' "$label" "$test_status" \
      | tee "$EVIDENCE/$label-attachments-export.log"
    evidence_status=1
  fi
  printf '%s\n' "$evidence_status" > "$EVIDENCE/$label-evidence-status.txt"
  if [ "$evidence_status" -ne 0 ]; then result=1; fi
done < "$EVIDENCE/simulators.tsv"

printf '\nFOCUSED VISUAL REGRESSION SUMMARY (nine selected cases per device; not full parity or release validation)\n'
while IFS=$'\t' read -r label device; do
  printf '%s exit: %s (simulator %s)\n' "$label" "$(cat "$EVIDENCE/$label-status.txt")" "$device"
done < "$EVIDENCE/simulators.tsv"
for log in "$EVIDENCE"/*-tests.log; do
  printf '\n%s\n' "$(basename "$log")"
  grep -E 'error:|Test Case.*(passed|failed)|Executed [0-9]+ tests|\*\* TEST.* (FAILED|SUCCEEDED)' "$log" | tail -n 18 || true
done
exit "$result"
