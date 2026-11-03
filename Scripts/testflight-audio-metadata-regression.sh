#!/usr/bin/env bash
set -euo pipefail
EVIDENCE="$PWD/build/testflight-reviewed"
mkdir -p "$EVIDENCE"
xcrun simctl list devices available --json > "$EVIDENCE/available-simulators.json"
DEVICE=$(python3 - "$EVIDENCE/available-simulators.json" <<'PY'
import json,sys
devices=json.load(open(sys.argv[1]))['devices']
phones=[d for runtime in sorted(devices,reverse=True) if 'iOS' in runtime for d in devices[runtime] if d['name'].startswith('iPhone')]
if not phones: raise SystemExit('No iPhone simulator available')
print(phones[0]['udid'])
PY
)
xcodebuild test -project Ekitapligim.xcodeproj -scheme EkitapligimModernUnit \
  -configuration Development -destination "platform=iOS Simulator,id=$DEVICE" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests/testAssetDurationLoadsThroughAuthenticatedRangesWithoutStartingAudioOutput \
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests/testAssetDurationWithMissingHeadMetadataUsesOneByteProbe \
  -resultBundlePath "$EVIDENCE/audio-metadata.xcresult" \
  -clonedSourcePackagesDirPath .build/xcode-packages \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements" \
  2>&1 | tee "$EVIDENCE/native-audio-metadata.log"
xcrun xcresulttool get test-results summary --path "$EVIDENCE/audio-metadata.xcresult" > "$EVIDENCE/native-audio-metadata-summary.json"
python3 - "$EVIDENCE/native-audio-metadata-summary.json" <<'PY'
import json,sys
report=json.load(open(sys.argv[1]))
assert report['passedTests']==2 and report['failedTests']==0 and report.get('skippedTests',0)==0, report
print('Native AVFoundation audio metadata tests: 2 passed, 0 failed, 0 skipped.')
PY
