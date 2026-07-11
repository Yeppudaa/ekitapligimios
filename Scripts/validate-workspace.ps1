param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

function Write-Step($Message) {
    Write-Host "==> $Message"
}

function Assert-File($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required file: $Path"
    }
}

function Get-XcconfigValue($Content, $Key) {
    $match = [Regex]::Match($Content, "(?m)^\s*$([Regex]::Escape($Key))\s*=\s*(?<value>.+?)\s*$")
    if (-not $match.Success) {
        throw "Missing xcconfig value: $Key"
    }
    return $match.Groups["value"].Value.Trim()
}

function Normalize-XcconfigURL($Value) {
    return $Value -replace "/\$\(\)/", "//"
}

Write-Step "Checking required files"
@(
    "Package.swift",
    "project.yml",
    "App/Ekitapligim/Support/Info.plist",
    "App/Ekitapligim/Support/Ekitapligim.entitlements",
    "App/Ekitapligim/Support/PrivacyInfo.xcprivacy",
    "App/Ekitapligim/Features/MyCommentsView.swift",
    "App/Ekitapligim/StoreKit/Ekitapligim.storekit",
    "Backend/MobileApi-addon/routes-fragment.xml",
    "Backend/MobileApi-addon/Service/IosEntitlement.php",
    "Backend/MobileApi-addon/Api/Controller/BookRequestVote.php",
    "APP_STORE_METADATA.md",
    "REVIEWER_TEST_PLAN.md",
    "UNIVERSAL_LINKS.md",
    "SECRETS_AND_ENVIRONMENT.md",
    "Scripts/api-smoke-test.ps1",
    "Scripts/api-route-contract-audit.ps1",
    "Scripts/public-release-audit.ps1",
    "Scripts/prepare-public-deployment.ps1",
    "Scripts/session-rotation-smoke-test.ps1",
    "Scripts/ugc-safety-smoke-test.ps1",
    "Scripts/appstore-preflight.ps1",
    "Scripts/apply-mobileapi-ios-patch.ps1",
    "Scripts/generate-placeholder-appicon.ps1",
    "Scripts/generate-branded-appicon.ps1",
    "Scripts/swift-test-windows.ps1",
    "Scripts/swift-static-audit.ps1",
    "Scripts/ui-accessibility-audit.ps1",
    "Web/.well-known/apple-app-site-association",
    "App/Ekitapligim/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "APP_ICON_SOURCE.md"
    "Backend/MobileApi-addon/public-route-contract.txt"
) | ForEach-Object { Assert-File $_ }

Write-Step "Parsing XML/plist files"
@(
    "App/Ekitapligim/Support/Info.plist",
    "App/Ekitapligim/Support/Ekitapligim.entitlements",
    "App/Ekitapligim/Support/PrivacyInfo.xcprivacy",
    "Backend/MobileApi-addon/routes-fragment.xml"
) | ForEach-Object {
    [xml](Get-Content -Raw -LiteralPath $_) | Out-Null
}

Write-Step "Parsing JSON resources"
@(
    "Sources/EkitapligimCore/Resources/Localizable.xcstrings",
    "App/Ekitapligim/StoreKit/Ekitapligim.storekit",
    "Web/.well-known/apple-app-site-association",
    "App/Ekitapligim/Assets.xcassets/AppIcon.appiconset/Contents.json"
) | ForEach-Object {
    Get-Content -Raw -LiteralPath $_ | ConvertFrom-Json | Out-Null
}

Write-Step "Checking AppIcon asset files"
Add-Type -AssemblyName System.Drawing
$appIcon = Get-Content -Raw -LiteralPath "App/Ekitapligim/Assets.xcassets/AppIcon.appiconset/Contents.json" | ConvertFrom-Json
foreach ($image in $appIcon.images) {
    if ($image.filename) {
        $iconPath = Join-Path "App/Ekitapligim/Assets.xcassets/AppIcon.appiconset" $image.filename
        Assert-File $iconPath
        $expectedPixels = [int]([double]$image.size.Split('x')[0] * [double]$image.scale.TrimEnd('x'))
        $bitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $iconPath))
        try {
            if ($bitmap.Width -ne $expectedPixels -or $bitmap.Height -ne $expectedPixels) {
                throw "AppIcon dimensions do not match Contents.json: $($image.filename) expected ${expectedPixels}x${expectedPixels}, got $($bitmap.Width)x$($bitmap.Height)"
            }
            if ([System.Drawing.Image]::IsAlphaPixelFormat($bitmap.PixelFormat)) {
                throw "AppIcon must be opaque without an alpha channel: $($image.filename)"
            }
        } finally {
            $bitmap.Dispose()
        }
    }
}
$iconEvidence = Get-Content -Raw -LiteralPath "APP_ICON_SOURCE.md"
if ($iconEvidence -notmatch "Android brand asset" -or $iconEvidence -notmatch "Source SHA-256") {
    throw "App icon source evidence is missing or incomplete"
}
$marketingIconPath = "App/Ekitapligim/Assets.xcassets/AppIcon.appiconset/appicon-1024.png"
$marketingIconBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $marketingIconPath))
if ($marketingIconBytes.Length -lt 100000) {
    throw "Marketing AppIcon is unexpectedly small and may still be placeholder artwork"
}

