#!/usr/bin/env bash
set -euo pipefail

# Local native regression only: no upload, signing account, purchase or real server mutation.
EVIDENCE="$PWD/build/keyboard-layout-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE"
xcodebuild -version > "$EVIDENCE/xcode-version.txt"
xcodegen generate
xcrun simctl list devices available --json > "$EVIDENCE/available-devices.json"

# Select exact older/small iPhones, a current iPhone, and iPad. Missing coverage fails the run.
python3 - "$EVIDENCE" <<'PY'
import json, re, sys
from pathlib import Path
root = Path(sys.argv[1])
groups = json.loads((root / 'available-devices.json').read_text())['devices']
def version(runtime):
    match = re.search(r'iOS-(\d+)-(\d+)', runtime)
    return tuple(map(int, match.groups())) if match else (0, 0)
runtimes = sorted((r for r in groups if version(r)[0] >= 17), key=version)
if not runtimes:
    raise SystemExit('Install supported iOS simulators before running keyboard validation.')
newest = runtimes[-1]
devices = groups[newest]
selected, missing = [], []
for name in ('iPhone SE (3rd generation)', 'iPhone 11', 'iPhone 13'):
    found = next((d for d in devices if d['name'] == name), None)
    if found: selected.append((newest, found))
    else: missing.append(f'{name} on {newest}')
phones = [d for d in devices if d['name'].startswith('iPhone')]
def phone_version(device):
    match = re.search(r'iPhone (\d+)', device['name'])
    return int(match.group(1)) if match else 0
if phones: selected.append((newest, max(phones, key=phone_version)))
pads = [d for d in devices if d['name'].startswith('iPad')]
if pads: selected.append((newest, sorted(pads, key=lambda d: d['name'])[0]))
else: missing.append(f'iPad on {newest}')
baseline = next((r for r in runtimes if version(r)[0] == 17), None)
if baseline:
    old_phone = next((d for d in groups[baseline] if d['name'].startswith('iPhone')), None)
    if old_phone: selected.append((baseline, old_phone))
    else: missing.append('iPhone on iOS 17')
else: missing.append('iOS 17 runtime / minimum supported OS coverage')
seen, rows = set(), []
for runtime, device in selected:
    if device['udid'] in seen: continue
    seen.add(device['udid'])
    rows.append(dict(runtime=runtime, name=device['name'], udid=device['udid'],
                     ipad=device['name'].startswith('iPad')))
(root / 'selected-devices.json').write_text(json.dumps(rows, indent=2))
(root / 'missing-coverage.json').write_text(json.dumps(missing, indent=2))
(root / 'devices.tsv').write_text(''.join(f"{d['udid']}\t{int(d['ipad'])}\n" for d in rows))
if missing: print('Incomplete device coverage (run will fail): ' + ', '.join(missing))
PY

previous_hardware_keyboard="$(defaults read com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true)"
restore_keyboard_preference() {
    if [ -n "$previous_hardware_keyboard" ]; then
        defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool "$previous_hardware_keyboard"
    else
        defaults delete com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true
    fi
}
trap restore_keyboard_preference EXIT
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false

xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
    -clonedSourcePackagesDirPath .build/xcode-packages > "$EVIDENCE/package-resolution.log" 2>&1
result=0
while IFS=$'\t' read -r device ipad; do
    xcrun simctl boot "$device" > /dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b > "$EVIDENCE/$device-boot.log" 2>&1
    expected=10
    exclusions=()
    if [ "$ipad" = 0 ]; then
        expected=9
        exclusions=(-skip-testing:EkitapligimUITests/KeyboardLayoutUITests/testCurrentIPadWindowAtLargeTextRestoresAfterKeyboardAndSheetDismissal)
    fi
    status=0
    xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim \
        -configuration Development -destination "platform=iOS Simulator,id=$device" \
        -parallel-testing-enabled NO -test-timeouts-enabled YES \
        -only-testing:EkitapligimUITests/KeyboardLayoutUITests "${exclusions[@]}" \
        -resultBundlePath "$EVIDENCE/$device.xcresult" \
        -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution \
        CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
        CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
        > "$EVIDENCE/$device.log" 2>&1 || status=$?
    printf '%s\n' "$status" > "$EVIDENCE/$device-exit.txt"
    if [ "$status" -ne 0 ]; then result=1; fi
    if [ ! -d "$EVIDENCE/$device.xcresult" ]; then result=1; continue; fi
    xcrun xcresulttool get test-results summary --path "$EVIDENCE/$device.xcresult" \
        > "$EVIDENCE/$device-summary.json" || { result=1; continue; }
    python3 - "$EVIDENCE/$device-summary.json" "$expected" <<'PY' || result=1
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text())
count = int(sys.argv[2])
expected = dict(totalTestCount=count, passedTests=count, failedTests=0, skippedTests=0)
if any(type(data.get(k)) is not int or data[k] != v for k, v in expected.items()):
    raise SystemExit(f'Incomplete native keyboard results: expected {expected}, got {data}')
PY
    xcrun xcresulttool export attachments --path "$EVIDENCE/$device.xcresult" \
        --output-path "$EVIDENCE/$device-attachments" || result=1
done < "$EVIDENCE/devices.tsv"

python3 - "$EVIDENCE/missing-coverage.json" <<'PY' || result=1
import json, sys
from pathlib import Path
missing = json.loads(Path(sys.argv[1]).read_text())
if missing: raise SystemExit('Coverage incomplete: ' + ', '.join(missing))
PY
printf '%s\n' "$result" > "$EVIDENCE/result-code.txt"
echo "Native keyboard evidence: $EVIDENCE"
exit "$result"
