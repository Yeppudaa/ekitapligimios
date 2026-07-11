$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$endpointPath = Join-Path $root "Sources/EkitapligimCore/APIEndpoint.swift"
$contractPath = Join-Path $root "Backend/MobileApi-addon/public-route-contract.txt"

function Test-RouteMatch([string]$Endpoint, [string]$Contract) {
    $endpointSegments = @($Endpoint.Trim('/') -split '/')
    $contractSegments = @($Contract.Trim('/') -split '/')
    if ($endpointSegments.Count -ne $contractSegments.Count) { return $false }

    for ($index = 0; $index -lt $endpointSegments.Count; $index++) {
        if ($contractSegments[$index].StartsWith(':')) { continue }
        if ($endpointSegments[$index] -ne $contractSegments[$index]) { return $false }
    }
    return $true
}

$source = Get-Content -Raw -LiteralPath $endpointPath
$matches = [regex]::Matches($source, 'path:\s*"(?<path>[^"]+)"')
$endpoints = @($matches | ForEach-Object {
    $_.Groups['path'].Value -replace '\\\([^\)]+\)', ':value'
} | Where-Object { $_ -ne ':value/:value/books' } | Sort-Object -Unique)

# DirectoryKind resolves these paths at runtime instead of using a path literal.
$endpoints += @('authors', 'authors/:value/books', 'publishers', 'publishers/:value/books')
$endpoints = @($endpoints | Sort-Object -Unique)
$contracts = @(Get-Content -LiteralPath $contractPath | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$missing = @()
foreach ($endpoint in $endpoints) {
    if (-not ($contracts | Where-Object { Test-RouteMatch $endpoint $_ } | Select-Object -First 1)) {
        $missing += $endpoint
    }
}

if ($missing.Count) {
    throw "Swift API endpoint paths missing from public route contract:`n$($missing -join "`n")"
}

Write-Host "API route contract audit completed: $($endpoints.Count) Swift path templates matched."

$installedRoutesPath = "C:\xampp\htdocs\ekitapligim\src\addons\Ekitapligim\MobileApi\_data\routes.xml"
if (Test-Path -LiteralPath $installedRoutesPath) {
    [xml]$installedRoutes = Get-Content -Raw -LiteralPath $installedRoutesPath
    $installedTemplates = @($installedRoutes.routes.route | Where-Object {
        $_.route_type -eq 'public' -and ([string] $_.format).StartsWith('v1/')
    } | ForEach-Object {
        (([string] $_.format).Substring(3).Trim('/')) -replace ':[^/<]+<[^>]+>', ':value'
    } | Sort-Object -Unique)

    $missingInstalled = @()
    foreach ($contract in $contracts) {
        if (-not ($installedTemplates | Where-Object { Test-RouteMatch $_ $contract } | Select-Object -First 1)) {
            $missingInstalled += $contract
        }
    }
    if ($missingInstalled.Count) {
        throw "Public route contract missing from installed MobileApi routes:`n$($missingInstalled -join "`n")"
    }
    Write-Host "Installed MobileApi route audit completed: $($contracts.Count) contract templates matched."
}
