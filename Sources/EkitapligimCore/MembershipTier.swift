import Foundation

/// Display-only membership identity sent by the server. It never grants access or entitlements.
public enum MembershipTier: String, Equatable, Sendable {
    case member
    case premium
    case vip

    /// Matches the Android client: "premium" and "vip_supporter" are the only non-member values.
    public static func fromWire(_ value: String?) -> MembershipTier {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "premium": return .premium
        case "vip_supporter": return .vip
        default: return .member
        }
    }

    /// Emoji shown in front of names, identical to Android (👑 Premium, 💎 VIP).
    public var namePrefix: String {
        switch self {
        case .member: return ""
        case .premium: return "👑 "
        case .vip: return "💎 "
        }
    }

    public var emoji: String { namePrefix.trimmingCharacters(in: .whitespaces) }

    public static let vipPremiumName = "VIP Premium"
}

public enum VipL10n {
    public static func text(_ key: String) -> String {
        NSLocalizedString(key, tableName: "VipPremium", bundle: .module, comment: "VIP Premium membership")
    }
}
