import XCTest
@testable import EkitapligimCore

final class AndroidRelativeTimeTests: XCTestCase {
    func testAgendaRelativeTimeMatchesAndroidBookAgendaScreen() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(CommunityRelativeTimeFormatting.format(timestampSeconds: 0, now: now), L10n.timeJustNow)
        XCTAssertEqual(CommunityRelativeTimeFormatting.format(timestampSeconds: -1, now: now), L10n.timeJustNow)
        XCTAssertEqual(CommunityRelativeTimeFormatting.format(timestampSeconds: 1_700_000_000 - 30, now: now), L10n.timeJustNow)
        XCTAssertEqual(CommunityRelativeTimeFormatting.format(timestampSeconds: 1_700_000_000 - 5 * 60, now: now), L10n.timeMinutesAgo(5))
        XCTAssertEqual(CommunityRelativeTimeFormatting.format(timestampSeconds: 1_700_000_000 - 2 * 3_600, now: now), L10n.timeHoursAgo(2))
        XCTAssertEqual(CommunityRelativeTimeFormatting.format(timestampSeconds: 1_700_000_000 - 3 * 86_400, now: now), L10n.timeDaysAgo(3))

        let aged = 1_700_000_000 - 10 * 86_400
        let formatted = CommunityRelativeTimeFormatting.format(timestampSeconds: aged, now: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy"
        XCTAssertEqual(formatted, formatter.string(from: Date(timeIntervalSince1970: TimeInterval(aged))))
        XCTAssertTrue(formatted.contains("2023") || formatted.contains("23"))
    }
}
