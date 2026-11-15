#!/usr/bin/env bash
set -euo pipefail

# Test-only workflow: no App Store Connect, signing-profile creation or publishing.
EVIDENCE="$PWD/build/modern-parity"
mkdir -p "$EVIDENCE"
result=0
core_status=not-run
review_group="${EKITAPLIGIM_REVIEW_GROUP:-all}"
case "$review_group" in
  all|native-unit|iPhone-compact|iPhone-large|iPad) ;;
  *) printf 'Unknown review group: %s\n' "$review_group" >&2; exit 1 ;;
esac

# Package whatever was actually produced, including failures before the test loop finishes.
# Keep full result bundles separate from the compact screenshots/text archive. Nothing is sent.
finish_evidence() {
  local command_status="$1" final_status="$1" packaging_status=0
  trap - EXIT
  set +e
  if [ "${keyboard_preference_changed:-0}" -eq 1 ]; then
    if [ -n "$previous_hardware_keyboard" ]; then
      defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool "$previous_hardware_keyboard"
    else
      defaults delete com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true
    fi
  fi
  if [ "$result" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  python3 "$PWD/Scripts/package-modern-parity-evidence.py" \
    --evidence-root "$EVIDENCE" --output-root "$PWD/build/modern-parity-archives" \
    > "$PWD/build/modern-parity-packaging.log" 2>&1 || packaging_status=$?
  cat "$PWD/build/modern-parity-packaging.log"
  if [ "$packaging_status" -ne 0 ] && [ "$final_status" -eq 0 ]; then final_status=1; fi
  printf '%s\n' "$final_status" > "$EVIDENCE/result-code.txt"
  mkdir -p "$PWD/build/modern-parity-archives"
  printf '{"commandExit":%s,"validationResult":%s,"packagingExit":%s,"finalExit":%s}\n' \
    "$command_status" "$result" "$packaging_status" "$final_status" \
    > "$PWD/build/modern-parity-archives/packaging-status.json"
  printf '\nEVIDENCE PACKAGING exit: %s; final validation exit: %s\n' "$packaging_status" "$final_status"
  exit "$final_status"
}
trap 'finish_evidence "$?"' EXIT

git rev-parse HEAD > "$EVIDENCE/revision.txt"
xcodebuild -version | tee "$EVIDENCE/xcode-version.txt"
xcrun xcresulttool version > "$EVIDENCE/xcresulttool-version.txt"
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen generate
if [ "$review_group" = all ] || [ "$review_group" = native-unit ]; then
  core_status=0
  swift test 2>&1 | tee "$EVIDENCE/core-tests.log" || core_status=$?
  if [ "$core_status" -ne 0 ]; then result=1; fi
fi
printf '%s\n' "$core_status" > "$EVIDENCE/core-status.txt"
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -clonedSourcePackagesDirPath .build/xcode-packages 2>&1 | tee "$EVIDENCE/package-resolution.log"

if [ "${EKITAPLIGIM_FULL_RELEASE_REVIEW:-0}" = "1" ] && { [ "$review_group" = all ] || [ "$review_group" = native-unit ]; }; then
  xcodebuild clean build -project Ekitapligim.xcodeproj -scheme Ekitapligim \
    -configuration Development -destination 'generic/platform=iOS Simulator' \
    -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$EVIDENCE/development-clean-build.log"
fi

production_status=not-run
if [ "$review_group" = all ] || [ "$review_group" = native-unit ]; then
  production_status=0
  xcodebuild clean build -project Ekitapligim.xcodeproj -scheme Ekitapligim \
    -configuration Production -destination generic/platform=iOS -derivedDataPath build/modern-parity-production \
    -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$EVIDENCE/production-build.log" || production_status=$?
  if [ "$production_status" -ne 0 ]; then result=1; fi
fi
printf '%s\n' "$production_status" > "$EVIDENCE/production-status.txt"

# Choose installed simulators rather than depending on an SDK-specific device name.
xcrun simctl list devices available --json > "$EVIDENCE/available-simulators.json"
python3 - "$EVIDENCE" "$review_group" <<'PY'
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
selected = [('native-unit', small), ('iPhone-compact', small), ('iPhone-large', large), ('iPad', pad)]
if sys.argv[2] != 'all':
    selected = [(label, device) for label, device in selected if label == sys.argv[2]]
(root / 'selected-simulators.json').write_text(json.dumps(selected, indent=2))
(root / 'simulators.tsv').write_text('\n'.join(f"{label}\t{device['udid']}" for label, device in selected) + '\n')
PY

while IFS=$'\t' read -r label device; do
  test_status=0
  scheme=Ekitapligim
  arguments=(-only-testing:EkitapligimUITests/ModernParityUITests -only-testing:EkitapligimUITests/BookLibraryUITests)
  if [ "${EKITAPLIGIM_FULL_RELEASE_REVIEW:-0}" = "1" ]; then
    arguments=(-only-testing:EkitapligimUITests)
  fi
  if [ -n "${EKITAPLIGIM_REVIEW_TEST_CASES:-}" ]; then
    if [ "$label" = "native-unit" ]; then
      printf 'UI diagnostic selections cannot be applied to the native unit group\n' >&2
      exit 1
    fi
    python3 - "$EVIDENCE" <<'PY'
import json, os, re, sys
from pathlib import Path
selection = json.loads(os.environ['EKITAPLIGIM_REVIEW_TEST_CASES'])
if not isinstance(selection, list) or not selection or len(selection) != len(set(selection)):
    raise SystemExit('Expected a nonempty list of distinct UI test identifiers')
if any(not isinstance(item, str) or not re.fullmatch(r'EkitapligimUITests/[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?', item) for item in selection):
    raise SystemExit('Invalid UI diagnostic test selection')
root = Path(sys.argv[1])
(root / 'diagnostic-selection.json').write_text(json.dumps(selection, indent=2))
(root / 'diagnostic-selection.txt').write_text('\n'.join(selection) + '\n')
PY
    arguments=()
    while IFS= read -r selected_test; do
      arguments+=("-only-testing:$selected_test")
    done < "$EVIDENCE/diagnostic-selection.txt"
  fi
  # Unit tests use a blank app host and never share a launch environment with UI tests.
  if [ "$label" = "native-unit" ]; then
    scheme=EkitapligimModernUnit
    arguments=(-only-testing:EkitapligimTests)
  else
    # UI keyboard assertions require the same software keyboard configuration as the
    # dedicated keyboard regression runner. This is an ephemeral CI simulator.
    if [ "${keyboard_preference_changed:-0}" -eq 0 ]; then
      previous_hardware_keyboard="$(defaults read com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true)"
      keyboard_preference_changed=1
    fi
    defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
    xcrun simctl boot "$device" > /dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b 2>&1 | tee "$EVIDENCE/$label-boot.log"
  fi
  xcodebuild test -project Ekitapligim.xcodeproj -scheme "$scheme" \
    -configuration Development -destination "platform=iOS Simulator,id=$device" \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -resultBundlePath "$EVIDENCE/$label.xcresult" \
    -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
    "${arguments[@]}" CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
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

printf '%s\n' "$result" > "$EVIDENCE/result-code.txt"
# Keep outcomes and concrete diagnostics visible in Codemagic's short web log as well as artifacts.
printf '\nVALIDATION SUMMARY\nCore exit: %s\nProduction exit: %s\n' "$core_status" "$production_status"
if [ -f "$EVIDENCE/core-tests.log" ]; then
  grep -E 'Executed [0-9]+ tests|Test Suite .All tests.' "$EVIDENCE/core-tests.log" | tail -n 2 || true
fi
while IFS=$'\t' read -r label device; do
  printf '%s exit: %s (simulator %s)\n' "$label" "$(cat "$EVIDENCE/$label-status.txt")" "$device"
done < "$EVIDENCE/simulators.tsv"
for log in "$EVIDENCE"/*-tests.log "$EVIDENCE/production-build.log"; do
  [ -f "$log" ] || continue
  printf '\n%s\n' "$(basename "$log")"
  grep -E 'error:|Executed [0-9]+ tests|\*\* (TEST|BUILD).* (FAILED|SUCCEEDED)' "$log" | tail -n 6 || true
done
exit "$result"
