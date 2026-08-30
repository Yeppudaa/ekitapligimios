param([string]$AddonZip = "")

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $AddonZip) { $AddonZip = Join-Path $root "release-archive/Ekitapligim-IosApi.zip" }
if (-not (Test-Path -LiteralPath $AddonZip)) {
    throw "Standalone IosApi ZIP is missing. Run Scripts/build-ios-api-addon.ps1 -CreateZip."
}

$resolvedZip = Resolve-Path $AddonZip
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZip)

function Get-EntryText([string]$Path) {
    $entry = $archive.Entries | Where-Object { $_.FullName -eq $Path } | Select-Object -First 1
    if (-not $entry) { throw "IosApi ZIP is missing required file: $Path" }
    $reader = [System.IO.StreamReader]::new($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Assert-Contains([string]$Text, [string]$Needle, [string]$Label) {
    if (-not $Text.Contains($Needle, [System.StringComparison]::Ordinal)) {
        throw "IosApi release audit failed: $Label is missing '$Needle'."
    }
}

try {
    $prefix = "upload/src/addons/Ekitapligim/IosApi/"
    $addon = Get-EntryText ($prefix + "addon.json") | ConvertFrom-Json
    if ($addon.title -ne "Ekitapligim iOS API") { throw "Unexpected add-on title: $($addon.title)" }
    if ([int]$addon.version_id -ne 1000012 -or $addon.version_string -ne "1.0.12") {
        throw "IosApi must be exactly 1.0.12 / 1000012; found $($addon.version_string) / $($addon.version_id)."
    }
    if ([int]$addon.require.'Ekitapligim/MobileApi'[0] -ne 1000136) {
        throw "IosApi must depend on the unchanged production MobileApi 1.0.136."
    }

    $routes = Get-EntryText ($prefix + "_data/routes.xml")
    foreach ($route in @(
        'format="v1/legal/terms"', 'format="v1/safety/reports"',
        'controller="Ekitapligim\IosApi:AuthLogin"', 'controller="Ekitapligim\IosApi:AuthRegister"',
        'controller="Ekitapligim\IosApi:ForumThreads"', 'controller="Ekitapligim\IosApi:BookComments"',
        'controller="Ekitapligim\IosApi:BookAgenda"', 'controller="Ekitapligim\IosApi:ChatMessages"',
        'controller="Ekitapligim\IosApi:Conversations"'
    )) { Assert-Contains $routes $route "Guideline 1.2 route table" }
    if ($routes.Contains('route_prefix="mobile-api"', [System.StringComparison]::Ordinal)) {
        throw "IosApi ZIP must not define or modify /mobile-api routes."
    }

    $policy = Get-EntryText ($prefix + "Service/UgcPolicy.php")
    Assert-Contains $policy "ekIosUgcBlockedTerms" "managed content filter"
    Assert-Contains $policy "contentChecker" "XenForo spam checker"
    $moderation = Get-EntryText ($prefix + "Service/UgcModeration.php")
    Assert-Contains $moderation "xf_ekitapligim_ios_ugc_event" "additive UGC event migration"
    Assert-Contains $moderation "XF:Report\Creator" "XenForo report queue"
    $cron = Get-EntryText ($prefix + "Cron/UgcSla.php")
    Assert-Contains $cron "72000" "20-hour reminder"
    Assert-Contains $cron "86400" "24-hour escalation"
    $options = Get-EntryText ($prefix + "_data/options.xml")
    Assert-Contains $options "ekIosUgcModeratorEmails" "moderator email option"
    Assert-Contains $options "ekIosUgcBlockedTerms" "content filter option"

    $hash = (Get-FileHash -LiteralPath $resolvedZip -Algorithm SHA256).Hash
    Write-Host "Standalone IosApi release audit completed: $(Split-Path -Leaf $resolvedZip) ($($addon.version_string))"
    Write-Host "SHA-256: $hash"
    Write-Host "Staging remains blocked until moderator emails and filter terms are configured and tested."
} finally {
    $archive.Dispose()
}
