import XCTest

/// Uses the shipping root navigation with offline, read-only catalog responses.
@MainActor
final class CatalogSearchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testCatalogSearchIsVisibleWithoutScrollingAndCanSearchAndClear() {
        let app = launch(screen: "catalog")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable, "Search must be visible when Books first opens")
        search.tap()
        search.typeText("no-matching-book-20261022\n")
        XCTAssertTrue(app.staticTexts["Kitap bulunamadı"].waitForExistence(timeout: 8),
                      "Submitting search must send the query to the catalog API")

        let clear = search.buttons.firstMatch
        XCTAssertTrue(clear.isHittable)
        clear.tap()
        let restoredBook = app.buttons["catalog.book.900042"]
        for _ in 0..<8 {
            if restoredBook.waitForExistence(timeout: 1) { break }
            app.scrollViews["catalog.scroll"].swipeUp()
        }
        XCTAssertTrue(restoredBook.exists,
                      "Clearing search must reload the unfiltered catalog")
    }

    func testHomeSearchOpensCatalogReadyForTyping() {
        let app = launch(screen: "home")
        let shortcut = app.buttons["home.search"]
        let scroll = app.scrollViews["home.scroll"]
        for _ in 0..<8 {
            if shortcut.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(shortcut.isHittable)
        shortcut.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["catalog.scroll"].exists)
        XCTAssertFalse(app.scrollViews["library.scroll"].exists)
        // Do not tap the field: the home shortcut must activate it itself.
        search.typeText("no-matching-book-20261022\n")
        XCTAssertTrue(app.staticTexts["Kitap bulunamadı"].waitForExistence(timeout: 8))
    }

    func testSearchRemainsVisibleWithAccessibilityTextAndAfterSwitchingTabs() {
        let app = launch(screen: "catalog", largeText: true)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable)
        app.buttons["primary-tab-home"].tap()
        app.buttons["primary-tab-catalog"].tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable)
    }

    private func launch(screen: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = largeText ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_GUEST"] = "1"
        app.launchEnvironment["MODERN_PARITY_PLAY_AUDIO"] = "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 12))
        return app
    }
}
