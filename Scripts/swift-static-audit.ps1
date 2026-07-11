$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

function Write-Step($Message) {
    Write-Host "==> $Message"
}

function Fail($Message) {
    throw $Message
}

Write-Step "Checking Swift files for force unwraps and release markers"
$forceFindings = rg -n "try!|as!|fatalError|preconditionFailure|TODO|FIXME" App Sources Tests 2>$null
if ($LASTEXITCODE -eq 0 -and $forceFindings) {
    Fail "Swift release marker or unsafe force operation found:`n$forceFindings"
}

Write-Step "Checking UIKit imports for UIKit-backed APIs"
$reader = Get-Content -Raw -LiteralPath "App/Ekitapligim/Features/ReaderView.swift"
if ($reader -match "UIViewRepresentable|PDFView|PDFDocument" -and $reader -notmatch "import UIKit") {
    Fail "ReaderView.swift uses UIKit-backed APIs without importing UIKit"
}
$download = Get-Content -Raw -LiteralPath "App/Ekitapligim/Downloads/DownloadManager.swift"
if ($download -match "FileProtectionType" -and $download -notmatch "import UIKit") {
    Fail "DownloadManager.swift uses FileProtectionType without importing UIKit"
}

Write-Step "Checking Package.swift target/resource paths"
if (-not (Test-Path -LiteralPath "Sources/EkitapligimCore")) {
    Fail "Missing Sources/EkitapligimCore"
}
if (-not (Test-Path -LiteralPath "Sources/EkitapligimCore/Resources/Localizable.xcstrings")) {
    Fail "Missing Localizable.xcstrings resource"
}
if (-not (Test-Path -LiteralPath "Tests/EkitapligimCoreTests")) {
    Fail "Missing Tests/EkitapligimCoreTests"
}

Write-Step "Checking project.yml references"
$project = Get-Content -Raw -LiteralPath "project.yml"
@(
    "App/Ekitapligim/Support/Info.plist",
    "App/Ekitapligim/Support/Ekitapligim.entitlements",
    "App/Ekitapligim/Support/PrivacyInfo.xcprivacy",
    "App/Ekitapligim/StoreKit/Ekitapligim.storekit",
    "AppIcon"
) | ForEach-Object {
    if ($project -notmatch [Regex]::Escape($_)) {
        Fail "project.yml missing reference: $_"
    }
}
foreach ($requiredReadiumReference in @(
    "https://github.com/readium/swift-toolkit.git",
    "exactVersion: 3.9.0",
    "product: ReadiumShared",
    "product: ReadiumStreamer",
    "product: ReadiumNavigator"
)) {
    if ($project -notmatch [Regex]::Escape($requiredReadiumReference)) {
        Fail "project.yml missing pinned EPUB dependency: $requiredReadiumReference"
    }
}
if (-not (Test-Path -LiteralPath "THIRD_PARTY_NOTICES.md")) {
    Fail "Missing third-party license notices"
}

Write-Step "Checking secure EPUB reader controls"
$epubReader = Get-Content -Raw -LiteralPath "App/Ekitapligim/Reader/EPUBReaderView.swift"
foreach ($requiredEPUBControl in @(
    'sourceURL.scheme?.lowercased() == "https"',
    'DownloadFilePolicy.validateHeader',
    'FileProtectionType.completeUntilFirstUserAuthentication',
    'isExcludedFromBackup = true',
    'EPUBNavigatorViewController'
)) {
    if ($epubReader -notmatch [Regex]::Escape($requiredEPUBControl)) {
        Fail "EPUB reader missing security/integration control: $requiredEPUBControl"
    }
}

Write-Step "Checking common accidental localhost references in app config"
$configFindings = rg -n "localhost|127\.0\.0\.1|http://" App/Ekitapligim/Config App/Ekitapligim/App App/Ekitapligim/Features App/Ekitapligim/Downloads App/Ekitapligim/Security App/Ekitapligim/Purchases Sources 2>$null |
    Where-Object { $_ -notmatch "^Sources\\EkitapligimCore\\AppConfig\.swift:" }
if ($configFindings) {
    Fail "Runtime source/config contains localhost or insecure URL:`n$configFindings"
}

$appConfig = Get-Content -Raw -LiteralPath "Sources/EkitapligimCore/AppConfig.swift"
if ($appConfig -notmatch 'URL\(string:\s*"https://ekitapligim\.com/mobile-api/v1/"\)' -or
    $appConfig -notmatch 'URL\(string:\s*"https://ekitapligim\.com/"\)') {
    Fail "AppConfig production defaults must point to HTTPS ekitapligim.com URLs"
}

Write-Step "Checking reader/download flows use authorized session URLs"
$directBookPdfUsage = rg -n "book\.pdfUrl" App/Ekitapligim/Features App/Ekitapligim/Downloads 2>$null
if ($LASTEXITCODE -eq 0 -and $directBookPdfUsage) {
    Fail "Reader/download UI must use reader session source URLs instead of persistent book.pdfUrl:`n$directBookPdfUsage"
}

Write-Step "Checking offline download storage controls"
$downloadManager = Get-Content -Raw -LiteralPath "App/Ekitapligim/Downloads/DownloadManager.swift"
foreach ($requiredDownloadControl in @(
    "DownloadFilePolicy.fileName",
    "DownloadFilePolicy.validateHeader",
    "isExcludedFromBackup = true",
    "FileProtectionType.completeUntilFirstUserAuthentication"
)) {
    if ($downloadManager -notmatch [regex]::Escape($requiredDownloadControl)) {
        Fail "DownloadManager missing offline storage control: $requiredDownloadControl"
    }
}
$downloadPolicy = Get-Content -Raw -LiteralPath "Sources/EkitapligimCore/DownloadFilePolicy.swift"
if ($downloadPolicy -notmatch "invalidBookIdentifier" -or $downloadPolicy -notmatch "%PDF-" -or $downloadPolicy -notmatch "0x50, 0x4B") {
    Fail "Download file policy must reject unsafe identifiers and validate PDF/EPUB signatures"
}
$project = Get-Content -Raw -LiteralPath "project.yml"
if ($project -notmatch "EkitapligimTests" -or $project -notmatch "App/EkitapligimTests") {
    Fail "project.yml must include the iOS app unit-test target"
}

Write-Host "Swift static audit completed."
