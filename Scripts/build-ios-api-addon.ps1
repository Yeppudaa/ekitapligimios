param(
    [switch]$CreateZip,

    [switch]$SkipRouteRegeneration,

    [switch]$RegenerateRoutes,

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

if ($SkipRouteRegeneration -and $RegenerateRoutes) {
    throw "Use either -SkipRouteRegeneration or -RegenerateRoutes, not both."
}

if (-not $RegenerateRoutes) {
    Write-Step "Using the reviewed IosApi routes.xml"
} else {
    Write-Step "Regenerating ios-api routes from the installed read-only MobileApi reference"
    $mobileApiRoutes = "C:\xampp\htdocs\ekitapligim\src\addons\Ekitapligim\MobileApi\_data\routes.xml"
    if (-not (Test-Path -LiteralPath $mobileApiRoutes)) {
        Write-Warning "MobileApi reference routes not found at $mobileApiRoutes; using existing IosApi routes.xml"
    } else {
        & (Join-Path $PSScriptRoot "generate-ios-api-routes.ps1") -MobileApiRoutesPath $mobileApiRoutes
    }
}

Write-Step "Running API route contract audit"
& (Join-Path $PSScriptRoot "api-route-contract-audit.ps1") -SkipInstalled

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

Write-Step "Auditing IosApi Pub wrappers for public routes"
foreach ($route in @($routes.routes.route | Where-Object { $_.controller -like "*IosApi:*" })) {
    $controllerName = ([string]$route.controller -split ":")[-1]
    $pubPath = Join-Path $addonRoot "Pub\Controller\$controllerName.php"
    if (-not (Test-Path -LiteralPath $pubPath)) {
        throw "Missing Pub wrapper for $($route.controller): $pubPath"
    }
    $pubSource = Get-Content -Raw -LiteralPath $pubPath
    if ($pubSource.IndexOf("use PublicEndpointTrait", [System.StringComparison]::Ordinal) -lt 0) {
        throw "Pub wrapper does not apply bearer/JSON dispatch trait: $pubPath"
    }
}

Write-Step "Running PHP syntax checks"
$phpCommand = Get-Command php -ErrorAction SilentlyContinue
$phpPath = if ($phpCommand) { $phpCommand.Source } elseif (Test-Path -LiteralPath "C:\xampp\php\php.exe") { "C:\xampp\php\php.exe" } else { $null }
if ($phpPath) {
    Get-ChildItem -LiteralPath $addonRoot -Filter "*.php" -Recurse | ForEach-Object {
        & $phpPath -l $_.FullName | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "PHP syntax check failed: $($_.FullName)"
        }
    }
    Write-Host "PHP syntax checks passed."
    & $phpPath (Join-Path $repoRoot "Tests\Backend\ApnsPushPolicyTest.php")
    if ($LASTEXITCODE -ne 0) {
        throw "APNs token removal policy tests failed."
    }
    & $phpPath (Join-Path $repoRoot "Tests\Backend\PushIntegrationContractTest.php")
    if ($LASTEXITCODE -ne 0) {
        throw "Push integration contract tests failed."
    }
} else {
    Write-Warning "PHP not installed; skipped syntax checks."
}

Write-Step "Auditing Guideline 1.2 package controls"
$requiredFiles = @(
    "Service\UgcPolicy.php",
    "Service\UgcModeration.php",
    "Job\UgcModerationMail.php",
    "Cron\UgcSla.php",
    "Api\Controller\LegalTerms.php",
    "Api\Controller\SafetyReports.php",
    "Api\Controller\MeDeviceToken.php",
    "Listener\AlertCreated.php",
    "Job\SendAlertPush.php",
    "Job\SendConversationPush.php",
    "Service\ApnsPush.php",
    "Service\NotificationCounts.php",
    "XF\Service\Conversation\Notifier.php",
    "Cli\Command\PushTest.php",
    "_data\code_event_listeners.xml",
    "_data\options.xml",
    "_data\cron.xml"
)
foreach ($relative in $requiredFiles) { Assert-Path (Join-Path $addonRoot $relative) }
$addonManifest = Get-Content -Raw -LiteralPath (Join-Path $addonRoot "addon.json") | ConvertFrom-Json
if ([int]$addonManifest.version_id -ne 1000023 -or $addonManifest.version_string -ne "1.0.23") {
    throw "IosApi package must be exactly 1.0.23 / 1000023 for this release."
}
$routeText = Get-Content -Raw -LiteralPath (Join-Path $addonRoot "_data\routes.xml")
foreach ($requiredRoute in @(
        'format="v1/legal/terms"',
        'format="v1/safety/reports"',
        'format="v1/posts/:int&lt;post_id&gt;/"',
        'format="v1/posts/:int&lt;post_id&gt;/edit"',
        'format="v1/posts/:int&lt;post_id&gt;/delete"',
        'controller="Ekitapligim\IosApi:AuthLogin"',
        'controller="Ekitapligim\IosApi:AuthRegister"',
        'controller="Ekitapligim\IosApi:ForumPost"',
        'controller="Ekitapligim\IosApi:MeNotifications"',
        'controller="Ekitapligim\IosApi:MeNotificationCounts"',
        'controller="Ekitapligim\IosApi:MeNotificationMark"',
        'format="v1/me/device-token"',
        'format="v1/me/conversations/:int&lt;conversation_id&gt;/read"'
    )) {
    if ($routeText.IndexOf($requiredRoute, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Guideline 1.2 route audit failed: $requiredRoute"
    }
}

$listenerText = Get-Content -Raw -LiteralPath (Join-Path $addonRoot "_data\code_event_listeners.xml")
foreach ($requiredListenerControl in @(
        'event_id="entity_post_save"',
        'hint="XF\Entity\UserAlert"',
        'callback_class="Ekitapligim\IosApi\Listener\AlertCreated"'
    )) {
    if ($listenerText.IndexOf($requiredListenerControl, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Push listener audit failed: $requiredListenerControl"
    }
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
