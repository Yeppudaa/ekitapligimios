param(
    [string]$BaseUrl = "https://ekitapligim.com/ios-api/v1/",
    [switch]$AllowInsecure,
    [switch]$SkipNetwork
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root
. (Join-Path $PSScriptRoot "load-smoke-env.ps1") -Root $root

function Write-Step($Message) { Write-Host "==> $Message" }
function Write-Result($Name, $Status, $Detail) {
    $color = switch ($Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        default { "White" }
    }
    Write-Host ("[{0}] {1} - {2}" -f $Status, $Name, $Detail) -ForegroundColor $color
}

$results = @()

function Add-Result($Name, $Status, $Detail) {
    $script:results += [pscustomobject]@{ Name = $Name; Status = $Status; Detail = $Detail }
    Write-Result $Name $Status $Detail
}

function Join-AuditUrl([string]$Relative) {
    $normalized = $BaseUrl.Trim().TrimEnd('/') + '/'
    return [Uri]::new([Uri]$normalized, $Relative)
}

Write-Step "Running Android/iOS parity audit"

# Code wiring checks (static evidence)
$codeChecks = @(
    @{ Name = "Book requests create/vote UI"; Pattern = "bookRequests\.create|toggleVote"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book requests initial load"; Pattern = "guard !isLoading else \{ return \}"; Path = "App/Ekitapligim/Features/BookRequestsView.swift"; ShouldNotMatch = $true; PassDetail = "Initial load guard removed" }
    @{ Name = "Book requests hero card"; Pattern = "bookRequestsHeroTitle|heroCard"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request status pills"; Pattern = "BookRequestStatusPill"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request Android status labels"; Pattern = "Uygun Bulunmadı|Temin Edildi"; Path = "Sources/EkitapligimCore/Localization.swift" }
    @{ Name = "Catalog cover always shows favorite glyph"; Pattern = 'heart.fill" : "heart'; Path = "App/Ekitapligim/Features/CatalogView.swift" }
    @{ Name = "Book request author line"; Pattern = "bookRequestsAuthorLine"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Members initial load"; Pattern = "guard !isLoading else \{ return \}"; Path = "App/Ekitapligim/Features/MembersView.swift"; ShouldNotMatch = $true; PassDetail = "Initial load guard removed" }
    @{ Name = "Forum topic create UI"; Pattern = "createThread|forumThreadsCreate"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum guest create opens sheet"; Pattern = "if isSignedIn \{ showCreateSheet = true \} else \{ showLoginAlert = true \}"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift"; ShouldNotMatch = $true; PassDetail = "Android ForumThreadsScreen opens create dialog without login intercept" }
    @{ Name = "Forum empty glyph uses on-surface tint"; Pattern = "size: 48\)\r?\n\s+\.foregroundStyle\([^)]*teal\)"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift"; ShouldNotMatch = $true; PassDetail = "Android Forum empty icon uses default onSurface" }
    @{ Name = "Forum thread pagination"; Pattern = "load\(reset: false\)|currentPage < lastPage"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum guest reply CTA"; Pattern = "forumThreadGuestReplyTitle|showLoginAlert"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum reply UI"; Pattern = "community\.reply"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Book agenda quoted post"; Pattern = "quotedPostCard"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Chat send UI"; Pattern = "container\.chat\.send"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat messages Android load-failed copy"; Pattern = "chatMessagesFailed"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Agenda post options Android a11y"; Pattern = "agendaPostOptions"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda comment options Android a11y"; Pattern = "agendaCommentOptions"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Chat send requires authenticated canUse"; Pattern = "capabilities.authenticated\r?\n\s+&& capabilities.canUse"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat session refresh CTA"; Pattern = "refreshSessionData\(\)"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat hero card"; Pattern = "chatHero|chatHeroTitle"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat room tab pills"; Pattern = "chatRoomTab|onlinePill"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat labeled access CTA"; Pattern = "chatAccessCallToAction|chatSessionRefresh"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Book requests list section"; Pattern = "bookRequestsListSection|requestListSection"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book requests action CTA"; Pattern = "bookRequestsRequestAction"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Agenda tab cards"; Pattern = "agendaTabCard|agendaTabPersonalSubtitle"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda hero refresh"; Pattern = "agendaRefresh"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Forum locked reply composer"; Pattern = "forumThreadReplyPermissionHint"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum create blank-only gate"; Pattern = "trimmingCharacters\(in: \.whitespacesAndNewlines\)\.isEmpty"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum reply blank-only gate"; Pattern = "trimmingCharacters\(in: \.whitespacesAndNewlines\)\.isEmpty"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum reply trims message"; Pattern = "let message = replyText.trimmingCharacters"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "UGC blank-only content safety"; Pattern = "trimmed.count < 3"; Path = "Sources/EkitapligimCore/ContentSafety.swift"; ShouldNotMatch = $true; PassDetail = "Android isNotBlank gate (no 3-char minimum)" }
    @{ Name = "Forum report blank-only gate"; Pattern = "case .post: return !trimmedMessage.isEmpty"; Path = "App/Ekitapligim/Features/ReportContentView.swift" }
    @{ Name = "Book comment requires sign-in"; Pattern = "guard isSignedIn, !message.isEmpty"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Agenda comment requires sign-in"; Pattern = "guard container.isSignedIn, !message.isEmpty"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Book request create Android enablement"; Pattern = ".disabled\(isSubmitting \|\| !container.isSignedIn\)"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book comment submit Android enablement"; Pattern = ".disabled\(isSubmittingComment\)"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Report type locked to selected chip"; Pattern = "if case .book = kind"; Path = "App/Ekitapligim/Features/ReportContentView.swift" }
    @{ Name = "Chat Android scaffold wash"; Pattern = "0xF5F8F9"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Report Android dialog titles"; Pattern = "bookDetailIssueBrokenLinkReportTitle"; Path = "App/Ekitapligim/Features/ReportContentView.swift" }
    @{ Name = "Forum report Android submit label"; Pattern = "forumThreadReportSubmit"; Path = "App/Ekitapligim/Features/ReportContentView.swift" }
    @{ Name = "Agenda edit blank-only save"; Pattern = "isSaving \|\| message.trimmingCharacters"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda comment edit 2000 cap"; Pattern = "lineLimit\(3\.\.\.10\)"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Similar books Android take(8)"; Pattern = "similarBooks\.prefix\(8\)"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Similar card Android widths"; Pattern = "if heroCardWidth < 380 { return 106 }"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Forum guest cream prompt"; Pattern = "0xF7F2EA"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum guest Android title ink"; Pattern = "0x1E2433"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Book issue Android inline feedback"; Pattern = "0x0F766E"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book issue login Android copy"; Pattern = "bookDetailIssueLoginRequired"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book detail Android Hemen Oku CTA"; Pattern = "Hemen Oku"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book detail Android Format cell"; Pattern = "bookDetailInfoFormat"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android PDF EPUB fallback"; Pattern = "displayedFormat"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Book request vote Oy label"; Pattern = "bookRequestsVoteCount"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Forum rich message body"; Pattern = "ForumMessageBody"; Path = "App/Ekitapligim/Design/EKitapligimComponents.swift" }
    @{ Name = "Forum message formatting core"; Pattern = "ForumMessageFormatting"; Path = "Sources/EkitapligimCore/ForumMessageFormatting.swift" }
    @{ Name = "Library selected shelf summary"; Pattern = "librarySelectedShelfLabel|selectedShelfSummary"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library branded empty state"; Pattern = "libraryEmptyState"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library empty Android catalog copy"; Pattern = "Bu rafta henüz kitap yok"; Path = "Sources/EkitapligimCore/Resources/Localizable.xcstrings" }
    @{ Name = "Library Android card progress row"; Pattern = "displayProgressPercent|chevron\.right"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library author missing fallback"; Pattern = "libraryAuthorMissing"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Finished shelf progress 100"; Pattern = "isOnFinishedShelf \{ return 100 \}"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Agenda single attachment layout"; Pattern = "attachments\.count == 1"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Forum pinned reply composer"; Pattern = "safeAreaInset\(edge: \.bottom"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum post full-width images"; Pattern = "forumPostImage|minHeight: 120, maxHeight: 360"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum reply trailing submit"; Pattern = "paperplane\.fill"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum reply in-flight guard"; Pattern = "isReplySending"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Chat draft character limit"; Pattern = "draftCharacterLimit"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat composer person icon"; Pattern = "person\.fill"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat send rounded square"; Pattern = "width: 50, height: 50"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Book comments Android header"; Pattern = "bookCommentsSignedInSubtitle|commentsSectionHeader"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book comments end-aligned submit"; Pattern = "bookCommentsSubmit"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Agenda quoted purple attribution"; Pattern = "agendaQuotedFrom|agendaPurple"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda quoted Android lavender card"; Pattern = "0xF8F6FF"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Optimistic shelf library patch"; Pattern = "applyOptimisticShelfUpdate|upsertLibraryItem"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Agenda comment count sync"; Pattern = "self\.post = post\.updating"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda feed sync from detail"; Pattern = "onPostUpdated"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Library last-read meta"; Pattern = "libraryMetaText|libraryMetaLastPage|continueReadingFromPage"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library uses shared shelf state"; Pattern = "container\.libraryItems"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library downloads local merge"; Pattern = "downloadManager\.localFile"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Book detail shelf refresh"; Pattern = "onChange\(of: container\.libraryItems\)"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Shelf menu preserves reading shelf"; Pattern = "displayShelfStateForMenu"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Forum reply canReply refresh"; Pattern = "posts\.last\?\.canReply"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Reader auto reading shelf"; Pattern = "promoteReadingShelfIfNeeded|OKUYORUM"; Path = "App/Ekitapligim/Features/ReaderView.swift" }
    @{ Name = "Reader patches library progress"; Pattern = "patchLibraryItem"; Path = "App/Ekitapligim/Features/ReaderView.swift" }
    @{ Name = "Book detail guest read login"; Pattern = "showingReaderLoginAlert"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail download denial"; Pattern = "downloadDenialMessage"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Library download offline meta"; Pattern = "libraryDownloadOfflineReady"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Agenda comment reaction score"; Pattern = "reactionScore"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Forum thread card metrics"; Pattern = "metricPill|amberSoft"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum create labeled CTA"; Pattern = "forumThreadsCreate"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum create dialog title"; Pattern = "forumThreadsCreateDialogTitle"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum load-more Android copy"; Pattern = "forumThreadsLoadMore"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum collapsed + create icon"; Pattern = "forumThreadsCreateAccessibility"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum reply placeholder copy"; Pattern = "forumThreadReplyPlaceholder"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum report Raporla label"; Pattern = "forumThreadReportAction"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum premium post badge"; Pattern = "chatRolePremium"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Chat nav subtitle"; Pattern = "ChatNavigationSubtitleModifier\(subtitle: L10n\.chatSubtitle\)"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Agenda load-more Android copy"; Pattern = "commonLoadMoreItems"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Library meta Devam et fallback"; Pattern = "libraryMetaContinue"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Library meta Indirildi label"; Pattern = "libraryMetaDownloaded"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Library local download meta merge"; Pattern = "libraryMetaText\(treatingAsDownloaded"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Book request create dialog title"; Pattern = "bookRequestsCreateDialogTitle"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request Android field labels"; Pattern = "Kitap Adı|ISBN \(Opsiyonel\)"; Path = "Sources/EkitapligimCore/Localization.swift" }
    @{ Name = "Book request empty Android copy"; Pattern = "Henüz kitap isteği yapılmamış"; Path = "Sources/EkitapligimCore/Localization.swift" }
    @{ Name = "Chat session preparing composer"; Pattern = "chatSessionPreparingTitle"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Book request circular vote control"; Pattern = "0x1954C8|width: 62, height: 62"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request hash cover palettes"; Pattern = "private static let palettes"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request orange gradient CTA"; Pattern = "0xFFA122"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request section accent bar"; Pattern = "0x1B56E8"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request hero height"; Pattern = "minHeight: 178"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request cover glow canvas"; Pattern = "white.opacity\(0.13\)"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request status pill icons"; Pattern = "checkmark.circle.fill"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Forum reply focused teal border"; Pattern = "0x087A80"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Book comments focused teal border"; Pattern = "0x087A80"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Chat composer focused teal border"; Pattern = "isComposerFocused"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Forum guest reply Android copy"; Pattern = "forumThreadGuestReplyTitle|Cevap yazmak için kayıt olun"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda saved filter bookmark chip"; Pattern = "bookmark\.fill"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer bottom sheet"; Pattern = "presentationDetents|presentationDragIndicator"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Forum gold-trim hero surface"; Pattern = "forumHeroSurface|EKForumGoldDecoration"; Path = "App/Ekitapligim/Design/EKitapligimComponents.swift" }
    @{ Name = "Forum hero inline Konu Ac CTA"; Pattern = "forumThreadsHeroMetricLabel"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Book request Social hero copy"; Pattern = "Sosyal & Topluluk"; Path = "Sources/EkitapligimCore/Localization.swift" }
    @{ Name = "Forum detail collapsible hero"; Pattern = "EKCollapsibleHero|heroCollapseProgress"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Library meta text"; Pattern = "libraryMetaText|displayProgressPercent"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Book comments five-star rows"; Pattern = "bookCommentsTitleCount|ForEach\(1\.\.\.5"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book comments Android placeholder"; Pattern = "Bu kitap hakkındaki düşüncelerinizi paylaşın"; Path = "Sources/EkitapligimCore/Localization.swift" }
    @{ Name = "Book comments catalog placeholder"; Pattern = "Bu kitap hakkındaki düşüncelerinizi paylaşın"; Path = "Sources/EkitapligimCore/Resources/Localizable.xcstrings" }
    @{ Name = "Android copy regression tests"; Pattern = "AndroidParityCopyTests|bookCommentsPlaceholder"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Android UGC write-contract tests"; Pattern = "shelf_state|post_type|book-requests/42/vote"; Path = "Tests/EkitapligimCoreTests/AndroidUGCParityContractTests.swift" }
    @{ Name = "Book request vote pending-only"; Pattern = "allowsVote"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request author required"; Pattern = "author\.trimmed\.isEmpty"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book requests guest create hint"; Pattern = "bookRequestsGuestCreateHint"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book requests success feedback"; Pattern = "bookRequestsCreated|bookRequestsVoteSaved"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book requests iconless empty state"; Pattern = "EKEmptyState"; Path = "App/Ekitapligim/Features/BookRequestsView.swift"; ShouldNotMatch = $true; PassDetail = "Empty list uses text card, not EKEmptyState" }
    @{ Name = "Agenda signed-in personal tab"; Pattern = "tab = \.personal"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Book agenda post UI"; Pattern = "bookAgenda\.createPost"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer type chips"; Pattern = "agendaTypeNote|agendaTypeProgressCompose|composerTypeOptions"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Book comments UI"; Pattern = "books\.createComment"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Shelf sync API"; Pattern = "updateLibraryItem"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Shelf sync preserves progress"; Pattern = "readingProgressForShelfUpdate"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Android shelf codes"; Pattern = "isOnReadingShelf|OKUYORUM"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Collapsible hero scaffold"; Pattern = "EKCollapsibleHero"; Path = "App/Ekitapligim/Design/EKitapligimDesign.swift" }
    @{ Name = "Catalog badges"; Pattern = "CatalogBookCover"; Path = "App/Ekitapligim/Features/CatalogView.swift" }
    @{ Name = "Book comments Android card chrome"; Pattern = "0xE4E9EA"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book comments 30pt rating stars"; Pattern = "width: 30, height: 30"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Chat incoming white bubble"; Pattern = "return \.white"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat Android bubble radii"; Pattern = "topLeadingRadius: 16"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat bot username gold"; Pattern = "0x95610A"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Forum Konu Ac CTA copy lock"; Pattern = "forumThreadsCreate,"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Forum post Android gold divider"; Pattern = "0xE9D9BA"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum post cream avatar tile"; Pattern = "size: 58"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum post trailing Raporla"; Pattern = "forumThreadReportAction"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Agenda featured gold border"; Pattern = "0xE6C878"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda actor handle meta"; Pattern = "post.actor.username\) ·"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Forum thread cream-teal avatar tile"; Pattern = "0xEDF7F5"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum thread Android metric chips"; Pattern = "0xF7F4EA"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum thread mint card border"; Pattern = "0xE1ECEA"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Library Android header gradient"; Pattern = "0xF4F9FF"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library Android navy title"; Pattern = "0x18343A"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library Android accent count"; Pattern = "0x16756F"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library Android page background"; Pattern = "0xF6FAFA"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library Android progress track"; Pattern = "0xE3EEEE"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library Android cover placeholder"; Pattern = "0xEDF4F4"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Book detail Android read gradient"; Pattern = "0x0A3B43"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Chat Android page gradient"; Pattern = "0xF9FCFC"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Agenda quoted type indigo"; Pattern = "0x5A67B7"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda progress type green"; Pattern = "0x27875F"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Book detail Android author gold"; Pattern = "0xB17C2A"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android category accent"; Pattern = "0xE75D8F"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android download count copy"; Pattern = "bookDetailDownloadCount"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Forum collapsed Android gold tile"; Pattern = "0xE2C48E"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum detail Android hero tile"; Pattern = "0xD9C79F"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Book detail Android gold section rule"; Pattern = "0xD5A65A"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android cream section border"; Pattern = "0xE7D3B3"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "MobileApi forum create backend"; Pattern = "function actionPost"; Path = "Backend/MobileApi-addon/Api/Controller/ForumThreads.php" }
    @{ Name = "Book detail Android synopsis wash"; Pattern = "0xFFFCF6"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android synopsis border"; Pattern = "0xEFE3D4"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android synopsis accent"; Pattern = "0xE18A1A"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Agenda Android book chip wash"; Pattern = "0xF7FAFA"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda Android avatar mint"; Pattern = "0xE7F7F7"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda Android progress track"; Pattern = "0xE5F2F2"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Chat Android reconnect cream"; Pattern = "0xE2D7C5"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Forum list Android page wash"; Pattern = "0xFFFCF4"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum detail Android page wash"; Pattern = "0xFAF6EC"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Book detail Android page wash"; Pattern = "0xFBF7EF"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android issue card"; Pattern = "0xC9E5E3"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail Android similar card border"; Pattern = "0xE5D7BD"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book request disabled CTA gold"; Pattern = "0xE0B16D"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request Android page wash"; Pattern = "0xF7FAFC"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Forum collapsed plus Android gold"; Pattern = "0xE2B866"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum post Android cream avatar gradient"; Pattern = "0xFFF7EA\), Color\(hex: 0xF5EDDC"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Book detail Android cover sizes"; Pattern = "compact \? 112 : 170"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "IosApi forum create backend"; Pattern = "function actionPost"; Path = "Backend/IosApi-addon/Api/Controller/ForumThreads.php" }
    @{ Name = "IosApi forum create Pub wrapper"; Pattern = "PublicEndpointTrait"; Path = "Backend/IosApi-addon/Pub/Controller/ForumThreads.php" }
    @{ Name = "IosApi thread posts Pub wrapper"; Pattern = "PublicEndpointTrait"; Path = "Backend/IosApi-addon/Pub/Controller/ThreadPosts.php" }
    @{ Name = "Agenda book picker take(10)"; Pattern = "prefix\(10\)"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda book picker 38x54 cover"; Pattern = "width: 38, height: 54"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda book picker TR locale"; Pattern = "tr-TR"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda book picker Kapat"; Pattern = "commonClose"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer selected title author"; Pattern = "selectedBook.map"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda book picker search copy"; Pattern = "agendaComposerSearchBook"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book request submitting Android copy"; Pattern = "bookRequestsSubmitting"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request submitting ellipsis"; Pattern = "Gönderiliyor\.\.\."; Path = "Sources/EkitapligimCore/Localization.swift" }
    @{ Name = "Book comment no 10000 cap"; Pattern = "prefix\(10_000\)"; Path = "App/Ekitapligim/Features/BookDetailView.swift"; ShouldNotMatch = $true; PassDetail = "Android comment field has no client take()" }
    @{ Name = "Agenda review Android slider"; Pattern = "in: 1\.\.\.5,\s+step: 1"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda review Puan copy"; Pattern = "agendaComposerRating\(5\)"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda create default public visibility"; Pattern = "visibility: \.public,"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda edit visibility Android copy"; Pattern = "agendaVisibilityPrivate"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda progress empty-total Android gate"; Pattern = "isProgressCurrentExceedingTotal"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda Android relative time Core helper"; Pattern = "timestampSeconds <= 0"; Path = "Sources/EkitapligimCore/CommunityRelativeTimeFormatting.swift" }
    @{ Name = "Agenda Android relative time year format"; Pattern = "d MMM yyyy"; Path = "Sources/EkitapligimCore/CommunityRelativeTimeFormatting.swift" }
    @{ Name = "App relativeTime delegates to Core"; Pattern = "CommunityRelativeTimeFormatting\.format"; Path = "App/Ekitapligim/Design/EKitapligimComponents.swift" }
    @{ Name = "Agenda relative time Android copy"; Pattern = "timeJustNow"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Forum post header has no relative timestamp"; Pattern = "relativeTime"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift"; ShouldNotMatch = $true; PassDetail = "Android PremiumPostCard shows no timestamp" }
    @{ Name = "Forum empty posts Android copy"; Pattern = "forumThreadEmptyPosts"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda refresh Android a11y"; Pattern = "agendaRefresh"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Chat refresh Android a11y"; Pattern = "chatRefresh"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Book detail download Android a11y"; Pattern = "bookDetailOfflineDownload"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book request vote Android a11y"; Pattern = "bookRequestsVoteAccessibility"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Chat empty-room Android copy"; Pattern = "chatMessagesEmpty"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book request requested-by Android copy"; Pattern = "bookRequestsRequestedBy"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book request author field Android copy"; Pattern = "bookRequestsAuthor,"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda composer validation Android copy"; Pattern = "agendaComposerEmptyMessage"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Chat read-only Android copy"; Pattern = "chatComposerReadOnlyTitle"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Chat no-permission uses Android subtitle"; Pattern = "chatComposerNoPermission"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat read-only notice keeps Android title"; Pattern = "!capabilities\.canUse \|\| selectedRoom\?\.isReadOnly"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat blocked send still shows composer"; Pattern = "else if !canSend \{"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android shows composer unless read-only or !canUse" }
    @{ Name = "Library open-book Android a11y"; Pattern = "libraryOpenBookDetail"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Library cover Android a11y"; Pattern = "accessibilityTitle: item.title"; Path = "App/Ekitapligim/Features/LibraryView.swift" }
    @{ Name = "Avatar profile-photo Android a11y"; Pattern = "profilePhotoAccessibility"; Path = "App/Ekitapligim/Design/EKitapligimComponents.swift" }
    @{ Name = "Chat load-older Android copy"; Pattern = "chatLoadOlder"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Chat role badges Android copy"; Pattern = "chatRoleAdmin"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Chat edited suffix Android copy"; Pattern = "chatEdited"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Forum post image Android a11y copy"; Pattern = "forumThreadPostImage"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Library shelf Okuyorum/Okudum Android copy"; Pattern = "libraryShelfFinished"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda verified Android a11y copy"; Pattern = "profileVerifiedAccessibility"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Forum report description Android copy"; Pattern = "forumThreadReportDescription"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book künye/similar Android copy"; Pattern = "bookDetailSimilarBooks"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda tab Android copy"; Pattern = "agendaTabPersonal"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Chat hero/welcome Android copy"; Pattern = "chatWelcomeReady"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Book detail Android gold round toolbar"; Pattern = "0xE3C79A"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book detail share not square action chip"; Pattern = "frame\(width: 52, height: 52\)"; Path = "App/Ekitapligim/Features/BookDetailView.swift"; ShouldNotMatch = $true; PassDetail = "Android share is 48pt round top-bar control" }
    @{ Name = "Book detail hides system nav for Android top bar"; Pattern = "toolbar\(\.hidden, for: \.navigationBar\)"; Path = "App/Ekitapligim/Features/BookDetailView.swift" }
    @{ Name = "Book share Android threads fallback"; Pattern = "ekitapligim.com/threads/"; Path = "Sources/EkitapligimCore/Models.swift" }
    @{ Name = "Book share Android chooser payload test"; Pattern = "cdn.example/a.pdf"; Path = "Tests/EkitapligimCoreTests/AndroidUGCParityContractTests.swift" }
    @{ Name = "Share/back Android copy"; Pattern = "commonBack,"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Forum error retry Android copy"; Pattern = "commonRetryAgain"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Retry-again Android copy"; Pattern = "commonRetryAgain"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda locked tab opens login"; Pattern = "if locked \{\s+showingLogin = true"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda locked tab remains tappable"; Pattern = "\.disabled\(locked\)"; Path = "App/Ekitapligim/Features/BookAgendaView.swift"; ShouldNotMatch = $true; PassDetail = "Android guest tab tap opens login" }
    @{ Name = "Agenda login switches to personal tab"; Pattern = "onChange\(of: container\.isSignedIn\)"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda locked-tab Android copy"; Pattern = "agendaTabLocked"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda composer Android edit glyph"; Pattern = "frame\(width: 42, height: 42\)"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer Android forward chevron"; Pattern = "arrow.forward"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer not using profile avatar"; Pattern = "profileState\?\.avatarUrl"; Path = "App/Ekitapligim/Features/BookAgendaView.swift"; ShouldNotMatch = $true; PassDetail = "Android composer prompt uses edit glyph, not avatar" }
    @{ Name = "Agenda comment Android 38pt avatar"; Pattern = "size: 38"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda comment not 34pt avatar"; Pattern = "size: 34"; Path = "App/Ekitapligim/Features/BookAgendaView.swift"; ShouldNotMatch = $true; PassDetail = "Android AgendaAvatar comment size is 38" }
    @{ Name = "Agenda comment trailing reply submit"; Pattern = "arrowshape.turn.up.left"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda comment guest teal login"; Pattern = "agendaTeal, in: RoundedRectangle"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer Android 22pt title"; Pattern = "size: 22, weight: \.heavy"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer Android send glyph"; Pattern = "paperplane.fill"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda composer sheet has no nav stack"; Pattern = "showingComposer\) \{\s+NavigationStack"; Path = "App/Ekitapligim/Features/BookAgendaView.swift"; ShouldNotMatch = $true; PassDetail = "Android composer is a bottom sheet without a navigation bar" }
    @{ Name = "Book request create Android dialog detents"; Pattern = "presentationDetents"; Path = "App/Ekitapligim/Features/BookRequestsView.swift" }
    @{ Name = "Book request create not Form sheet"; Pattern = "Form \{"; Path = "App/Ekitapligim/Features/BookRequestsView.swift"; ShouldNotMatch = $true; PassDetail = "Android create is AlertDialog, not a Form sheet" }
    @{ Name = "Forum topic create Android dialog detents"; Pattern = "presentationDetents"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum topic create not Form sheet"; Pattern = "Form \{"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift"; ShouldNotMatch = $true; PassDetail = "Android create is AlertDialog, not a Form sheet" }
    @{ Name = "Chat read-only Android visibility tile"; Pattern = "width: 42, height: 42"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat read-only notice is inline row"; Pattern = "readOnlyNotice\(title: String, subtitle: String\)[\s\S]{0,120}HStack"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat composer Android 22pt top corners"; Pattern = "topLeadingRadius: 22"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat composer not hairline divider"; Pattern = "overlay\(alignment: \.top\)"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android composer is a 22pt top-rounded bordered surface" }
    @{ Name = "Chat welcome Android ready fill"; Pattern = "sessionReady \? Color\(hex: 0xEAF8F7\)"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat welcome not ChatTealSoft ready fill"; Pattern = "sessionReady \? EKitapligimPalette.chatTealSoft"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android ChatWelcomeNote ready fill is 0xEAF8F7" }
    @{ Name = "Chat Android 35pt avatar"; Pattern = "size: 35"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat avatar not 30pt"; Pattern = "size: 30"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android ChatAvatar is 35.dp" }
    @{ Name = "Chat load-older Android history icon"; Pattern = "clock.arrow.circlepath"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat load-older Android 12pt corners"; Pattern = "clipShape\(RoundedRectangle\(cornerRadius: 12, style: \.continuous\)\)"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Book comments omit Android-absent empty copy"; Pattern = "bookCommentsEmpty"; Path = "App/Ekitapligim/Features/BookDetailView.swift"; ShouldNotMatch = $true; PassDetail = "Android PremiumCommentsSection has no empty-state string" }
    @{ Name = "Chat rooms empty is not error reconnect"; Pattern = "errorMessage = L10n.chatRoomsEmpty"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android ChatEmptyState is used when no rooms exist" }
    @{ Name = "Chat Android loading spinner card"; Pattern = "padding\(\.horizontal, 34\)"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat Android empty Forum glyph"; Pattern = "bubble.left.and.bubble.right.fill"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat messages loading not skeleton"; Pattern = "EKSkeletonCard"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android ChatLoadingState is a spinner card, not skeletons" }
    @{ Name = "Chat empty not generic state card"; Pattern = "EKStateCard"; Path = "App/Ekitapligim/Features/ChatView.swift"; ShouldNotMatch = $true; PassDetail = "Android ChatEmptyState uses Forum icon + muted body" }
    @{ Name = "Chat messages loading Android copy wired"; Pattern = "chatMessagesLoading"; Path = "App/Ekitapligim/Features/ChatView.swift" }
    @{ Name = "Chat loading/empty Android copy tests"; Pattern = "chatMessagesLoading"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Forum list empty Android 48pt glyph"; Pattern = "size: 48"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift" }
    @{ Name = "Forum list empty not generic unavailable view"; Pattern = "EKEmptyState"; Path = "App/Ekitapligim/Features/ForumThreadsView.swift"; ShouldNotMatch = $true; PassDetail = "Android empty forum uses 48.dp Forum icon + copy + Yeni konu ac" }
    @{ Name = "Forum posts empty Android 48pt vertical pad"; Pattern = "padding\(\.vertical, 48\)"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift" }
    @{ Name = "Forum posts empty not card chrome"; Pattern = "forumThreadEmptyPosts[\s\S]{0,220}ekitapligimCard"; Path = "App/Ekitapligim/Features/ForumThreadDetailView.swift"; ShouldNotMatch = $true; PassDetail = "Android empty posts is centered muted text, not a card" }
    @{ Name = "Chat hero Android member status copy"; Pattern = "chatStatusMember"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Chat hero Android live-update copy"; Pattern = "chatHeroLiveUpdate"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda load-more Android 14pt corners"; Pattern = "cornerRadius: 14, style: \.continuous"; Path = "App/Ekitapligim/Design/EKitapligimComponents.swift" }
    @{ Name = "Agenda state Android books glyph"; Pattern = "books.vertical.fill"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda load-more failure Android inline error"; Pattern = "showsIcon: false"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda inline error Android Yeniden dene"; Pattern = "commonRetryAgain"; Path = "App/Ekitapligim/Features/BookAgendaView.swift" }
    @{ Name = "Agenda empty/error Android copy tests"; Pattern = "agendaCommentsEmptyTitle"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }
    @{ Name = "Agenda load-more Android copy"; Pattern = "commonLoadMoreItems"; Path = "Tests/EkitapligimCoreTests/AndroidParityCopyTests.swift" }

)

foreach ($check in $codeChecks) {
    $fullPath = Join-Path $root $check.Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        Add-Result $check.Name "FAIL" "Missing file $($check.Path)"
        continue
    }
    $content = Get-Content -Raw -LiteralPath $fullPath
    $matched = $content -match $check.Pattern
    if ($check.ShouldNotMatch) {
        if ($matched) {
            Add-Result $check.Name "FAIL" "Blocked pattern still present in $($check.Path)"
        } else {
            $detail = if ($check.PassDetail) { $check.PassDetail } else { "Pattern absent in $($check.Path)" }
            Add-Result $check.Name "PASS" $detail
        }
        continue
    }
    if ($matched) {
        Add-Result $check.Name "PASS" "Wired in $($check.Path)"
    } else {
        Add-Result $check.Name "FAIL" "Pattern not found in $($check.Path)"
    }
}

Write-Step "Running Swift unit tests"
$previousEAP = $ErrorActionPreference
$ErrorActionPreference = "Stop"
try {
    $windowsTestScript = Join-Path $PSScriptRoot "swift-test-windows.ps1"
    if (($env:OS -eq "Windows_NT") -and (Test-Path -LiteralPath $windowsTestScript)) {
        & $windowsTestScript
    } else {
        & swift test --parallel
        if ($LASTEXITCODE -ne 0) { throw "swift test failed with exit code $LASTEXITCODE" }
    }
    Add-Result "Swift unit tests" "PASS" "swift-test-windows.ps1 completed"
    $global:LASTEXITCODE = 0
} catch {
    Add-Result "Swift unit tests" "FAIL" $_.Exception.Message
} finally {
    $ErrorActionPreference = $previousEAP
}

Write-Step "Running API route contract audit"
$ErrorActionPreference = "Continue"
try {
    $routeOutput = & (Join-Path $PSScriptRoot "api-route-contract-audit.ps1") 2>&1
    $routeText = $routeOutput | Out-String
    if ($routeText -match "Swift API endpoint paths missing|Public route contract missing") { throw $routeText }
    Add-Result "Route contract" "PASS" $routeText.Trim()
} catch {
    Add-Result "Route contract" "FAIL" $_.Exception.Message
} finally {
    $ErrorActionPreference = $previousEAP
}

if (-not $SkipNetwork) {
    Write-Step "Running public API smoke test"
    $ErrorActionPreference = "Continue"
    try {
        $smokeArgs = @{ BaseUrl = $BaseUrl }
        if ($AllowInsecure) { $smokeArgs.AllowInsecure = $true }
        $smokeOutput = & (Join-Path $PSScriptRoot "api-smoke-test.ps1") @smokeArgs 2>&1
        $smokeText = $smokeOutput | Out-String
        if ($smokeText -match "(?m)^FAIL ") { throw $smokeText }
        Add-Result "Public API smoke" "PASS" "Completed against $BaseUrl"
    } catch {
        Add-Result "Public API smoke" "FAIL" $_.Exception.Message
    } finally {
        $ErrorActionPreference = $previousEAP
    }

    Write-Step "Probing live forum topic create route"
    try {
        $probeUri = Join-AuditUrl("forums/2/threads")
        $probeBody = "title=parity+audit+probe&message=probe"
        Invoke-WebRequest -Uri $probeUri -Method POST -Body $probeBody -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -TimeoutSec 15 | Out-Null
        Add-Result "Live forum create POST" "PASS" "Route responds on production/staging"
    }
    catch {
        $status = 0
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
        }
        if ($status -eq 401 -or $status -eq 403) {
            Add-Result "Live forum create POST" "PASS" "Route exists (HTTP $status without auth is expected)"
        }
        elseif ($status -eq 404 -or $status -eq 405) {
            Add-Result "Live forum create POST" "WARN" "HTTP $status - deploy release-archive/Ekitapligim-IosApi.zip (v1.0.4+)"
        }
        else {
            Add-Result "Live forum create POST" "FAIL" "Unexpected HTTP $status"
        }
    }

    Write-Step "Probing live thread posts route"
    try {
        $postsUri = Join-AuditUrl("threads/1/posts?page=1")
        Invoke-WebRequest -Uri $postsUri -Method GET -UseBasicParsing -TimeoutSec 15 | Out-Null
        Add-Result "Live thread posts GET" "PASS" "Route responds on production/staging"
    } catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        if ($status -in 401, 403) {
            Add-Result "Live thread posts GET" "PASS" "Route exists (HTTP $status without auth is expected)"
        } elseif ($status -in 404, 405) {
            Add-Result "Live thread posts GET" "WARN" "HTTP $status - deploy IosApi zip v1.0.5+ with ThreadPosts Pub wrapper"
        } else {
            Add-Result "Live thread posts GET" "FAIL" "Unexpected HTTP $status"
        }
    }
} else {
    Add-Result "Public API smoke" "WARN" "Skipped (-SkipNetwork)"
    Add-Result "Live forum create POST" "WARN" "Skipped (-SkipNetwork)"
    Add-Result "Live thread posts GET" "WARN" "Skipped (-SkipNetwork)"
}

Write-Step "Checking IosApi release artifact"
$zipPath = Join-Path $root "release-archive/Ekitapligim-IosApi.zip"
if (Test-Path -LiteralPath $zipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $forumEntry = $zip.Entries | Where-Object { $_.FullName -like "*ForumThreads.php" } | Select-Object -First 1
        if ($forumEntry) {
            $stream = $forumEntry.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $php = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            $pubEntry = $zip.Entries | Where-Object { $_.FullName -like "*Pub/Controller/ForumThreads.php" } | Select-Object -First 1
            if ($php -match "function actionPost") {
                if ($pubEntry) {
                    Add-Result "IosApi release zip" "PASS" "ForumThreads::actionPost + Pub wrapper in $(Split-Path -Leaf $zipPath)"
                } else {
                    Add-Result "IosApi release zip" "WARN" "ForumThreads::actionPost present but Pub/Controller/ForumThreads.php missing"
                }
            } else {
                Add-Result "IosApi release zip" "FAIL" "ForumThreads.php missing actionPost"
            }
        } else {
            Add-Result "IosApi release zip" "FAIL" "ForumThreads.php not found in zip"
        }
    } finally {
        $zip.Dispose()
    }
} else {
    Add-Result "IosApi release zip" "WARN" "Missing $zipPath - run Scripts/build-ios-api-addon.ps1 -CreateZip"
}

Add-Result "Auth UGC mutations" "WARN" "Requires EKITAPLIGIM_SMOKE_LOGIN/PASSWORD or -BearerToken with -ExerciseMutations"
$smokeLogin = [string]$env:EKITAPLIGIM_SMOKE_LOGIN
$smokePassword = [string]$env:EKITAPLIGIM_SMOKE_PASSWORD
$smokeToken = [string]$env:EKITAPLIGIM_SMOKE_ACCESS_TOKEN
if (-not $SkipNetwork -and (
        (-not [string]::IsNullOrWhiteSpace($smokeLogin) -and -not [string]::IsNullOrWhiteSpace($smokePassword)) -or
        -not [string]::IsNullOrWhiteSpace($smokeToken)
    )) {
    Write-Step "Running authenticated UGC mutation smoke"
    $ErrorActionPreference = "Continue"
    try {
        $mutationArgs = @{ BaseUrl = $BaseUrl; ExerciseMutations = $true }
        if ($AllowInsecure) { $mutationArgs.AllowInsecure = $true }
        if (-not [string]::IsNullOrWhiteSpace($smokeToken)) {
            $mutationArgs.BearerToken = $smokeToken
        } else {
            $mutationArgs.Login = $smokeLogin
            $mutationArgs.Password = $smokePassword
        }
        $mutationOutput = & (Join-Path $PSScriptRoot "api-smoke-test.ps1") @mutationArgs 2>&1
        $mutationExit = $LASTEXITCODE
        if ($mutationExit -ne 0) { throw ($mutationOutput | Out-String) }
        $mutationText = ($mutationOutput | Out-String)
        $script:results = @($results | Where-Object { $_.Name -ne "Auth UGC mutations" })
        if ($mutationText -match "WARN POST forums/.+threads") {
            Add-Result "Auth UGC mutations" "WARN" "Authenticated smoke completed; forum create still 404 until IosApi deploy"
        } else {
            Add-Result "Auth UGC mutations" "PASS" "ExerciseMutations completed against $BaseUrl"
        }

        if (-not [string]::IsNullOrWhiteSpace($smokeToken)) {
            Write-Step "Running UGC safety smoke test"
            $safetyArgs = @{
                BaseUrl = $BaseUrl
                BearerToken = $smokeToken
            }
            if ($AllowInsecure) { $safetyArgs.AllowInsecure = $true }
            $safetyOutput = & (Join-Path $PSScriptRoot "ugc-safety-smoke-test.ps1") @safetyArgs 2>&1
            $safetyExit = $LASTEXITCODE
            if ($safetyExit -ne 0) { throw ($safetyOutput | Out-String) }
            Add-Result "UGC safety smoke" "PASS" "Completed with bearer token"
        }
    } catch {
        $script:results = @($results | Where-Object { $_.Name -ne "Auth UGC mutations" -and $_.Name -ne "UGC safety smoke" })
        Add-Result "Auth UGC mutations" "FAIL" $_.Exception.Message
    } finally {
        $ErrorActionPreference = $previousEAP
    }
} else {
    Add-Result "UGC safety smoke" "WARN" "Requires EKITAPLIGIM_SMOKE_ACCESS_TOKEN when running auth mutations"
}
Add-Result "Visual screenshot parity" "WARN" "Requires Mac/Xcode simulator side-by-side comparison"

Write-Host ""
Write-Step "Summary"
$pass = @($results | Where-Object Status -eq "PASS").Count
$warn = @($results | Where-Object Status -eq "WARN").Count
$fail = @($results | Where-Object Status -eq "FAIL").Count
Write-Host "PASS=$pass WARN=$warn FAIL=$fail"

if ($fail -gt 0) {
    exit 1
}

Write-Host ""
Write-Step "Actionable next steps"
if (@($results | Where-Object { $_.Name -eq "Live forum create POST" -and $_.Status -eq "WARN" }).Count -gt 0) {
    Write-Host "- Deploy release-archive/Ekitapligim-IosApi.zip (v1.0.4+) on XenForo and rebuild routes."
    Write-Host "- Verify deploy: .\Scripts\verify-ios-api-deploy.ps1 -BaseUrl `"$BaseUrl`""
}
if (@($results | Where-Object { $_.Name -eq "Auth UGC mutations" -and $_.Status -eq "WARN" }).Count -gt 0) {
    Write-Host "- Copy .env.example to .env with EKITAPLIGIM_SMOKE_LOGIN/PASSWORD (or set env vars) and re-run parity-audit.ps1."
}
if (@($results | Where-Object { $_.Name -eq "Visual screenshot parity" }).Count -gt 0) {
    Write-Host "- Capture Mac/Xcode side-by-side screenshots vs Android reference for scoped UGC screens."
    Write-Host "- Checklist: .\Scripts\visual-parity-checklist.ps1"
}
Write-Host "- Full matrix: ANDROID_IOS_FEATURE_PARITY.md"
