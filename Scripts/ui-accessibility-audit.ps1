$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

function Write-Step($Message) {
    Write-Host "==> $Message"
}

function Fail($Message) {
    throw $Message
}

function Get-SwiftFiles {
    Get-ChildItem -LiteralPath "App" -Recurse -Filter "*.swift" |
        Where-Object { $_.FullName -notmatch "\\DerivedData\\" }
}

Write-Step "Checking icon-only SwiftUI buttons for accessibility labels"
$buttonFindings = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-SwiftFiles) {
    $lines = Get-Content -LiteralPath $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "Button\s*\{") {
            $windowEnd = [Math]::Min($i + 16, $lines.Count - 1)
            $window = ($lines[$i..$windowEnd] -join "`n")
            if ($window -match "Image\(systemName:" -and
                $window -notmatch "Label\(" -and
                $window -notmatch "\.accessibility(Label|Element|Hidden)\(") {
                $relativePath = Resolve-Path -LiteralPath $file.FullName -Relative
                $buttonFindings.Add("${relativePath}:$($i + 1)")
            }
        }
    }
}
if ($buttonFindings.Count -gt 0) {
    Fail "Icon-only Button blocks need an accessibility label:`n$($buttonFindings -join "`n")"
}

Write-Step "Checking multi-line text editors for accessibility labels"
$editorFindings = New-Object System.Collections.Generic.List[string]
foreach ($file in Get-SwiftFiles) {
    $lines = Get-Content -LiteralPath $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "TextEditor\(text:") {
            $windowEnd = [Math]::Min($i + 8, $lines.Count - 1)
            $window = ($lines[$i..$windowEnd] -join "`n")
            if ($window -notmatch "\.accessibilityLabel\(") {
                $relativePath = Resolve-Path -LiteralPath $file.FullName -Relative
                $editorFindings.Add("${relativePath}:$($i + 1)")
            }
        }
    }
}
if ($editorFindings.Count -gt 0) {
    Fail "TextEditor controls need explicit accessibility labels:`n$($editorFindings -join "`n")"
}

Write-Step "Checking localization resource is populated"
$localizationPath = "Sources/EkitapligimCore/Resources/Localizable.xcstrings"
$localization = Get-Content -Raw -LiteralPath $localizationPath | ConvertFrom-Json
$stringCount = ($localization.strings.PSObject.Properties | Measure-Object).Count
if ($stringCount -lt 2) {
    Fail "Localizable.xcstrings is unexpectedly sparse"
}
if (-not $localization.strings.'app.name') {
    Fail "Localizable.xcstrings must define app.name"
}
foreach ($requiredLocalizationKey in @(
    "account.delete.title",
    "account.delete.warning",
    "account.delete.submit",
    "account.security.title",
    "account.security.currentPassword",
    "account.security.email.update",
    "account.security.password.update",
    "book.detail.title",
    "book.detail.similarBooks",
    "book.detail.loading",
    "book.detail.openFailed",
    "book.detail.offlineDownload",
    "book.detail.secureDownloadMissing",
    "bookComments.title",
    "bookComments.placeholder",
    "bookComments.submit",
    "bookComments.report",
    "bookRequests.title",
    "bookRequests.create",
    "bookRequests.bookTitle",
    "bookRequests.loginRequiredMessage",
    "bookRequests.voteCount",
    "blockMember.title",
    "blockMember.submit",
    "blockedMembers.title",
    "catalog.title",
    "catalog.filters.title",
    "catalog.filters.apply",
    "catalog.display.grid",
    "catalog.display.list",
    "catalog.loadMore",
    "catalog.loading",
    "catalog.searchPrompt",
    "common.close",
    "common.bookNumber",
    "common.percent",
    "community.title",
    "community.blockUser",
    "conversations.title",
    "conversations.new",
    "conversations.recipient",
    "conversations.replyPlaceholder",
    "myComments.title",
    "myComments.loading",
    "myComments.emptyTitle",
    "notifications.noDestination",
    "downloads.title",
    "downloads.emptyTitle",
    "downloads.downloading",
    "directory.authors.title",
    "directory.publishers.title",
    "directory.searchPrompt",
    "directory.bookCount",
    "forumThread.replySection",
    "forumThread.submitReply",
    "forumThreads.loading",
    "forumThreads.meta",
    "home.title",
    "home.openCatalog",
    "home.continueReading",
    "home.stats.section",
    "home.stats.books",
    "home.stats.authors",
    "home.stats.publishers",
    "home.stats.categories",
    "home.stats.loadFailed",
    "login.title",
    "login.usernamePlaceholder",
    "login.passwordPlaceholder",
    "login.submit",
    "login.mode.register",
    "login.emailPlaceholder",
    "login.passwordConfirmation",
    "login.acceptLegal",
    "login.forgotPassword",
    "login.reset.submit",
    "login.reset.privacyNotice",
    "library.title",
    "library.loading",
    "library.shelfPicker",
    "library.shelf.all",
    "library.readingProgressLabel",
    "members.title",
    "members.searchPrompt",
    "members.follow",
    "members.blockConfirmation",
    "notifications.title",
    "notifications.markAllRead",
    "privacy.title",
    "privacy.summarySection",
    "privacy.trackingLabel",
    "privacy.analyticsLabel",
    "privacy.offlineNotice",
    "privacy.trackingNotice",
    "profile.title",
    "profile.statsSection",
    "profile.edit.title",
    "profile.edit.about",
    "profile.edit.location",
    "profile.edit.website",
    "profile.edit.activityVisible",
    "profile.edit.save",
    "premium.title",
    "premium.plans",
    "premium.restore",
    "premium.manageSubscriptions",
    "premium.renewalDisclosure",
    "reader.preparing",
    "reader.addBookmark",
    "reader.removeBookmark",
    "reader.bookmarks",
    "reader.bookmarks.empty",
    "reader.page",
    "reader.unavailable",
    "reader.secureLinkMissing",
    "reader.atsLinkMissing",
    "reader.sessionFailed",
    "reader.unsupportedFormat",
    "reader.epub.preparing",
    "reader.epub.unavailable",
    "report.title",
    "report.reason",
    "report.messageLabel",
    "report.submit",
    "settings.title",
    "settings.signIn",
    "settings.signOut",
    "settings.privacyPolicy",
    "settings.support",
    "tab.home",
    "tab.catalog",
    "tab.library",
    "tab.community",
    "tab.account",
    "terms.title",
    "terms.acceptToggle",
    "terms.accept"
)) {
    if (-not $localization.strings.$requiredLocalizationKey) {
        Fail "Localizable.xcstrings missing required key: $requiredLocalizationKey"
    }
}

Write-Host "UI accessibility audit completed."
