param(
    [switch]$CreateZip,

    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$addonRoot = Join-Path $repoRoot "Backend\IosApi-addon"

function Write-Step($Message) {
    Write-Host "==> $Message"
}

function Assert-Path($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }
}

Assert-Path (Join-Path $addonRoot "addon.json")
Assert-Path (Join-Path $addonRoot "_data\routes.xml")
Assert-Path (Join-Path $addonRoot "public-route-contract.txt")

Write-Step "Regenerating ios-api routes from MobileApi reference"
$mobileApiRoutes = "C:\Users\Monster\Downloads\startdesign (1)\MobileApi-addon\_data\routes.xml"
if (-not (Test-Path -LiteralPath $mobileApiRoutes)) {
    Write-Warning "MobileApi reference routes not found at $mobileApiRoutes; using existing IosApi routes.xml"
} else {
    & (Join-Path $PSScriptRoot "generate-ios-api-routes.ps1") -MobileApiRoutesPath $mobileApiRoutes
}

Write-Step "Running API route contract audit"
& (Join-Path $PSScriptRoot "api-route-contract-audit.ps1")

Write-Step "Auditing IosApi routed action prefixes"
[xml]$routes = Get-Content -Raw -LiteralPath (Join-Path $addonRoot "_data\routes.xml")
$apiDir = Join-Path $addonRoot "Api\Controller"
foreach ($route in @($routes.routes.route | Where-Object { $_.controller -like "Ekitapligim\IosApi:*" -and $_.action_prefix })) {
    $controllerName = ([string]$route.controller -split ":")[-1]
    $controllerPath = Join-Path $apiDir ($controllerName + ".php")
    if (-not (Test-Path -LiteralPath $controllerPath)) {
        throw "IosApi route controller not found: $($route.controller)"
    }

    $actionWords = ([string]$route.action_prefix -replace "[^a-zA-Z0-9]", " ")
    $actionName = (Get-Culture).TextInfo.ToTitleCase($actionWords).Replace(" ", "")
    $candidateMethods = @(
        "actionPost$actionName",
        "actionDelete$actionName",
        "actionGet$actionName",
        "action$actionName"
    )
    $controllerSource = Get-Content -Raw -LiteralPath $controllerPath
    $matched = $false
    foreach ($methodName in $candidateMethods) {
        if ($controllerSource -match ("function\s+" + [regex]::Escape($methodName) + "\s*\(")) {
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        throw "Route '$($route.format)' expects one of $($candidateMethods -join ', ') in $controllerName"
    }
}

Write-Step "Running PHP syntax checks"
$php = Get-Command php -ErrorAction SilentlyContinue
if ($php) {
    Get-ChildItem -LiteralPath $addonRoot -Filter "*.php" -Recurse | ForEach-Object {
        & php -l $_.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "PHP syntax check failed: $($_.FullName)"
        }
    }
    Write-Host "PHP syntax checks passed."
} else {
    Write-Warning "PHP not installed; skipped syntax checks."
}

if ($CreateZip) {
    Write-Step "Creating XenForo upload ZIP"
    if (-not $OutputDirectory) {
        $OutputDirectory = Join-Path $repoRoot "release-archive"
    }
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

    $zipPath = Join-Path $OutputDirectory "Ekitapligim-IosApi.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $archivePrefix = "upload/src/addons/Ekitapligim/IosApi"
    $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $addonRoot -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Substring($addonRoot.Length).TrimStart("\", "/")
            $entryName = ($archivePrefix + "/" + ($relativePath -replace "\\", "/"))
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $entryName)
        }
    }
    finally {
        $archive.Dispose()
    }

    $entryCount = ([System.IO.Compression.ZipFile]::OpenRead($zipPath)).Entries.Count
    if ($entryCount -lt 10) {
        throw "Created ZIP looks invalid: only $entryCount entries."
    }

    $addonJsonEntry = "upload/src/addons/Ekitapligim/IosApi/addon.json"
    $opened = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if (-not ($opened.Entries | Where-Object { $_.FullName -eq $addonJsonEntry })) {
            throw "Created ZIP is missing $addonJsonEntry"
        }
        if (-not ($opened.Entries | Where-Object { $_.FullName -eq "upload/src/addons/Ekitapligim/IosApi/Setup.php" })) {
            throw "Created ZIP is missing Setup.php"
        }
    }
    finally {
        $opened.Dispose()
    }

    $zipSize = (Get-Item -LiteralPath $zipPath).Length
    if ($zipSize -lt 4096) {
        throw "Created ZIP is too small ($zipSize bytes)."
    }

    Write-Host "Created $zipPath ($entryCount entries, $zipSize bytes)"
}

Write-Host "IosApi addon build completed."
