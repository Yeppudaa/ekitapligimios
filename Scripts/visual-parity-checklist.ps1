param(
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

$checks = @(
    @{ Screen = "Book detail shelf actions"; Android = "BookDetailScreen.kt (gold shelf menu + favorite heart)"; iOS = "App/Ekitapligim/Features/BookDetailView.swift"; Notes = "Android PremiumBookTopBar gold 48pt round back/share; OKUYORUM/OKUYACAGIM/OKUDUM menu, heart toggle; share payload title — author + pdfUrl/threads URL" }
    @{ Screen = "Forum thread detail"; Android = "ForumThreadDetailScreen.kt"; iOS = "App/Ekitapligim/Features/ForumThreadDetailView.swift"; Notes = "Collapsible hero, ForumMessageBody, full-width images, keyboard-safe reply inset, trailing Cevapla, cream guest prompt, permission hint without locking field (server checks canReply)" }
    @{ Screen = "Book requests"; Android = "SocialScreen.kt (SocialHeroCard + RequestSectionTitle)"; iOS = "App/Ekitapligim/Features/BookRequestsView.swift"; Notes = "Gradient hero, Kitap Istek Listesi header, orange Istekte Bulun CTA, status pills, vote shows N Oy" }
    @{ Screen = "Okur Sohbeti"; Android = "ChatScreen.kt (ChatHero + ChatRoomTab)"; iOS = "App/Ekitapligim/Features/ChatView.swift"; Notes = "ChatHero, room tabs, welcome note, labeled Giris/Oturum CTAs, person leading icon, 50pt rounded send button, 1000-char draft" }
    @{ Screen = "Kitap Gündemi"; Android = "BookAgendaScreen.kt (AgendaTabCard + hero refresh)"; iOS = "App/Ekitapligim/Features/BookAgendaView.swift"; Notes = "Hero refresh, tab cards, quoted posts with purple attribution, single attachment 16:9, feed comment count sync" }
    @{ Screen = "Book comments"; Android = "BookDetailScreen.kt PremiumCommentsSection"; iOS = "App/Ekitapligim/Features/BookDetailView.swift"; Notes = "Icon header + subtitle, guest Giris CTA, Puaniniz row, gold-bordered field, end-aligned Yorum Gonder, 5-star rows" }
    @{ Screen = "Library shelves"; Android = "LibraryScreen.kt (LibraryFilterChips + LibraryEmptyState)"; iOS = "App/Ekitapligim/Features/LibraryView.swift"; Notes = "Selected-shelf summary, tab icon boxes, branded empty state, card with meta icon + bar/% row + circular chevron, finished=100%" }
    @{ Screen = "Book detail read/download"; Android = "BookDetailScreen.kt guest login redirect"; iOS = "App/Ekitapligim/Features/BookDetailView.swift"; Notes = "Guest login on read/download, ReaderAccess denial messages, post-download library refresh" }
    @{ Screen = "Catalog grid"; Android = "Catalog/grid badges"; iOS = "App/Ekitapligim/Features/CatalogView.swift"; Notes = "PREMIUM/favorite/downloaded badges, collapsible hero" }
)

$lines = @(
    "# iOS vs Android Visual Parity Checklist (scoped UGC/library)",
    "",
    "Capture side-by-side Xcode Simulator + Android reference screenshots for each row.",
    "Mark PASS only when layout, primary actions, and status affordances match.",
    "",
    "| Screen | Android reference | iOS file | Verification notes | PASS |",
    "|---|---|---|---|---|"
)

foreach ($check in $checks) {
    $lines += "| $($check.Screen) | $($check.Android) | $($check.iOS) | $($check.Notes) |  |"
}

$lines += ""
$lines += "## Commands"
$lines += ""
$lines += "- Automated code gate: ``.\Scripts\parity-audit.ps1`` (expect PASS=296 WARN=4 FAIL=0)"
$lines += "- Completion status: ``.\Scripts\parity-completion-report.ps1``"
$lines += "- Full matrix: ``ANDROID_IOS_FEATURE_PARITY.md``"
$lines += ""
$text = $lines -join "`n"

if ($OutputPath) {
    Set-Content -LiteralPath $OutputPath -Value $text -Encoding utf8NoBOM
    Write-Host "Wrote $OutputPath"
} else {
    Write-Host $text
}
