#!/usr/bin/env bash
set -euo pipefail
EVIDENCE="$PWD/build/testflight-reviewed"
mkdir -p "$EVIDENCE"
xcrun simctl list devices available --json > "$EVIDENCE/available-simulators.json"
DEVICE=$(python3 - "$EVIDENCE" <<'PY'
from pathlib import Path
import json,sys
out=Path(sys.argv[1]); groups=json.loads((out/'available-simulators.json').read_text())['devices']
phones=[d for runtime in sorted(groups,reverse=True) if 'iOS' in runtime for d in groups[runtime] if d['name'].startswith('iPhone')]
assert phones, 'No iPhone simulator available'
phone=next((p for p in phones if p['name']=='iPhone 13'),phones[0])
(out/'selected-simulator.json').write_text(json.dumps(phone,indent=2))
print(phone['udid'])
PY
)
previous_keyboard=$(defaults read com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true)
restore_keyboard() {
  if [ -n "$previous_keyboard" ]; then defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool "$previous_keyboard";
  else defaults delete com.apple.iphonesimulator ConnectHardwareKeyboard 2>/dev/null || true; fi
}
trap restore_keyboard EXIT
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
COMMON=(-project Ekitapligim.xcodeproj -configuration Development -destination "platform=iOS Simulator,id=$DEVICE"
  -parallel-testing-enabled NO -test-timeouts-enabled YES -clonedSourcePackagesDirPath .build/xcode-packages
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual CODE_SIGN_ENTITLEMENTS="$PWD/Scripts/ci-simulator.entitlements")
NATIVE=(AudioPageRoutingTests BookAgendaFeedModelTests BookAgendaDetailModelTests PremiumLayoutTests ResponsiveComponentLayoutTests)
SELECT=()
for suite in "${NATIVE[@]}"; do SELECT+=("-only-testing:EkitapligimTests/$suite"); done
SELECT+=(
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests/testAssetDurationLoadsThroughAuthenticatedRangesWithoutStartingAudioOutput
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests/testAssetDurationWithMissingHeadMetadataUsesOneByteProbe)
xcodebuild test -scheme EkitapligimModernUnit "${COMMON[@]}" "${SELECT[@]}" \
  -resultBundlePath "$EVIDENCE/current-native.xcresult" 2>&1 | tee "$EVIDENCE/current-native.log"
xcrun xcresulttool get test-results summary --path "$EVIDENCE/current-native.xcresult" > "$EVIDENCE/current-native-summary.json"
python3 - "$EVIDENCE/current-native-summary.json" <<'PY'
from pathlib import Path
import json,re,sys
suites=('AudioPageRoutingTests','BookAgendaFeedModelTests','BookAgendaDetailModelTests','PremiumLayoutTests','ResponsiveComponentLayoutTests')
expected=2+sum(len(re.findall(r'func test\w+\(',Path('App/EkitapligimTests',s+'.swift').read_text())) for s in suites)
s=json.load(open(sys.argv[1])); assert s['passedTests']==expected and s['failedTests']==0 and s.get('skippedTests',0)==0,(expected,s)
print('Current native tests passed:',expected)
PY
UI=(
  ShellMenuLayoutUITests/testRootMenusAndPageActionsHaveSeparateHitAreas
  ShellMenuLayoutUITests/testRootMenusAndPageActionsHaveSeparateHitAreasWithAccessibilityText
  ShellMenuLayoutUITests/testLiveRefreshStaysReachableAfterScrollingAndOpeningTheDrawer
  BookAgendaUITests/testCommentHeadingAndPaddedEditorOpenKeyboardAndFailedSendKeepsDraft
  BookAgendaUITests/testCommentLoadFailureDoesNotShowFalseEmptyState
  KeyboardLayoutUITests/testForumKeyboardRepeatedlyOpensAndClosesWithoutRetainingItsHeight
  KeyboardLayoutUITests/testAgendaCommentKeyboardRestoresRootShellAtAccessibilityTextSize
  ModernParityUITests/testHomeNewArrivalCardsRemainVisibleAndOpenNativeBookDetails
  ModernParityUITests/testHomeAgendaRailKeepsDifferentContentAtEqualCardDimensions
  ModernParityUITests/testAudiobookCatalogDetailAndLibraryKeepNativeBackNavigation)
SELECT=()
for test in "${UI[@]}"; do SELECT+=("-only-testing:EkitapligimUITests/$test"); done
xcodebuild test -scheme Ekitapligim "${COMMON[@]}" "${SELECT[@]}" \
  -resultBundlePath "$EVIDENCE/current-ui.xcresult" 2>&1 | tee "$EVIDENCE/current-ui.log"
xcrun xcresulttool get test-results summary --path "$EVIDENCE/current-ui.xcresult" > "$EVIDENCE/current-ui-summary.json"
python3 - "$EVIDENCE/current-ui-summary.json" "${#UI[@]}" <<'PY'
import json,sys
s=json.load(open(sys.argv[1])); expected=int(sys.argv[2])
assert s['passedTests']==expected and s['failedTests']==0 and s.get('skippedTests',0)==0,(expected,s)
print('Current targeted UI tests passed:',expected)
PY
for label in current-native current-ui; do
  xcrun xcresulttool export attachments --path "$EVIDENCE/$label.xcresult" --output-path "$EVIDENCE/$label-images"
done
ditto -c -k --keepParent "$EVIDENCE/current-native-images" "$EVIDENCE/current-native-images.zip"
ditto -c -k --keepParent "$EVIDENCE/current-ui-images" "$EVIDENCE/current-ui-images.zip"
