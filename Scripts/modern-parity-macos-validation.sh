#!/usr/bin/env bash
set -euo pipefail

# Test-only workflow: no App Store Connect, signing-profile creation or publishing.
EVIDENCE="$PWD/build/modern-parity"
mkdir -p "$EVIDENCE"
result=0
core_status=0
git rev-parse HEAD > "$EVIDENCE/revision.txt"
xcodebuild -version | tee "$EVIDENCE/xcode-version.txt"
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen generate
swift test 2>&1 | tee "$EVIDENCE/core-tests.log" || core_status=$?
if [ "$core_status" -ne 0 ]; then result=1; fi
printf '%s\n' "$core_status" > "$EVIDENCE/core-status.txt"
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
selected = [('native-unit', small), ('iPhone-compact', small), ('iPhone-large', large), ('iPad', pad)]
(root / 'selected-simulators.json').write_text(json.dumps(selected, indent=2))
(root / 'simulators.tsv').write_text('\n'.join(f"{label}\t{device['udid']}" for label, device in selected) + '\n')
PY

while IFS=$'\t' read -r label device; do
  test_status=0
  scheme=Ekitapligim
  arguments=(-only-testing:EkitapligimUITests/ModernParityUITests)
  # Unit tests use a blank app host and never share a launch environment with UI tests.
  if [ "$label" = "native-unit" ]; then
    scheme=EkitapligimModernUnit
    arguments=(-only-testing:EkitapligimTests)
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
  if [ -d "$EVIDENCE/$label.xcresult" ]; then
    mkdir -p "$EVIDENCE/$label-screenshots"
    xcrun xcresulttool export attachments --path "$EVIDENCE/$label.xcresult" \
      --output-path "$EVIDENCE/$label-screenshots" || result=1
  fi
done < "$EVIDENCE/simulators.tsv"

production_status=0
xcodebuild clean build -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -configuration Production -destination generic/platform=iOS -derivedDataPath build/modern-parity-production \
  -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$EVIDENCE/production-build.log" || production_status=$?
printf '%s\n' "$production_status" > "$EVIDENCE/production-status.txt"
if [ "$production_status" -ne 0 ]; then result=1; fi
printf '%s\n' "$result" > "$EVIDENCE/result-code.txt"
# Keep outcomes and concrete diagnostics visible in Codemagic's short web log as well as artifacts.
printf '\nVALIDATION SUMMARY\nCore exit: %s\nProduction exit: %s\n' "$core_status" "$production_status"
grep -E 'Executed [0-9]+ tests|Test Suite .All tests.' "$EVIDENCE/core-tests.log" | tail -n 2 || true
while IFS=$'\t' read -r label device; do
  printf '%s exit: %s (simulator %s)\n' "$label" "$(cat "$EVIDENCE/$label-status.txt")" "$device"
done < "$EVIDENCE/simulators.tsv"
for log in "$EVIDENCE"/*-tests.log "$EVIDENCE/production-build.log"; do
  printf '\n%s\n' "$(basename "$log")"
  grep -E 'error:|Executed [0-9]+ tests|\*\* (TEST|BUILD).* (FAILED|SUCCEEDED)' "$log" | tail -n 6 || true
done
exit "$result"
