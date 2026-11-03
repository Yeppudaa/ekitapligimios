[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\profile-directory-state-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'Combine'), (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null
$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "ProfileDirectoryStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Combine", path: "Combine"),
    .target(name: "Ekitapligim", dependencies: ["Combine", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "ProfileDirectoryStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
$combineStub = @'
// Test-only storage wrapper. Apple Combine publication and SwiftUI are not exercised.
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
'@
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $harnessPackage)
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Combine\Combine.swift'), $combineStub)
foreach ($name in @('DirectoryListModel', 'ProfileEditorModel')) {
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "App\Ekitapligim\Features\$name.swift") -Destination (Join-Path $harnessRoot "App\$name.swift")
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "App\EkitapligimTests\${name}Tests.swift") -Destination (Join-Path $harnessRoot "Tests\${name}Tests.swift")
}
& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot -Jobs 4
if ($LASTEXITCODE -ne 0) { throw 'Profile/directory state tests failed.' }
Write-Output 'Actual profile and directory model tests passed. Native rendering, PhotosPicker encoding and Apple Combine still require macOS/iOS.'
