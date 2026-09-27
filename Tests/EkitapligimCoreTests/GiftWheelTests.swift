import XCTest
@testable import EkitapligimCore

enum WheelFixtures {
    static let status = """
    {"api_version":1,"ready":true,"availability":"ready","revision":2,
    "segments":[{"index":0,"days":0},{"index":1,"days":1},{"index":2,"days":3},{"index":3,"days":7},
    {"index":4,"days":14},{"index":5,"days":30},{"index":6,"days":0},{"index":7,"days":1},
    {"index":8,"days":3},{"index":9,"days":7},{"index":10,"days":14},{"index":11,"days":30}],
    "quota":{"limit":1,"remaining":1,"wait_seconds":0},"wallet":{"seconds":259200,"running":false},
    "history":[{"days":3,"created_at":1790504500,"refunded":false}]}
    """
    static let spin = """
    {"api_version":1,"result":{"spin_id":42,"prize_index":3,"days":7,"promoted":true,"replayed":false},
    "quota":{"limit":1,"remaining":0,"wait_seconds":86400},"wallet":{"seconds":604800,"running":true}}
    """
    static func decode<T: Decodable>(_ value: String, as type: T.Type = T.self) throws -> T {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(value.utf8))
    }
}

final class GiftWheelTests: XCTestCase {
    func testServerControlsSegmentsQuotaWalletAndAvailability() throws {
        let status: GiftWheelStatusDTO = try WheelFixtures.decode(WheelFixtures.status)
        XCTAssertTrue(try status.validated().canSpin)
        XCTAssertEqual(status.history.first?.days, 3)
        XCTAssertEqual(status.wallet.seconds, 259200)
        XCTAssertEqual(status.wallet.label, "3 gün")
        for availability in ["paused", "account_wait", "not_allowed", "quota_exhausted"] {
            let denied: GiftWheelStatusDTO = try WheelFixtures.decode(WheelFixtures.status.replacingOccurrences(of: "\"availability\":\"ready\"", with: "\"availability\":\"\(availability)\""))
            XCTAssertFalse(denied.canSpin)
        }
    }
    func testChangedGeometryAndVersionFailClosed() throws {
        for json in [WheelFixtures.status.replacingOccurrences(of: "\"api_version\":1", with: "\"api_version\":2"),
                     WheelFixtures.status.replacingOccurrences(of: "\"index\":0", with: "\"index\":12"),
                     WheelFixtures.status.replacingOccurrences(of: "\"days\":30", with: "\"days\":90")] {
            let status: GiftWheelStatusDTO = try WheelFixtures.decode(json)
            XCTAssertThrowsError(try status.validated())
        }
    }
    func testAwardMismatchCannotInventPrizeAndReplayMapsByDays() throws {
        let mismatch = WheelFixtures.spin.replacingOccurrences(of: "\"prize_index\":3", with: "\"prize_index\":1")
        let invalid: GiftWheelSpinDTO = try WheelFixtures.decode(mismatch)
        XCTAssertThrowsError(try invalid.displayIndex(in: GiftWheelSegmentDTO.defaults))
        let replay: GiftWheelSpinDTO = try WheelFixtures.decode(mismatch.replacingOccurrences(of: "\"replayed\":false", with: "\"replayed\":true"))
        XCTAssertEqual(try replay.displayIndex(in: GiftWheelSegmentDTO.defaults), 3)
    }
    func testAllTwelveSlicesLandAtFixedPointerAfterRepeatedSpins() throws {
        var start = GiftWheelMotion.initialRotation
        for _ in 0..<5 {
            for index in 0..<12 {
                let target = try GiftWheelMotion.target(from: start, index: index)
                XCTAssertGreaterThanOrEqual(target-start, 9*360)
                XCTAssertEqual((target + (Double(index)+0.5)*30).truncatingRemainder(dividingBy: 360), 0, accuracy: 0.00001)
                start = target
            }
        }
        XCTAssertThrowsError(try GiftWheelMotion.target(from: 0, index: 12))
    }
    func testTenSecondEasingIsMonotonicAndDoesNotFinishEarly() {
        XCTAssertEqual(GiftWheelMotion.duration, 10)
        var previous = 0.0
        for sample in 0..<1000 {
            let next = GiftWheelMotion.progress(elapsed: Double(sample)/100)
            XCTAssertGreaterThanOrEqual(next, previous)
            XCTAssertLessThan(next, 1)
            previous = next
        }
        XCTAssertEqual(GiftWheelMotion.progress(elapsed: 10), 1)
    }
    func testGiftWheelDeepLinksAndMenuRoute() {
        let parser = DeepLinkParser()
        XCTAssertEqual(parser.parse("https://ekitapligim.com/hediye-carki/"), .giftWheel)
        XCTAssertEqual(parser.parse("https://www.ekitapligim.com/hediye-carki"), .giftWheel)
        XCTAssertEqual(parser.parseNativeRoute("gift-wheel"), .giftWheel)
        XCTAssertEqual(parser.parseNativeRoute("hediye-carki"), .giftWheel)
        XCTAssertNil(parser.parseNativeRoute("gift-wheel/spin"))
        XCTAssertNil(parser.parse("https://example.com/hediye-carki/"))
        XCTAssertNil(parser.parse("https://ekitapligim.com/hediye-carki-api/spin"))
        XCTAssertFalse(AppRoute.giftWheel.requiresAuthentication)
    }
}

