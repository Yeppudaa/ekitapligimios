#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
evidence="$PWD/build/testflight-beta"
mkdir -p "$evidence"
git rev-parse HEAD > "$evidence/revision.txt"
xcodebuild -version > "$evidence/xcode-version.txt"
python3 Scripts/test_release_version.py
swift test --xunit-output "$evidence/core-tests.xml" 2>&1 | tee "$evidence/core-tests.log"
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -clonedSourcePackagesDirPath .build/xcode-packages 2>&1 | tee "$evidence/packages.log"
xcrun simctl list devices available --json > "$evidence/simulators.json"
device=$(python3 - "$evidence/simulators.json" <<'PY'
import json,sys
devices=json.load(open(sys.argv[1]))['devices']
for runtime in sorted(devices, reverse=True):
    if 'iOS' not in runtime: continue
    phones=[d for d in devices[runtime] if d['name'].startswith('iPhone') and d.get('isAvailable')]
    if phones:
        print(next((d for d in phones if 'SE' in d['name']), phones[0])['udid'])
        break
else:
    raise SystemExit('An available iPhone simulator is required')
PY
)
common=(-project Ekitapligim.xcodeproj -configuration Development
  -destination "platform=iOS Simulator,id=$device"
  -clonedSourcePackagesDirPath .build/xcode-packages -disableAutomaticPackageResolution
  -parallel-testing-enabled NO -test-timeouts-enabled YES
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual
  "CODE_SIGN_ENTITLEMENTS=$PWD/Scripts/ci-simulator.entitlements")

# Use the blank unit-test host so startup networking and audio cannot contaminate tests.
xcodebuild clean test -scheme EkitapligimModernUnit "${common[@]}" \
  -only-testing:EkitapligimTests -resultBundlePath "$evidence/native.xcresult" \
  2>&1 | tee "$evidence/native.log"
xcrun xcresulttool get test-results summary --path "$evidence/native.xcresult" > "$evidence/native-summary.json"

# Beta smoke coverage is explicit. The full two-iPhone/iPad release matrix is separate.
xcodebuild test -scheme Ekitapligim "${common[@]}" \
  -only-testing:EkitapligimUITests/AgendaMediaUITests \
  -only-testing:EkitapligimUITests/ReaderOpeningUITests \
  -only-testing:EkitapligimUITests/PremiumAvatarUITests \
  -only-testing:EkitapligimUITests/ProfileDirectoryUITests \
  -only-testing:EkitapligimUITests/CommunityDesignUITests \
  -resultBundlePath "$evidence/ui-smoke.xcresult" \
  2>&1 | tee "$evidence/ui-smoke.log"
xcrun xcresulttool get test-results summary --path "$evidence/ui-smoke.xcresult" > "$evidence/ui-smoke-summary.json"
python3 - "$evidence" <<'PY'
import json,sys
from pathlib import Path
root=Path(sys.argv[1])
for name,minimum in [('native',270),('ui-smoke',25)]:
    result=json.loads((root/f'{name}-summary.json').read_text())
    assert result['failedTests']==0 and result['skippedTests']==0, result
    assert result['passedTests']>=minimum, f'{name}: incomplete test execution'
print('Complete native suite and explicitly scoped beta UI smoke tests passed.')
PY
