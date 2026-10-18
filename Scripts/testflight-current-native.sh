#!/usr/bin/env bash
set -euo pipefail
PHASE="${1:-all}"
[[ "$PHASE" == all || "$PHASE" == native || "$PHASE" == ui ]] || exit 2
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
native_status=0
ui_status=0
if [ "$PHASE" != ui ]; then
NATIVE=(AudioPageRoutingTests BookAgendaFeedModelTests BookAgendaDetailModelTests PremiumLayoutTests ResponsiveComponentLayoutTests BookLibraryMutationTests LiveActivityModelTests MyAudioCommentsModelTests MenuButtonAppearanceTests HomeBookCardLayoutTests)
SELECT=()
for suite in "${NATIVE[@]}"; do SELECT+=("-only-testing:EkitapligimTests/$suite"); done
SELECT+=(
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests/testAssetDurationLoadsThroughAuthenticatedRangesWithoutStartingAudioOutput
  -only-testing:EkitapligimTests/AudioPlaybackRuntimeTests/testAssetDurationWithMissingHeadMetadataUsesOneByteProbe)
native_status=0
xcodebuild test -scheme EkitapligimModernUnit "${COMMON[@]}" "${SELECT[@]}" \
  -resultBundlePath "$EVIDENCE/current-native.xcresult" 2>&1 | tee "$EVIDENCE/current-native.log" || native_status=$?
xcrun xcresulttool get test-results summary --path "$EVIDENCE/current-native.xcresult" > "$EVIDENCE/current-native-summary.json" || native_status=1
python3 - "$EVIDENCE/current-native-summary.json" <<'PY' || native_status=1
from pathlib import Path
import json,re,sys
suites=('AudioPageRoutingTests','BookAgendaFeedModelTests','BookAgendaDetailModelTests','PremiumLayoutTests','ResponsiveComponentLayoutTests','BookLibraryMutationTests','LiveActivityModelTests','MyAudioCommentsModelTests','MenuButtonAppearanceTests','HomeBookCardLayoutTests')
expected=2+sum(len(re.findall(r'func test\w+\(',Path('App/EkitapligimTests',s+'.swift').read_text())) for s in suites)
s=json.load(open(sys.argv[1])); assert s['passedTests']==expected and s['failedTests']==0 and s.get('skippedTests',0)==0,(expected,s)
print('Current native tests passed:',expected)
PY
fi
if [ "$PHASE" != native ]; then
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
  ModernParityUITests/testAudiobookCatalogDetailAndLibraryKeepNativeBackNavigation
  ShellMenuLayoutUITests/testHomeGenreCatalogAndBookDetailDoNotReceiveAFloatingMenu
  BookLibraryUITests/testReadingShelfAndFavoritePersistIntoProfileAndLiveActivity
  BookLibraryUITests/testRejectedFavoriteKeepsReadingShelfAndShowsFailureWithoutPublishingAnEvent
  BookLibraryUITests/testLargeTextGuestCanFindShelfActionAndReceivesSignInPrompt
  MyAudioCommentsUITests/testProfileCommentsOpenNativeAudioDetailsAndBackRetainsProfileTab
  MyAudioCommentsUITests/testLargeTextCommentsRemainWithinTheScreenAndBothRowsAreReachable
  MyAudioCommentsUITests/testEmptyAudioHistoryShowsAnHonestNativeEmptyState
  MyAudioCommentsUITests/testUnavailableAudioEndpointShowsAnErrorWithoutOpeningTheWebsite
  HomeBookRailUITests/testNormalCardsKeepCoverRatioAndCompactMetadataWhileScrolling
  HomeBookRailUITests/testFailedAndDelayedCoversKeepTheirCardGeometry
  HomeBookRailUITests/testAccessibilityCardsGrowForTextWithoutStretchingTheCover)
SELECT=()
for test in "${UI[@]}"; do SELECT+=("-only-testing:EkitapligimUITests/$test"); done
ui_status=0
xcodebuild test -scheme Ekitapligim "${COMMON[@]}" "${SELECT[@]}" \
  -resultBundlePath "$EVIDENCE/current-ui.xcresult" 2>&1 | tee "$EVIDENCE/current-ui.log" || ui_status=$?
xcrun xcresulttool get test-results summary --path "$EVIDENCE/current-ui.xcresult" > "$EVIDENCE/current-ui-summary.json" || ui_status=1
python3 - "$EVIDENCE/current-ui-summary.json" "${#UI[@]}" <<'PY' || ui_status=1
import json,sys
s=json.load(open(sys.argv[1])); expected=int(sys.argv[2])
assert s['passedTests']==expected and s['failedTests']==0 and s.get('skippedTests',0)==0,(expected,s)
print('Current targeted UI tests passed:',expected)
PY
fi
LABELS=()
if [ "$PHASE" != ui ]; then LABELS+=(current-native); fi
if [ "$PHASE" != native ]; then LABELS+=(current-ui); fi
for label in "${LABELS[@]}"; do
  xcrun xcresulttool export attachments --path "$EVIDENCE/$label.xcresult" --output-path "$EVIDENCE/$label-images"
  ditto -c -k --keepParent "$EVIDENCE/$label-images" "$EVIDENCE/$label-images.zip"
  python3 - "$EVIDENCE/$label-summary.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))
print('VALIDATION SUMMARY:',{k:s.get(k) for k in ('title','result','passedTests','failedTests','skippedTests')})
PY
done
if [ "$native_status" -ne 0 ] || [ "$ui_status" -ne 0 ]; then
  echo "Current validation failed: native=$native_status UI=$ui_status; upload remains blocked."
  exit 1
fi