@MainActor final class GiftWheelControllerTests: XCTestCase {
    private func setup() async -> (GiftWheelController, WheelTestService, WheelMemoryPending) {
        let service = WheelTestService(), storage = WheelMemoryPending()
        let model = GiftWheelController(service: service, pendingStore: storage)
        model.activate(account: "reader")
        await model.refresh()
        return (model, service, storage)
    }
    func testResultHiddenUntilFullTenSecondsAndOnlyOnePOSTWhileSpinning() async throws {
        let (model, service, store) = await setup()
        await model.spin()
        XCTAssertTrue(model.state.spinning)
        XCTAssertNotNil(try store.read(account: "reader"))
        model.frame(at: 100)
        model.frame(at: 109.999)
        XCTAssertNil(model.state.prize)
        XCTAssertTrue(model.state.spinning)
        await model.spin()
        let calls = await service.keys
        XCTAssertEqual(calls.count, 1)
        model.frame(at: 110)
        XCTAssertFalse(model.state.spinning)
        XCTAssertEqual(model.state.prize?.result.days, 7)
        XCTAssertEqual(model.state.elapsed, 10)
        XCTAssertNil(try store.read(account: "reader"))
        XCTAssertEqual(model.state.wallet.seconds, 604800)
    }
    func testBackgroundTimeDoesNotShortenVisibleSpin() async {
        let (model, _, _) = await setup()
        await model.spin(); model.frame(at: 1); model.frame(at: 5)
        model.suspendAnimation()
        model.frame(at: 500)
        XCTAssertEqual(model.state.elapsed, 4)
        model.frame(at: 505.999)
        XCTAssertNil(model.state.prize)
        model.frame(at: 506)
        XCTAssertEqual(model.state.prize?.result.days, 7)
    }
    func testTimeoutAndRelaunchRecoverSameKeyEvenWhenQuotaIsExhausted() async throws {
        let (model, service, store) = await setup()
        await service.setTimeout(true)
        await model.spin()
        let pending = try XCTUnwrap(store.read(account: "reader"))
        XCTAssertTrue(model.state.pendingRetry)
        let restored = GiftWheelController(service: service, pendingStore: store)
        await service.setTimeout(false)
        await service.exhaustQuota()
        restored.activate(account: "reader"); await restored.refresh()
        XCTAssertFalse(restored.state.status?.canSpin ?? true)
        await restored.spin()
        let keys = await service.keys
        XCTAssertEqual(keys, [pending.key, pending.key])
        XCTAssertTrue(restored.state.spinning)
    }
    func testExplicitRejectionClearsPendingButDoesNotSpin() async throws {
        let (model, service, store) = await setup()
        await service.setFailure(.server(409, "Quota")); await model.spin()
        XCTAssertFalse(model.state.spinning)
        XCTAssertFalse(model.state.pendingRetry)
        XCTAssertNil(try store.read(account: "reader"))
    }
    func testPersistenceFailureNeverSendsPOST() async {
        let (model, service, store) = await setup()
        store.failSave = true; await model.spin()
        let keys = await service.keys
        XCTAssertTrue(keys.isEmpty)
        XCTAssertNotNil(model.state.error)
    }
    func testGuestAndAccountSwitchDoNotLeakAwardOrRequestKey() async throws {
        let (model, service, store) = await setup()
        await model.spin(); model.frame(at: 0)
        model.activate(account: nil); model.frame(at: 10); await model.spin()
        XCTAssertNil(model.state.prize)
        XCTAssertNil(model.state.status)
        XCTAssertTrue(model.state.winners.isEmpty)
        model.activate(account: "other"); await model.refresh()
        XCTAssertFalse(model.state.pendingRetry)
        XCTAssertNotNil(try store.read(account: "reader"))
        XCTAssertNil(try store.read(account: "other"))
        let keys = await service.keys
        XCTAssertEqual(keys.count, 1)
    }
    func testCooldownRequiresServerPermissionAfterClockExpires() async {
        let service = WheelTestService(), store = WheelMemoryPending()
        var time = 0.0
        await service.exhaustQuota()
        let model = GiftWheelController(service: service, pendingStore: store, now: { time })
        model.activate(account: "reader"); await model.refresh()
        time = 86401; await model.tick()
        XCTAssertFalse(model.state.status?.canSpin ?? true)
        await model.spin()
        let keys = await service.keys
        XCTAssertTrue(keys.isEmpty)
    }
    func testAtomicPendingStorageIsAccountScopedAcrossInstances() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FileGiftWheelPendingStore(directory: folder)
        let pending = PendingGiftSpin(revision: 2)
        try store.save(pending, account: "reader/../ü")
        let restored = FileGiftWheelPendingStore(directory: folder)
        XCTAssertEqual(try restored.read(account: "reader/../ü"), pending)
        XCTAssertNil(try restored.read(account: "other"))
        try restored.clear(account: "reader/../ü")
        XCTAssertNil(try store.read(account: "reader/../ü"))
    }
    func testAccountDeletionErasesOnlyCurrentAccountsPendingSpin() async throws {
        let (model, _, store) = await setup()
        let other = PendingGiftSpin(revision: 2)
        try store.save(other, account: "other")
        await model.spin()
        try model.eraseCurrentAccount()
        XCTAssertNil(try store.read(account: "reader"))
        XCTAssertEqual(try store.read(account: "other"), other)
        XCTAssertNil(model.state.status)
        XCTAssertFalse(model.state.spinning)
    }
    func testInFlightAwardIsDiscardedAfterAccountSwitch() async throws {
        let (model, service, store) = await setup()
        await service.holdNextSpin()
        let request = Task { await model.spin() }
        await service.waitUntilSpinIsHeld()
        XCTAssertTrue(model.state.submitting)
        model.activate(account: "other")
        await model.refresh()
        await service.releaseSpin()
        await request.value
        XCTAssertFalse(model.state.spinning)
        XCTAssertFalse(model.state.pendingRetry)
        XCTAssertNil(model.state.prize)
        XCTAssertNotNil(try store.read(account: "reader"))
        XCTAssertNil(try store.read(account: "other"))
    }
    func testNoPrizeUsesSameTenSecondsAndNeverAddsGiftTime() async {
        let (model, service, _) = await setup()
        await service.returnNoPrize()
        await model.spin()
        model.frame(at: 0); model.frame(at: 9.999)
        XCTAssertNil(model.state.prize)
        model.frame(at: 10)
        XCTAssertEqual(model.state.prize?.result.days, 0)
        XCTAssertEqual(model.state.wallet.seconds, 0)
        XCTAssertEqual(model.state.waitSeconds, 86400)
    }
}

