# Audio and AI layout source audit — 2026-10-18

## Scope reviewed

- `App/Ekitapligim/Audio/AudioComponents.swift`: artwork, remote covers, action buttons, book cards, shelves, resume, errors/empty states, premium access sheet.
- `App/Ekitapligim/Features/AudioBooksView.swift`: hero, weekly pick, wrapping feature layout, category rail, filters, result grid, pagination.
- `App/Ekitapligim/Features/AudioBookDetailView.swift`: hero, badges, author/share, primary action, save/favorite/note groups, anchor/category rails, metadata, chapters, description, related shelves.
- `App/Ekitapligim/Features/AudioLibraryView.swift`: library/hero/tabs, journey statistics, home resume/discovery, profile tiles and entry actions.
- `App/Ekitapligim/Features/AudioPlayerView.swift`: mini player, portrait/two-column player, artwork/controls, progress/times, chapter list, notes/quotes/actions, settings and annotation editor.
- `App/Ekitapligim/Features/AIAssistantView.swift`: toolbar, usage quota, context/welcome, horizontal suggestions, book strips, user/assistant messages, fact/comparison rows, evidence, actions, composer/keyboard.
- `App/Ekitapligim/Features/AIAssistantPanels.swift`: history, preferences, collections, feedback, floating launcher and book entry.

Source review targets: 320, 375, 390 and 414 point phone widths, long Turkish/English content, standard through accessibility Dynamic Type. iPhone 13 is 390 points wide and iPhone 11 is 414 points wide in portrait. This is a source audit, not evidence of device or simulator rendering.

## Concrete risks addressed

1. Multiple flexible action buttons could continue squeezing labels into horizontal rows instead of switching layouts. Horizontal candidates now measure their natural widths, and vertical fallbacks preserve multiline label height. Player actions also have a final all-vertical fallback.
2. Fixed-width audio and AI book rails had inadequate space at accessibility text sizes. Rail card widths now scale with text and are capped to their scroll container. Normal compact cover-title truncation is preserved; accessibility titles, authors and recommendation text can grow vertically.
3. Audio catalog/library/statistics/profile grids now use one flexible column at accessibility sizes. Their single-column size follows the available parent width; no new minimum wider than a nested card was introduced.
4. Audio chapter titles no longer compete with a noncompressible duration at accessibility sizes. Durations move underneath the title. Important detail and metadata titles can grow vertically.
5. Player chapter names no longer occupy the same row as elapsed/remaining time. The time row itself has a vertical fallback. Mini-player artwork yields its width to accessibility text, and its title can occupy two lines.
6. Decorative audio icons yield space in dense accessibility headers and primary-action labels. Fixed 40–44 point artwork controls use proportional fixed-size symbols, retaining their existing touch targets.
7. Audio annotation content now scrolls when the keyboard or a short viewport reduces available height. Existing editor limits, save behavior, requests and permission checks remain unchanged.
8. Three AI trailing navigation actions crowded the principal title/back affordance. The same actions are now available in the existing localized “more” menu. Accessibility title presentation omits decorative avatar/status and stays on one navigation-bar line.
9. AI usage title/remaining count now stack if their natural widths do not fit. Fact and comparison key/value rows stack for accessibility sizes and preserve wrapped text height otherwise.
10. The AI composer uses at most three visible lines at accessibility sizes to leave room for keyboard and conversation. The underlying editable text and maximum message length are unchanged.
11. Long AI history/collection/context/evidence/follow-up/entry labels preserve vertical height. Expanded launcher content has a compact fallback if it does not fit the available width.

## Validation executed

- `swiftc -frontend -parse <file>`: exit 0, no diagnostics, for all seven changed Swift files.
- `git diff --check -- <seven files>`: exit 0; only repository CRLF conversion notices were emitted.
- Inspected DTO/helper signatures used by new presentation-only helper functions: chapter durations are `Double`, annotations are `AudioBookmarkDTO`.
- The `swiftc -parse` driver invocation exited 1 without diagnostics on this Windows installation; direct frontend parsing succeeded. Neither invocation is an iOS build or SwiftUI type-check.

## Limits and preserved behavior

- No Xcode/iOS SDK, simulator, native UI screenshots or physical-device checks were available. Actual 320/375/390/414 point rendering, VoiceOver focus, keyboard scrolling, long remote content, and accessibility hit testing still require a macOS/iOS runtime pass.
- Audio artwork uses explicit clipped image frames/background geometry; fixed cover sizes are below the reviewed phone content widths. Only rail-card sizing changed.
- Existing intentional preview truncation (ordinary compact card titles, player description and mini-player author) remains. Full detail titles and descriptions retain their existing expansion/read-more affordances.
- The current audio palette is a fixed light palette. No theme override, appearance redesign or new dark-mode claim was introduced.
- No purchase, StoreKit, audio controller, playback/session/model/API/auth, annotation persistence or deletion semantics were changed. Existing actions and callback targets were preserved; only their visual placement changed.
