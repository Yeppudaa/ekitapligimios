# Community and account layout audit — 2026-10-18

## Scope and evidence

Source inspection covered all 22 assigned feature files and their local subviews. The audit considered 320, 375, 390 and 414 point portrait widths, long Turkish/English copy, long member/book/thread names, high counters, Dynamic Type, keyboard-visible sheets, clipped images and pinned composers. These are source-level findings; this Windows host cannot render SwiftUI, run an iOS simulator, or execute native XCTest. No pixel-level or device-level pass is claimed.

Existing uncommitted changes in `BookAgendaView.swift` were preserved. Changes in this audit are presentation/layout only: no networking, authentication, permissions, state transitions, purchase behavior, service calls or navigation destinations were changed.

## Concrete risks corrected

| Area | Prior source-level risk | Change |
| --- | --- | --- |
| Login / registration / reset | Three legal links forced onto one line inside two layers of padding; 54 pt fixed text-button heights could crop large text. | Legal links use horizontal-to-vertical fitting; button heights grow with wrapping text; narrow-screen horizontal padding reduced; headings and signals expand vertically. |
| Conversations list | Title, unread/star markers and timestamp shared one line while a safety menu overlaid the top-right corner. | Timestamp gets a separate line; the title reserves the menu area; accessibility sizes stack avatar and copy. |
| Conversation detail | Detail title/participants had summary line limits; large placeholder text was drawn over a bounded editor. | Full detail titles/participants wrap; accessibility placeholder occupies normal layout above the native scrolling editor. |
| Forum threads | Top-right safety menu could cover the shared thread title. | Thread row receives a 44 pt title inset where a menu exists; shared row fixes are owned by the root audit. |
| Forum detail | Fixed 126 pt collapsible hero could crop narrow-screen long titles; author/role and guest actions competed for width. | Detail hero opts out of fixed collapse height; title wraps completely; accessibility role/actions stack. Large reply placeholder now occupies layout above the editor. |
| Forum create sheet | Non-scrolling medium sheet could hide fields/actions with keyboard and large text. | Sheet body scrolls; accessibility footer stacks. |
| Book agenda cards | All action counters and bookmark/view icons shared one horizontal row; three badges could exceed a narrow card. | Action buttons use a scaled adaptive grid with minimum 44 pt heights; badges fall back to a column; large-type author/actions and book chips stack. |
| Agenda composer / picker | Decorative rating stars could outgrow the card at the largest accessibility sizes; book titles/authors were limited in the picker. | Decorative stars cap their visual scale while the accessible rating label/slider retain scaling; picker labels wrap at accessibility sizes. Existing responsive composer work is retained. |
| Member directory / profile | Segmented sort, paired actions, avatar/name/role, date pair and several badges could become compressed. Member message sheet did not scroll. | Larger type uses menu sort and stacked controls; profile dates have separate lines; badges use an adaptive grid and scalable caption text; shelf grid is one column at accessibility sizes; message sheet scrolls. |
| Book requests | Cover and text competed at accessibility sizes; author/requester and vote labels had restrictive line limits. | Accessibility card content stacks; labels expand; metric tiles become a single column at accessibility sizes. |
| Notifications | Banner icon and large heading competed; two metric tiles left very narrow copy areas at accessibility sizes. | Banner stacks and metric tiles become one column for accessibility sizes. |
| Live activity | Type/time row competed at large type; 9–10 pt fixed metadata did not scale; book names had a one-line limit. | Type/time stack at accessibility sizes, metadata uses scalable caption text, book/title author allow more lines. |
| Community cards | Large headings remained beside a fixed icon; hero eyebrow had a capsule outline around wrapped large text. | Accessibility card content stacks; wrapped accessibility eyebrow uses a rounded rectangle outline. |
| My comments | Thread titles were forced to a single summary line. | Titles get two lines normally and unrestricted lines at accessibility sizes. Message excerpts remain intentional summaries. |
| Settings / privacy / account security | Long usernames, email addresses and label/value pairs competed in one row. | Rows fit horizontally only when content fits, otherwise they use a wrapping vertical pair. |
| Profile editing / blocked members | Preview/avatar and control labels could become extremely narrow at large type. | Accessibility rows stack; text labels expand vertically. Images retain explicit bounds and clipping. |
| Chat | Larger non-accessibility fonts could leave a tall decorative header above a tiny transcript; access CTA remained in one row. | Chat uses its compact header above the default text size; accessibility access CTA stacks. Existing message wrapping, reaction grids, bounded composer and image rules are retained. |

## Screen-by-screen coverage

