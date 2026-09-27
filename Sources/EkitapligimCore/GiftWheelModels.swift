import Foundation

public enum WheelL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "GiftWheel", bundle: .module, comment: "Gift wheel")
    }
    public static func format(_ key: String, _ value: Int) -> String {
        String(format: text(key), value)
    }
}

public struct GiftWheelSegmentDTO: Codable, Equatable, Sendable {
    public let index: Int
    public let days: Int
    public var colorHex: UInt32 {
        switch days {
        case 1: 0x7860C9
        case 3: 0xE78B70
        case 7: 0x339E99
        case 14: 0x5985CE
        case 30: 0xEFC05F
        default: 0xE6E2F1
        }
    }
    public var label: String { days == 0 ? WheelL10n.text("tryAgain") : WheelL10n.format("days", days) }
    public static let defaults = (0..<12).map { GiftWheelSegmentDTO(index: $0, days: [0, 1, 3, 7, 14, 30][$0 % 6]) }
    public static func validate(_ segments: [Self]) throws {
        guard segments.count == 12,
              segments.enumerated().allSatisfy({ $0.offset == $0.element.index }),
              segments.map(\.days).sorted() == defaults.map(\.days).sorted() else {
            throw GiftWheelError.invalidResponse
        }
    }
}

public struct GiftWheelWalletDTO: Codable, Equatable, Sendable {
    public let seconds: Int
    public let running: Bool
    public static let empty = Self(seconds: 0, running: false)
    public var label: String {
        seconds > 0 && seconds < 86_400 ? WheelL10n.text("lessThanDay") : WheelL10n.format("days", max(0, seconds) / 86_400)
    }
    public var description: String {
        WheelL10n.text(running ? "walletRunning" : (seconds > 0 ? "walletPending" : "walletEmpty"))
    }
}

public struct GiftWheelQuotaDTO: Codable, Equatable, Sendable {
    public let limit: Int
    public let remaining: Int
    public let waitSeconds: Int
}

public struct GiftWheelEntryDTO: Codable, Equatable, Sendable {
    public let username: String?
    public let days: Int
    public let createdAt: TimeInterval
    public let refunded: Bool?
}

public struct GiftWheelStatusDTO: Codable, Equatable, Sendable {
    public let apiVersion: Int
    public let ready: Bool
    public let availability: String
    public let revision: Int
    public let segments: [GiftWheelSegmentDTO]
    public var quota: GiftWheelQuotaDTO
    public var wallet: GiftWheelWalletDTO
    public let history: [GiftWheelEntryDTO]
    public var canSpin: Bool { ready && availability == "ready" && quota.remaining != 0 && quota.waitSeconds <= 0 }
    public func validated() throws -> Self {
        guard apiVersion == 1, revision > 0 else { throw GiftWheelError.invalidResponse }
        try GiftWheelSegmentDTO.validate(segments)
        return self
    }
}

public struct GiftWheelSpinDTO: Codable, Equatable, Sendable {
    public struct ResultDTO: Codable, Equatable, Sendable {
        public let prizeIndex: Int
        public let days: Int
        public let promoted: Bool
        public let replayed: Bool
    }
    public let apiVersion: Int
    public let result: ResultDTO
    public let quota: GiftWheelQuotaDTO
    public let wallet: GiftWheelWalletDTO
    public func displayIndex(in segments: [GiftWheelSegmentDTO]) throws -> Int {
        try GiftWheelSegmentDTO.validate(segments)
        guard apiVersion == 1 else { throw GiftWheelError.invalidResponse }
        if segments.indices.contains(result.prizeIndex), segments[result.prizeIndex].days == result.days { return result.prizeIndex }
        // The server can replay an earlier revision, but the shown award must still match its days.
        if result.replayed, let index = segments.firstIndex(where: { $0.days == result.days }) { return index }
        throw GiftWheelError.invalidResponse
    }
    public var message: String {
        result.days == 0 ? WheelL10n.text("noPrize") : WheelL10n.format(result.promoted ? "promoted" : "won", result.days)
    }
}

public struct GiftWheelWinnersDTO: Codable, Sendable {
    public let apiVersion: Int
    public let winners: [GiftWheelEntryDTO]
}

public enum GiftWheelError: Error, LocalizedError, Equatable {
    case authenticationRequired, invalidResponse, invalidConfiguration
    case server(Int, String?)
    public var errorDescription: String? {
        switch self {
        case .authenticationRequired: WheelL10n.text("sessionRequired")
        case .invalidResponse: WheelL10n.text("updated")
        case .invalidConfiguration: WheelL10n.text("unavailable")
        case .server(_, let message): message?.isEmpty == false ? message : WheelL10n.text("unavailable")
        }
    }
}

public enum GiftWheelMotion {
    public static let duration: TimeInterval = 10
    public static let initialRotation: Double = -15
    public static func target(from start: Double, index: Int) throws -> Double {
        guard (0..<12).contains(index), start.isFinite else { throw GiftWheelError.invalidResponse }
        let normalized = (start.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let target = 360 - (Double(index) + 0.5) * 30
        return start + 9 * 360 + (target - normalized + 360).truncatingRemainder(dividingBy: 360)
    }
    /// Android's cubic-bezier(.12, .7, .12, 1), driven by elapsed frame time, not an OS animation scale.
    public static func progress(elapsed: TimeInterval) -> Double {
        let x = min(1, max(0, elapsed / duration))
        if x == 0 || x == 1 { return x }
        var low = 0.0, high = 1.0
        for _ in 0..<28 {
            let t = (low + high) / 2
            let sample = 3 * (1-t) * (1-t) * t * 0.12 + 3 * (1-t) * t * t * 0.12 + t * t * t
            if sample < x { low = t } else { high = t }
        }
        let t = (low + high) / 2
        return 3 * (1-t) * (1-t) * t * 0.7 + 3 * (1-t) * t * t + t * t * t
    }
}
