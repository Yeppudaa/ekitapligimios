[CmdletBinding()]
param(
    [string]$BaselineRef = 'd1dd1395f84250452e813d3cb07db30a9b6be6f6',
    [string]$ClientRef = '',
    [string]$AddonZip = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ClientRef) { $ClientRef = $BaselineRef }
if (-not $AddonZip) {
    $AddonZip = Join-Path $repositoryRoot 'artifacts\purchase-fix-20261012\server-package\Ekitapligim-IosApi.zip'
}
$zipPath = (Resolve-Path -LiteralPath $AddonZip).Path
$harnessRoot = Join-Path $repositoryRoot ('.codex-temp\legacy-client-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $harnessRoot | Out-Null

# Read-only compatibility check against the 1.0.8 app / IosApi 1.0.32 source.
# It never connects to a live server, database, StoreKit or a real account.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $changed = @()
    foreach ($entry in $archive.Entries) {
        $relative = $entry.FullName.Replace('upload/src/addons/Ekitapligim/IosApi/', 'Backend/IosApi-addon/')
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $packaged = $reader.ReadToEnd().Replace("`r`n", "`n").TrimEnd("`n") }
        finally { $reader.Dispose() }
        $baseline = & git -C $repositoryRoot show ($BaselineRef + ':' + $relative) 2>$null
        if ($LASTEXITCODE -ne 0 -or $packaged -cne ($baseline -join "`n").TrimEnd("`n")) {
            $changed += $relative
        }
    }
    $expectedChanges = @('Backend/IosApi-addon/addon.json', 'Backend/IosApi-addon/README.md',
        'Backend/IosApi-addon/Service/ChatSerializer.php', 'Backend/IosApi-addon/Service/MobileSession.php')
    $manifestReader = [IO.StreamReader]::new($archive.GetEntry('upload/src/addons/Ekitapligim/IosApi/addon.json').Open())
    try { $manifest = $manifestReader.ReadToEnd() | ConvertFrom-Json }
    finally { $manifestReader.Dispose() }
    $services = @('ChatSerializer', 'MobileSession')
    if ($manifest.version_string -in @('1.0.34', '1.0.35') -and [int]$manifest.version_id -in @(1000034, 1000035)) {
        $expectedChanges += 'Backend/IosApi-addon/Service/ApnsPush.php'
        $services += 'ApnsPush'
    } elseif ($manifest.version_string -ne '1.0.33' -or [int]$manifest.version_id -ne 1000033) {
        throw 'This compatibility gate covers only reviewed IosApi 1.0.33 through 1.0.35.'
    }
    if ($manifest.version_string -eq '1.0.35') {
        $expectedChanges += @('Backend/IosApi-addon/Service/AppStoreTermSchedule.php',
            'Backend/IosApi-addon/Service/AppStoreTransactionStore.php',
            'Backend/IosApi-addon/Service/AppStoreEntitlementPolicy.php',
            'Backend/IosApi-addon/Api/Controller/AppStoreVerify.php',
            'Backend/IosApi-addon/Api/Controller/MeDeviceToken.php')
        $services += @('AppStoreTermSchedule', 'AppStoreTransactionStore', 'AppStoreEntitlementPolicy')
    }
    if (@(Compare-Object ($changed | Sort-Object) ($expectedChanges | Sort-Object)).Count) {
        throw 'Unexpected package differences from 1.0.32. Review compatibility before installation.'
    }
    Write-Output "PASS: $($archive.Entries.Count - $changed.Count) package files unchanged for $($manifest.version_string); reviewed changes: $($expectedChanges -join ', ')."
    foreach ($service in $services) {
        $entry = $archive.GetEntry("upload/src/addons/Ekitapligim/IosApi/Service/$service.php")
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $packaged = $reader.ReadToEnd().Replace("`r`n", "`n") }
        finally { $reader.Dispose() }
        $current = [IO.File]::ReadAllText((Join-Path $repositoryRoot "Backend\IosApi-addon\Service\$service.php")).Replace("`r`n", "`n")
        if ($packaged -cne $current) { throw "$service test source does not match the package." }
    }
    foreach ($relative in $expectedChanges) {
        $entry = $archive.GetEntry($relative.Replace('Backend/IosApi-addon/', 'upload/src/addons/Ekitapligim/IosApi/'))
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $packaged = $reader.ReadToEnd().Replace("`r`n", "`n") }
        finally { $reader.Dispose() }
        $current = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relative)).Replace("`r`n", "`n")
        if ($packaged -cne $current) { throw "$relative test source does not match the package." }
    }
} finally { $archive.Dispose() }

