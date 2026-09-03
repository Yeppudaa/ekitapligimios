import XCTest

final class EkitapligimUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-AppleLanguages", "(tr)",
            "-AppleLocale", "tr_TR"
        ]
        app.launch()
        return app
    }

    func testPrimaryNavigationIsAvailableOffline() throws {
        let app = launchApp()
        let primaryNavigation = app.buttons
        XCTAssertTrue(primaryNavigation["Ana sayfa"].waitForExistence(timeout: 10))
        XCTAssertTrue(primaryNavigation["Kitaplar"].exists)
        XCTAssertTrue(primaryNavigation["Gündem"].exists)
        XCTAssertTrue(primaryNavigation["Akış"].exists)
        XCTAssertTrue(primaryNavigation["İstekler"].exists)
        XCTAssertTrue(primaryNavigation["Profil"].exists)

        selectPrimaryDestination(app, titled: "Kitaplar")
        XCTAssertTrue(app.navigationBars["Kitaplar"].waitForExistence(timeout: 5))

        selectPrimaryDestination(app, titled: "Gündem")
        XCTAssertTrue(app.navigationBars["Kitap Gündemi"].waitForExistence(timeout: 5))

        selectPrimaryDestination(app, titled: "Akış")
        XCTAssertTrue(app.navigationBars["Canlı Aktivite"].waitForExistence(timeout: 5))

        selectPrimaryDestination(app, titled: "İstekler")
        XCTAssertTrue(app.navigationBars["Kitap İstekleri"].waitForExistence(timeout: 5))

        selectPrimaryDestination(app, titled: "Profil")
        XCTAssertTrue(app.navigationBars["Profilim"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Giriş yap"].exists)
    }

    func testGoogleSignInAndRegistrationControlsAreAvailable() throws {
        let app = launchApp()
        selectPrimaryDestination(app, titled: "Profil")
        let signIn = app.buttons["Giriş yap"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        XCTAssertTrue(app.buttons["Google ile giriş"].waitForExistence(timeout: 5))
        app.buttons["Henüz hesabınız yok mu? Kayıt olun"].tap()
        XCTAssertTrue(app.buttons["Google ile kayıt ol"].waitForExistence(timeout: 5))
    }

    func testDrawerRoutesPresentContentShells() throws {
        let app = launchApp()
        let menuButton = app.buttons["Menü"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        tapDrawerItem(app, titled: "Forum")
        XCTAssertTrue(app.navigationBars["Topluluk"].waitForExistence(timeout: 5))
        dismissSheet(app)

        menuButton.tap()
        tapDrawerItem(app, titled: "Yayınevleri")
        XCTAssertTrue(app.navigationBars["Yayınevleri"].waitForExistence(timeout: 5))
        dismissSheet(app)
    }

    func testCatalogAndAuthorsScreensAreNotBlank() throws {
        let app = launchApp()
        selectPrimaryDestination(app, titled: "Kitaplar")
        XCTAssertTrue(
            app.navigationBars["Kitaplar"].waitForExistence(timeout: 5)
                || app.staticTexts["Kataloğu Keşfet"].waitForExistence(timeout: 5)
        )

        let menuButton = app.buttons["Menü"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()
        tapDrawerItem(app, titled: "Yazarlar")
        XCTAssertTrue(app.navigationBars["Yazarlar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["EmptyView"].exists)
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Menü"].waitForExistence(timeout: 15))
        sleep(8)
        keepScreenshot(named: "01-home")

        selectPrimaryDestination(app, titled: "Kitaplar")
        XCTAssertTrue(app.navigationBars["Kitaplar"].waitForExistence(timeout: 10))
        sleep(4)
        keepScreenshot(named: "02-catalog")

        selectPrimaryDestination(app, titled: "Gündem")
        XCTAssertTrue(app.navigationBars["Kitap Gündemi"].waitForExistence(timeout: 10))
        sleep(4)
        keepScreenshot(named: "03-agenda")

        selectPrimaryDestination(app, titled: "Akış")
        XCTAssertTrue(app.navigationBars["Canlı Aktivite"].waitForExistence(timeout: 10))
        sleep(4)
        keepScreenshot(named: "04-flow")

        selectPrimaryDestination(app, titled: "İstekler")
        XCTAssertTrue(app.navigationBars["Kitap İstekleri"].waitForExistence(timeout: 10))
        sleep(4)
        keepScreenshot(named: "05-requests")

        selectPrimaryDestination(app, titled: "Profil")
        XCTAssertTrue(app.navigationBars["Profilim"].waitForExistence(timeout: 10))
        sleep(4)
        keepScreenshot(named: "06-profile")
    }

    private func selectPrimaryDestination(_ app: XCUIApplication, titled title: String) {
        let identifiers = [
            "Ana sayfa": "primary-tab-home",
            "Kitaplar": "primary-tab-catalog",
            "Gündem": "primary-tab-agenda",
            "Akış": "primary-tab-flow",
            "İstekler": "primary-tab-requests",
            "Profil": "primary-tab-profile"
        ]
        if let identifier = identifiers[title] {
            let identifiedButtons = app.buttons.matching(identifier: identifier)
            if identifiedButtons.firstMatch.waitForExistence(timeout: 2) {
                let identifiedButtonCount = identifiedButtons.count
                for index in stride(from: identifiedButtonCount - 1, through: 0, by: -1) {
                    let candidate = identifiedButtons.element(boundBy: index)
                    if candidate.isHittable {
                        candidate.tap()
                        return
                    }
                }
            }
        }

        let tabBarButton = app.tabBars.firstMatch.buttons[title]
        if tabBarButton.waitForExistence(timeout: 2) {
            tabBarButton.tap()
            return
        }

        let adaptiveTabButtons = app.buttons.matching(identifier: title)
        let adaptiveButtonCount = adaptiveTabButtons.count
        guard adaptiveButtonCount > 0 else {
            XCTFail("No primary destination named \(title)")
            return
        }
        for index in stride(from: adaptiveButtonCount - 1, through: 0, by: -1) {
            let candidate = adaptiveTabButtons.element(boundBy: index)
            if candidate.isHittable {
                candidate.tap()
                return
            }
        }
        XCTFail("No hittable primary destination named \(title)")
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

    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
