[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\library-mutation-state-harness'
New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot 'App'), (Join-Path $harnessRoot 'Tests') | Out-Null

function Read-SourceSection([string]$Source, [string]$Pattern, [string]$Name) {
    $match = [regex]::Match($Source, $Pattern)
    if (-not $match.Success) { throw "Cannot extract current library mutation source: $Name" }
    return $match.Value
}

$containerSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\App\AppContainer.swift')
$tokenSource = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\Security\TokenStore.swift')
$auth = Read-SourceSection $containerSource '(?ms)^    @Published var authState: AuthenticationState = \.signedOut \{.*?^    \}' 'authentication observer'
$tokenProtocol = Read-SourceSection $tokenSource '(?m)^protocol TokenStore:.*\{\}' 'TokenStore protocol'
$parts = @($auth.Replace('@Published ', ''))
foreach ($name in @('sessionGeneration', 'needsSessionRestore', 'isRefreshingSession', 'libraryItems', 'libraryUpdatingBookIDs', 'libraryMutationErrors', 'libraryWriteOperations', 'libraryGeneration')) {
    $parts += (Read-SourceSection $containerSource "(?m)^    (?:@Published )?(?:private\(set\) |private )?var ${name}:?.*$" "$name storage").Replace('@Published ', '')
}
foreach ($name in @('isSignedIn', 'favoriteBooks')) {
    $parts += Read-SourceSection $containerSource "(?m)^    var ${name}:.*$" "$name projection"
}
$parts += Read-SourceSection $containerSource '(?m)^    private enum BookLibraryChange:.*$' 'library mutation kind'
foreach ($name in @('patchLibraryItem', 'upsertLibraryItem', 'updateBookShelf', 'setBookFavorite', 'markBookReading', 'changeBookLibrary')) {
    $parts += Read-SourceSection $containerSource "(?ms)^    (?:private )?func ${name}\(.*?^    \}" "$name method"
}

# Execute the exact production mutation methods, enum, account observer and state projections.
# UI publication, Keychain, downloads, StoreKit and account activation side effects are excluded.
# Their stubs only supply required collaborators; the real Core API client/repository and
# ReaderWriteQueue execute against the same isolated URLProtocol XCTest cases used on iOS.
$libraryMutationHost = @'
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import EkitapligimCore

@MainActor
final class AppContainer {
    let books: BookRepository
    let readerWrites = ReaderWriteQueue()
    let downloadManager = LibraryMutationDownloadStub()
    let notificationReadSync = LibraryMutationNotificationStub()
    let storeKit = LibraryMutationStoreKitStub()

    init(apiSession: URLSession? = nil, tokenStore: (any TokenStore)? = nil) {
        guard let configuration = try? AppConfig.production() else { preconditionFailure("Invalid fixture API configuration") }
        books = BookRepository(apiClient: APIClient(config: configuration,
            session: apiSession ?? .shared, tokenProvider: tokenStore))
    }
    private func activateReaderAccount() {}
    private func activateAssistantAccount() {}
    private func activateGiftWheelAccount() {}

'@ + ($parts -join "`n`n") + "`n}`n`n" + $tokenProtocol + @'

// Test-host collaborators only: no production behavior is inferred from these no-ops.
struct LibraryMutationDownloadStub { func localFile(for id: String) -> URL? { nil } }
struct LibraryMutationNotificationStub { func clear() {} }
struct LibraryMutationStoreKitStub { func activateAccount(_ username: String?) {} }
'@

$package = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "LibraryMutationStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Ekitapligim", dependencies: [.product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "LibraryMutationStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $package)
[System.IO.File]::WriteAllText((Join-Path $harnessRoot 'App\AppContainer.swift'), $libraryMutationHost)
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\App\LibraryActivityEvents.swift') -Destination (Join-Path $harnessRoot 'App\LibraryActivityEvents.swift')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\EkitapligimTests\BookLibraryMutationTests.swift') -Destination (Join-Path $harnessRoot 'Tests\BookLibraryMutationTests.swift')

& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Library mutation state harness failed.' }
Write-Output 'Library mutation state tests passed. Native Combine/SwiftUI, Keychain, StoreKit and iOS rendering still require Xcode.'