| Feature file | Local views inspected | Result |
| --- | --- | --- |
| `BookAgendaView.swift` | Feed/tabs/filter strip, prompt, post cards, quotations/reviews/progress, image attachments, detail/comments, create/edit forms, book picker | Layout changes listed above; prior composer changes preserved. |
| `LiveActivityView.swift` | Feed states, timeline/standard/compact rows, metadata, attached book | Layout changes listed above. |
| `NotificationsView.swift` | Banner, permission state/actions, counters, notification rows | Layout changes listed above. |
| `CommunityView.swift` | Forum grid/actions, literary hero, invitation card, scenic banner | Layout changes listed above. Image fills remain bounded and clipped. |
| `ForumThreadsView.swift` | Empty/loading/error/list, menu overlay, create sheet | Layout changes listed above; shared thread row reviewed by root. |
| `ForumThreadDetailView.swift` | Expanded/collapsed hero, guest/member composer, post headers/roles/actions, post images, edit sheet | Layout changes listed above. Full-image content uses fit inside bounded native image regions. |
| `ChatView.swift` | Pinned hero/status, transcript, guest/read-only/session states, composer/quote, messages/announcements, reaction chips/picker | Targeted changes listed above; existing bounded editor and native scroll behavior retained. |
| `ConversationsView.swift` | List rows and menu, detail hero, message cards, pinned reply composer, new-message form | Layout changes listed above. |
| `MembersView.swift` | Search/sort/header, member rows, profile/banner/actions/stats/tabs, shelves/about/activity, safety actions and message sheet | Layout changes listed above; shared profile/shelf cards reviewed by other audit owners. |
| `BookRequestsView.swift` | Hero, steps, metrics, featured/list cards, filters/search, create sheet, vote/menu footer | Layout changes listed above; shared drawn cover/status reviewed by root. |
| `MyCommentsView.swift` | List titles/excerpts and pagination/state cards | Title wrapping improved; excerpts intentionally limited. |
| `SettingsView.swift` | Authentication/profile/account/legal/privacy sections | Label/value fallback added. Native list rows remain scrollable and content-sized. |
| `ProfileEditView.swift` | Avatar/banner previews, PhotosPicker labels, edit fields, toggle/status/save | Accessibility photo rows stack; images remain clipped to their previews. |
| `LoginView.swift` | Login/register/reset, signals, credentials, legal toggle/links, notices, Google and submit actions | Layout changes listed above. |
| `DeleteAccountView.swift` | Warning, confirmation/password fields, reason editor, status/submit | No concrete fixed-height text or image-width issue found in source; native scrolling Form retained. |
| `AccountSecurityView.swift` | Current email, email/password forms, status messages | Label/value fallback added; native Form fields retain scrolling. |
| `PrivacySettingsView.swift` | Summary pairs, data notices, legal links | Label/value fallback added. |
| `CommunitySafetyView.swift` | Commitment/rules, controls, support link | No concrete fixed-height text/image issue found in source; native scrolling List retained. |
| `ReportContentView.swift` | All report kinds, reason selection, description, editor placeholder, status/submit, UGC menu | No new change required: native Form scrolls; placeholder participates in a ZStack's measured height, unlike an unmeasured overlay. |
| `TermsAcceptanceView.swift` | Intro/link/toggle/status/submit | No concrete fixed-height text/image issue found in source; native scrolling Form retained. |
| `BlockMemberView.swift` | Instruction, member ID, reason, detail field, status/submit | No new change required: ScrollView and vertical text field already allow growing content. |
| `BlockedMembersView.swift` | Loading/error/empty/list and unblock action | Accessibility rows stack; long username/action text expands vertically. |

## Retained intentional constraints

- Horizontal tab/filter/stat carousels scroll on narrow phones; offscreen items are intentional carousel behavior.
- Summary cards retain bounded excerpts at default text sizes. Full detail titles, message bodies and entered content remain readable through wrapping or native editor scrolling.
- Chat room name in the compact pinned header and quoted-message composer preview remain deliberately compact to preserve the transcript viewport. Full content exists in the transcript/accessibility label.
- Images have bounded artwork/cover/avatar regions. Cropping a decorative cover or banner to fill that region is intentional; text is not placed in a fixed-height image region.
- Pinned reply editors retain their 76–128 pt bounds and native internal scrolling. Accessibility placeholder text is no longer drawn outside those bounds.

## Executed validation

1. `swiftc.exe -frontend -parse` executed successfully for all 22 assigned feature files.
2. `git diff --check` executed successfully for this audit's 17 modified feature files.
3. Source diff reviewed for accidental service/auth/state/purchase changes; only view layout/presentation and existing-condition-derived menu space were changed.

The parser does not typecheck SwiftUI or prove a rendered layout. Required remaining native evidence: iOS build/typecheck, screenshots and accessibility/interaction checks on 320/375/390/414 pt widths, long fixtures, Turkish/English, default and accessibility text sizes, keyboard-visible sheets and both appearance modes. In particular, inspect the new adaptive action rows and multiline detail heroes on a simulator/device before claiming device-level visual clearance.
