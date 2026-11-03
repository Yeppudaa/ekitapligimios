import XCTest

@MainActor
final class DirectoryDesignUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ screen: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DIRECTORY_PAGES"] = "1"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 15))
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<14 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBothDirectoriesRecoverFromEmptySearchAndKeepInlineSearchUsable() {
        for screen in ["authors", "publishers"] {
            let app = launch(screen)
            capture(app, "\(screen)-scenic-header")
            let search = app.textFields["directory.search"]
            reveal(search, app: app); search.tap(); search.typeText("no-matching-directory-entry")
            let clear = app.buttons["directory.clearSearch"]
            XCTAssertTrue(clear.waitForExistence(timeout: 5)); clear.tap()
            app.buttons["Tamam"].firstMatch.tap()
            let first = app.buttons["directory.item.950100"]
            XCTAssertTrue(first.waitForExistence(timeout: 10))
            reveal(first, app: app)
            capture(app, "\(screen)-cards-and-filters")
            XCTAssertTrue(app.buttons["directory.loadMore"].exists)
            app.terminate()
        }
    }

    func testLargeTextKeepsAllAndTurkishLettersReachable() throws {
        for screen in ["authors", "publishers"] {
            let app = launch(screen, largeText: true)
            capture(app, "\(screen)-large-text-header")
            let all = app.buttons["directory.letter.#"]
            reveal(all, app: app)
            XCTAssertEqual(all.label, "Tümü")
            XCTAssertGreaterThanOrEqual(all.frame.height, 44)
            let alphabet = app.scrollViews["directory.alphabet"]
            let letter = app.buttons["directory.letter.İ"]
            for _ in 0..<14 {
                if letter.exists && letter.isHittable { break }
                alphabet.swipeLeft()
            }
            XCTAssertTrue(letter.isHittable); letter.tap()
            XCTAssertGreaterThanOrEqual(letter.frame.height, 44)
            capture(app, "\(screen)-large-text-filter")
            try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
            app.terminate()
        }
    }
}
