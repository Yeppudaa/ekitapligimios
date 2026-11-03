import XCTest

/// Offline layout evidence for the shipping screens. No purchase, login or playback is started.
/// Container bounds are automatic checks; screenshot review is still needed for clipped glyphs.
@MainActor
final class LayoutAuditUITests: XCTestCase {
    private let screens = [
        "home", "catalog", "library", "profile", "requests", "forum", "threads", "authors",
        "publishers", "agenda", "live", "chat", "audio", "audio-detail", "audio-library", "notifications"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 1_800
        XCUIDevice.shared.orientation = .portrait
    }

    func testPortraitScreensWithNormalText() {
        auditScreens(largeText: false)
    }

    func testPortraitScreensWithAccessibilityText() {
        auditScreens(largeText: true)
    }

    func testPortraitScreensWithAccessibilityTextInDarkAppearance() {
        auditScreens(largeText: true, dark: true)
    }

    func testDrawerCloseAndScrolledContentFitTheViewport() {
        for largeText in [false, true] {
            let app = launch("home", largeText: largeText)
            let menu = app.buttons["Menü"].firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 8))
            menu.tap()
            let close = app.buttons["modern-menu-close"]
            XCTAssertTrue(close.waitForExistence(timeout: 8))
            assertContained(close, in: app)
            capture(app, "menu-top-\(largeText)")
            let scroll = app.scrollViews["modern-menu-scroll"]
            XCTAssertTrue(scroll.exists)
            scroll.swipeUp()
            assertContained(close, in: app)
            XCTAssertTrue(close.isHittable)
            capture(app, "menu-scrolled-\(largeText)")
            close.tap()
            XCTAssertFalse(close.exists)
            app.terminate()
        }
    }

    private func auditScreens(largeText: Bool, dark: Bool = false) {
        for screen in screens {
            let app = launch(screen, largeText: largeText, dark: dark)
            let scroll = app.scrollViews.firstMatch
            XCTAssertTrue(scroll.waitForExistence(timeout: 10), "No native scroll viewport: \(screen)")
            assertContained(scroll, in: app)
            XCTAssertFalse(app.alerts.firstMatch.exists, "Unexpected alert: \(screen)")
            capture(app, "\(screen)-top-large\(largeText)-dark\(dark)")
            // Sample successive vertical positions without tapping a transaction or content action.
            // Nested horizontal rails may intentionally show partial cards; their children are not
            // incorrectly treated as overflowing the whole screen.
            for step in 1...3 {
                let viewport = app.scrollViews["modern-menu-scroll"].exists
                    ? app.scrollViews["modern-menu-scroll"] : scroll
                viewport.swipeUp()
                assertContained(scroll, in: app)
                capture(app, "\(screen)-scroll\(step)-large\(largeText)-dark\(dark)")
            }
            app.terminate()
        }
    }

    private func launch(_ screen: String, largeText: Bool, dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment = [
            "MODERN_PARITY_SCREEN": screen,
            "MODERN_PARITY_LARGE_TEXT": largeText ? "1" : "0",
            "MODERN_PARITY_DARK": dark ? "1" : "0",
            "MODERN_PARITY_PLAY_AUDIO": "0",
            "MODERN_PARITY_LONG_AGENDA": "1"
        ]
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["modern-parity-error"].exists)
        let width = app.windows.firstMatch.frame.width
        XCTAssertGreaterThanOrEqual(width, 320)
        XCTAssertLessThanOrEqual(width, 430, "Run this class on an iPhone, not an iPad")
        return app
    }

    private func assertContained(_ element: XCUIElement, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let frame = element.frame
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(frame.width, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1, file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "layout-\(Int(app.windows.firstMatch.frame.width))pt-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
