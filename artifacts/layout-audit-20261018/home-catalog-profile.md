# Home, catalog, library, profile, directory, and book detail layout audit

Date: 2026-10-18. This is a source-level audit and a record of targeted presentation fixes. It is not evidence of successful iOS rendering or a simulator test run.

## Coverage

Reviewed all UI declarations in these nine files, including their nested cards and empty/loading/error states:

- `App/Ekitapligim/Features/HomeView.swift`: header, search, hero/section composition, book/discovery/agenda rails, continue-reading entry, live activity, request/chat previews.
- `App/Ekitapligim/Features/ModernHomeComponents.swift`: genres, spotlight, continue-reading panel, promos, category showcase, editorial panels, library banner/statistics.
- `App/Ekitapligim/Features/CatalogView.swift`: expanded/collapsed hero, custom hero columns, category chips, list/grid cards, cover badges, filter form.
- `App/Ekitapligim/Features/LibraryView.swift`: signed-in header, shelf scroller, book/progress cards, empty state, guest prompt.
- `App/Ekitapligim/Features/ProfileView.swift`: signed-in/guest layouts, identity/banner, metrics, reading summaries/achievements, action/shelf grids, premium membership summary, information, posts, badges, guest benefit tiles and authentication buttons.
- `App/Ekitapligim/Features/ProfileSharedComponents.swift`: shared headings, shelf cards, book/progress rows, empty states and activity embedding (also used on member profiles).
- `App/Ekitapligim/Features/ModernProfileBooksSection.swift`: nested shelves, continue-reading, journey link.
- `App/Ekitapligim/Features/DirectoryView.swift`: author/publisher directory, totals, result cards, book grids and archive hero.
- `App/Ekitapligim/Features/BookDetailView.swift`: hero/metadata, read/shelf/download/favorite controls, book information, synopsis, report chips, similar books, comments/composer and toolbar.

Reasoned about 320, 375, 390 (iPhone 13 portrait), and 414 (iPhone 11 portrait) logical-point widths, long Turkish titles/names/categories, populated and empty states, and accessibility Dynamic Type. This reasoning does not replace measured native frames.

## Concrete risks fixed

1. Home search had a fixed 58-point height and a one-line placeholder. It now wraps and grows from a minimum height.
2. Home agenda rail cards forced all names, preview, quoted context, book context and footer into 360 points. Even non-accessibility large text or a quoted post can exceed that total. The card now retains its 360-point minimum while allowing intrinsic growth; the preview retains its intentional summary line count and uses its full required height.
3. Home category-showcase and editorial rows now stack cover and copy at accessibility sizes. Decorative symbols with fixed circles/tiles use bounded symbol fonts so large text cannot make the symbol overlap nearby copy.
4. The catalog's 8-point hero eyebrow was too small; its scaled base is now 11 points. Filter ordering uses native inline options instead of squeezing three localized labels into a segmented control. Category and page-count metadata in list results use an intrinsic-width horizontal candidate with a vertical fallback, preserving full category text.
5. Library guest content now scrolls, allowing authentication and explanatory text to remain reachable when large text or short viewport height requires more space.
6. Profile action/library grids use one column at accessibility sizes. Reading summaries, achievements, premium-summary headings/perks, metric cards, information headings, post headers and badge rows have vertical alternatives. Shelf names wrap. Shared profile book rows stack at accessibility sizes and allow full book/author text there.
7. Nested profile ebook shelves now use a 140-point adaptive minimum; the effective narrow width accounts for page, section and card padding. Continue-reading places copy beneath the cover when a scaled 160-point copy column does not fit. Journey/footer controls have a measured horizontal candidate and wrapping vertical fallback.
8. Guest profile benefits now use adaptive columns (one at accessibility sizes) and full intrinsic title/subtitle height. Authentication labels can wrap, and their buttons use minimum heights instead of fixed 58/60-point caps.
9. Directory statistics/results and archive grids provide accessibility stacking/single-column alternatives. Author/publisher names and totals can grow vertically. Decorative initials/icons are bounded independently of text scaling.
10. Book-detail hero stacks below a 330-point card width or at accessibility sizes. Rating, download count and premium badge use a vertical fallback; author/publisher lines wrap. Information cells use adaptive columns and full value height, so ISBN/category/publisher metadata is no longer cut to a single line.
11. Book-detail read/shelf controls grow with multiline labels. Report chips have adaptive columns, padding and a 44-point minimum instead of one-line labels in a fixed 42-point row. Guest comment login action flows below its heading, and the rating caption sits above five 44-point targets. Comment metadata stacks at accessibility sizes. Fixed-frame decorative symbols use bounded fonts.

## Existing workspace changes preserved

The workspace contained uncommitted work before this audit. During the audit, independent Home/ModernHome changes appeared (including viewport-relative rail widths, cover aspect ratio, genre title/arrow separation and bounded genre artwork). Those were re-read and preserved. They must not be attributed solely to this audit. No restore/reset, commit, purchase logic, API, authentication, navigation target or data mutation behavior was introduced by this audit.

Intentional summary truncation remains on compact catalog/cover/rail thumbnails and the normal book toolbar title. Full book information and accessibility alternatives remain available in the detail/list layouts. Decorative fixed heights remain on artwork, separators, progress tracks and touch symbols, rather than on variable text containers.

## Verification executed

- `swiftc -frontend -parse` for all nine owned Swift files: exit code 0, no diagnostics.
- `git diff --check --` for the same nine files: exit code 0; only the workspace's existing LF/CRLF conversion warnings were emitted.
- Re-inspected fixed text-height, one-line, adaptive-grid, `ViewThatFits` and accessibility branches after editing.

The Windows host has a Swift frontend but no Xcode/iOS SDK/simulator. Swift parsing validates syntax only; SwiftUI type checking, native screenshot comparison, measured non-overlap assertions, actual iPhone 11/13 rendering, VoiceOver, and Dynamic Type UI tests must still execute on a macOS/iOS runner. No claim of runtime overflow-free layout or release readiness is made here.