private actor WheelTestService: GiftWheelServing {
    var keys: [String] = []
    var failure: GiftWheelError?
    var exhausted = false
    var timeout = false
    var noPrize = false
    var hold = false
    var spinGate: CheckedContinuation<Void, Never>?
    var startGate: CheckedContinuation<Void, Never>?
    func setFailure(_ value: GiftWheelError?) { failure = value }
    func setTimeout(_ value: Bool) { timeout = value }
    func returnNoPrize() { noPrize = true }
    func holdNextSpin() { hold = true }
    func waitUntilSpinIsHeld() async {
        if spinGate != nil { return }
        await withCheckedContinuation { startGate = $0 }
    }
    func releaseSpin() { spinGate?.resume(); spinGate = nil }
    func exhaustQuota() { exhausted = true }
    func status(account: String) async throws -> GiftWheelStatusDTO {
        var json = WheelFixtures.status
        if exhausted { json = json.replacingOccurrences(of: "\"remaining\":1,\"wait_seconds\":0", with: "\"remaining\":0,\"wait_seconds\":86400") }
        return try WheelFixtures.decode(json)
    }
    func winners(account: String) async throws -> [GiftWheelEntryDTO] { [] }
    func spin(account: String, pending: PendingGiftSpin) async throws -> GiftWheelSpinDTO {
        keys.append(pending.key)
        if hold {
            await withCheckedContinuation { spinGate = $0; startGate?.resume(); startGate = nil }
        }
        if timeout { throw URLError(.timedOut) }
        if let failure { throw failure }
        exhausted = true
        let json = noPrize ? WheelFixtures.spin.replacingOccurrences(of: "\"prize_index\":3,\"days\":7", with: "\"prize_index\":0,\"days\":0")
            .replacingOccurrences(of: "604800", with: "0").replacingOccurrences(of: "\"running\":true", with: "\"running\":false") : WheelFixtures.spin
        return try WheelFixtures.decode(json)
    }
}

@MainActor private final class WheelMemoryPending: GiftWheelPendingStoring {
    var values: [String: PendingGiftSpin] = [:]
    var failSave = false
    func read(account: String) throws -> PendingGiftSpin? { values[account] }
    func save(_ pending: PendingGiftSpin, account: String) throws {
        if failSave { throw CocoaError(.fileWriteNoPermission) }
        values[account] = pending
    }
    func clear(account: String) throws { values[account] = nil }
}
