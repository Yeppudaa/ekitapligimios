[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\live-activity-state-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'Combine'), (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

# Compile the actual feed model and XCTest cases. This storage wrapper does not
# validate Apple Combine publication, SwiftUI lifecycle, or native iOS rendering.
$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "LiveActivityStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Combine", path: "Combine"),
    .target(name: "Ekitapligim", dependencies: ["Combine", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "LiveActivityStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
$combineStub = @'
// Test-only storage wrapper; does not exercise Apple Combine publication.
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
'@
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $harnessPackage)
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Combine\Combine.swift'), $combineStub)
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\Features\LiveActivityModel.swift') -Destination (Join-Path $harnessRoot 'App\LiveActivityModel.swift')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\EkitapligimTests\LiveActivityModelTests.swift') -Destination (Join-Path $harnessRoot 'Tests\LiveActivityModelTests.swift')

& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot -Jobs 2
if ($LASTEXITCODE -ne 0) { throw 'Live activity state harness failed.' }
Write-Output 'Live activity business-state tests passed. Apple Combine/SwiftUI and native device tests remain pending macOS.'
