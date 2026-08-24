param(
    [string]$BaseUrl = "https://ekitapligim.com/ios-api/v1/",
    [string]$ZipPath = "",
    [int]$ForumNodeId = 2,
    [switch]$AllowInsecure
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $ZipPath) {
    $ZipPath = Join-Path $root "release-archive/Ekitapligim-IosApi.zip"
}

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

Write-Step "Verifying IosApi deploy artifact and production forum-create route"

if (-not (Test-Path -LiteralPath $ZipPath)) {
    Write-Result "Deploy zip" "FAIL" "Missing $ZipPath - run .\Scripts\build-ios-api-addon.ps1 -CreateZip"
    exit 1
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $addonJsonEntry = $zip.Entries | Where-Object { $_.FullName -like "*addon.json" } | Select-Object -First 1
    if (-not $addonJsonEntry) {
        Write-Result "Deploy zip addon.json" "FAIL" "addon.json missing from zip"
        exit 1
    }
    $stream = $addonJsonEntry.Open()
    $reader = New-Object System.IO.StreamReader($stream)
    $addonJson = $reader.ReadToEnd() | ConvertFrom-Json
    $reader.Close()
    $stream.Close()
    Write-Result "Deploy zip version" "PASS" "$($addonJson.version_string) (version_id $($addonJson.version_id))"

    $forumApi = $zip.Entries | Where-Object { $_.FullName -like "*Api/Controller/ForumThreads.php" } | Select-Object -First 1
    $forumPub = $zip.Entries | Where-Object { $_.FullName -like "*Pub/Controller/ForumThreads.php" } | Select-Object -First 1
    if (-not $forumApi) {
        Write-Result "ForumThreads backend" "FAIL" "Api/Controller/ForumThreads.php missing from zip"
        exit 1
    }
    $apiStream = $forumApi.Open()
    $apiReader = New-Object System.IO.StreamReader($apiStream)
    $apiSource = $apiReader.ReadToEnd()
    $apiReader.Close()
    $apiStream.Close()
    if ($apiSource -notmatch "function actionPost") {
        Write-Result "ForumThreads backend" "FAIL" "actionPost missing in zip artifact"
        exit 1
    }
    Write-Result "ForumThreads backend" "PASS" "actionPost present in zip artifact"
    if ($forumPub) {
        Write-Result "ForumThreads Pub wrapper" "PASS" "Bearer auth wrapper present in zip"
    } else {
        Write-Result "ForumThreads Pub wrapper" "WARN" "Pub/Controller/ForumThreads.php missing - bearer auth may fail on public route"
    }

    $threadPub = $zip.Entries | Where-Object { $_.FullName -like "*Pub/Controller/ThreadPosts.php" } | Select-Object -First 1
    if ($threadPub) {
        Write-Result "ThreadPosts Pub wrapper" "PASS" "Bearer auth wrapper present in zip"
    } else {
        Write-Result "ThreadPosts Pub wrapper" "WARN" "Pub/Controller/ThreadPosts.php missing - GET/POST threads/:id/posts 404s on public route"
    }

    $routesEntry = $zip.Entries | Where-Object { $_.FullName -like "*_data/routes.xml" } | Select-Object -First 1
    if ($routesEntry) {
        $routesStream = $routesEntry.Open()
        $routesReader = New-Object System.IO.StreamReader($routesStream)
        $routesXml = $routesReader.ReadToEnd()
        $routesReader.Close()
        $routesStream.Close()
        if ($routesXml -match 'controller="Ekitapligim\\IosApi:ForumThreads"') {
            Write-Result "Forum create route" "PASS" "routes.xml maps forums/:node_id/threads to IosApi:ForumThreads"
        } else {
            Write-Result "Forum create route" "FAIL" "routes.xml missing IosApi:ForumThreads mapping"
            exit 1
        }
    }
}
finally {
    $zip.Dispose()
}

$normalized = $BaseUrl.TrimEnd("/") + "/"
$uri = [Uri]::new($normalized + "forums/$ForumNodeId/threads")
if ($uri.Scheme -ne "https" -and -not $AllowInsecure) {
    Write-Result "Production probe" "FAIL" "BaseUrl must use HTTPS unless -AllowInsecure"
    exit 1
}

$deployReady = $false
Write-Step "Probing live forum topic create route at $uri"
try {
    $probeBody = "title=deploy-verify`&message=probe"
    Invoke-WebRequest -Uri $uri -Method POST -Body $probeBody -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -TimeoutSec 15 | Out-Null
    Write-Result "Production forum POST" "PASS" "Route responds (unexpected success without auth - verify server policy)"
    $deployReady = $true
}
catch {
    $status = 0
    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }
    if ($status -in 401, 403) {
        Write-Result "Production forum POST" "PASS" "Route deployed (HTTP $status without auth is expected)"
        $deployReady = $true
    }
    elseif ($status -in 404, 405) {
        Write-Result "Production forum POST" "WARN" "HTTP $status - upload $ZipPath to XenForo and rebuild routes"
        $deployReady = $false
    }
    else {
        Write-Result "Production forum POST" "FAIL" "Unexpected HTTP $status"
        exit 1
    }
}

Write-Host ""
$postsUri = [Uri]::new($normalized + "threads/1/posts?page=1")
Write-Step "Probing live thread posts route at $postsUri"
try {
    Invoke-WebRequest -Uri $postsUri -Method GET -UseBasicParsing -TimeoutSec 15 | Out-Null
    Write-Result "Production thread posts GET" "PASS" "Route responds"
} catch {
    $status = 0
    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }
    if ($status -in 401, 403) {
        Write-Result "Production thread posts GET" "PASS" "Route deployed (HTTP $status)"
    } elseif ($status -in 404, 405) {
        Write-Result "Production thread posts GET" "WARN" "HTTP $status - upgrade IosApi zip so Pub/Controller/ThreadPosts.php is installed"
        $deployReady = $false
    } else {
        Write-Result "Production thread posts GET" "FAIL" "Unexpected HTTP $status"
        exit 1
    }
}

Write-Host "Deploy checklist (XenForo Admin):"
Write-Host "  1. Ensure Ekitapligim/MobileApi is installed and active."
Write-Host "  2. Admin -> Add-ons -> Install/upgrade Ekitapligim/IosApi from:"
Write-Host "     $ZipPath"
Write-Host "  3. Rebuild routes and caches when prompted."
Write-Host ('  4. Re-run: .\Scripts\verify-ios-api-deploy.ps1 -BaseUrl "' + $normalized + '"')
Write-Host ('  5. Re-run: .\Scripts\parity-audit.ps1 -BaseUrl "' + $normalized + '"')

if (-not $deployReady) {
    exit 2
}
