import XCTest

/// Exercises the real shell, including the menu that standalone screen fixtures do not contain.
/// Run on iPhone 11/13 and a 320 pt device. All requests use the existing offline transport.
@MainActor
final class ShellMenuLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 900
        XCUIDevice.shared.orientation = .portrait
    }

    func testRootMenusAndPageActionsHaveSeparateHitAreas() {
        auditRootActions(largeText: false)
    }

    func testRootMenusAndPageActionsHaveSeparateHitAreasWithAccessibilityText() {
        auditRootActions(largeText: true)
    }

    func testLiveRefreshStaysReachableAfterScrollingAndOpeningTheDrawer() {
        let app = launch("live")
        let menu = app.buttons["shell.menu"]
        let refresh = app.buttons["live.refresh"]
        assertSeparated(menu, refresh, in: app)
        refresh.tap()
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        scroll.swipeUp()
        assertSeparated(menu, refresh, in: app)
        XCTAssertTrue(app.navigationBars.firstMatch.buttons["shell.menu"].exists,
                      "The menu must be measured by the bar, not floating over page content")
        menu.tap()
        let close = app.buttons["modern-menu-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        assertSeparated(menu, refresh, in: app)
        refresh.tap()
        capture(app, "live-refresh-after-scroll-and-drawer")
        app.terminate()
    }

    func testHomeGenreCatalogAndBookDetailDoNotReceiveAFloatingMenu() {
        let app = launch("home")
        let genre = app.buttons["home.genre.6"]
        let home = app.scrollViews["home.scroll"]
        for _ in 0..<12 {
            if genre.isHittable { break }
            home.swipeUp()
        }
        XCTAssertTrue(genre.isHittable)
        genre.tap()
        let filters = app.buttons["catalog.filters"]
        let displayMode = app.buttons["catalog.displayMode"]
        assertSeparated(filters, displayMode, in: app)
        XCTAssertFalse(app.buttons["shell.menu"].exists,
                       "The root Home menu must not overlay a pushed catalog's controls")
        let catalog = app.scrollViews["catalog.scroll"]
        let book = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "catalog.book.")).firstMatch
        for _ in 0..<12 {
            if book.isHittable { break }
            catalog.swipeUp()
        }
        XCTAssertTrue(book.isHittable)
        book.tap()
        let back = app.buttons["book.detail.back"]
        let share = app.buttons["book.detail.share"]
        assertSeparated(back, share, in: app)
        XCTAssertFalse(app.buttons["shell.menu"].exists,
                       "The book's custom Back/Share bar must have no absolute shell overlay")
        capture(app, "home-genre-book-detail-header")
        back.tap()
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        XCTAssertTrue(filters.isHittable)
        app.terminate()
    }

    private func auditRootActions(largeText: Bool) {
        let screens: [(String, [String])] = [
            ("home", ["shell.home.premium"]),
            ("catalog", ["catalog.displayMode", "catalog.filters"]),
            ("agenda", ["agenda.refresh"]),
            ("live", ["live.refresh"]),
            ("requests", ["requests.create.open"]),
            ("profile", ["profile.edit"]),
            ("forum", [])
        ]
        for (screen, actionIDs) in screens {
            let app = launch(screen, largeText: largeText)
            let menu = app.buttons["shell.menu"]
            XCTAssertTrue(menu.waitForExistence(timeout: 8))
            assertContainedAndHittable(menu, in: app)
            if screen != "home" {
                XCTAssertTrue(app.navigationBars.firstMatch.buttons["shell.menu"].exists,
                              "\(screen) must place its menu inside the native navigation bar")
            }
            for id in actionIDs { assertSeparated(menu, app.buttons[id], in: app) }
            if screen == "catalog" {
                assertSeparated(app.buttons["catalog.displayMode"], app.buttons["catalog.filters"], in: app)
            }
            menu.tap()
            let close = app.buttons["modern-menu-close"]
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            assertContainedAndHittable(close, in: app)
            close.tap()
            XCTAssertTrue(menu.waitForExistence(timeout: 5))
            for id in actionIDs { assertSeparated(menu, app.buttons[id], in: app) }
            capture(app, "\(screen)-largeText-\(largeText)")
            app.terminate()
        }
    }

    private func launch(_ screen: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment = [
            "MODERN_PARITY_SCREEN": screen,
            "MODERN_PARITY_SHELL_NAVIGATION": "1",
            "MODERN_PARITY_LARGE_TEXT": largeText ? "1" : "0",
            "MODERN_PARITY_PLAY_AUDIO": "0"
        ]
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["modern-parity-error"].exists)
        let width = app.windows.firstMatch.frame.width
        XCTAssertGreaterThanOrEqual(width, 320)
        XCTAssertLessThanOrEqual(width, 430, "Use an iPhone simulator for this narrow-layout regression")
        return app
    }

    private func assertSeparated(_ first: XCUIElement, _ second: XCUIElement, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(first.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(second.waitForExistence(timeout: 8), file: file, line: line)
        assertContainedAndHittable(first, in: app, file: file, line: line)
        assertContainedAndHittable(second, in: app, file: file, line: line)
        let overlap = first.frame.intersection(second.frame)
        XCTAssertTrue(overlap.isNull || overlap.width * overlap.height < 1,
                      "Action hit areas overlap: \(first.identifier) \(first.frame), \(second.identifier) \(second.frame)",
                      file: file, line: line)
    }

    private func assertContainedAndHittable(_ element: XCUIElement, in app: XCUIApplication,
                                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.isHittable, element.identifier, file: file, line: line)
        let frame = element.frame
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(frame.width, 0, file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, window.minY - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, window.maxY + 1, file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "shell-menu-\(Int(app.windows.firstMatch.frame.width))pt-\(name)"
        image.lifetime = .keepAlways
        add(image)
    }
}
