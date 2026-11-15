import Foundation

/// Read-only presentation of the server's request allowance. Never grants membership or quota.
public struct BookRequestQuotaDTO: Decodable, Equatable, Sendable {
    public let isPremium: Bool
    public let limit: Int
    public let used: Int
    public let remaining: Int
    public let canRequest: Bool
    public let resetsAt: Int
    public let timezone: String

    public var explanation: BookRequestAccessPresentation? {
        if !isPremium { return .membership }
        if !canRequest && remaining == 0 && limit > 0 { return .exhausted(self) }
        return nil
    }
}

public enum BookRequestAccessPresentation: Equatable, Sendable, Identifiable {
    case membership
    case exhausted(BookRequestQuotaDTO)

    public var id: String {
        switch self { case .membership: "membership"; case .exhausted: "exhausted" }
    }

    public var quota: BookRequestQuotaDTO? {
        if case .exhausted(let value) = self { return value }
        return nil
    }

    public func renewalLabel(locale: Locale = .current) -> String? {
        guard let quota, quota.resetsAt > 0, let zone = TimeZone(identifier: quota.timezone) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(quota.resetsAt)))
    }
}