$sourceArchive = Join-Path $harnessRoot 'baseline.zip'
& git -C $repositoryRoot archive --format=zip ('--output=' + $sourceArchive) $ClientRef Sources/EkitapligimCore
if ($LASTEXITCODE -ne 0) { throw 'Cannot export the previous app core.' }
[IO.Compression.ZipFile]::ExtractToDirectory($sourceArchive, $harnessRoot)
$legacySession = (& git -C $repositoryRoot show ($BaselineRef + ':Backend/IosApi-addon/Service/MobileSession.php')) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot read previous session service.' }
$legacySession = $legacySession.Replace('namespace Ekitapligim\IosApi\Service;', 'namespace Ekitapligim\LegacyCompatibility\Service;')
[IO.File]::WriteAllText((Join-Path $harnessRoot 'LegacyMobileSession.php'), $legacySession)
$legacySerializer = (& git -C $repositoryRoot show ($BaselineRef + ':Backend/IosApi-addon/Service/ChatSerializer.php')) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Cannot read previous chat serializer.' }
$legacySerializer = $legacySerializer.Replace('class ChatSerializer', 'class LegacyChatSerializer')
[IO.File]::WriteAllText((Join-Path $harnessRoot 'LegacyChatSerializer.php'), $legacySerializer)

$fixtureScript = @'
<?php
$repo = $argv[1];
$fixtureRoot = $argv[2];
require $repo.'/Tests/Backend/MobileSessionRetryTest.php';
require $fixtureRoot.'/LegacyMobileSession.php';
$user = resetSessionTest();
$oldTokens = \Ekitapligim\LegacyCompatibility\Service\MobileSession::issue($user);
$rowsBeforeUpgrade = XF::$db->rows;
check(\Ekitapligim\IosApi\Service\MobileSession::userIdForAccessToken($oldTokens['access_token']) === 7,
    'Existing access token was rejected by the upgraded service');
check(XF::$db->rows === $rowsBeforeUpgrade, 'Reading an existing session mutated it');
XF::$time += 3600;
$newSession = \Ekitapligim\IosApi\Service\MobileSession::rotate($oldTokens['refresh_token']);
check($newSession !== null && $newSession['user']->user_id === 7, 'Previous-version refresh token cannot rotate');
check(\Ekitapligim\IosApi\Service\MobileSession::userIdForAccessToken($newSession['tokens']['access_token']) === 7,
    'Old client cannot use its renewed session');