Write-Step "Checking production configuration"
$productionConfig = Get-Content -Raw -LiteralPath "App/Ekitapligim/Config/Production.xcconfig"
if ($productionConfig -match "localhost|127\.0\.0\.1|http://|192\.168\.|10\.0\.") {
    throw "Production.xcconfig contains a local or insecure URL"
}
$productionApiURL = Normalize-XcconfigURL (Get-XcconfigValue $productionConfig "EKITAPLIGIM_API_BASE_URL")
if ($productionApiURL -ne "https://ekitapligim.com/mobile-api/v1/") {
    throw "Production.xcconfig does not point at the expected HTTPS production API: $productionApiURL"
}
try {
    $productionApiUri = [Uri]$productionApiURL
} catch {
    throw "Production API URL is not a valid URL: $productionApiURL"
}
if ($productionApiUri.Scheme -ne "https" -or $productionApiUri.Host -ne "ekitapligim.com") {
    throw "Production API URL must use HTTPS ekitapligim.com: $productionApiURL"
}

Write-Step "Checking entitlements are not broader than implemented features"
$entitlements = Get-Content -Raw -LiteralPath "App/Ekitapligim/Support/Ekitapligim.entitlements"
if ($entitlements -match "aps-environment") {
    throw "Push notification entitlement is present before push is implemented"
}
if ($entitlements -match "com\.apple\.developer\.in-app-payments") {
    throw "Apple Pay entitlement is present; StoreKit IAP does not use Apple Pay entitlement"
}

Write-Step "Checking privacy manifest coverage"
$privacyManifest = Get-Content -Raw -LiteralPath "App/Ekitapligim/Support/PrivacyInfo.xcprivacy"
if ($privacyManifest -notmatch "<key>NSPrivacyTracking</key>\s*<false/>") {
    throw "Privacy manifest must explicitly declare no tracking unless tracking is implemented"
}

Write-Step "Checking App Transport Security scope"
$infoPlist = Get-Content -Raw -LiteralPath "App/Ekitapligim/Support/Info.plist"
if ($infoPlist -match "<key>NSAllowsArbitraryLoads</key>\s*<true/>") {
    throw "Info.plist must not allow arbitrary App Transport Security loads"
}
if ($infoPlist -match "<key>NSAllowsArbitraryLoadsInWebContent</key>\s*<true/>") {
    throw "Info.plist must not allow arbitrary web content loads"
}
foreach ($requiredPrivacyType in @(
    "NSPrivacyCollectedDataTypeEmailAddress",
    "NSPrivacyCollectedDataTypeOtherUserContactInfo",
    "NSPrivacyCollectedDataTypeCoarseLocation",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypeProductInteraction",
    "NSPrivacyCollectedDataTypePurchaseHistory",
    "NSPrivacyCollectedDataTypeOtherUserContent",
    "NSPrivacyCollectedDataTypeOtherDataTypes"
)) {
    if ($privacyManifest -notmatch [regex]::Escape($requiredPrivacyType)) {
        throw "Privacy manifest missing collected data type: $requiredPrivacyType"
    }
}
$privacyView = Get-Content -Raw -LiteralPath "App/Ekitapligim/Features/PrivacySettingsView.swift"
if ($privacyView -match "analyticsOptIn|notificationPreviews|Toggle\(") {
    throw "Privacy screen contains a preference control that is not wired to implemented behavior"
}
foreach ($requiredApiType in @(
    "NSPrivacyAccessedAPICategoryFileTimestamp",
    "NSPrivacyAccessedAPICategoryUserDefaults"
)) {
    if ($privacyManifest -notmatch [regex]::Escape($requiredApiType)) {
        throw "Privacy manifest missing required reason API type: $requiredApiType"
    }
}

