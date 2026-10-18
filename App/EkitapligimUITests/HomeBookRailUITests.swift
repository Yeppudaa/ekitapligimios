import XCTest
import UIKit

/// Tests the real Home rails with locally intercepted tall/wide, delayed and failed cover URLs.
@MainActor
final class HomeBookRailUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testNormalCardsKeepCoverRatioAndCompactMetadataWhileScrolling() async throws {
        let app = launch()
        defer { app.terminate() }
        let first = app.buttons["home.bookRail.newest.book.900041"]
        try reveal(first, in: app)
        let before = try await geometry(id: "900041", app: app)
        check(before, normal: true)
        let rail = app.scrollViews["home.bookRail.newest"]
        XCTAssertTrue(rail.exists)
        let second = app.buttons["home.bookRail.newest.book.900042"]
        for _ in 0..<4 {
            if second.isHittable && second.frame.maxX <= app.frame.maxX - 8 { break }
            rail.swipeLeft()
        }
        let next = try await geometry(id: "900042", app: app)
        check(next, normal: true)
        XCTAssertEqual(next.card.width, before.card.width, accuracy: 1)
        XCTAssertEqual(next.card.height, before.card.height, accuracy: 1)
        XCTAssertEqual(next.cover.height, before.cover.height, accuracy: 1)
        capture(app, "home-newest-wide-cover-and-long-title")
        second.tap()
        let back = app.buttons["book.detail.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 8))
        back.tap()
        XCTAssertTrue(app.scrollViews["home.scroll"].waitForExistence(timeout: 5))
    }

    func testFailedAndDelayedCoversKeepTheirCardGeometry() async throws {
        let app = launch()
        defer { app.terminate() }
        let first = app.buttons["home.bookRail.newest.book.900041"]
        try reveal(first, in: app)
        let rail = app.scrollViews["home.bookRail.newest"]
        for id in ["900043", "900044"] {
            let card = app.buttons["home.bookRail.newest.book.\(id)"]
            for _ in 0..<8 {
                if card.isHittable && card.frame.maxX <= app.frame.maxX - 8 { break }
                rail.swipeLeft()
            }
            let before = try await geometry(id: id, app: app)
            check(before, normal: true)
            try await Task.sleep(nanoseconds: 2_300_000_000)
            let after = try await geometry(id: id, app: app)
            check(after, normal: true)
            XCTAssertEqual(before.card.height, after.card.height, accuracy: 1)
            XCTAssertEqual(before.cover.height, after.cover.height, accuracy: 1)
        }
        capture(app, "home-newest-failed-and-delayed-covers")
    }

    func testAccessibilityCardsGrowForTextWithoutStretchingTheCover() async throws {
        let app = launch(large: true)
        defer { app.terminate() }
        let card = app.buttons["home.bookRail.newest.book.900041"]
        try reveal(card, in: app)
        let measured = try await geometry(id: "900041", app: app)
        check(measured, normal: false)
        let title = element("home.book.title.900041", app)
        XCTAssertTrue(title.exists)
        XCTAssertGreaterThan(title.frame.height, 0)
        capture(app, "home-newest-accessibility3")
    }

    private func launch(large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = "home"
        app.launchEnvironment["MODERN_PARITY_HOME_COVERS"] = "1"
        app.launchEnvironment["MODERN_PARITY_CARD_SIZING"] = "1"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = large ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 10))
        return app
    }

    private struct CardGeometry { let card: CGRect; let cover: CGRect; let title: CGRect; let author: CGRect? }

    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func geometry(id: String, app: XCUIApplication) async throws -> CardGeometry {
        let deadline = Date().addingTimeInterval(8)
        var previous: CardGeometry?
        var matches = 0
        while Date() < deadline {
            let card = app.buttons["home.bookRail.newest.book.\(id)"]
            let cover = element("home.book.cover.\(id)", app)
            let title = element("home.book.title.\(id)", app)
            let author = element("home.book.author.\(id)", app)
            if card.exists && cover.exists && title.exists && !cover.frame.isEmpty {
                let value = CardGeometry(card: card.frame, cover: cover.frame, title: title.frame,
                                         author: author.exists ? author.frame : nil)
                if let previous, abs(previous.card.height - value.card.height) < 0.5,
                   abs(previous.cover.height - value.cover.height) < 0.5 { matches += 1 }
                else { matches = 0 }
                if matches >= 3 { return value }
                previous = value
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        capture(app, "home-book-geometry-failure-\(id)")
        XCTFail("Actual card, cover and metadata must have stable native frames")
        throw GeometryFailure.unavailable
    }

    private func check(_ value: CardGeometry, normal: Bool, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(value.cover.height, (value.cover.width - 20) * 1.48 + 20, accuracy: 1,
                       "Cover shape must be independent of the downloaded image", file: file, line: line)
        XCTAssertLessThan(value.cover.maxY, value.title.minY, file: file, line: line)
        XCTAssertGreaterThanOrEqual(value.cover.minY, value.card.minY, file: file, line: line)
        if let author = value.author {
            XCTAssertLessThanOrEqual(author.maxY, value.card.maxY, file: file, line: line)
            XCTAssertGreaterThanOrEqual(author.minY, value.title.minY, file: file, line: line)
            if normal {
                let oneLine = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
                XCTAssertLessThanOrEqual(author.minY - value.title.maxY, oneLine + 10,
                                         "The author must follow the title without an empty text block", file: file, line: line)
            }
        }
        if normal {
            // The non-cover part is only two title lines, two metadata lines, padding and gaps.
            let copy = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight * 2 +
                UIFont.preferredFont(forTextStyle: .caption1).lineHeight +
                UIFont.preferredFont(forTextStyle: .caption2).lineHeight
            XCTAssertLessThanOrEqual(value.card.height - value.cover.height, copy + 48,
                                     "No parent height may turn a book into a tall empty card", file: file, line: line)
        }
    }

    private func reveal(_ card: XCUIElement, in app: XCUIApplication) throws {
        let scroll = app.scrollViews["home.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for _ in 0..<30 {
            if card.isHittable { return }
            scroll.swipeUp()
        }
        capture(app, "home-book-unreachable")
        XCTFail("Loaded newest books must be reachable")
        throw GeometryFailure.unavailable
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private enum GeometryFailure: Error { case unavailable }
}
