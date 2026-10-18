#!/usr/bin/env bash
set -euo pipefail

# Explicit visual-only validation. Never archives, publishes, purchases or starts playback.
# Native screenshot contents must be reviewed even when container assertions pass.
EVIDENCE="$PWD/build/layout-audit"
mkdir -p "$EVIDENCE"
xcodebuild -version > "$EVIDENCE/xcode-version.txt"
xcodegen generate
xcrun simctl list devices available --json > "$EVIDENCE/available-devices.json"
python3 - "$EVIDENCE" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
devices = json.loads((root / 'available-devices.json').read_text())['devices']
selected = []
for name in ('iPhone 11', 'iPhone 13'):
    matches = [(runtime, device) for runtime, group in devices.items() if 'iOS' in runtime
               for device in group if device['name'] == name]
    if not matches:
        raise SystemExit(f'Missing exact {name} simulator. Install it before this audit; no device substitution is made.')
    runtime, device = sorted(matches, key=lambda item: item[0], reverse=True)[0]
    selected.append({'name': name, 'runtime': runtime, 'udid': device['udid']})
(root / 'selected-devices.json').write_text(json.dumps(selected, indent=2))
(root / 'devices.tsv').write_text(''.join(f"{item['name']}\t{item['udid']}\n" for item in selected))
PY
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
    -clonedSourcePackagesDirPath .build/xcode-packages > "$EVIDENCE/package-resolution.log" 2>&1
result=0
verify_summary() {
    local bundle="$1" expected="$2" summary="$3"
    xcrun xcresulttool get test-results summary --path "$bundle" > "$summary" || return 1
    python3 - "$summary" "$expected" <<'PY'
import json, sys
from pathlib import Path
summary = json.loads(Path(sys.argv[1]).read_text())
expected = int(sys.argv[2])
required = {'totalTestCount': expected, 'passedTests': expected, 'failedTests': 0, 'skippedTests': 0}
counts = {key: summary.get(key) for key in required}
if any(type(counts[key]) is not int or counts[key] != value for key, value in required.items()):
    raise SystemExit(f'Incomplete layout test results: expected {required}, received {counts}')
print(json.dumps(counts))
PY
}
while IFS=$'\t' read -r name device; do
    label="${name// /-}"
    native_status=0
    xcodebuild test -project Ekitapligim.xcodeproj -scheme EkitapligimModernUnit \
        -configuration Development -destination "platform=iOS Simulator,id=$device" \
        -parallel-testing-enabled NO -test-timeouts-enabled YES \
        -only-testing:EkitapligimTests/ResponsiveComponentLayoutTests \
        -only-testing:EkitapligimTests/PremiumLayoutTests \
        -resultBundlePath "$EVIDENCE/$label-components.xcresult" \
        -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
        CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
        CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
        > "$EVIDENCE/$label-components.log" 2>&1 || native_status=$?
    printf '%s\n' "$native_status" > "$EVIDENCE/$label-components-exit.txt"
    if [ "$native_status" -ne 0 ]; then result=1; fi
    if [ -d "$EVIDENCE/$label-components.xcresult" ]; then
        verify_summary "$EVIDENCE/$label-components.xcresult" 5 "$EVIDENCE/$label-components-summary.json" || result=1
        xcrun xcresulttool export attachments --path "$EVIDENCE/$label-components.xcresult" \
            --output-path "$EVIDENCE/$label-components-screenshots" || result=1
    else
        result=1
    fi
    status=0
    xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim \
        -configuration Development -destination "platform=iOS Simulator,id=$device" \
        -parallel-testing-enabled NO -test-timeouts-enabled YES \
        -only-testing:EkitapligimUITests/LayoutAuditUITests \
        -only-testing:EkitapligimUITests/ShellMenuLayoutUITests \
        -resultBundlePath "$EVIDENCE/$label.xcresult" \
        -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
        CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
        CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
        > "$EVIDENCE/$label.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$EVIDENCE/$label-exit.txt"
    if [ "$status" -ne 0 ]; then result=1; fi
    if [ -d "$EVIDENCE/$label.xcresult" ]; then
        verify_summary "$EVIDENCE/$label.xcresult" 8 "$EVIDENCE/$label-summary.json" || result=1
        xcrun xcresulttool export attachments --path "$EVIDENCE/$label.xcresult" \
            --output-path "$EVIDENCE/$label-screenshots" || result=1
    else
        result=1
    fi
done < "$EVIDENCE/devices.tsv"
printf '%s\n' "$result" > "$EVIDENCE/result-code.txt"
exit "$result"
