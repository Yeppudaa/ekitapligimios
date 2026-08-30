param(
    [string]$MobileApiRoutesPath = "C:\xampp\htdocs\ekitapligim\src\addons\Ekitapligim\MobileApi\_data\routes.xml",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot "Backend\IosApi-addon\_data\routes.xml"
}

if (-not (Test-Path -LiteralPath $MobileApiRoutesPath)) {
    throw "MobileApi routes reference not found: $MobileApiRoutesPath"
}

# Android-only public routes excluded from the iOS API surface.
$excludedFormats = @(
    "v1/billing/google-play/verify",
    "v1/me/push-devices"
)

# Controllers owned by IosApi (namespace remap from MobileApi).
$iosControllers = @{
    "MeReadingStats" = $true
    "MeMedia" = $true
    "BookAgendaFollow" = $true
    "AuthApple" = $true
    "AppStoreVerify" = $true
    "AppStoreNotifications" = $true
    "AccountDeletionRequest" = $true
    "BlockedMembers" = $true
    "MemberBlock" = $true
    "PostReport" = $true
    "Terms" = $true
    "ForumThreads" = $true
    "ThreadPosts" = $true
    "AuthLogin" = $true
    "AuthRegister" = $true
    "BookAgenda" = $true
    "BookAgendaPost" = $true
    "BookAgendaComments" = $true
    "BookAgendaComment" = $true
    "BookComments" = $true
    "ChatMessages" = $true
    "Conversations" = $true
}

[xml]$source = Get-Content -Raw -LiteralPath $MobileApiRoutesPath
$doc = New-Object System.Xml.XmlDocument
$declaration = $doc.CreateXmlDeclaration("1.0", "utf-8", $null)
[void]$doc.AppendChild($declaration)
$routesNode = $doc.CreateElement("routes")
[void]$doc.AppendChild($routesNode)

$added = 0
foreach ($route in @($source.routes.route | Where-Object { $_.route_type -eq "public" -and $_.route_prefix -eq "mobile-api" })) {
    $format = [string]$route.format
    if ($excludedFormats -contains $format) {
        continue
    }

    $imported = $doc.ImportNode($route, $true)
    $imported.SetAttribute("route_prefix", "ios-api")

    $controller = [string]$route.controller
    if ($controller -match "Ekitapligim\\MobileApi:(.+)$") {
        $shortName = $Matches[1]
        if ($iosControllers.ContainsKey($shortName)) {
            $imported.SetAttribute("controller", "Ekitapligim\IosApi:$shortName")
        }
    }

    [void]$routesNode.AppendChild($imported)
    $added++
}

foreach ($customRoute in @(
    @{ sub_name = "legal-terms"; format = "v1/legal/terms"; controller = "Ekitapligim\IosApi:LegalTerms" },
    @{ sub_name = "safety-reports"; format = "v1/safety/reports"; controller = "Ekitapligim\IosApi:SafetyReports" }
)) {
    $node = $doc.CreateElement("route")
    $node.SetAttribute("route_type", "public")
    $node.SetAttribute("route_prefix", "ios-api")
    $node.SetAttribute("sub_name", $customRoute.sub_name)
    $node.SetAttribute("format", $customRoute.format)
    $node.SetAttribute("controller", $customRoute.controller)
    [void]$routesNode.AppendChild($node)
    $added++
}

$doc.Save($OutputPath)
Write-Host "Generated $added ios-api public routes -> $OutputPath"
