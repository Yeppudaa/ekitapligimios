param(
    [switch]$AllowPlaceholders
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

function Write-Step($Message) {
    Write-Host "==> $Message"
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

Write-Step "Checking App Store metadata placeholders"
$placeholderTargets = @(
    "APP_STORE_METADATA.md",
    "REVIEWER_TEST_PLAN.md",
    "UNIVERSAL_LINKS.md",
    "Web/.well-known/apple-app-site-association",
    "SECRETS_AND_ENVIRONMENT.md",
    "App/Ekitapligim/Config/Production.xcconfig",
    "project.yml"
)

$placeholderPattern = "\[[A-Z0-9_]+\]|TEAMID|\$\(APPLE_TEAM_ID\)"
$matches = rg -n --pcre2 $placeholderPattern $placeholderTargets 2>$null
if ($LASTEXITCODE -eq 0 -and $matches -and -not $AllowPlaceholders) {
    throw "App Store preflight placeholders remain:`n$matches"
}
if ($matches) {
    Write-Host "PLACEHOLDERS ALLOWED:`n$matches"
}

Write-Step "Checking reviewer notes include required flows"
$metadata = Get-Content -Raw -LiteralPath "APP_STORE_METADATA.md"
@(
    "Log in",
    "book detail",
    "download",
    "forum",
    "report",
    "blocking",
    "Hesap silme",
    "StoreKit"
) | ForEach-Object {
    if ($metadata -notmatch [Regex]::Escape($_)) {
        throw "APP_STORE_METADATA.md missing review flow text: $_"
    }
}

Write-Step "Checking public URLs are HTTPS"
$urlMatches = Select-String -Path "APP_STORE_METADATA.md" -Pattern "URL:\s+(?<url>\S+)" -AllMatches
foreach ($match in $urlMatches.Matches) {
    $url = $match.Groups["url"].Value
    if ($url -notmatch "^https://") {
        throw "Non-HTTPS App Store URL found: $url"
    }
}
$expectedMetadataURLs = @(
    "Support URL: https://ekitapligim.com/diger/iletisim",
    "Marketing URL: https://ekitapligim.com/",
    "Privacy Policy URL: https://ekitapligim.com/yardim/gizlilik-politikasi/",
    "Terms of Service URL: https://ekitapligim.com/yardim/kurallar/"
)
foreach ($expectedURL in $expectedMetadataURLs) {
    if ($metadata -notmatch [regex]::Escape($expectedURL)) {
        throw "App Store metadata missing verified live URL: $expectedURL"
    }
}
foreach ($obsoleteURL in @(
    "https://ekitapligim.com/contact",
    "https://ekitapligim.com/privacy-policy",
    "https://ekitapligim.com/terms"
)) {
    $obsoleteMatches = rg -n -F $obsoleteURL APP_STORE_METADATA.md App/Ekitapligim Sources 2>$null
    if ($LASTEXITCODE -eq 0 -and $obsoleteMatches) {
        throw "Obsolete/non-live legal URL remains:`n$obsoleteMatches"
    }
}

Write-Step "Checking metadata matches shipped features"
foreach ($requiredMetadataText in @(
    "PDF ve EPUB Kitap Okuyucu",
    "30 gün",
    "ekitapligim.premium.monthly",
    "ekitapligim.premium.yearly",
    'MobileApi `1.0.84`',
    "Other User Contact Info",
    "Coarse Location"
)) {
    if ($metadata -notmatch [regex]::Escape($requiredMetadataText)) {
        throw "APP_STORE_METADATA.md does not match shipped behavior: $requiredMetadataText"
    }
}

Write-Step "Checking production API configuration"
$productionConfig = Get-Content -Raw -LiteralPath "App/Ekitapligim/Config/Production.xcconfig"
$productionApiURL = Normalize-XcconfigURL (Get-XcconfigValue $productionConfig "EKITAPLIGIM_API_BASE_URL")
if ($productionApiURL -ne "https://ekitapligim.com/mobile-api/v1/") {
    throw "Production API URL must be https://ekitapligim.com/mobile-api/v1/: $productionApiURL"
}
try {
    $productionApiUri = [Uri]$productionApiURL
} catch {
    throw "Production API URL is not valid: $productionApiURL"
}
if ($productionApiUri.Scheme -ne "https" -or $productionApiUri.Host -ne "ekitapligim.com") {
    throw "Production API URL must use HTTPS ekitapligim.com: $productionApiURL"
}

Write-Step "Checking App Transport Security scope"
$infoPlist = Get-Content -Raw -LiteralPath "App/Ekitapligim/Support/Info.plist"
if ($infoPlist -match "<key>NSAllowsArbitraryLoads</key>\s*<true/>") {
    throw "Info.plist must not allow arbitrary App Transport Security loads"
}
if ($infoPlist -match "<key>NSAllowsArbitraryLoadsInWebContent</key>\s*<true/>") {
    throw "Info.plist must not allow arbitrary web content loads"
}

Write-Host "App Store preflight completed."