Write-Step "Checking Swift source for release-blocking markers"
$swiftFindings = rg -n "try!|fatalError|preconditionFailure|TODO|FIXME" App Sources Tests 2>$null
if ($LASTEXITCODE -eq 0 -and $swiftFindings) {
    throw "Swift source contains release-blocking markers:`n$swiftFindings"
}

Write-Step "Checking macOS CI test gate"
$ciWorkflow = Get-Content -Raw -LiteralPath ".github/workflows/ios-ci.yml"
foreach ($requiredCIControl in @(
    "workflow_dispatch:",
    "- master",
    "Xcode 16.4",
    "xcodebuild -resolvePackageDependencies",
    "Readium 3.9.0 resolved",
    "-disableAutomaticPackageResolution",
    "xcodebuild test",
    "Ekitapligim.xcodeproj",
    "TestResults.xcresult",
    "actions/upload-artifact@v4",
    "xcodebuild clean build"
)) {
    if ($ciWorkflow -notmatch [regex]::Escape($requiredCIControl)) {
        throw "iOS CI workflow missing test/build evidence control: $requiredCIControl"
    }
}
foreach ($requiredUITestControl in @(
    "EkitapligimUITests",
    "bundle.ui-testing",
    "App/EkitapligimUITests"
)) {
    $projectSpec = Get-Content -Raw -LiteralPath "project.yml"
    if ($projectSpec -notmatch [regex]::Escape($requiredUITestControl)) {
        throw "project.yml missing UI test control: $requiredUITestControl"
    }
}
Assert-File "App/EkitapligimUITests/EkitapligimUITests.swift"

Write-Step "Checking StoreKit purchase and restore surface"
$premiumView = Get-Content -Raw -LiteralPath "App/Ekitapligim/Features/PremiumView.swift"
$storeKitService = Get-Content -Raw -LiteralPath "App/Ekitapligim/Purchases/StoreKitPurchaseService.swift"
foreach ($requiredPremiumControl in @(
    "premium.monthly",
    "premium.yearly",
    "Transaction.currentEntitlements",
    "verifyAppStorePurchase",
    "AppStore.sync()",
    "PurchaseVerificationPolicy.requireActive",
    "Transaction.updates",
    "startObservingTransactions",
    "stopObservingTransactions"
)) {
    if ($storeKitService -notmatch [regex]::Escape($requiredPremiumControl)) {
        throw "StoreKit service missing purchase/restore verification control: $requiredPremiumControl"
    }
}
$appContainerSource = Get-Content -Raw -LiteralPath "App/Ekitapligim/App/AppContainer.swift"
foreach ($requiredObserverLifecycleControl in @(
    "storeKit.startObservingTransactions()",
    "storeKit.stopObservingTransactions()"
)) {
    if ($appContainerSource -notmatch [regex]::Escape($requiredObserverLifecycleControl)) {
        throw "StoreKit transaction observer is not tied to auth lifecycle: $requiredObserverLifecycleControl"
    }
}
if ($storeKitService -notmatch "catch\s*\{\s*// Leave unverified or unsynced transactions unfinished") {
    throw "StoreKit transaction updates must remain unfinished when backend synchronization fails"
}

$forbiddenBillingFindings = rg -n -i "BillingClient|Google Play Billing|play-billing" App Sources 2>$null
if ($LASTEXITCODE -eq 0 -and $forbiddenBillingFindings) {
    throw "iOS source contains Android billing code or prompts:`n$forbiddenBillingFindings"
}

$storeKitConfig = Get-Content -Raw -LiteralPath "App/Ekitapligim/StoreKit/Ekitapligim.storekit" | ConvertFrom-Json
$configuredProductIds = @($storeKitConfig.subscriptionGroups.subscriptions.productID | Sort-Object -Unique)
$expectedProductIds = @("ekitapligim.premium.monthly", "ekitapligim.premium.yearly")
if (Compare-Object $expectedProductIds $configuredProductIds) {
    throw "StoreKit configuration product IDs do not match the native purchase service"
}
foreach ($requiredPremiumUI in @(
    "premiumRestore",
    "premiumManageSubscriptions",
    "premiumRenewalDisclosure",
    "privacyPolicyURL",
    "termsURL"
)) {
    if ($premiumView -notmatch [regex]::Escape($requiredPremiumUI)) {
        throw "Premium UI missing review control: $requiredPremiumUI"
    }
}

