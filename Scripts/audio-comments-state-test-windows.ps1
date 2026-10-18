[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\audio-comments-state-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

# Compile the exact production business model after removing only Apple Combine
# observation declarations. This validates state transitions, not UI publishing.
$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "AudioCommentsStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Ekitapligim", dependencies: [.product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "AudioCommentsStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $harnessPackage)
$modelSource = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot 'App\Ekitapligim\Features\MyAudioCommentsModel.swift'))
$modelSource = $modelSource.Replace("import Combine`r`n", '').Replace("import Combine`n", '').Replace(': ObservableObject {', ' {').Replace('@Published ', '')
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'App\MyAudioCommentsModel.swift'), $modelSource)
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\EkitapligimTests\MyAudioCommentsModelTests.swift') -Destination (Join-Path $harnessRoot 'Tests\MyAudioCommentsModelTests.swift')
& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot -Jobs 2
if ($LASTEXITCODE -ne 0) { throw 'Audio comments state harness failed.' }
Write-Output 'Audio comments business-state tests passed. Apple Combine/SwiftUI and native device tests remain pending macOS.'
