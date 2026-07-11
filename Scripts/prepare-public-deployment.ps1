[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Z0-9]{10}$')]
    [string]$TeamId,

    [ValidatePattern('^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$')]
    [string]$BundleId = "com.ekitapligim.app",

    [string]$AddonZip = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$aasaTemplate = Join-Path $root "Web/.well-known/apple-app-site-association"

if (-not $AddonZip) {
    $latestZip = Get-ChildItem (Join-Path $root "Backend/packages/Ekitapligim-MobileApi-iOS-*.zip") -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $latestZip) {
        throw "No MobileApi release ZIP was found under Backend/packages."
    }
    $AddonZip = $latestZip.FullName
}

$resolvedZip = Resolve-Path $AddonZip
if (-not (Test-Path -LiteralPath $aasaTemplate)) {
    throw "AASA template was not found: $aasaTemplate"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZip)
try {
    $addonEntry = $archive.Entries | Where-Object {
        $_.FullName -eq "upload/src/addons/Ekitapligim/MobileApi/addon.json"
    } | Select-Object -First 1
    if (-not $addonEntry) {
        throw "MobileApi ZIP does not contain the expected XenForo addon.json path."
    }
} finally {
    $archive.Dispose()
}

$templateText = Get-Content -Raw -LiteralPath $aasaTemplate
if ($templateText -notmatch "TEAMID") {
    throw "AASA template has no TEAMID placeholder."
}
$aasaText = $templateText.Replace("TEAMID", $TeamId)
$aasa = $aasaText | ConvertFrom-Json
$expectedAppId = "$TeamId.$BundleId"
$appIds = @($aasa.applinks.details | ForEach-Object { @($_.appID) + @($_.appIDs) })
if ($appIds -notcontains $expectedAppId) {
    throw "Generated AASA does not contain '$expectedAppId'."
}
if ($aasaText -match "TEAMID|CREATE_|STORE_IN_|PUBLIC_HTTPS") {
    throw "Generated AASA still contains a release placeholder."
}

if (-not $OutputDirectory) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDirectory = Join-Path $root "Backend/deployment/$stamp"
}
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
$workspaceRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
if (-not $resolvedOutput.StartsWith($workspaceRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must remain inside the workspace."
}
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "OutputDirectory already exists: $resolvedOutput"
}

New-Item -ItemType Directory -Path $resolvedOutput | Out-Null
$wellKnown = Join-Path $resolvedOutput ".well-known"
New-Item -ItemType Directory -Path $wellKnown | Out-Null
$zipDestination = Join-Path $resolvedOutput (Split-Path $resolvedZip -Leaf)
Copy-Item -LiteralPath $resolvedZip -Destination $zipDestination
Set-Content -LiteralPath (Join-Path $wellKnown "apple-app-site-association") -Value $aasaText -Encoding utf8NoBOM

$hash = (Get-FileHash -LiteralPath $zipDestination -Algorithm SHA256).Hash
$manifest = [ordered]@{
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    team_id = $TeamId
    bundle_id = $BundleId
    addon_zip = Split-Path $zipDestination -Leaf
    addon_sha256 = $hash
    aasa_public_url = "https://ekitapligim.com/.well-known/apple-app-site-association"
    api_health_url = "https://ekitapligim.com/mobile-api/v1/books?page=1"
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $resolvedOutput "deployment-manifest.json") -Encoding utf8NoBOM

$instructions = @"
# Ekitapligim Public Deployment

1. Verify the addon ZIP SHA-256 against `deployment-manifest.json`.
2. Install or upgrade the ZIP through the XenForo add-on release process.
3. Publish `.well-known/apple-app-site-association` at the site root without redirects or authentication and with `Content-Type: application/json`.
4. Configure the production Apple secrets described in `Backend/MobileApi-addon/README.md` outside source control.
5. Run `Scripts/public-release-audit.ps1 -TeamId "$TeamId" -BundleId "$BundleId"`.
6. Run authenticated API, session rotation, UGC safety, StoreKit sandbox, and account-deletion reviewer tests.
"@
Set-Content -LiteralPath (Join-Path $resolvedOutput "DEPLOY.md") -Value $instructions -Encoding utf8NoBOM

Write-Host "Public deployment package created: $resolvedOutput"
Write-Host "MobileApi SHA-256: $hash"
