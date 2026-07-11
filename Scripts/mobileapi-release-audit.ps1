param(
    [string]$AddonZip = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

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
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZip)

function Get-EntryText([string]$Path) {
    $entry = $archive.Entries | Where-Object { $_.FullName -eq $Path } | Select-Object -First 1
    if (-not $entry) {
        throw "Release ZIP is missing required file: $Path"
    }
    $reader = [System.IO.StreamReader]::new($entry.Open())
    try {
        return $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
}

function Assert-Contains([string]$Text, [string]$Needle, [string]$Label) {
    if (-not $Text.Contains($Needle, [System.StringComparison]::Ordinal)) {
        throw "Release ZIP check failed: $Label is missing '$Needle'."
    }
}

try {
    $prefix = "upload/src/addons/Ekitapligim/MobileApi/"
    $addon = Get-EntryText ($prefix + "addon.json") | ConvertFrom-Json
    # XenForo 2.3 add-on manifests infer the add-on ID from the ZIP path.
    if ($addon.title -ne "Ekitapligim Mobile API") {
        throw "Release ZIP has unexpected add-on title: $($addon.title)"
    }
    if ([int]$addon.version_id -lt 1000085) {
        throw "Release ZIP MobileApi version must be at least 1.0.85; found $($addon.version_string)."
    }

    $routes = Get-EntryText ($prefix + "_data/routes.xml")
    foreach ($route in @(
        'format="v1/auth/login"',
        'format="v1/books/:int&lt;thread_id&gt;/reader/access"',
        'format="v1/books/:int&lt;thread_id&gt;/reader/session"',
        'format="v1/billing/app-store/verify"',
        'format="v1/me/account-deletion-request"'
    )) {
        Assert-Contains $routes $route "public API route table"
    }

    $mobileSession = Get-EntryText ($prefix + "Service/MobileSession.php")
    Assert-Contains $mobileSession "ms_at_" "revocable access-token service"
    Assert-Contains $mobileSession "ms_rt_" "revocable refresh-token service"
    Assert-Contains $mobileSession "revokeUserSessions" "session revocation service"

    $readerAccess = Get-EntryText ($prefix + "Api/Controller/BookReaderAccess.php")
    Assert-Contains $readerAccess "IosEntitlement::hasActiveEntitlement" "reader access entitlement check"
    Assert-Contains $readerAccess "login_required" "guest reader denial"

    $readerSession = Get-EntryText ($prefix + "Api/Controller/BookReaderSession.php")
    Assert-Contains $readerSession "purpose === 'download'" "download reader-session purpose"
    Assert-Contains $readerSession "IosEntitlement::hasActiveEntitlement" "reader-session entitlement check"
    Assert-Contains $readerSession "recordDownload" "download limit recording"
    Assert-Contains $readerSession "recordRead" "read limit recording"

    $accountDeletion = Get-EntryText ($prefix + "Api/Controller/AccountDeletionRequest.php")
    Assert-Contains $accountDeletion "revokeUserSessions" "account-deletion session revocation"

    $hash = (Get-FileHash -LiteralPath $resolvedZip -Algorithm SHA256).Hash
    Write-Host "MobileApi release audit completed: $(Split-Path -Leaf $resolvedZip) ($($addon.version_string))"
    Write-Host "SHA-256: $hash"
} finally {
    $archive.Dispose()
}