echo "PASS: sessions issued by 1.0.32 survive service upgrade and renew after access expiry.\n";
'@
$chatFixtureScript = @'
<?php
$repo = $argv[1];
$fixtureRoot = $argv[2];
require $repo.'/Tests/Backend/ChatSerializerTest.php';
require $fixtureRoot.'/LegacyChatSerializer.php';
XF::$app->blocked = [];
XF::$app->messages[81]->visible = true;
XF::$app->messages[81]->message_room_id = 4;
$premiumUser->premium = true;
$premiumMessage->User = $premiumUser;
$serializer = new \Ekitapligim\IosApi\Service\ChatSerializer();
$messages = [];
foreach (['Hello', '', 'Türkçe: çığ öşü 👑', quote(81)."\nReply", quote(81),
    '[QUOTE="Historical"]Old quote[/QUOTE] Reply', 'Before '.quote(99, 8, 'HIDDEN').' After',
    quote(81, 9, 'Visible '.quote(99, 8, 'HIDDEN')).' Reply'] as $text)
{
    $messages[] = new \Siropu\Chat\Entity\Message(82, $text);
}
$messages[] = clone $premiumMessage; $messages[] = clone $announcement;
foreach (['is_admin', 'is_moderator', 'is_staff'] as $flag)
{
    $staffMessage = clone $premiumMessage; $staffMessage->User = clone $premiumUser;
    $staffMessage->User->$flag = true; $messages[] = $staffMessage;
}
foreach (['bot', 'announcement'] as $type)
{
    $synthetic = clone $premiumMessage; $synthetic->message_type = $type; $messages[] = $synthetic;
}
$legacy = new \Ekitapligim\IosApi\Service\LegacyChatSerializer();
foreach ($messages as $index => $message)
{
    $before = $legacy->message($message);
    $after = (new \Ekitapligim\IosApi\Service\ChatSerializer())->message($message);
    $legacyFields = array_diff_key($after, array_flip(['is_premium', 'role_type', 'announcement_member']));
    check($before === $legacyFields, 'An existing field/type/value changed in chat case '.$index);
}
echo 'PASS: all existing chat response fields/types/values match 1.0.32 in '.count($messages)." message scenarios.\n";
$payloads = [
    'plain' => serializeMessage('Hello'),
    'premium' => $serializer->message($premiumMessage),
    'quote' => serializeMessage(quote(81)."\nReply"),
    'announcement' => $serializer->message($announcement)
];
file_put_contents($fixtureRoot.'/Tests/payloads.json', json_encode($payloads, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE));
'@
New-Item -ItemType Directory -Path (Join-Path $harnessRoot 'Tests') | Out-Null
[IO.File]::WriteAllText((Join-Path $harnessRoot 'ExportFixtures.php'), $fixtureScript)
& php (Join-Path $harnessRoot 'ExportFixtures.php') $repositoryRoot $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Legacy session compatibility checks failed.' }
[IO.File]::WriteAllText((Join-Path $harnessRoot 'ExportChatFixtures.php'), $chatFixtureScript)
& php (Join-Path $harnessRoot 'ExportChatFixtures.php') $repositoryRoot $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Legacy chat fixture checks failed.' }

$package = @'
// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "LegacyClientCompatibility", defaultLocalization: "tr", targets: [
    .target(name: "EkitapligimCore", path: "Sources/EkitapligimCore", resources: [.process("Resources")]),
    .testTarget(name: "LegacyClientTests", dependencies: ["EkitapligimCore"], path: "Tests", resources: [.copy("payloads.json"), .copy("billing.json")])
])
'@
$tests = @'
import Foundation
import XCTest
@testable import EkitapligimCore

