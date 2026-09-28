import XCTest

/// Run on iPhone and iPad simulators. These screenshots render the real PDFKit document and reader chrome.
final class ReaderExperienceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ mode: String = "reading", largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-reader-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment["READER_FIXTURE_MODE"] = mode
        app.launchEnvironment["READER_FIXTURE_THEME"] = "sepia"
        app.launch()
        XCTAssertTrue(app.buttons["reader.showControls"].waitForExistence(timeout: 10), app.debugDescription)
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertPage(_ page: Int, in app: XCUIApplication, controls: Bool) {
        let element = controls ? app.sliders["Sayfa seçici"] : app.staticTexts["reader.focusProgress"]
        let attribute = controls ? "value" : "label"
        let predicate = NSPredicate(format: "%K == %@", attribute, "Sayfa \(page) / 60")
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    func testFocusStartsAtRestoredPageAndShowsFullScreenPaper() {
        let app = launch()
        assertPage(25, in: app, controls: false)
        XCTAssertFalse(app.buttons["reader.theme"].exists)
        XCTAssertEqual(app.navigationBars.count, 0)
        XCTAssertEqual(app.tabBars.count, 0)
        let paper = app.descendants(matching: .any)["reader.fixture.document"].firstMatch
        XCTAssertTrue(paper.exists)
        XCTAssertLessThanOrEqual(paper.frame.minY, app.frame.minY + 1)
        XCTAssertGreaterThanOrEqual(paper.frame.maxY, app.frame.maxY - 1)
        capture(app, "reader-sepia-focus-page25")
        app.buttons["reader.showControls"].tap()
        assertPage(25, in: app, controls: true)
        XCTAssertTrue(app.buttons["reader.focus"].isHittable)
        capture(app, "reader-sepia-tools-page25")
        app.buttons["reader.focus"].tap()
        assertPage(25, in: app, controls: false)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["reader.theme"].waitForExistence(timeout: 3))
        assertPage(25, in: app, controls: true)
    }

    func testThemesPreserveTheCurrentPDFPageAfterNavigation() {
        let app = launch()
        assertPage(25, in: app, controls: false)
        app.buttons["reader.showControls"].tap()
        app.buttons["Sonraki sayfa"].tap()
        assertPage(26, in: app, controls: true)
        let theme = app.buttons["reader.theme"]
        XCTAssertEqual(theme.value as? String, "Sepya")
        for (label, imageName) in [("Gece", "night"), ("Beyaz", "white"), ("Sepya", "sepia")] {
            theme.tap()
            XCTAssertEqual(theme.value as? String, label)
            assertPage(26, in: app, controls: true)
            capture(app, "reader-\(imageName)-tools-page26")
            app.buttons["reader.focus"].tap()
            assertPage(26, in: app, controls: false)
            capture(app, "reader-\(imageName)-focus-page26")
            app.buttons["reader.showControls"].tap()
        }
    }

    func testLoadingShowsMeasuredPercentAndBytes() {
        let app = launch("download-known")
        let percent = app.staticTexts["reader.loading.percent"]
        XCTAssertTrue(percent.waitForExistence(timeout: 3))
        XCTAssertEqual(percent.label, "%37")
        XCTAssertTrue(app.staticTexts["reader.loading.bytes"].exists)
        XCTAssertTrue(app.staticTexts["Kitap yükleniyor…"].exists)
        capture(app, "reader-loading-37-percent")
    }

    func testUnknownLengthAndOpeningNeverInventAPercentage() {
        var app = launch("download-unknown")
        XCTAssertTrue(app.staticTexts["reader.loading.bytes"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["reader.loading.percent"].exists)
        capture(app, "reader-loading-unknown-length")
        app.terminate()
        app = launch("opening")
        XCTAssertTrue(app.staticTexts["Sayfalar hazırlanıyor…"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["reader.loading.percent"].exists)
        capture(app, "reader-opening-pdf")
    }

    func testLargeTextKeepsControlsUsable() {
        let app = launch(largeText: true)
        assertPage(25, in: app, controls: false)
        app.buttons["reader.showControls"].tap()
        assertPage(25, in: app, controls: true)
        assertControlsFit(app)
        capture(app, "reader-large-text-tools")
        app.buttons["reader.focus"].tap()
        assertPage(25, in: app, controls: false)
        capture(app, "reader-large-text-focus")
    }

    func testLandscapePreservesPageAndControlsFitOnPhoneAndTablet() {
        let app = launch()
        assertPage(25, in: app, controls: false)
        XCUIDevice.shared.orientation = .landscapeLeft
        app.buttons["reader.showControls"].tap()
        assertPage(25, in: app, controls: true)
        assertControlsFit(app)
        capture(app, "reader-landscape-tools")
    }

    private func assertControlsFit(_ app: XCUIApplication) {
        for id in ["reader.close", "reader.focus", "reader.theme"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        XCTAssertTrue(app.sliders["Sayfa seçici"].isHittable)
        let toolbar = app.descendants(matching: .any)["reader.toolbar"].firstMatch
        let controls = app.descendants(matching: .any)["reader.controls"].firstMatch
        XCTAssertLessThan(toolbar.frame.maxY, controls.frame.minY)
        XCTAssertGreaterThanOrEqual(toolbar.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(controls.frame.maxX, app.frame.maxX)
    }
}
