import XCTest

@MainActor
final class AgendaMediaUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String, mode: String = "portrait", selected: Bool = false, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-modern-parity-ui-fixture", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["MODERN_PARITY_SCREEN"] = screen
        app.launchEnvironment["MODERN_PARITY_AGENDA_MEDIA"] = mode
        app.launchEnvironment["MODERN_PARITY_AGENDA_SELECTED_PHOTO"] = selected ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_LARGE_TEXT"] = large ? "1" : "0"
        app.launchEnvironment["MODERN_PARITY_DARK"] = large ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.otherElements["modern-parity-ready"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, scrollID: String) {
        let scroll = app.scrollViews[scrollID]
        XCTAssertTrue(scroll.waitForExistence(timeout: 6))
        for _ in 0..<12 {
            if element.isHittable { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testPhotoAppearsOnHomeAndOpensExistingDetail() {
        let app = launch("home")
        defer { app.terminate() }
        let card = app.buttons["agenda.open.940001"]
        reveal(card, in: app, scrollID: "home.scroll")
        XCTAssertEqual(card.value as? String, "1 fotoğraf")
        XCTAssertGreaterThan(card.frame.height, 300)
        capture(app, "agenda-photo-home")
        card.tap()
        XCTAssertTrue(app.scrollViews["agenda.detail.scroll"].waitForExistence(timeout: 8))
    }

    func testPortraitLandscapeGalleryAndLargeDarkDetailStayWithinScreen() {
        for mode in ["portrait", "landscape", "gallery"] {
            let app = launch("agenda-detail", mode: mode, large: mode == "portrait")
            let image = app.descendants(matching: .any)["agenda.image.940001.21"].firstMatch
            reveal(image, in: app, scrollID: "agenda.detail.scroll")
            XCTAssertGreaterThan(image.frame.width, 100)
            XCTAssertLessThanOrEqual(image.frame.maxX, app.frame.maxX + 1)
            if mode == "gallery" {
                image.swipeLeft()
                XCTAssertTrue(app.descendants(matching: .any)["agenda.image.940001.22"].firstMatch.waitForExistence(timeout: 5))
            }
            capture(app, "agenda-photo-detail-\(mode)")
            app.terminate()
        }
    }

    func testPhotoFailureOffersRetryInsteadOfBookCoverPlaceholder() {
        let app = launch("agenda-detail", mode: "failure")
        defer { app.terminate() }
        let retry = app.buttons["Yeniden dene"].firstMatch
        reveal(retry, in: app, scrollID: "agenda.detail.scroll")
        XCTAssertTrue(retry.isEnabled)
        capture(app, "agenda-photo-failure")
    }

    func testSystemPickerCanBeOpenedFromExistingComposer() {
        let app = launch("agenda")
        defer { app.terminate() }
        app.buttons["agenda.composer.open"].tap()
        let choose = app.buttons["agenda.composer.photo.choose"]
        reveal(choose, in: app, scrollID: "agenda.composer.scroll")
        choose.tap()
        // Apple's picker is outside the app's view hierarchy; verify its cancel control appears.
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["İptal", "Vazgeç", "Cancel"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        cancel.tap()
        XCTAssertTrue(app.buttons["agenda.composer.submit"].exists)
    }

    func testFailedPhotoUploadRetainsPreviewAndCanBeRemoved() {
        let app = launch("agenda", mode: "upload-failure", selected: true)
        defer { app.terminate() }
        app.buttons["agenda.composer.open"].tap()
        let preview = app.images["agenda.composer.photo.preview"]
        reveal(preview, in: app, scrollID: "agenda.composer.scroll")
        app.buttons["agenda.composer.submit"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["agenda.composer.error"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(preview.exists)
        capture(app, "agenda-photo-upload-failure-keeps-draft")
        let remove = app.buttons["agenda.composer.photo.remove"]
        reveal(remove, in: app, scrollID: "agenda.composer.scroll")
        remove.tap()
        XCTAssertFalse(preview.exists)
    }

    func testPhotoOnlyPostUsesAtomicMultipartAndClosesComposer() {
        let app = launch("agenda", selected: true)
        defer { app.terminate() }
        app.buttons["agenda.composer.open"].tap()
        let preview = app.images["agenda.composer.photo.preview"]
        reveal(preview, in: app, scrollID: "agenda.composer.scroll")
        capture(app, "agenda-photo-composer-preview")
        app.buttons["agenda.composer.submit"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.buttons["agenda.composer.submit"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 8), .completed)
    }
}
