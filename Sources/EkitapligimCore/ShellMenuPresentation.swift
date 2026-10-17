import Foundation

/// Presentation only. Membership truth continues to come from the existing subscription state.
public struct PremiumMenuPresentation: Equatable, Sendable {
    public enum Detail: Equatable, Sendable { case promotion, active, days(Int) }
    public let isActive: Bool
    public let detail: Detail

    public init(isSignedIn: Bool, isPremium: Bool, remainingDays: Int?) {
        isActive = isSignedIn && isPremium
        if !isActive { detail = .promotion }
        else if let remainingDays, remainingDays > 0 { detail = .days(remainingDays) }
        else { detail = .active }
    }
}

public enum ShellMenuSelection {
    public static func matches(item: AppRoute, current: AppRoute) -> Bool {
        switch (item, current) {
        case (.catalog, .bookDetail), (.catalog, .reader): return true
        case (.audiobooks, .audiobook), (.audiobooks, .audioLibrary), (.audiobooks, .audioPlayer): return true
        case (.bookAgenda, .bookAgendaPost): return true
        case (.chat, .chatRoom): return true
        case (.forum, .forumDetail), (.forum, .thread): return true
        case (.members, .member): return true
        case (.messages, .conversation): return true
        case (.aiAssistant, .aiAssistant), (.aiAssistant, .aiCollections): return true
        case (.library, .library): return true
        default: return item == current
        }
    }

    public static func badge(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 99 ? "99+" : String(count)
    }
}
