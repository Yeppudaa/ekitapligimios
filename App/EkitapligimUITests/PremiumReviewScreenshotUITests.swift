import XCTest

final class PremiumReviewScreenshotUITests: XCTestCase {
    func testCaptureNativePremiumProductCards() {
        let app = XCUIApplication()
        app.launchArguments = ["-premium-review-screenshot", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()

        let products: [(String, String)] = [
            ("three_months", "premium-review-three-months"),
            ("six_months", "premium-review-six-months"),
            ("yearly_once", "premium-review-yearly-once"),
            ("lifetime", "premium-review-lifetime")
        ]
        for (suffix, name) in products {
            let card = app.buttons["premium.product.com.ekitapligim.app.premium.\(suffix)"]
            XCTAssertTrue(card.waitForExistence(timeout: 10), "Missing \(suffix) card")
            for _ in 0..<12 where !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.isHittable, "Cannot display \(suffix) card")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
