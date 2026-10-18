import XCTest
import UIKit

/// Tests the real Home rails with locally intercepted tall/wide, delayed and failed cover URLs.
@MainActor
final class HomeBookRailUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        XCUIDevice.shared.orientation = .portrait
    }

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
        revealHorizontally(second, rail: rail, app: app)
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
            revealHorizontally(card, rail: rail, app: app)
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
        // A very tall accessible card need not fit as a whole; its visible cover must open it.
        element("home.book.cover.900041", app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["book.detail.back"].waitForExistence(timeout: 8))
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
        // Each accessibility frame query takes a simulator round trip; allow four complete
        // samples while retaining the stable-frame and geometry assertions below.
        let deadline = Date().addingTimeInterval(30)
        var previous: CardGeometry?
        var matches = 0
        while Date() < deadline {
            let card = app.buttons["home.bookRail.newest.book.\(id)"]
            let cover = element("home.book.cover.\(id)", app)
            let title = element("home.book.title.\(id)", app)
            let author = element("home.book.author.\(id)", app)
            let expectsAuthor = id != "900042" // This fixture deliberately omits its author.
            if card.exists && cover.exists && title.exists,
               finite(card.frame), finite(cover.frame), finite(title.frame),
               !expectsAuthor || (author.exists && finite(author.frame)) {
                let value = CardGeometry(card: card.frame, cover: cover.frame, title: title.frame,
                                         author: expectsAuthor ? author.frame : nil)
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

    private func finite(_ frame: CGRect) -> Bool {
        !frame.isEmpty && frame.minX.isFinite && frame.minY.isFinite &&
            frame.width.isFinite && frame.height.isFinite
    }

    private func revealHorizontally(_ card: XCUIElement, rail: XCUIElement, app: XCUIApplication) {
        for _ in 0..<20 {
            let viewport = rail.frame.intersection(app.frame).insetBy(dx: 8, dy: 8)
            let frame = card.exists ? card.frame : CGRect.null
            // Frame queries are safe for offscreen cards; activation-point queries are not.
            if finite(frame), frame.minX >= viewport.minX,
               frame.maxX <= viewport.maxX, card.isHittable { return }
            let moveRight = finite(frame) && frame.minX < viewport.minX
            let remaining = finite(frame)
                ? (moveRight ? viewport.minX - frame.minX : frame.maxX - viewport.maxX)
                : viewport.width
            let distance = min(max(remaining + 12, 40), viewport.width * 0.3)
            let direction: CGFloat = moveRight ? 1 : -1
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            let start = origin.withOffset(CGVector(dx: viewport.midX - direction * distance / 2 - app.frame.minX,
                                                   dy: viewport.midY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: viewport.midX + direction * distance / 2 - app.frame.minX,
                                                 dy: viewport.midY - app.frame.minY))
            // A slow drag with a final hold avoids flinging past the target. Correct either
            // direction when previous momentum has already moved the target to the left.
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        capture(app, "home-book-horizontal-unreachable-\(card.identifier)")
        XCTFail("The target card must be fully visible in its horizontal rail; frame=\(card.exists ? card.frame : .null), rail=\(rail.frame)")
    }

    private func reveal(_ card: XCUIElement, in app: XCUIApplication) throws {
        let scroll = app.scrollViews["home.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        let cover = element("home.book.cover.900041", app)
        for _ in 0..<80 {
            let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 8, dy: 8)
            let coverFrame = cover.exists ? cover.frame : CGRect.null
            let cardFrame = card.exists ? card.frame : CGRect.null
            // Normal cards fit as a whole. Very tall accessibility cards only need their
            // visible cover to fit, so that the navigation target can still be tapped.
            let target = finite(cardFrame) && cardFrame.height <= viewport.height ? cardFrame : coverFrame
            if finite(target), viewport.contains(target) { return }
            let above = finite(target) ? target.midY < viewport.midY :
                (finite(cardFrame) && cardFrame.minY < viewport.minY)
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: above ? 0.45 : 0.70))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: above ? 0.70 : 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture(app, "home-book-unreachable")
        XCTFail("Loaded newest book covers must be visible and reachable")
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
