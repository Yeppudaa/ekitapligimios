import XCTest
import AVFoundation
import MediaPlayer
import UIKit
import Darwin
import EkitapligimCore
@testable import Ekitapligim

/// Native AVFoundation tests: a generated, silent PCM WAV is served entirely by URLProtocol.
/// These exercise AVPlayer -> AVAssetResourceLoader -> authenticated HEAD/206 transport, not a mock player.
@MainActor
final class AudioPlaybackRuntimeTests: XCTestCase {
    nonisolated(unsafe) private var previousTraceEnvironment: String?
    override func setUpWithError() throws {
        executionTimeAllowance = 90
        previousTraceEnvironment = ProcessInfo.processInfo.environment["MODERN_PARITY_AUDIO_TRACE"]
        setenv("MODERN_PARITY_AUDIO_TRACE", "1", 1)
    }
    override func tearDownWithError() throws {
        if let previousTraceEnvironment { setenv("MODERN_PARITY_AUDIO_TRACE", previousTraceEnvironment, 1) }
        else { unsetenv("MODERN_PARITY_AUDIO_TRACE") }
    }

    /// A framework control uses identical generated PCM bytes without the repository, resource loader,
    /// controller, KVO or Now Playing. Its failure identifies a native audio environment problem separately.
    func testA00GeneratedLocalWaveParsesReachesPlayerReadinessAndAdvances() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("generated-control.wav")
        try AudioRuntimeOrigin.silentWave(seconds: 20).write(to: url, options: .atomic)
        let asset = AVURLAsset(url: url)
        var parsed = false
        var parseError: Error?
        let parseTask = Task { @MainActor in
            do {
                let duration = try await asset.load(.duration)
                let playable = try await asset.load(.isPlayable)
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                XCTAssertEqual(duration.seconds, 20, accuracy: 0.15)
                XCTAssertTrue(playable)
                XCTAssertEqual(tracks.count, 1)
                parsed = true
                NSLog("MODERN_AUDIO_CONTROL local-asset-parsed")
            } catch { parseError = error }
        }
        defer { parseTask.cancel(); asset.cancelLoading() }
        try await waitForControl("Local generated WAV parses", diagnostics: { "parsed=\(parsed)" }) {
            parsed || parseError != nil
        }
        if let parseError { throw parseError }
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.volume = 0
        defer {
            NSLog("MODERN_AUDIO_CONTROL cleanup.pause-before")
            player.pause()
            NSLog("MODERN_AUDIO_CONTROL cleanup.pause-returned")
            player.replaceCurrentItem(with: nil)
            NSLog("MODERN_AUDIO_CONTROL cleanup.item-detached")
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            NSLog("MODERN_AUDIO_CONTROL cleanup.session-deactivated")
        }
        try await waitForControl("Local generated WAV reaches AVPlayer readiness", diagnostics: {
            "itemStatus=\(item.status.rawValue),timeControl=\(player.timeControlStatus.rawValue)"
        }) { item.status != .unknown }
        if let error = item.error { throw error }
        XCTAssertEqual(item.status, .readyToPlay)
        NSLog("MODERN_AUDIO_CONTROL local-player-ready")
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        NSLog("MODERN_AUDIO_CONTROL local-session-category-set")
        try AVAudioSession.sharedInstance().setActive(true)
        NSLog("MODERN_AUDIO_CONTROL local-session-active")
        player.playImmediately(atRate: 1)
        try await waitForControl("Local generated WAV advances", diagnostics: {
            "itemStatus=\(item.status.rawValue),timeControl=\(player.timeControlStatus.rawValue),position=\(player.currentTime().seconds)"
        }) { player.currentTime().seconds > 0.25 }
        NSLog("MODERN_AUDIO_CONTROL local-player-advanced")
    }

    func testA01CloseWhileNativeMetadataIsPendingCancelsMediaAndCannotRevivePlayer() async throws {
        let fixture = try AudioRuntimeFixture(holdMetadata: true, initialPosition: 7.25)
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native resource loader has a genuinely pending HEAD", controller: fixture.controller) {
            fixture.origin.snapshot.pendingMetadataRequests > 0
        }
        XCTAssertTrue(fixture.controller.loading)
        XCTAssertTrue(fixture.controller.visible)
        XCTAssertNotNil(fixture.controller.manifest)
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertEqual(fixture.origin.snapshot.rangeRequests, 0)
        XCTAssertEqual(fixture.controller.position, 7.25)
        let pauseStarted = ProcessInfo.processInfo.systemUptime
        fixture.controller.pause()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - pauseStarted, 2)
        XCTAssertEqual(fixture.controller.position, 7.25,
                       "An unready native timeline must preserve the manifest's cached resume position")

        let closeStarted = ProcessInfo.processInfo.systemUptime
        fixture.controller.close()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - closeStarted, 2,
                          "Closing an unready native item must not wait for its timeline")
        try await waitUntil("Closing cancels the held native metadata request", controller: fixture.controller) {
            fixture.origin.snapshot.cancelledMetadataRequests > 0 && fixture.origin.snapshot.pendingMetadataRequests == 0
        }
        let manifestsAfterClose = fixture.origin.snapshot.manifestRequests
        await fixture.origin.releaseHeldMetadataResponses()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertGreaterThan(fixture.origin.snapshot.metadataDeliveryAttempts, 0)
        XCTAssertEqual(fixture.origin.snapshot.rangeRequests, 0)
        XCTAssertEqual(fixture.origin.snapshot.manifestRequests, manifestsAfterClose)
        XCTAssertEqual(fixture.origin.snapshot.unexpectedRequests, [])
        XCTAssertFalse(fixture.controller.visible)
        XCTAssertFalse(fixture.controller.loading)
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertNil(fixture.controller.manifest)
        XCTAssertNil(fixture.controller.requestedBookID)
        XCTAssertEqual(fixture.controller.position, 0)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func testA02AccountSwitchWhileNativeMetadataIsPendingCancelsOldMediaAndCannotResume() async throws {
        let fixture = try AudioRuntimeFixture(holdMetadata: true)
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native metadata is pending before an account switch", controller: fixture.controller) {
            fixture.origin.snapshot.pendingMetadataRequests > 0
        }
        XCTAssertTrue(fixture.controller.loading)
        XCTAssertTrue(fixture.controller.visible)
        XCTAssertFalse(fixture.controller.playing)
        await fixture.tokens.switchAccount()
        let switchStarted = ProcessInfo.processInfo.systemUptime
        fixture.controller.activate(account: "runtime-other")
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - switchStarted, 2,
                          "Switching accounts must close an unready native item promptly")
        try await waitUntil("Account switch cancels the old native metadata request", controller: fixture.controller) {
            fixture.origin.snapshot.cancelledMetadataRequests > 0 && fixture.origin.snapshot.pendingMetadataRequests == 0
        }
        let manifestsAfterSwitch = fixture.origin.snapshot.manifestRequests
        fixture.controller.resume()
        await fixture.origin.releaseHeldMetadataResponses()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertGreaterThan(fixture.origin.snapshot.metadataDeliveryAttempts, 0)
        XCTAssertEqual(fixture.origin.snapshot.rangeRequests, 0)
        XCTAssertEqual(fixture.origin.snapshot.manifestRequests, manifestsAfterSwitch)
        XCTAssertFalse(fixture.origin.snapshot.mediaBearers.contains("Bearer ms_at_runtime_other"))
        XCTAssertEqual(fixture.origin.snapshot.unexpectedRequests, [])
        XCTAssertEqual(fixture.controller.account, "runtime-other")
        XCTAssertFalse(fixture.controller.visible)
        XCTAssertFalse(fixture.controller.loading)
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertNil(fixture.controller.manifest)
        XCTAssertNil(fixture.controller.requestedBookID)
        XCTAssertEqual(fixture.controller.position, 0)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    private func waitForControl(_ description: String, diagnostics: () -> String,
                                file: StaticString = #filePath, line: UInt = #line,
                                predicate: () -> Bool) async throws {
        let deadline = ContinuousClock().now.advanced(by: .seconds(15))
        while !predicate() {
            try Task.checkCancellation()
            if ContinuousClock().now >= deadline {
                XCTFail("\(description): \(diagnostics())", file: file, line: line)
                throw AudioRuntimeFailure.timedOut
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    func testAssetDurationLoadsThroughAuthenticatedRangesWithoutStartingAudioOutput() async throws {
        let fixture = try AudioRuntimeFixture()
        defer { fixture.cleanUp() }
        let manifest = try await fixture.repository.manifest(bookID: AudioRuntimeOrigin.bookID, account: "runtime-reader")
        let chapter = try XCTUnwrap(manifest.chapters.first)
        let loader = AudioAssetResourceLoader(repository: fixture.repository, bookID: AudioRuntimeOrigin.bookID,
                                              chapter: chapter, account: "runtime-reader")
        let asset = try loader.asset()
        var duration: CMTime?
        var loadingError: Error?
        let task = Task { @MainActor in
            do { duration = try await asset.load(.duration) }
            catch { loadingError = error }
        }
        defer { asset.cancelLoading(); task.cancel(); loader.stop() }
        try await waitUntil("Native asset parses the local WAV before any audio output", controller: fixture.controller,
                            diagnostics: { loader.debugSnapshot }) {
            duration != nil || loadingError != nil
        }
        if let loadingError { throw loadingError }
        XCTAssertEqual(try XCTUnwrap(duration).seconds, 20, accuracy: 0.15)
        XCTAssertGreaterThan(fixture.origin.snapshot.headRequests, 0)
        XCTAssertGreaterThan(fixture.origin.snapshot.rangeRequests, 0)
        XCTAssertEqual(fixture.origin.snapshot.unexpectedRequests, [])
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertFalse(fixture.controller.visible)
    }

    func testAssetDurationWithMissingHeadMetadataUsesOneByteProbe() async throws {
        let fixture = try AudioRuntimeFixture(omitHeadMetadata: true)
        defer { fixture.cleanUp() }
        let manifest = try await fixture.repository.manifest(bookID: AudioRuntimeOrigin.bookID, account: "runtime-reader")
        let chapter = try XCTUnwrap(manifest.chapters.first)
        let loader = AudioAssetResourceLoader(repository: fixture.repository, bookID: AudioRuntimeOrigin.bookID,
                                              chapter: chapter, account: "runtime-reader")
        let asset = try loader.asset()
        var duration: CMTime?
        var loadingError: Error?
        let task = Task { @MainActor in
            do { duration = try await asset.load(.duration) }
            catch { loadingError = error }
        }
        defer { asset.cancelLoading(); task.cancel(); loader.stop() }
        try await waitUntil("Native asset parses WAV despite missing HEAD size and ranges", controller: fixture.controller,
                            diagnostics: { loader.debugSnapshot }) {
            duration != nil || loadingError != nil
        }
        if let loadingError { throw loadingError }
        XCTAssertEqual(try XCTUnwrap(duration).seconds, 20, accuracy: 0.15)
        XCTAssertGreaterThan(fixture.origin.snapshot.headRequests, 0)
        XCTAssertGreaterThan(fixture.origin.snapshot.metadataProbeRequests, 0)
        XCTAssertEqual(fixture.origin.snapshot.metadataProbeBytes, fixture.origin.snapshot.metadataProbeRequests,
                       "Every metadata probe must return exactly one authenticated byte")
        XCTAssertGreaterThan(fixture.origin.snapshot.rangeRequests, fixture.origin.snapshot.metadataProbeRequests,
                             "AVFoundation must parse actual WAV data beyond the metadata probe")
        XCTAssertEqual(fixture.origin.snapshot.unexpectedRequests, [])
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertFalse(fixture.controller.visible)
    }

    func testGeneratedWavePlaysThroughNativeRangesAndSupportsPauseResumeAndFifteenSecondSkips() async throws {
        let fixture = try AudioRuntimeFixture()
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native WAV playback advances", controller: fixture.controller) {
            fixture.controller.playing && !fixture.controller.loading && fixture.controller.position > 1.1
        }
        XCTAssertNil(fixture.controller.error)
        XCTAssertEqual(fixture.controller.duration, 20, accuracy: 0.15)
        XCTAssertEqual(fixture.controller.chapter?.id, AudioRuntimeOrigin.chapterID)
        XCTAssertGreaterThan(fixture.origin.snapshot.headRequests, 0)
        XCTAssertGreaterThan(fixture.origin.snapshot.rangeRequests, 0)
        XCTAssertEqual(fixture.origin.snapshot.unexpectedRequests, [])
        XCTAssertTrue(fixture.origin.snapshot.mediaBearers.allSatisfy { $0 == "Bearer ms_at_runtime_fixture" })

        fixture.controller.pause()
        let pausedPosition = fixture.controller.position
        XCTAssertFalse(fixture.controller.playing)
        try await Task.sleep(for: .milliseconds(350)) // An async delay leaves the main run loop available to AVFoundation.
        XCTAssertEqual(fixture.controller.position, pausedPosition, accuracy: 0.15)
        try await waitUntil("Paused progress reaches the offline server", controller: fixture.controller) {
            fixture.origin.snapshot.progressPositions.contains { $0 >= pausedPosition - 0.15 }
        }
        XCTAssertTrue(fixture.origin.snapshot.progressSequences.allSatisfy { $0 > 0 })
        let sequences = fixture.origin.snapshot.progressSequences
        XCTAssertEqual(sequences, sequences.sorted())
        XCTAssertEqual(Set(sequences).count, sequences.count)

        // Anchor this check away from EOF even if a loaded CI simulator delayed the first periodic tick.
        fixture.controller.seek(to: 1)
        fixture.controller.skip(15)
        let forwardTarget = 16.0
        XCTAssertEqual(fixture.controller.position, forwardTarget, accuracy: 0.15)
        fixture.controller.resume()
        try await waitUntil("AVPlayer resumes after seeking forward", controller: fixture.controller) {
            fixture.controller.playing && fixture.controller.position > forwardTarget + 0.25
        }
        fixture.controller.pause()
        let beforeRewind = fixture.controller.position
        fixture.controller.skip(-15)
        XCTAssertEqual(fixture.controller.position, max(0, beforeRewind - 15), accuracy: 0.15)
        fixture.controller.resume()
        let rewindTarget = max(0, beforeRewind - 15)
        try await waitUntil("AVPlayer resumes after seeking backward", controller: fixture.controller) {
            fixture.controller.playing && fixture.controller.position > rewindTarget + 0.25
        }
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func testCloseRemovesMiniPlayerStopsMediaAndClearsNowPlaying() async throws {
        let fixture = try AudioRuntimeFixture()
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native player is ready before close", controller: fixture.controller) {
            fixture.controller.playing && fixture.controller.position > 0.2
        }
        XCTAssertTrue(fixture.controller.visible)
        XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        fixture.controller.close()
        XCTAssertFalse(fixture.controller.visible)
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertFalse(fixture.controller.loading)
        XCTAssertNil(fixture.controller.manifest)
        XCTAssertNil(fixture.controller.requestedBookID)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        let mediaRequestsAfterClose = fixture.origin.snapshot.rangeRequests
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(fixture.origin.snapshot.rangeRequests, mediaRequestsAfterClose)
        XCTAssertFalse(fixture.controller.visible)
        XCTAssertEqual(fixture.controller.position, 0)
    }

    func testAccountChangeClosesTheExistingNativePlayerAndCannotResumeOldAudio() async throws {
        let fixture = try AudioRuntimeFixture()
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native player is ready before account change", controller: fixture.controller) {
            fixture.controller.playing && fixture.controller.position > 0.2
        }
        await fixture.tokens.switchAccount()
        fixture.controller.activate(account: "runtime-other")
        XCTAssertFalse(fixture.controller.visible)
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertNil(fixture.controller.manifest)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        let previousRanges = fixture.origin.snapshot.rangeRequests
        fixture.controller.resume()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertFalse(fixture.controller.visible)
        XCTAssertEqual(fixture.origin.snapshot.rangeRequests, previousRanges)
        XCTAssertFalse(fixture.origin.snapshot.mediaBearers.contains("Bearer ms_at_runtime_other"))
    }

    func testServerPremium403NeverCreatesAnAssetOrRequestsMedia() async throws {
        let fixture = try AudioRuntimeFixture(manifestStatus: 403)
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Server rejects non-Premium listening", controller: fixture.controller, allowPlaybackError: true) {
            !fixture.controller.loading && fixture.controller.accessError == .premiumRequired
        }
        XCTAssertFalse(fixture.controller.playing)
        XCTAssertNil(fixture.controller.manifest)
        XCTAssertEqual(fixture.origin.snapshot.manifestRequests, 1)
        XCTAssertEqual(fixture.origin.snapshot.headRequests, 0)
        XCTAssertEqual(fixture.origin.snapshot.rangeRequests, 0)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func testTerminationNotificationClosesNativePlayback() async throws {
        let fixture = try AudioRuntimeFixture()
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native player is ready before termination", controller: fixture.controller) {
            fixture.controller.playing && fixture.controller.position > 0.2
        }
        NotificationCenter.default.post(name: UIApplication.willTerminateNotification, object: nil)
        try await waitUntil("Termination releases native playback", controller: fixture.controller) {
            !fixture.controller.visible && !fixture.controller.playing && fixture.controller.manifest == nil
        }
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }

    func testAcknowledgedDetailFavoriteUpdatesPlayingBookWithoutRestartAndRejectsStaleAccountAck() async throws {
        let fixture = try AudioRuntimeFixture()
        defer { fixture.cleanUp() }
        fixture.controller.start(bookID: AudioRuntimeOrigin.bookID)
        try await waitUntil("Native player is ready before a detail favorite change", controller: fixture.controller) {
            fixture.controller.playing && fixture.controller.position > 0.2
        }
        let originalLease = fixture.controller.manifest?.session
        let originalPosition = fixture.controller.position
        let originalRevision = fixture.controller.revision
        XCTAssertFalse(fixture.controller.favorite)
        try await fixture.repository.shelf(bookID: AudioRuntimeOrigin.bookID, field: .favorite, value: true, account: "runtime-reader")
        await fixture.controller.acknowledgeShelfChange(bookID: AudioRuntimeOrigin.bookID, field: .favorite, value: true, account: "runtime-reader")
        XCTAssertEqual(fixture.origin.snapshot.shelfFavorites, [true])
        XCTAssertTrue(fixture.controller.favorite)
        XCTAssertTrue(fixture.controller.playing)
        XCTAssertEqual(fixture.controller.manifest?.session, originalLease)
        XCTAssertEqual(fixture.origin.snapshot.manifestRequests, 1, "A shelf acknowledgement must not restart the media lease")
        XCTAssertGreaterThanOrEqual(fixture.controller.position, originalPosition - 0.15)
        XCTAssertNotEqual(fixture.controller.revision, originalRevision)

        await fixture.tokens.switchAccount()
        let beforeStaleAck = fixture.controller.revision
        await fixture.controller.acknowledgeShelfChange(bookID: AudioRuntimeOrigin.bookID, field: .favorite, value: false, account: "runtime-reader")
        XCTAssertTrue(fixture.controller.favorite, "An acknowledgement from the previous account must not change visible state")
        XCTAssertEqual(fixture.controller.revision, beforeStaleAck)
        fixture.controller.activate(account: "runtime-other")
        XCTAssertFalse(fixture.controller.visible)
    }

    private func waitUntil(_ description: String, controller: AudioPlaybackController,
                           allowPlaybackError: Bool = false, timeout: Duration = .seconds(15),
                           file: StaticString = #filePath, line: UInt = #line,
                           diagnostics: (() -> String)? = nil,
                           predicate: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !predicate() {
            try Task.checkCancellation()
            if !allowPlaybackError, let error = controller.error {
                XCTFail("\(description): native playback failed: \(error)", file: file, line: line)
                throw AudioRuntimeFailure.playbackFailed
            }
            if clock.now >= deadline {
                XCTFail("\(description): timed out waiting for the real AVPlayer; \(controller.debugPlaybackState); \(diagnostics?() ?? "")", file: file, line: line)
                throw AudioRuntimeFailure.timedOut
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}

@MainActor
private final class AudioRuntimeFixture {
    let origin: AudioRuntimeOrigin
    let tokens: AudioRuntimeTokens
    let session: URLSession
    let repository: AudioRepository
    let controller: AudioPlaybackController
    init(manifestStatus: Int = 200, holdMetadata: Bool = false, initialPosition: Double = 0, omitHeadMetadata: Bool = false) throws {
        let origin = try AudioRuntimeOrigin(manifestStatus: manifestStatus, holdMetadata: holdMetadata, initialPosition: initialPosition,
                                          omitHeadMetadata: omitHeadMetadata)
        self.origin = origin
        let tokens = AudioRuntimeTokens()
        self.tokens = tokens
        AudioRuntimeURLProtocol.register(origin)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AudioRuntimeURLProtocol.self]
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        self.session = session
        let repository = try AudioRepository(webBaseURL: origin.webBaseURL, tokens: tokens,
            refresh: { _ in throw AudioRuntimeFailure.unexpectedRefresh }, session: session)
        self.repository = repository
        controller = AudioPlaybackController(repository: repository)
        controller.activate(account: "runtime-reader")
        controller.setVolume(0)
    }
    func cleanUp() {
        controller.close()
        session.invalidateAndCancel()
        AudioRuntimeURLProtocol.unregister(origin)
    }
}

private enum AudioRuntimeFailure: Error { case timedOut, playbackFailed, unexpectedRefresh, malformedFixture }

private actor AudioRuntimeTokens: SessionTokenManaging {
    private var session: Session? = Session(accessToken: "ms_at_runtime_fixture", refreshToken: "runtime-refresh", username: "runtime-reader", userID: "700001")
    func switchAccount() { session = Session(accessToken: "ms_at_runtime_other", refreshToken: "runtime-refresh-other", username: "runtime-other", userID: "700002") }
    func accessToken() async throws -> String? { session?.accessToken }
    func loadSession() async throws -> Session? { session }
    func save(session: Session) async throws { self.session = session }
    func clear() async throws { session = nil }
    func replaceSession(_ session: Session?, ifMatching expected: Session) async throws -> Bool {
        guard self.session == expected else { return false }; self.session = session; return true
    }
}

private final class AudioRuntimeOrigin: @unchecked Sendable {
    static let bookID = 700001
    static let chapterID = 700002
    let identifier: String
    let webBaseURL: URL
    private let wave: Data
    private let manifestStatus: Int
    private let holdsMetadata: Bool
    private let omitHeadMetadata: Bool
    private let initialPosition: Double
    private let lock = NSLock()
    private let metadataDeliveryQueue = DispatchQueue(label: "ekitapligim.native-audio-test.metadata")
    private var heldMetadata: [UUID: @Sendable () -> Void] = [:]
    private var cancelledMetadata: [@Sendable () -> Void] = []
    private var log = Snapshot()
    struct Snapshot {
        var manifestRequests = 0
        var headRequests = 0
        var rangeRequests = 0
        var metadataProbeRequests = 0
        var metadataProbeBytes = 0
        var mediaBearers: [String] = []
        var progressPositions: [Double] = []
        var progressSequences: [Int] = []
        var shelfFavorites: [Bool] = []
        var unexpectedRequests: [String] = []
        var pendingMetadataRequests = 0
        var cancelledMetadataRequests = 0
        var metadataDeliveryAttempts = 0
    }
    var snapshot: Snapshot { lock.lock(); defer { lock.unlock() }; return log }
    init(manifestStatus: Int, holdMetadata: Bool, initialPosition: Double, omitHeadMetadata: Bool) throws {
        let identifier = "audio-runtime-" + UUID().uuidString.lowercased()
        self.identifier = identifier
        guard let url = URL(string: "https://ekitapligim.com/\(identifier)/") else { throw AudioRuntimeFailure.malformedFixture }
        webBaseURL = url; self.manifestStatus = manifestStatus; holdsMetadata = holdMetadata; self.initialPosition = initialPosition
        self.omitHeadMetadata = omitHeadMetadata
        wave = Self.silentWave(seconds: 20)
    }
    /// A pending HEAD is retained as a callback, never as a sleeping/blocking URLProtocol thread.
    func holdMetadataResponse(for request: URLRequest, delivery: @escaping @Sendable () -> Void) -> UUID? {
        guard holdsMetadata, request.httpMethod == "HEAD", request.url?.path.hasSuffix("/stream") == true else { return nil }
        lock.lock(); defer { lock.unlock() }
        let identifier = UUID(); heldMetadata[identifier] = delivery; log.pendingMetadataRequests += 1
        return identifier
    }
    func cancelHeldMetadataResponse(_ identifier: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard let delivery = heldMetadata.removeValue(forKey: identifier) else { return }
        // Keep the abandoned callback solely to replay its delivery attempt after cancellation.
        // The protocol itself must suppress client callbacks once stopLoading has run.
        cancelledMetadata.append(delivery)
        log.pendingMetadataRequests -= 1; log.cancelledMetadataRequests += 1
    }
    func releaseHeldMetadataResponses() async {
        let deliveries = takeHeldMetadataResponses()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            metadataDeliveryQueue.async {
                deliveries.forEach { $0() }
                continuation.resume()
            }
        }
    }
    private func takeHeldMetadataResponses() -> [@Sendable () -> Void] {
        lock.lock(); defer { lock.unlock() }
        let deliveries = Array(heldMetadata.values) + cancelledMetadata
        heldMetadata.removeAll(); cancelledMetadata.removeAll(); log.pendingMetadataRequests = 0
        log.metadataDeliveryAttempts += deliveries.count
        return deliveries
    }
    func response(for request: URLRequest) throws -> (Int, [String: String], Data) {
        lock.lock(); defer { lock.unlock() }
        let method = request.httpMethod ?? "GET"
        let suffix = request.url?.path.replacingOccurrences(of: "/\(identifier)/mobile-api/v1/", with: "") ?? ""
        let bearer = request.value(forHTTPHeaderField: "Authorization") ?? ""
        guard bearer == "Bearer ms_at_runtime_fixture", request.value(forHTTPHeaderField: "Cookie") == nil else {
            log.unexpectedRequests.append("Unexpected auth or cookie")
            return (401, ["Content-Type": "application/json"], Data("{}".utf8))
        }
        if suffix == "audio-books/\(Self.bookID)/manifest", method == "POST" {
            log.manifestRequests += 1
            guard manifestStatus == 200 else { return (manifestStatus, ["Content-Type": "application/json"], Data(#"{"error":{"code":"audio_premium_required","message":"Premium required"}}"#.utf8)) }
            let book: [String: Any] = ["thread_id": Self.bookID, "title": "Generated silent WAV", "author": "Offline runtime fixture",
                "cover_url": "", "duration": 20, "can_listen": true, "chapter_count": 1, "user_state": ["chapter_id": Self.chapterID, "position": initialPosition, "speed": 1]]
            let chapter: [String: Any] = ["chapter_id": Self.chapterID, "title": "Generated chapter", "duration": 20, "display_order": 0,
                "url": webBaseURL.appendingPathComponent("mobile-api/v1/audio-books/\(Self.bookID)/stream").absoluteString + "?chapter_id=\(Self.chapterID)"]
            let manifest: [String: Any] = ["api_version": 1, "session": "runtime-playback-lease", "sequence": 0, "book": book, "chapters": [chapter],
                "state": ["chapter_id": Self.chapterID, "position": initialPosition, "speed": 1], "bookmarks": [], "recommendations": []]
            return (200, ["Content-Type": "application/json"], try JSONSerialization.data(withJSONObject: manifest))
        }
        if suffix == "audio-books/\(Self.bookID)/progress", method == "POST" {
            let fields = request.audioRuntimeFields
            guard fields["session"] == "runtime-playback-lease", Int(fields["chapter_id"] ?? "") == Self.chapterID,
                  let sequence = Int(fields["sequence"] ?? ""), sequence > (log.progressSequences.last ?? 0),
                  let position = Double(fields["position"] ?? ""), position.isFinite, position >= 0, position <= 20.1 else {
                log.unexpectedRequests.append("Invalid progress lease, sequence or position")
                return (409, ["Content-Type": "application/json"], Data("{}".utf8))
            }
            log.progressSequences.append(sequence); log.progressPositions.append(position)
            let result: [String: Any] = ["saved": true, "completed": false, "credited": Double(fields["listened"] ?? "") ?? 0,
                "state": ["chapter_id": Self.chapterID, "position": position, "progress": position * 5, "speed": 1]]
            return (200, ["Content-Type": "application/json"], try JSONSerialization.data(withJSONObject: result))
        }
        if suffix == "audio-books/\(Self.bookID)/shelf", method == "POST" {
            let fields = request.audioRuntimeFields
            guard fields["field"] == "favorite", ["0", "1"].contains(fields["value"] ?? "") else {
                log.unexpectedRequests.append("Invalid fixture shelf mutation")
                return (400, ["Content-Type": "application/json"], Data("{}".utf8))
            }
            log.shelfFavorites.append(fields["value"] == "1")
            return (200, ["Content-Type": "application/json"], Data(#"{"saved":true}"#.utf8))
        }
        if suffix == "audio-books/\(Self.bookID)/stream" {
            log.mediaBearers.append(bearer)
            guard request.value(forHTTPHeaderField: "Accept-Encoding") == "identity",
                  URLComponents(url: request.url ?? webBaseURL, resolvingAgainstBaseURL: false)?.queryItems == [.init(name: "chapter_id", value: String(Self.chapterID))] else {
                log.unexpectedRequests.append("Invalid native stream request")
                return (400, [:], Data())
            }
            if method == "HEAD" {
                log.headRequests += 1
                if omitHeadMetadata { return (200, ["Content-Type": "audio/wav"], Data()) }
                return (200, ["Content-Type": "audio/wav", "Content-Length": String(wave.count), "Accept-Ranges": "bytes"], Data())
            }
            if method == "GET", let header = request.value(forHTTPHeaderField: "Range"), header.hasPrefix("bytes=") {
                let bounds = header.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
                guard bounds.count == 2, let start = Int(bounds[0]), let end = Int(bounds[1]), start >= 0, end >= start,
                      start < wave.count, end - start < Int(AudioRangePolicy.chunkSize) else {
                    log.unexpectedRequests.append("Invalid byte range")
                    return (416, ["Content-Range": "bytes */\(wave.count)"], Data())
                }
                log.rangeRequests += 1
                let last = min(end, wave.count - 1)
                if start == 0, end == 0 { log.metadataProbeRequests += 1; log.metadataProbeBytes += last - start + 1 }
                return (206, ["Content-Type": "audio/wav", "Content-Length": String(last - start + 1),
                    "Accept-Ranges": "bytes", "Content-Range": "bytes \(start)-\(last)/\(wave.count)"], wave.subdata(in: start..<(last + 1)))
            }
        }
        log.unexpectedRequests.append("\(method) \(suffix)")
        return (500, ["Content-Type": "application/json"], Data("{}".utf8))
    }
    /// RIFF/WAVE, PCM format 1, mono, 22,050 Hz, signed 16-bit silence. No media assets or copyrights.
    static func silentWave(seconds: Int) -> Data {
        let rate: UInt32 = 22_050
        let byteCount = rate * UInt32(seconds) * 2
        var result = Data("RIFF".utf8)
        func append<T: FixedWidthInteger>(_ value: T) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { result.append(contentsOf: $0) }
        }
        append(UInt32(36) + byteCount); result.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(rate); append(rate * 2)
        append(UInt16(2)); append(UInt16(16)); result.append(contentsOf: "data".utf8); append(byteCount)
        result.append(Data(repeating: 0, count: Int(byteCount)))
        return result
    }
}

/// A locked registry gives parallel XCTest instances separate offline origins. Missing origins fail closed.
private final class AudioRuntimeURLProtocol: URLProtocol, @unchecked Sendable {
    private static let registryLock = NSLock()
    private static var origins: [String: AudioRuntimeOrigin] = [:]
    private let stateLock = NSLock()
    private var stopped = false
    private var pendingMetadata: (origin: AudioRuntimeOrigin, identifier: UUID)?
    static func register(_ origin: AudioRuntimeOrigin) { registryLock.lock(); defer { registryLock.unlock() }; origins[origin.identifier] = origin }
    static func unregister(_ origin: AudioRuntimeOrigin) { registryLock.lock(); defer { registryLock.unlock() }; origins.removeValue(forKey: origin.identifier) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.registryLock.lock()
        let key = request.url?.pathComponents.dropFirst().first ?? ""
        let origin = Self.origins[key]
        Self.registryLock.unlock()
        do {
            guard let origin, let url = request.url, url.scheme == "https", url.host == "ekitapligim.com" else { throw AudioRuntimeFailure.malformedFixture }
            let (status, headers, data) = try origin.response(for: request)
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else { throw AudioRuntimeFailure.malformedFixture }
            if let identifier = origin.holdMetadataResponse(for: request, delivery: { [weak self] in self?.deliver(response, data: data) }) {
                stateLock.lock()
                let alreadyStopped = stopped
                if !alreadyStopped { pendingMetadata = (origin, identifier) }
                stateLock.unlock()
                if alreadyStopped { origin.cancelHeldMetadataResponse(identifier) }
                return
            }
            deliver(response, data: data)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    private func deliver(_ response: HTTPURLResponse, data: Data) {
        stateLock.lock(); let shouldStop = stopped; stateLock.unlock()
        guard !shouldStop else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        var offset = 0
        while offset < data.count {
            stateLock.lock(); let shouldStop = stopped; stateLock.unlock()
            guard !shouldStop else { return }
            let end = min(data.count, offset + 65_536)
            client?.urlProtocol(self, didLoad: data.subdata(in: offset..<end)); offset = end
        }
        stateLock.lock(); let finished = !stopped; stateLock.unlock()
        if finished { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() {
        stateLock.lock(); stopped = true
        let pending = pendingMetadata; pendingMetadata = nil
        stateLock.unlock()
        if let pending { pending.origin.cancelHeldMetadataResponse(pending.identifier) }
    }
}

private extension URLRequest {
    var audioRuntimeFields: [String: String] {
        let data: Data
        if let httpBody { data = httpBody }
        else if let stream = httpBodyStream {
            stream.open(); defer { stream.close() }
            var collected = Data(), buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; collected.append(buffer, count: count) }
            data = collected
        } else { return [:] }
        var components = URLComponents()
        components.percentEncodedQuery = String(data: data, encoding: .utf8)
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
}
