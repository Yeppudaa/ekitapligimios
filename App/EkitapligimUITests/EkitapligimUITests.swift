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
        XCTAssertTrue(tabBar.buttons["Katalog"].exists)
        XCTAssertTrue(tabBar.buttons["Yazarlar"].exists)
        XCTAssertTrue(tabBar.buttons["İstekler"].exists)

        tabBar.buttons["Katalog"].tap()
        XCTAssertTrue(app.navigationBars["Kitaplar"].waitForExistence(timeout: 5))

        // iPhone tab bars expose destinations after the fourth item through the
        // system overflow tab. Select it by position so the test is independent
        // of the simulator's localization of the system-provided "More" label.
        let overflowTab = tabBar.buttons.element(boundBy: 4)
        XCTAssertTrue(overflowTab.exists)
        overflowTab.tap()
        XCTAssertTrue(app.staticTexts["Forum"].waitForExistence(timeout: 5))
        let profileDestination = app.staticTexts["Profilim"]
        XCTAssertTrue(profileDestination.exists)
        profileDestination.tap()
        XCTAssertTrue(app.navigationBars["Profilim"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Giriş yap"].exists)
    }
}
