[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\chat-state-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'Combine'), (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

# Compile the actual business model and XCTest cases. The storage wrapper below
# deliberately does not implement or validate Apple Combine publishing.
$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "ChatStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Combine", path: "Combine"),
    .target(name: "Ekitapligim", dependencies: ["Combine", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "ChatStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
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
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\Features\ChatModel.swift') -Destination (Join-Path $harnessRoot 'App\ChatModel.swift')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\EkitapligimTests\ChatModelTests.swift') -Destination (Join-Path $harnessRoot 'Tests\ChatModelTests.swift')
& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Chat state harness failed.' }
Write-Output 'Chat business-state tests passed. Apple Combine/SwiftUI and native device tests remain pending macOS.'
