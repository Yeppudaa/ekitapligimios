import XCTest

final class EkitapligimUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        return app
    }

    func testPrimaryNavigationIsAvailableOffline() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertTrue(tabBar.buttons["Ana Sayfa"].exists)
        XCTAssertTrue(tabBar.buttons["Katalog"].exists)
        XCTAssertTrue(tabBar.buttons["Yazarlar"].exists)
        XCTAssertTrue(tabBar.buttons["İstekler"].exists)

        tabBar.buttons["Katalog"].tap()
        XCTAssertTrue(app.navigationBars["Kitaplar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kataloğu Keşfet"].waitForExistence(timeout: 5))

        tabBar.buttons["Yazarlar"].tap()
        XCTAssertTrue(app.navigationBars["Yazarlar"].waitForExistence(timeout: 5))

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

    func testDrawerRoutesPresentContentShells() throws {
        let app = launchApp()
        let menuButton = app.buttons["Menü"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        tapDrawerItem(app, titled: "Canlı Akış")
        XCTAssertTrue(app.navigationBars["Canlı Aktivite"].waitForExistence(timeout: 5))
        dismissSheet(app)

        menuButton.tap()
        tapDrawerItem(app, titled: "Yayınevleri")
        XCTAssertTrue(app.navigationBars["Yayınevleri"].waitForExistence(timeout: 5))
        dismissSheet(app)
    }

    func testCatalogAndAuthorsScreensAreNotBlank() throws {
        let app = launchApp()
        let tabBar = app.tabBars.firstMatch

        tabBar.buttons["Katalog"].tap()
        XCTAssertTrue(app.staticTexts["Kataloğu Keşfet"].waitForExistence(timeout: 5))

        tabBar.buttons["Yazarlar"].tap()
        XCTAssertTrue(app.navigationBars["Yazarlar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["EmptyView"].exists)
    }

    private func tapDrawerItem(_ app: XCUIApplication, titled title: String) {
        let item = app.staticTexts[title].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }

    private func dismissSheet(_ app: XCUIApplication) {
        let close = app.buttons["Kapat"]
        if close.waitForExistence(timeout: 3) {
            close.tap()
        }
    }
}
