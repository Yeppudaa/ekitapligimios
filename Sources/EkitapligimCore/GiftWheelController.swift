import Foundation

public struct PendingGiftSpin: Codable, Equatable, Sendable {
    public let key: String
    public let revision: Int
    public init(key: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(), revision: Int) {
        self.key = key; self.revision = revision
    }
    public var isValid: Bool { (32...64).contains(key.count) && key.allSatisfy { "0123456789abcdef".contains($0) } && revision > 0 }
}

@MainActor public protocol GiftWheelPendingStoring {
    func read(account: String) throws -> PendingGiftSpin?
    func save(_ pending: PendingGiftSpin, account: String) throws
    func clear(account: String) throws
}

/// Persist only the recovery key/revision, atomically before sending a spin. Tokens remain in Keychain.
@MainActor public final class FileGiftWheelPendingStore: GiftWheelPendingStoring {
    private let directory: URL
    public init(directory: URL) { self.directory = directory }
    private func file(_ account: String) -> URL {
        let name = Data(account.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
        return directory.appendingPathComponent(name + ".json")
    }
    public func read(account: String) throws -> PendingGiftSpin? {
        let url = file(account)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let pending = try JSONDecoder().decode(PendingGiftSpin.self, from: Data(contentsOf: url))
        guard pending.isValid else { throw GiftWheelError.invalidResponse }
        return pending
    }
    public func save(_ pending: PendingGiftSpin, account: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(pending).write(to: file(account), options: .atomic)
    }
    public func clear(account: String) throws {
        let url = file(account)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

public struct GiftWheelState: Equatable, Sendable {
    public var status: GiftWheelStatusDTO?
    public var winners: [GiftWheelEntryDTO] = []
    public var loading = false
    public var submitting = false
    public var spinning = false
    public var needsLogin = false
    public var pendingRetry = false
    public var winnersError = false
    public var error: String?
    public var rotation = GiftWheelMotion.initialRotation
    public var elapsed: TimeInterval = 0
    public var waitSeconds = 0
    public var prize: GiftWheelSpinDTO?
    public var busy: Bool { loading || submitting || spinning }
    public var segments: [GiftWheelSegmentDTO] { status?.segments ?? GiftWheelSegmentDTO.defaults }
    public var wallet: GiftWheelWalletDTO { status?.wallet ?? .empty }
    public init() {}
}

/// UI-independent state machine; every award comes from PremiumWheel, never from local randomness.
@MainActor public final class GiftWheelController {
    public private(set) var state = GiftWheelState() { didSet { didChange?(state) } }
    public var didChange: ((GiftWheelState) -> Void)?
    private let service: any GiftWheelServing
    private let pendingStore: any GiftWheelPendingStoring
    private let now: () -> TimeInterval
    private var account: String?
    private var generation = UUID()
    private var operation: Task<Void, Never>?
    private var animation: (prize: GiftWheelSpinDTO, start: Double, target: Double)?
    private var lastFrame: TimeInterval?
    private var waitDeadline: TimeInterval?

    public init(service: any GiftWheelServing, pendingStore: any GiftWheelPendingStoring, now: (() -> TimeInterval)? = nil) {
        self.service = service; self.pendingStore = pendingStore
        let clock = ContinuousClock(), origin = ContinuousClock.now
        self.now = now ?? {
            let parts = origin.duration(to: clock.now).components
            return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
        }
    }
    public func activate(account: String?) {
        guard self.account != account else { return }
        operation?.cancel(); operation = nil
        self.account = account; generation = UUID(); animation = nil; lastFrame = nil; waitDeadline = nil
        state = GiftWheelState()
        if let account {
            do { state.pendingRetry = try pendingStore.read(account: account) != nil }
            catch { state.error = WheelL10n.text("storageError") }
        }
    }
    public func refresh() async {
        guard let account, !state.busy else { return }
        let generation = generation
        state.loading = true; state.error = nil
        do {
            let status = try await service.status(account: account).validated()
            guard self.generation == generation else { return }
            state.status = status; state.needsLogin = false
            state.pendingRetry = try pendingStore.read(account: account) != nil
            setCountdown(status.quota.waitSeconds)
            await refreshWinners(account: account, generation: generation)
        } catch {
            guard self.generation == generation else { return }
            show(error)
        }
        guard self.generation == generation else { return }
        state.loading = false
    }
    public func spin() async {
        guard let account, !state.busy, !state.needsLogin,
              state.status != nil, state.pendingRetry || state.status?.canSpin == true else { return }
        let generation = generation
        state.submitting = true; state.prize = nil; state.error = nil
        do {
            let pending = try pendingStore.read(account: account) ?? PendingGiftSpin(revision: state.status?.revision ?? 0)
            try pendingStore.save(pending, account: account)
            state.pendingRetry = true
            let prize = try await service.spin(account: account, pending: pending)
            guard self.generation == generation else { return }
            let index = try prize.displayIndex(in: state.segments)
            let target = try GiftWheelMotion.target(from: state.rotation, index: index)
            animation = (prize, state.rotation, target)
            lastFrame = nil; state.elapsed = 0; state.submitting = false; state.spinning = true
        } catch {
            guard self.generation == generation else { return }
            if case GiftWheelError.server(let code, _) = error, code == 400 || code == 409 {
                do { try pendingStore.clear(account: account); state.pendingRetry = false }
                catch { state.error = WheelL10n.text("storageError") }
            }
            state.submitting = false
            show(error)
        }
    }
    /// Display-link timestamps accumulate only while the screen is visible and the scene is active.
    public func frame(at timestamp: TimeInterval) {
        guard timestamp.isFinite, let animation else { return }
        let delta = lastFrame.map { max(0, timestamp - $0) } ?? 0
        lastFrame = timestamp
        state.elapsed = min(GiftWheelMotion.duration, state.elapsed + delta)
        state.rotation = animation.start + (animation.target - animation.start) * GiftWheelMotion.progress(elapsed: state.elapsed)
        guard state.elapsed >= GiftWheelMotion.duration else { return }
        self.animation = nil; lastFrame = nil
        state.prize = animation.prize; state.spinning = false
        state.status?.quota = animation.prize.quota; state.status?.wallet = animation.prize.wallet
        setCountdown(animation.prize.quota.waitSeconds)
        if let account {
            do { try pendingStore.clear(account: account); state.pendingRetry = false }
            catch { state.error = WheelL10n.text("storageError") }
        }
        operation = Task { [weak self] in await self?.refresh() }
    }
    public func suspendAnimation() { lastFrame = nil }
    public func eraseCurrentAccount() throws {
        if let account { try pendingStore.clear(account: account) }
        activate(account: nil)
    }
    public func tick() async {
        guard !state.spinning, let deadline = waitDeadline else { return }
        state.waitSeconds = max(0, Int(ceil(deadline - now())))
        if state.waitSeconds == 0 {
            // Never grant a local right. Only a new status response can enable the button.
            waitDeadline = nil
            await refresh()
        }
    }
    private func setCountdown(_ seconds: Int) {
        state.waitSeconds = max(0, seconds)
        waitDeadline = seconds > 0 ? now() + Double(seconds) : nil
    }
    private func refreshWinners(account: String, generation: UUID) async {
        do {
            let winners = try await service.winners(account: account)
            guard self.generation == generation else { return }
            state.winners = winners; state.winnersError = false
        } catch {
            guard self.generation == generation else { return }
            state.winnersError = true
        }
    }
    private func show(_ error: Error) {
        if error is CancellationError { return }
        state.needsLogin = (error as? GiftWheelError) == .authenticationRequired
        state.error = (error as? GiftWheelError)?.errorDescription ?? WheelL10n.text("connectionError")
    }
}
