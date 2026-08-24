import Foundation

/// Mirrors Android `bookAgendaRelativeTime` buckets and zero-timestamp copy.
public enum CommunityRelativeTimeFormatting {
    public static func format(
        timestampSeconds: Int,
        now: Date = Date(),
        dayCutoff: Int = 7
    ) -> String {
        if timestampSeconds <= 0 { return L10n.timeJustNow }
        let elapsed = max(0, Int(now.timeIntervalSince1970) - timestampSeconds)
        if elapsed < 60 { return L10n.timeJustNow }
        if elapsed < 3_600 { return L10n.timeMinutesAgo(elapsed / 60) }
        if elapsed < 86_400 { return L10n.timeHoursAgo(elapsed / 3_600) }
        let dayCount = elapsed / 86_400
        if dayCount < dayCutoff { return L10n.timeDaysAgo(dayCount) }
        return datedString(timestampSeconds: timestampSeconds)
    }

    private static func datedString(timestampSeconds: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestampSeconds)))
    }
}
