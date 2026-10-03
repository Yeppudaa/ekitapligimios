[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = Join-Path $repositoryRoot '.codex-temp\notification-state-harness'
foreach ($part in @('Combine', 'UIKit', 'UserNotifications', 'App', 'Tests')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $harnessRoot $part) | Out-Null
}
$package = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "NotificationStateHarness", dependencies: [.package(name: "EkitapligimIOS", path: "../..")], targets: [
    .target(name: "Combine", path: "Combine"),
    .target(name: "UIKit", path: "UIKit"),
    .target(name: "UserNotifications", path: "UserNotifications"),
    .target(name: "Ekitapligim", dependencies: ["Combine", "UIKit", "UserNotifications", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "App"),
    .testTarget(name: "NotificationStateTests", dependencies: ["Ekitapligim", .product(name: "EkitapligimCore", package: "EkitapligimIOS")], path: "Tests")
])
'@
$combine = @'
public protocol ObservableObject: AnyObject {}
@propertyWrapper public struct Published<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
'@
$uiKit = @'
@MainActor public final class UIApplication {
    public static let shared = UIApplication()
    public func registerForRemoteNotifications() {}
}
'@
$notifications = @'
public struct UNAuthorizationOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let alert = Self(rawValue: 1)
    public static let badge = Self(rawValue: 2)
    public static let sound = Self(rawValue: 4)
}
public final class UNUserNotificationCenter: Sendable {
    public static func current() -> UNUserNotificationCenter { UNUserNotificationCenter() }
    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
}
'@
# These test-only modules permit the actual manager's injected transport tests on
# Windows. They do not test Apple Combine, permission UI or APNs delivery.
[IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $package)
[IO.File]::WriteAllText((Join-Path $harnessRoot 'Combine\Combine.swift'), $combine)
[IO.File]::WriteAllText((Join-Path $harnessRoot 'UIKit\UIKit.swift'), $uiKit)
[IO.File]::WriteAllText((Join-Path $harnessRoot 'UserNotifications\UserNotifications.swift'), $notifications)
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\Ekitapligim\Notifications\PushNotificationManager.swift') -Destination (Join-Path $harnessRoot 'App\PushNotificationManager.swift')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'App\EkitapligimTests\PushNotificationManagerTests.swift') -Destination (Join-Path $harnessRoot 'Tests\PushNotificationManagerTests.swift')
& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Notification state harness failed.' }
Write-Output 'Notification transport/state tests passed. Native Apple frameworks and APNs device delivery remain pending macOS.'
