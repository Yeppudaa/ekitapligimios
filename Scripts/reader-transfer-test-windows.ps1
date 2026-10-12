[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\file-transfer-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

# Compile the actual transfer implementation and XCTest cases in a separate package.
# Injected transport tests exercise request/retry/validation and file installation,
# not native Apple URLSession, Keychain, or iOS data-protection enforcement.
$harnessPackage = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "FileTransferHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Ekitapligim", dependencies: [.product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "FileTransferTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
$protectionCompatibility = @'
import Foundation
// TEST HARNESS ONLY: Windows has no iOS file-protection classes.
// FileManager on Windows ignores the Apple protection attribute.
extension FileAttributeKey {
    static let protectionKey = FileAttributeKey(rawValue: "NSFileProtectionKey")
}
enum FileProtectionType {
    static let completeUntilFirstUserAuthentication = "NSFileProtectionCompleteUntilFirstUserAuthentication"
}
'@
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $harnessPackage)
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'App\FileProtectionCompatibility.swift'), $protectionCompatibility)
$productionSource = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot 'App\Ekitapligim\Reader\ValidatedBookFileTransfer.swift'))
$testSource = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot 'App\EkitapligimTests\ValidatedBookFileTransferTests.swift'))
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'App\ValidatedBookFileTransfer.swift'), "import FoundationNetworking`n" + $productionSource)
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Tests\ValidatedBookFileTransferTests.swift'), "import FoundationNetworking`n" + $testSource)

& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Reader transfer harness failed.' }
Write-Output 'Reader transfer business-logic tests passed. Apple URLSession, Keychain, and iOS file-protection/device checks remain pending macOS.'
