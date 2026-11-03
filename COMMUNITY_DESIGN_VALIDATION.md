# Guest, messages, members, activity links and notifications — 2026-11-03

## Implemented, in order

1. **Guest profile and authentication:** native reading-salon hero, cream/green cards, clear login/register actions and three short benefits, following Android's updated guest screen. Google login/register is above credentials, with the existing consent/version checks and real Google SDK flow preserved. Authentication uses a centered 560 pt column on iPad.
2. **Messages:** warm inbox introduction, readable participant/preview rows, visible unread styling, refresh/compose actions and rounded detail/composer surfaces. Existing replies, reporting, blocking, read acknowledgments and keyboard-aware editors remain connected. Duplicate member-message/composer submissions are guarded.
3. **Members and member profile:** scenic community header, persistent search/sort controls even for empty results, debounced search, avatar rings, readable roles/counts, a photographic profile banner, public reading statistics and scrollable section tabs. Large text stacks the member row and statistics. Existing server capabilities govern follow/message operations; public-shelf behavior is retained.
4. **Activity links:** actor name/avatar and book title/cover have independent native destinations. Actor/book labels inside messages use native attributed links without nested buttons. General event navigation remains available on its badge. Book taps preserve the audio/e-book namespace; invalid IDs cannot create book/member links. Unicode and overlapping labels have executable coverage.
5. **Notifications:** permission granted from Notifications now starts APNs registration; foreground return rechecks authorization without prompting. The status card checks both alert permission and banner style, rather than treating Notification Center/lock-screen permission as popup permission. It displays device registration separately. A user-triggered local display test schedules a synthetic notification after three seconds and explicitly states that it does not verify server delivery. Foreground presentation requests banner, list, badge and sound. Cold-launch taps wait for startup/session restoration instead of being dropped before manager wiring. Registration drains a newer token and discards late results from an expired account.

Inbox, conversation and member-profile content have identities scoped to their account and target ID, so switching accounts or destinations creates fresh screen state. Cancelled/previous-session conversation reads cannot acknowledge data for the current session.

## Android reference inspected

Source checkout: `C:/Users/Monster/Downloads/startdesign (1)`. Relevant sources: `ProfileScreen.kt`, `LoginScreen.kt`, `MessagesScreen.kt`, `MembersScreen.kt`, `LiveActivityScreen.kt` and `deliverables/notification-popup-20261102/BILDIRIM-DOGRULAMA.md`.

Android screenshots inspected from:

- `deliverables/guest-auth-20261102/screenshots/misafir-profil.png` and `giris.png`.
- `deliverables/profile-messages-20261102/screenshots/mesajlar.png`.
- `deliverables/members-profile-20261102/screenshots/uyeler.png` and `uye-profili.png`.

The existing `agenda_reader_community` iOS asset supplies the shared imagery. Surfaces use cream, `#193F43` ink, `#26756B` teal, `#637671` muted copy and `#DDE8E1` borders, with 24–26 pt cards and content-driven text height. No website wrapper or new dependency was added. Android's Firebase popup evidence is Android-only evidence.

## Executed checks

| Check | Result / evidence |
|---|---|
| Portable Core suite | **504 tests passed**, including six new activity-link and three banner-policy tests; `.codex-artifacts/community-redesign-20261103/core-tests.log` |
| Clean optimized Core build/tests | **504 tests passed**; `core-release-tests.log` in the same evidence directory. This is not an iOS Production build. |
| Actual push-manager state/transport tests | **10 passed**, including token rotation during upload and session-loss/late-response races; `notification-state-tests.log`. Test-only Windows modules replace Apple frameworks, so this does not validate permission UI or APNs delivery. |
| Workspace audit | Passed, including Swift static audit, accessibility-label checks, basic secret scan, configuration/API contracts and PHP syntax; `workspace-audit.log` |
| Native-source syntax | Normal and DEBUG parse passed for 19 source/test files; `syntax.log`. No Apple SDK type checking. |
| Localization | 43 unique keys match in Turkish/English `CommunityDesign.strings`; no duplicate keys. |
| Backend APNs tests | `ApnsTransportContractTest.php`, `ApnsPushPolicyTest.php`, `ApnsDeliveryTest.php` and `MeDeviceTokenTest.php` exited 0 using `C:/xampp/php/php.exe`. Tool output in this chat confirms HTTP/2/topic/priority/payload construction, real test-key signature validation, token ownership and timestamp-aware cleanup. These were **offline**, with no APNs requests/database connection. |

## Native and real-device gates still open

This Windows environment has no Xcode, iOS SDK or iOS Simulator. Device inventory reported iPhone Bluetooth/audio interfaces, with no usable USB iOS testing interface or iOS device CLI. **No native iOS build, newly rendered iPhone/iPad screenshot, live Google login or actual iOS APNs → device → popup delivery is claimed.**

Authored but unexecuted native coverage:

- `CommunityDesignUITests`: six tests covering guest login/register, Google placement, member search recovery/profile/library, conversation/composer navigation and separate live member/book navigation. They capture real SwiftUI screenshots when executed.
- `CommunityDesignLayoutTests`: narrow/phone/tablet hero rendering at normal and accessibility text sizes.
- `NotificationDeliveryTests`: cold-start/late-manager tap handling and local test request construction/denied-banner behavior, using injected scheduling closures.

On macOS, run:

```bash
bash Scripts/community-design-macos.sh
```

The syntax-checked runner performs clean Development and unsigned Production builds, then native design/notification/Google-service and community/keyboard UI regressions on two iPhones and iPad, exporting result bundles and screenshots to a unique `build/community-design-*` directory. The runner itself has not executed here. Inspect all changed screens at narrow, large-text, landscape and iPad sizes before release; test real Google login/register and legal consent with an approved test account.

For notification delivery, use the new signed build on a test iPhone. Enable alerts/banners, inspect the registration status and explicitly run the local display test. That only verifies the display path. Separately send a real server/APNs test to that same device/account and retain the APNs response plus visible banner evidence in foreground, background and locked states. Test notification tap routing after force-quitting/relaunch, disabled banners, Focus/silent/summary settings, logout and account replacement. Do not substitute an Android FCM result, a successful token upload, or an offline payload test for this evidence.

Apple references: [alert permission does not guarantee presentation; alert style matters](https://developer.apple.com/documentation/usernotifications/unnotificationsettings/alertsetting), [foreground presentation options](https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions), and [local notification scheduling](https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app).

## Configuration and data handling

Existing source-directory rules in `project.yml` and SwiftPM include the new files/resources. No entitlement, StoreKit product, transaction flow, release URL or API request/response schema changed. No backend deployment, App Store/TestFlight upload or real user notification was performed. The local display test contains only localized synthetic text, no account route, token or private message; it does not change unread counts. Pending cold-start payload data is memory-only and consumed once. Tokens retain existing Keychain/session and server ownership handling. No new data collection, tracking or privacy-manifest category is introduced.
