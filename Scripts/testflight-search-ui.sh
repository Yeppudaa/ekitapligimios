#!/usr/bin/env bash
set -euo pipefail
EVIDENCE="$PWD/build/testflight-reviewed"
mkdir -p "$EVIDENCE"
xcrun simctl list devices available --json > "$EVIDENCE/search-simulators.json"
python3 - "$EVIDENCE" <<'PY'
from pathlib import Path
import json, sys
out = Path(sys.argv[1])
groups = json.loads((out/'search-simulators.json').read_text())['devices']
devices = [d for runtime in sorted(groups, reverse=True) if 'iOS' in runtime for d in groups[runtime] if d.get('isAvailable')]
selected = []
for family in ('iPhone', 'iPad'):
    matches = [d for d in devices if d['name'].startswith(family)]
    assert matches, 'No ' + family + ' simulator available'
    device = next((d for d in matches if d['name'] == 'iPhone 13'), matches[0])
    selected.append({'family': family, **device})
    (out/(family+'-search-udid.txt')).write_text(device['udid'])
(out/'search-selected-simulators.json').write_text(json.dumps(selected, indent=2))
print(json.dumps(selected, indent=2))
PY
previous_keyboard=$(defaults read com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true)
restore_keyboard() {
  if [ -n "$previous_keyboard" ]; then defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool "$previous_keyboard";
  else defaults delete com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true; fi
}
trap restore_keyboard EXIT
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
for FAMILY in iPhone iPad; do
  DEVICE=$(cat "$EVIDENCE/$FAMILY-search-udid.txt")
  status=0
  xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development \
    -destination "platform=iOS Simulator,id=$DEVICE" -parallel-testing-enabled NO \
    -test-timeouts-enabled YES -clonedSourcePackagesDirPath .build/xcode-packages \
    -only-testing:EkitapligimUITests/CatalogSearchUITests \
    -resultBundlePath "$EVIDENCE/search-$FAMILY.xcresult" \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
    CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
    2>&1 | tee "$EVIDENCE/search-$FAMILY.log" || status=$?
  xcrun xcresulttool get test-results summary --path "$EVIDENCE/search-$FAMILY.xcresult" > "$EVIDENCE/search-$FAMILY-summary.json"
  xcrun xcresulttool export attachments --path "$EVIDENCE/search-$FAMILY.xcresult" --output-path "$EVIDENCE/search-$FAMILY-images"
  ditto -c -k --keepParent "$EVIDENCE/search-$FAMILY-images" "$EVIDENCE/search-$FAMILY-images.zip"
  python3 - "$EVIDENCE/search-$FAMILY-summary.json" "$status" <<'PY'
import json, sys
summary = json.load(open(sys.argv[1]))
assert int(sys.argv[2]) == 0 and summary['passedTests'] == 3 and summary['failedTests'] == 0 and summary.get('skippedTests', 0) == 0, summary
print('SEARCH VALIDATION:', summary)
PY
done