Write-Step "Running Swift static audit"
& (Join-Path $PSScriptRoot "swift-static-audit.ps1")

Write-Step "Running API route contract audit"
& (Join-Path $PSScriptRoot "api-route-contract-audit.ps1")

Write-Step "Running UI accessibility audit"
& (Join-Path $PSScriptRoot "ui-accessibility-audit.ps1")

Write-Step "Checking for obvious committed secrets"
$secretPatterns = @(
    "BEGIN PRIVATE KEY",
    "BEGIN RSA PRIVATE KEY",
    "XF-Api-Key\s*[:=]\s*['""][^'""]+",
    "STORE_PASSWORD\s*=",
    "KEY_PASSWORD\s*=",
    "APP_STORE_CONNECT_API_KEY\s*=",
    "EKITAPLIGIM_API_KEY\s*=\s*[^<\[]"
)
$scanTargets = @("App", "Sources", "Tests", "Backend", "Package.swift", "project.yml")
foreach ($pattern in $secretPatterns) {
    $matches = rg -n --pcre2 $pattern $scanTargets 2>$null
    if ($LASTEXITCODE -eq 0 -and $matches) {
        throw "Potential secret matched pattern '$pattern':`n$matches"
    }
}

Write-Step "Checking backend PHP syntax"
$bookRequestVoteSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/BookRequestVote.php"
foreach ($requiredVoteControl in @(
    'FOR UPDATE',
    '$db->beginTransaction();',
    "['support_count' => `$voteCount]",
    "'vote_count' => `$voteCount"
)) {
    if ($bookRequestVoteSource -notmatch [regex]::Escape($requiredVoteControl)) {
        throw "Book request vote endpoint must preserve atomic count behavior: $requiredVoteControl"
    }
}
$threadPostsSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/ThreadPosts.php"
if ($threadPostsSource -match [regex]::Escape('$replier->setUser(')) {
    throw "Mobile forum replies must use the authenticated XenForo visitor; ReplierService::setUser is protected"
}
foreach ($requiredReplyControl in @(
    '$replier->checkForSpam();',
    '$floodChecker->checkFlooding(''post'', (int) $visitor->user_id);',
    "'reply_flooding'",
    '429',
    '$replier->sendNotifications();'
)) {
    if ($threadPostsSource -notmatch [regex]::Escape($requiredReplyControl)) {
        throw "Mobile forum replies must preserve XenForo reply safety behavior: $requiredReplyControl"
    }
}
$postReportSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/PostReport.php"
if ($postReportSource -match [regex]::Escape('$creator->setUser(')) {
    throw "Report CreatorService uses the authenticated XenForo visitor and has no public setUser API"
}
foreach ($requiredReportControl in @(
    '$post->canReport($error)',
    '$floodChecker->checkFlooding(''report'', (int) $visitor->user_id);',
    '$creator->sendNotifications();'
)) {
    if ($postReportSource -notmatch [regex]::Escape($requiredReportControl)) {
        throw "Mobile post reports must preserve XenForo report safety behavior: $requiredReportControl"
    }
}
$patchScriptSource = Get-Content -Raw -LiteralPath "Scripts/apply-mobileapi-ios-patch.ps1"
foreach ($requiredBookCommentControl in @(
    'Aligning book comments with XenForo reply safety',
    '$replier->checkForSpam();',
    "'comment_flooding'",
    '$replier->sendNotifications();'
)) {
    if ($patchScriptSource -notmatch [regex]::Escape($requiredBookCommentControl)) {
        throw "Book comment patch must preserve XenForo reply safety behavior: $requiredBookCommentControl"
    }
}
foreach ($requiredRouteDispatchControl in @(
    'Aligning routed action prefixes with XenForo dispatch',
    'Auditing routed action prefixes',
    'actionReply(ParameterBag $params)',
    'actionMessages(ParameterBag $params)',
    'actionFollow(ParameterBag $params)',
    'actionUnfollow(ParameterBag $params)',
    'actionMarkAll()'
)) {
    if ($patchScriptSource -notmatch [regex]::Escape($requiredRouteDispatchControl)) {
        throw "Mobile routed action patch is missing: $requiredRouteDispatchControl"
    }
}
$accountDeletionMailSource = @(
    Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/AccountDeletionRequest.php"
    Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Service/AccountDeletionCompletion.php"
) -join "`n"
if ($accountDeletionMailSource -match '->setSubject\(|->setBodyText\(') {
    throw "Account deletion mail must use XenForo 2.3 Mail::setContent"
}
$accountDeletionRequestSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/AccountDeletionRequest.php"
foreach ($requiredDeletionAuthControl in @(
    "current_password_required",
    "!`$hasAppleAuthorization && `$hasPassword",
    "`$requestId = `$this->recordDeletionRequest",
    "apple_revocation_pending",
    "MobileSession::revokeUserSessions"
)) {
    if ($accountDeletionRequestSource -notmatch [regex]::Escape($requiredDeletionAuthControl)) {
        throw "Account deletion authentication/revocation control missing: $requiredDeletionAuthControl"
    }
}
$deleteAccountViewSource = Get-Content -Raw -LiteralPath "App/Ekitapligim/Features/DeleteAccountView.swift"
$appContainerSource = Get-Content -Raw -LiteralPath "App/Ekitapligim/App/AppContainer.swift"
foreach ($requiredClientDeletionControl in @(
    "container.requestAccountDeletion",
    "isSubmitted = true"
)) {
    if ($deleteAccountViewSource -notmatch [regex]::Escape($requiredClientDeletionControl)) {
        throw "DeleteAccountView missing post-submission lifecycle control: $requiredClientDeletionControl"
    }
}
foreach ($requiredClientSessionCleanup in @(
    "await clearLocalSession()",
    "storeKit.stopObservingTransactions()",
    "tokenStore.clear()",
    "authState = .signedOut"
)) {
    if ($appContainerSource -notmatch [regex]::Escape($requiredClientSessionCleanup)) {
        throw "AppContainer missing account-deletion local session cleanup: $requiredClientSessionCleanup"
    }
}
$recordPosition = $accountDeletionRequestSource.IndexOf('$requestId = $this->recordDeletionRequest')
$revokePosition = $accountDeletionRequestSource.IndexOf('AppleAuthorization::revokeForUser')
if ($recordPosition -lt 0 -or $revokePosition -lt 0 -or $recordPosition -gt $revokePosition) {
    throw "Account deletion request must be durable before remote Apple revocation is attempted"
}
if (([regex]::Matches($accountDeletionMailSource, '->setContent\(')).Count -lt 2) {
    throw "Account deletion request and completion notices must both define mail content"
}
$legacyBearerFindings = rg -n "xf_user:" "Backend/MobileApi-addon" -g "*.php" 2>$null
if ($LASTEXITCODE -eq 0 -and $legacyBearerFindings) {
    throw "Backend runtime source still contains insecure legacy bearer tokens:`n$legacyBearerFindings"
}
$mobilePatchSource = Get-Content -Raw -LiteralPath "Scripts/apply-mobileapi-ios-patch.ps1"
if ($mobilePatchSource -notmatch [regex]::Escape("apiError('Login required.', 'login_required', null, 401)")) {
    throw "Mobile API patch does not map authentication failures to HTTP 401"
}
$mobileSessionSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Service/MobileSession.php"
foreach ($requiredSessionControl in @(
    "random_bytes(32)",
    "hash('sha256'",
    "access_expires_date",
    "refresh_expires_date",
    "revoked_date",
    "FOR UPDATE"
)) {
    if ($mobileSessionSource -notmatch [regex]::Escape($requiredSessionControl)) {
        throw "Mobile session implementation missing control: $requiredSessionControl"
    }
}
$appleAuthorizationSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Service/AppleAuthorization.php"
foreach ($requiredAppleControl in @(
    "https://appleid.apple.com/auth/token",
    "https://appleid.apple.com/auth/revoke",
    "grant_type",
    "authorization_code",
    "aes-256-gcm",
    "EKITAPLIGIM_APPLE_CLIENT_SECRET",
    "EKITAPLIGIM_APPLE_TOKEN_ENCRYPTION_KEY",
    "refresh_token_ciphertext"
)) {
    if ($appleAuthorizationSource -notmatch [regex]::Escape($requiredAppleControl)) {
        throw "Apple authorization implementation missing control: $requiredAppleControl"
    }
}
$appStoreVerifySource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/AppStoreVerify.php"
foreach ($requiredProductAllowlistControl in @(
    "ekitapligim.premium.monthly",
    "ekitapligim.premium.yearly",
    "if (!`$this->isAllowedProductId(`$productId))",
    "return in_array(`$productId, `$this->allowedProductIds(), true);"
)) {
    if ($appStoreVerifySource -notmatch [regex]::Escape($requiredProductAllowlistControl)) {
        throw "App Store verification must fail closed to the configured product allowlist: $requiredProductAllowlistControl"
    }
}
$appStoreNotificationsSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/AppStoreNotifications.php"
foreach ($requiredNotificationEntitlementControl in @(
    "validateNotificationPayload",
    "updateEntitlementFromNotification",
    "Notification transaction bundle mismatch",
    "Notification product is not allowed",
    "Notification transaction environment mismatch",
    "WHERE transaction_id = ? OR original_transaction_id = ?",
    "WHERE entitlement_id = ?"
)) {
    if ($appStoreNotificationsSource -notmatch [regex]::Escape($requiredNotificationEntitlementControl)) {
        throw "App Store Server Notifications entitlement control missing: $requiredNotificationEntitlementControl"
    }
}
$appleAuthControllerSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/AuthApple.php"
foreach ($requiredAppleAuthControl in @(
    "AppleAuthorization::exchangeCode",
    "AppleAuthorization::storeForUser",
    "hash_equals(hash('sha256', `$rawNonce), `$nonce)",
    "hash_equals((string) `$appleUser['sub'], (string) `$exchangedUser['sub'])"
)) {
    if ($appleAuthControllerSource -notmatch [regex]::Escape($requiredAppleAuthControl)) {
        throw "Apple authentication implementation missing control: $requiredAppleAuthControl"
    }
}
$deletionControllerSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Api/Controller/AccountDeletionRequest.php"
foreach ($requiredDeletionControl in @("AppleAuthorization::revokeForUser", "MobileSession::revokeUserSessions")) {
    if ($deletionControllerSource -notmatch [regex]::Escape($requiredDeletionControl)) {
        throw "Account deletion implementation missing control: $requiredDeletionControl"
    }
}
$deletionCompletionSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Service/AccountDeletionCompletion.php"
foreach ($requiredCompletionControl in @(
    "XF\Service\User\DeleteService",
    "AppleAuthorization::revokeForUser",
    "renameTo('Deleted member '",
    "request_state' => 'completed'",
    "'username' => ''",
    "'email' => ''",
    "'reason' => null"
)) {
    if ($deletionCompletionSource -notmatch [regex]::Escape($requiredCompletionControl)) {
        throw "Account deletion completion missing control: $requiredCompletionControl"
    }
}
$completionRevokePosition = $deletionCompletionSource.IndexOf('AppleAuthorization::revokeForUser')
$completionDeletePosition = $deletionCompletionSource.IndexOf('$deleteService->delete')
if ($completionRevokePosition -lt 0 -or $completionDeletePosition -lt 0 -or $completionRevokePosition -gt $completionDeletePosition) {
    throw "Account deletion completion must revoke Apple authorization before deleting the user"
}
$deletionCliSource = Get-Content -Raw -LiteralPath "Backend/MobileApi-addon/Cli/Command/CompleteAccountDeletion.php"
foreach ($requiredCliControl in @("--confirm", "DELETE-", "InputOption::VALUE_NONE")) {
    if ($deletionCliSource -notmatch [regex]::Escape($requiredCliControl)) {
        throw "Account deletion CLI missing irreversible-action guard: $requiredCliControl"
    }
}
$phpCommand = Get-Command php -ErrorAction SilentlyContinue
$phpPath = if ($phpCommand) { $phpCommand.Source } elseif (Test-Path -LiteralPath "C:\xampp\php\php.exe") { "C:\xampp\php\php.exe" } else { $null }
if ($phpPath) {
    Write-Host "php: $phpPath"
    Get-ChildItem -LiteralPath "Backend/MobileApi-addon" -Recurse -Filter "*.php" | ForEach-Object {
        & $phpPath -l $_.FullName | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw "PHP syntax check failed for $($_.FullName)"
        }
    }
} elseif ($Strict) {
    throw "php is required in strict mode"
} else {
    Write-Host "php not found; skipping PHP syntax check"
}

Write-Step "Checking optional tool availability"
foreach ($tool in @("swift", "xcodebuild", "xcodegen")) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $cmd -and $tool -eq "swift") {
        $installedSwift = Get-ChildItem "$env:LOCALAPPDATA\Programs\Swift\Toolchains\*\usr\bin\swift.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($installedSwift) {
            Write-Host "${tool}: $($installedSwift.FullName)"
            continue
        }
    }
    if ($cmd) {
        Write-Host "${tool}: $($cmd.Source)"
    } else {
        Write-Host "${tool}: not installed in this workspace"
    }
}

Write-Host "Workspace validation completed."
