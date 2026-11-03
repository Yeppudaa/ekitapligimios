import Foundation

/// The Android ReaderOpeningTransition clock, in milliseconds. Animation progress is
/// decorative and must never be used as download or document-preparation progress.
public struct ReaderOpeningFrame: Equatable, Sendable {
    public static let handoffMilliseconds = 1_640.0
    public static let durationMilliseconds = 2_160.0
    public static let reducedMotionMilliseconds = 180.0

    public let lift: Double
    public let hinge: Double
    public let coverAngle: Double
    public let coverOpacity: Double
    public let coverShadeOpacity: Double
    public let paperVisible: Bool
    public let paperExpansion: Double
    public let backdropOpacity: Double
    public let overlayOpacity: Double

    public init(elapsedMilliseconds: Double) {
        let elapsed = elapsedMilliseconds.isNaN ? 0 : max(0, elapsedMilliseconds)
        lift = Self.curve(Self.unit(elapsed / 560), 0.3, 0.7, 0.2, 1)
        hinge = Self.curve(Self.unit((elapsed - 560) / 820), 0.45, 0.05, 0.25, 1)
        coverAngle = hinge <= 0.8 ? -165 * hinge / 0.8 : -165 - 13 * (hinge - 0.8) / 0.2
        coverOpacity = Self.unit(1 - (hinge - 0.45) / 0.23)
        coverShadeOpacity = Self.unit(hinge / 0.85) * 0.35
        paperVisible = elapsed >= 560
        paperExpansion = Self.curve(Self.unit((elapsed - 1_120) / 520), 0.3, 0.7, 0.2, 1)
        backdropOpacity = elapsed >= Self.handoffMilliseconds ? 0 :
            0.82 * Self.curve(Self.unit(elapsed / 420), 0.42, 0, 1, 1)
        let fade = 1 - Self.unit((elapsed - 1_920) / 240)
        overlayOpacity = fade * fade
    }

    private static func unit(_ value: Double) -> Double { min(1, max(0, value)) }

    /// Invert the Bezier x coordinate before sampling y, as Compose Easing.transform does.
    private static func curve(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        guard x > 0, x < 1 else { return x }
        func sample(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let inverse = 1 - t
            return 3 * inverse * inverse * t * a + 3 * inverse * t * t * b + t * t * t
        }
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<24 {
            let middle = (lower + upper) / 2
            if sample(middle, x1, x2) < x { lower = middle } else { upper = middle }
        }
        return sample((lower + upper) / 2, y1, y2)
    }
}

/// A presentation-scoped, cancellable clock. No delayed route change can survive
/// dismissal, account replacement, or a cancelled SwiftUI task.
@MainActor
public final class ReaderOpeningSequence {
    public enum Phase: Equatable, Sendable {
        case idle, opening, revealing, finished, cancelled
        public var showsReader: Bool { self == .revealing || self == .finished }
    }

    public private(set) var phase: Phase = .idle
    public private(set) var reducesMotion = false
    private var start: ContinuousClock.Instant?
    private var revealStart: ContinuousClock.Instant?
    private let sleep: @MainActor (Duration) async throws -> Void
    private var onPhaseChange: (@MainActor (Phase) -> Void)?

    public init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    public var elapsedMilliseconds: Double {
        guard let start else { return 0 }
        let components = (revealStart ?? start).duration(to: .now).components
        let elapsed = max(0, Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15)
        if reducesMotion { return min(ReaderOpeningFrame.reducedMotionMilliseconds, elapsed) }
        if revealStart != nil { return min(ReaderOpeningFrame.durationMilliseconds, 1_640 + elapsed) }
        // Never let dropped frames fade the paper before the reader has actually mounted.
        return min(ReaderOpeningFrame.handoffMilliseconds, elapsed)
    }

    public func run(reduceMotion: Bool, onPhaseChange: @escaping @MainActor (Phase) -> Void) async {
        guard phase == .idle else { onPhaseChange(phase); return }
        guard !Task.isCancelled else { cancel(); onPhaseChange(phase); return }
        self.onPhaseChange = onPhaseChange
        defer { self.onPhaseChange = nil }
        reducesMotion = reduceMotion
        start = .now
        changePhase(.opening)
        do {
            guard phase == .opening else { return }
            if !reduceMotion { try await sleep(.milliseconds(1_640)) }
            try Task.checkCancellation()
            guard phase == .opening else { return }
            revealStart = .now
            changePhase(.revealing)
            guard phase == .revealing else { return }
            try await sleep(.milliseconds(reduceMotion ? 180 : 520))
            try Task.checkCancellation()
            guard phase == .revealing else { return }
            changePhase(.finished)
        } catch {
            // A reader-owned full-screen notice can cancel the parent's SwiftUI task.
            // Once handed off, keep that same reader mounted and only settle the artwork.
            if phase == .revealing { finish() }
            else { cancel() }
        }
    }

    public func cancel() {
        guard phase != .finished, phase != .cancelled else { return }
        changePhase(.cancelled)
    }

    /// Backgrounding or enabling Reduce Motion settles the existing presentation immediately.
    public func finish() {
        guard phase != .finished, phase != .cancelled else { return }
        changePhase(.finished)
    }

    /// Disappearance may mean a child presentation, rather than closing the reader.
    public func presentationDisappeared() {
        if phase.showsReader { finish() }
        else { cancel() }
    }

    private func changePhase(_ phase: Phase) {
        self.phase = phase
        onPhaseChange?(phase)
    }
}
