[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\agenda-state-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'Combine'), (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

# Compile the actual business model and XCTest cases. The storage wrapper below
# deliberately does not implement or validate Apple Combine publishing.
$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "AgendaStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Combine", path: "Combine"),
    .target(name: "Ekitapligim", dependencies: ["Combine", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "AgendaStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
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
foreach ($model in @('BookAgendaFeedModel', 'BookAgendaDetailModel')) {
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "App\Ekitapligim\Features\$model.swift") -Destination (Join-Path $harnessRoot "App\$model.swift")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "App\EkitapligimTests\${model}Tests.swift") -Destination (Join-Path $harnessRoot "Tests\${model}Tests.swift")
}
& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Agenda state harness failed.' }
Write-Output 'Agenda business-state tests passed. Apple Combine/SwiftUI and native device tests remain pending macOS.'