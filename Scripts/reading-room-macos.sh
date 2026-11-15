#!/usr/bin/env bash
set -euo pipefail

# Reading-room presentation regression only. Does not sign for distribution or publish.
cd "$(dirname "$0")/.."
EVIDENCE="$PWD/build/reading-room-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$EVIDENCE"
command -v xcodegen >/dev/null || { printf 'Install XcodeGen before running this check.\n' >&2; exit 1; }
xcodebuild -version | tee "$EVIDENCE/xcode-version.txt"
xcodegen generate
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -clonedSourcePackagesDirPath .build/xcode-packages 2>&1 | tee "$EVIDENCE/packages.log"
xcodebuild -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development \
  -destination 'generic/platform=iOS Simulator' -clonedSourcePackagesDirPath .build/xcode-packages \
  -disableAutomaticPackageResolution clean build CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$EVIDENCE/development-clean-build.log"
xcodebuild -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Production \
  -destination 'generic/platform=iOS' -clonedSourcePackagesDirPath .build/xcode-packages \
  -disableAutomaticPackageResolution build CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$EVIDENCE/production-build.log"
xcrun simctl list devices available --json > "$EVIDENCE/simulators.json"
python3 - "$EVIDENCE" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
devices = json.loads((root / 'simulators.json').read_text())['devices']
for runtime in sorted((key for key in devices if 'iOS' in key), reverse=True):
    phones = [d for d in devices[runtime] if d['name'].startswith('iPhone')]
    pads = [d for d in devices[runtime] if d['name'].startswith('iPad')]
    if len(phones) >= 2 and pads:
        compact = next((d for d in phones if 'SE' in d['name'] or 'mini' in d['name']), phones[0])
        large = next((d for d in phones if 'Max' in d['name'] and d['udid'] != compact['udid']), None)
        large = large or next(d for d in phones if d['udid'] != compact['udid'])
        selected = [('iPhone-compact', compact), ('iPhone-large', large), ('iPad', pads[0])]
        break
else:
    raise SystemExit('Validation requires two iPhones and one iPad on the same installed iOS runtime')
(root / 'selected-simulators.json').write_text(json.dumps(selected, indent=2))
(root / 'selected.tsv').write_text(''.join(f"{name}\t{device['udid']}\n" for name, device in selected))
PY
result=0
while IFS=$'\t' read -r label device; do
  status=0
  xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development \
    -destination "platform=iOS Simulator,id=$device" -parallel-testing-enabled NO \
    -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
    -resultBundlePath "$EVIDENCE/$label.xcresult" \
    -only-testing:EkitapligimTests/ReadingRoomLayoutTests \
    -only-testing:EkitapligimTests/SocialReliabilityTests \
    -only-testing:EkitapligimTests/BookAgendaDetailModelTests \
    -only-testing:EkitapligimUITests/ReadingRoomUITests \
    -only-testing:EkitapligimUITests/CommunityDesignUITests/testInboxOpensConversationAndComposer \
    -only-testing:EkitapligimUITests/ModernParityUITests/testHomeAgendaRailKeepsDifferentContentAtEqualCardDimensions \
    -only-testing:EkitapligimUITests/ModernParityUITests/testHomeAgendaKeepsCompactPreviewsAccessibleInBothOrientations \
    -only-testing:EkitapligimUITests/AgendaMediaUITests/testPhotoAppearsOnHomeAndOpensExistingDetail \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
    2>&1 | tee "$EVIDENCE/$label-tests.log" || status=$?
  printf '%s\n' "$status" > "$EVIDENCE/$label-status.txt"
  if [ "$status" -ne 0 ]; then result=1; fi
  if [ -d "$EVIDENCE/$label.xcresult" ]; then
    xcrun xcresulttool get test-results summary --path "$EVIDENCE/$label.xcresult" \
      > "$EVIDENCE/$label-summary.json" || result=1
    python3 - "$EVIDENCE/$label-summary.json" <<'PY_SUMMARY' || result=1
import json, sys
report = json.load(open(sys.argv[1]))
expected = dict(totalTestCount=38, passedTests=38, failedTests=0, skippedTests=0)
for key, count in expected.items():
    if report.get(key) != count:
        raise SystemExit(f"Incomplete native verification: {key}={report.get(key)}, expected {count}")
print('All 38 targeted native/UI checks passed')
PY_SUMMARY
    xcrun xcresulttool export attachments --path "$EVIDENCE/$label.xcresult" \
      --output-path "$EVIDENCE/$label-attachments" || result=1
  fi
done < "$EVIDENCE/selected.tsv"
printf '%s\n' "$result" > "$EVIDENCE/result-code.txt"
printf 'Native reading-room evidence: %s\n' "$EVIDENCE"
exit "$result"
