import XCTest

final class EkitapligimUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrimaryNavigationIsAvailableOffline() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertTrue(tabBar.buttons["Ana Sayfa"].exists)
        XCTAssertTrue(tabBar.buttons["Kitaplar"].exists)
        XCTAssertTrue(tabBar.buttons["Kitaplığım"].exists)
        XCTAssertTrue(tabBar.buttons["Topluluk"].exists)
        XCTAssertTrue(tabBar.buttons["Hesap"].exists)

        tabBar.buttons["Kitaplar"].tap()
        XCTAssertTrue(app.navigationBars["Kitaplar"].waitForExistence(timeout: 5))

        tabBar.buttons["Hesap"].tap()
        XCTAssertTrue(app.navigationBars["Hesap"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Giriş yap"].exists)
    }
}
