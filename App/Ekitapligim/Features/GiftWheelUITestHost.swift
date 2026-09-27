#if DEBUG
import SwiftUI
import EkitapligimCore

/// Offline fixtures only; excluded from production. Does not call authentication or purchase services.
@MainActor struct GiftWheelUITestHost: View {
    @StateObject private var model: GiftWheelModel
    private let mode: String
    init() {
        let mode = ProcessInfo.processInfo.environment["WHEEL_FIXTURE_MODE"] ?? "ready"
        self.mode = mode
        let model = GiftWheelModel(service: WheelFixtureService(mode: mode), pendingStore: WheelFixturePending())
        model.controller.activate(account: mode == "guest" ? nil : "fixture-reader")
        _model = StateObject(wrappedValue: model)
    }
    var body: some View {
        NavigationStack { GiftWheelView(model: model, isSignedIn: mode != "guest", onLogin: {}, onLiveActivity: {}) }
    }
}

private actor WheelFixtureService: GiftWheelServing {
    let mode: String
    var spun = false
    init(mode: String) { self.mode = mode }
    private func decode<T: Decodable>(_ json: String) throws -> T {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(json.utf8))
    }
    func status(account: String) async throws -> GiftWheelStatusDTO {
        if mode == "error" { throw URLError(.notConnectedToInternet) }
        let exhausted = spun || mode == "quota"
        let segments = GiftWheelSegmentDTO.defaults.map { "{\"index\":\($0.index),\"days\":\($0.days)}" }.joined(separator: ",")
        return try decode("""
        {"api_version":1,"ready":\(!exhausted),"availability":"\(exhausted ? "quota_exhausted" : "ready")",
        "revision":2,"segments":[\(segments)],"quota":{"limit":1,"remaining":\(exhausted ? 0 : 1),"wait_seconds":\(exhausted ? 86400 : 0)},
        "wallet":{"seconds":\(spun && mode != "noPrize" ? 604800 : 0),"running":\(spun && mode != "noPrize")},"history":[]}
        """)
    }
    func winners(account: String) async throws -> [GiftWheelEntryDTO] {
        try decode("[{\"username\":\"Kitap Dostu\",\"days\":7,\"created_at\":1790504500},{\"username\":\"Bir Okur\",\"days\":30,\"created_at\":1790504400}]")
    }
    func spin(account: String, pending: PendingGiftSpin) async throws -> GiftWheelSpinDTO {
        spun = true
        return try decode("""
        {"api_version":1,"result":{"prize_index":\(mode == "noPrize" ? 0 : 3),"days":\(mode == "noPrize" ? 0 : 7),"promoted":false,"replayed":false},
        "quota":{"limit":1,"remaining":0,"wait_seconds":86400},"wallet":{"seconds":\(mode == "noPrize" ? 0 : 604800),"running":false}}
        """)
    }
}
@MainActor private final class WheelFixturePending: GiftWheelPendingStoring {
    var pending: PendingGiftSpin?
    func read(account: String) throws -> PendingGiftSpin? { pending }
    func save(_ pending: PendingGiftSpin, account: String) throws { self.pending = pending }
    func clear(account: String) throws { pending = nil }
}
#endif
