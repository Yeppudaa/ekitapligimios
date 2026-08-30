param(
    [string]$ManifestPath = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $ManifestPath) {
    $ManifestPath = Join-Path $root "release-archive\visual-parity\manifest.json"
}

$requiredScreens = @(
    @{ Id = "book-detail-shelf"; Label = "Book detail shelf actions" }
    @{ Id = "forum-thread-list"; Label = "Forum thread list" }
    @{ Id = "forum-thread-detail"; Label = "Forum thread detail" }
    @{ Id = "book-requests"; Label = "Book requests" }
    @{ Id = "chat"; Label = "Okur Sohbeti" }
    @{ Id = "book-agenda"; Label = "Kitap Gündemi" }
    @{ Id = "book-comments"; Label = "Book comments" }
    @{ Id = "library-shelves"; Label = "Library shelves" }
    @{ Id = "book-detail-read"; Label = "Book detail read/download" }
    @{ Id = "catalog-grid"; Label = "Catalog grid" }
)

function Write-Step($Message) { Write-Host "==> $Message" }

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Step "Visual parity manifest missing at $ManifestPath"
    Write-Host "Create from release-archive/visual-parity/manifest.example.json after Mac side-by-side capture."
    exit 2
}

$manifestDir = Split-Path -Parent (Resolve-Path -LiteralPath $ManifestPath)
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$entries = @($manifest.screens)
if ($entries.Count -eq 0) {
    Write-Host "FAIL manifest has no screens array"
    exit 1
}

$entryById = @{}
foreach ($entry in $entries) {
    if ($entry.id) {
        $entryById[[string]$entry.id] = $entry
    }
}

$missing = @()
foreach ($required in $requiredScreens) {
    $id = [string]$required.Id
    if (-not $entryById.ContainsKey($id)) {
        $missing += "$id (missing entry)"
        continue
    }
    $entry = $entryById[$id]
    if ($entry.pass -ne $true) {
        $missing += "$id (pass is not true)"
        continue
    }
    foreach ($side in @("ios", "android")) {
        $relative = [string]$entry.$side
        if ([string]::IsNullOrWhiteSpace($relative)) {
            $missing += "$id ($side path missing)"
            continue
        }
        $fullPath = Join-Path $manifestDir $relative
        if (-not (Test-Path -LiteralPath $fullPath)) {
            $missing += "$id ($side file not found: $relative)"
        }
    }
}

if ($missing.Count -gt 0) {
    Write-Step "Visual parity evidence incomplete"
    foreach ($item in $missing) {
        Write-Host "  - $item"
    }
    exit 1
}

Write-Step "Visual parity evidence verified ($($requiredScreens.Count)/$($requiredScreens.Count) scoped screens)"
Write-Host "Manifest: $ManifestPath"
exit 0
