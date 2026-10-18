[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\audio-page-navigation-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

function Read-SourceSection([string]$Source, [string]$Pattern, [string]$Name) {
    $match = [regex]::Match($Source, $Pattern)
    if (-not $match.Success) { throw "Cannot extract current routing source: $Name" }
    return $match.Value
}

$containerSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\App\AppContainer.swift')
$librarySource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\Features\LibraryView.swift')
$tokenSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\Security\TokenStore.swift')
$selection = Read-SourceSection $containerSource '(?ms)^    @Published var selectedTab: AppTab = \.home \{.*?^    \}' 'selectedTab observer'
$openRoute = Read-SourceSection $containerSource '(?ms)^    func open\(route: AppRoute\) \{.*?^    \}' 'open(route:)'
$tabs = Read-SourceSection $containerSource '(?ms)^enum AppTab:.*?^\}' 'AppTab'
$libraryTabs = Read-SourceSection $librarySource '(?ms)^enum LibraryTab:.*?^\}' 'LibraryTab'
$tokenProtocol = Read-SourceSection $tokenSource '(?m)^protocol TokenStore:.*\{\}' 'TokenStore protocol'

# Exercise the exact current routing method, selection observer and route/tab enums.
# Only storage and the initializer are lightweight: no Combine publication, service initialization,
# SwiftUI navigation, animation, authentication UI or native Back gesture is validated here.
$routingHost = @'
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import EkitapligimCore

@MainActor
final class AppContainer {
    var presentedRoute: AppRoute?
    var audioPageRoute: AppRoute?
    var isForumPresented = false
    var libraryShelfTab = 0
    var pendingProfileLibraryTab: LibraryTab?

    init(apiSession: URLSession? = nil, tokenStore: (any TokenStore)? = nil) {}

'@ + $selection.Replace('@Published ', '') + "`n`n" + $openRoute + "`n}`n`n" + $tabs + "`n`n" + $libraryTabs + "`n`n" + $tokenProtocol + "`n"

$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "AudioPageNavigationHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Ekitapligim", dependencies: [.product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "AudioPageRoutingTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $harnessPackage)
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'App\AppContainer.swift'), $routingHost)
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\EkitapligimTests\AudioPageRoutingTests.swift') -Destination (Join-Path $harnessRoot 'Tests\AudioPageRoutingTests.swift')

& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Audio page routing harness failed.' }
Write-Output 'Audio routing-state tests passed. Actual SwiftUI push/back, modal transitions and iOS rendering still require Xcode.'