final class LegacyClientCompatibilityTests: XCTestCase {
    private func billing() throws -> [String: Data] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "billing", withExtension: "json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try object.mapValues { try JSONSerialization.data(withJSONObject: $0) }
    }
    func testOldClientDecodesCarriedFixedTermAndLifetimeVerification() throws {
        let data = try billing()
        let term = try JSONDecoder.ekitapligim.decode(BillingResponseDTO.self, from: XCTUnwrap(data["term1"]))
        XCTAssertTrue(term.success && term.isPremium)
        XCTAssertEqual(term.expirationTime, 1_909_137_600) // 2030-07-01 12:00 UTC
        let life = try JSONDecoder.ekitapligim.decode(BillingResponseDTO.self, from: XCTUnwrap(data["lifetime"]))
        XCTAssertTrue(life.success && life.isPremium)
        XCTAssertNil(life.expirationTime)
    }
    func testOldClientPreparationIgnoresAdditiveAdviceAndRetainsUUID() throws {
        let data = try billing()
        let rawBefore = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data["prepare"])) as? [String: Any])
        let rawAfter = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data["prepare_lifetime"])) as? [String: Any])
        XCTAssertEqual(rawBefore["app_account_token"] as? String, rawAfter["app_account_token"] as? String)
        #if LEGACY_PURCHASE_PREPARATION
        let before = try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: XCTUnwrap(data["prepare"]))
        let after = try JSONDecoder.ekitapligim.decode(PurchaseAccountDTO.self, from: XCTUnwrap(data["prepare_lifetime"]))
        XCTAssertTrue(before.success && after.success)
        XCTAssertEqual(before.appAccountToken, after.appAccountToken)
        #endif
    }
    private func payloads() throws -> [String: Data] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "payloads", withExtension: "json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try object.mapValues { try JSONSerialization.data(withJSONObject: $0) }
    }
    private func message(_ key: String) throws -> ChatMessageDTO {
        try JSONDecoder.ekitapligim.decode(ChatMessageDTO.self, from: XCTUnwrap(payloads()[key]))
    }
    func testPreviousAppReadsPlainAndPremiumMessagesFromNewServer() throws {
        XCTAssertEqual(try message("plain").message, "Hello")
        let premium = try message("premium")
        XCTAssertEqual(premium.username, "Ada")
        XCTAssertEqual(premium.userId, "9")
        XCTAssertEqual(premium.message, "Selam")
    }
    func testPreviousAppPreservesQuoteAndReplyWithoutDuplicateBody() throws {
        let reply = try message("quote")
        #if LEGACY_STRUCTURED_CHAT_QUOTES
        XCTAssertEqual(reply.message, "Reply")
        XCTAssertEqual(reply.quotedMessage?.message, "Original")
        #else
        // Older apps display the full `message` and ignore `message_body`.
        XCTAssertEqual(reply.message, "Original\nReply")
        #endif
    }
    func testPreviousAppPreservesFullAnnouncementWhenNewProfileFieldIsIgnored() throws {
        let announcement = try message("announcement")
        XCTAssertTrue(announcement.isAnnouncement)
        XCTAssertEqual(announcement.message, "Ada 👑 Premium üyeliğe yükseldi.")
        XCTAssertEqual(announcement.username, "Ada")
    }
    func testPreviousAppDecodesNewMessagePageWithAdditionalFields() throws {
        let items = try payloads().values.map { try JSONSerialization.jsonObject(with: $0) }
        let data = try JSONSerialization.data(withJSONObject: ["items": items])
        let page = try JSONDecoder.ekitapligim.decode(ChatMessagesPageDTO.self, from: data)
        XCTAssertEqual(page.messages.count, 4)
        XCTAssertTrue(page.messages.contains { $0.isAnnouncement })
    }
}
'@
$legacyCommunity = [IO.File]::ReadAllText((Join-Path $harnessRoot 'Sources\EkitapligimCore\CommunityModels.swift'))
if ($legacyCommunity.Contains('public let quotedMessage')) {
    $package = $package.Replace('resources: [.copy("payloads.json"), .copy("billing.json")])',
        'resources: [.copy("payloads.json"), .copy("billing.json")], swiftSettings: [.define("LEGACY_STRUCTURED_CHAT_QUOTES")])')
}
$legacyRepositories = [IO.File]::ReadAllText((Join-Path $harnessRoot 'Sources/EkitapligimCore/Repositories.swift'))
if ($legacyRepositories.Contains('struct PurchaseAccountDTO')) {
    if ($package.Contains('swiftSettings:')) {
        $package = $package.Replace('.define("LEGACY_STRUCTURED_CHAT_QUOTES")', '.define("LEGACY_STRUCTURED_CHAT_QUOTES"), .define("LEGACY_PURCHASE_PREPARATION")')
    } else {
        $package = $package.Replace('resources: [.copy("payloads.json"), .copy("billing.json")])',
            'resources: [.copy("payloads.json"), .copy("billing.json")], swiftSettings: [.define("LEGACY_PURCHASE_PREPARATION")])')
    }
}
& php (Join-Path $repositoryRoot 'Tests/Backend/AppStoreLegacyContractTest.php') (Join-Path $harnessRoot 'Tests/billing.json')
if ($LASTEXITCODE -ne 0) { throw 'Legacy billing contract export failed.' }
[IO.File]::WriteAllText((Join-Path $harnessRoot 'Package.swift'), $package)
[IO.File]::WriteAllText((Join-Path $harnessRoot 'Tests\LegacyClientCompatibilityTests.swift'), $tests)
& (Join-Path $PSScriptRoot 'swift-test-windows.ps1') -PackagePath $harnessRoot
if ($LASTEXITCODE -ne 0) { throw 'Previous app decoding compatibility tests failed.' }
Write-Output "Legacy source compatibility passed for client ref $ClientRef. Installed old iOS binary and live server staging validation remain separate checks."
