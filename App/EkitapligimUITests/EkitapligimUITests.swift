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
        let usesCompactTabBar = tabBar.waitForExistence(timeout: 5)
        let primaryNavigation = usesCompactTabBar ? tabBar.buttons : app.buttons
        XCTAssertTrue(primaryNavigation["Ana Sayfa"].waitForExistence(timeout: 10))
        XCTAssertTrue(primaryNavigation["Katalog"].exists)
        XCTAssertTrue(primaryNavigation["Yazarlar"].exists)
        XCTAssertTrue(primaryNavigation["İstekler"].exists)

        selectPrimaryDestination(app, titled: "Katalog")
        XCTAssertTrue(app.navigationBars["Kitaplar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kataloğu Keşfet"].waitForExistence(timeout: 5))

        selectPrimaryDestination(app, titled: "Yazarlar")
        XCTAssertTrue(app.navigationBars["Yazarlar"].waitForExistence(timeout: 5))

        if usesCompactTabBar {
            let overflowTab = tabBar.buttons.element(boundBy: 4)
            XCTAssertTrue(overflowTab.exists)
            overflowTab.tap()
            XCTAssertTrue(app.staticTexts["Forum"].waitForExistence(timeout: 5))
            let profileDestination = app.staticTexts["Profilim"]
            XCTAssertTrue(profileDestination.exists)
            profileDestination.tap()
            XCTAssertTrue(app.navigationBars["Profilim"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Giriş yap"].exists)
        } else {
            let menuButton = app.buttons["Menü"]
            XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
            menuButton.tap()
            let login = app.buttons["Giriş yap"]
            XCTAssertTrue(login.waitForExistence(timeout: 5))
            login.tap()
            XCTAssertTrue(app.navigationBars["Giriş"].waitForExistence(timeout: 5))
        }
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

        selectPrimaryDestination(app, titled: "Katalog")
        XCTAssertTrue(app.staticTexts["Kataloğu Keşfet"].waitForExistence(timeout: 5))

        selectPrimaryDestination(app, titled: "Yazarlar")
        XCTAssertTrue(app.navigationBars["Yazarlar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["EmptyView"].exists)
    }

    private func selectPrimaryDestination(_ app: XCUIApplication, titled title: String) {
        let tabBarButton = app.tabBars.firstMatch.buttons[title]
        if tabBarButton.waitForExistence(timeout: 2) {
            tabBarButton.tap()
            return
        }

        let adaptiveTabButton = app.buttons[title].firstMatch
        XCTAssertTrue(adaptiveTabButton.waitForExistence(timeout: 8))
        adaptiveTabButton.tap()
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
