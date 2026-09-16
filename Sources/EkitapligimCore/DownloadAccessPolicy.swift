import Foundation

public enum DownloadAccessDecision: Equatable, Sendable {
    case allowed
    case loginRequired
    case premiumRequired
    case dailyLimitReached
    case unavailable
}

public enum DownloadAccessPolicy {
    /// Standard members have no download quota. Treat a denied download as a
    /// premium upgrade, not a "limit full" message from the backend.
    public static func decision(
        isSignedIn: Bool,
        isPremium: Bool,
        access: ReaderAccessDTO?
    ) -> DownloadAccessDecision {
        guard isSignedIn else { return .loginRequired }
        if access?.canDownload == true { return .allowed }
        if !isPremium { return .premiumRequired }

        let code = access?.denialCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        switch code {
        case "LOGIN_REQUIRED":
            return .loginRequired
        case "PREMIUM_REQUIRED", "SUBSCRIPTION_REQUIRED", "PREMIUM_ONLY":
            return .premiumRequired
        case "DAILY_DOWNLOAD_LIMIT":
            return .dailyLimitReached
        default:
            break
        }

        if let quota = access?.dailyDownload, !quota.isUnlimited {
            if quota.limit <= 0 { return .premiumRequired }
            if !quota.isAllowed { return .dailyLimitReached }
        }
        return .unavailable
    }
}
