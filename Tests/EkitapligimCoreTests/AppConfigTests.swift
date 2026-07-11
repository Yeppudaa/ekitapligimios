import XCTest
@testable import EkitapligimCore

final class AppConfigTests: XCTestCase {
    func testLegalAndSupportURLsUseLiveXenForoRoutes() throws {
        let config = try AppConfig.production()

        XCTAssertEqual(config.supportURL.absoluteString, "https://ekitapligim.com/diger/iletisim")
        XCTAssertEqual(config.privacyPolicyURL.absoluteString, "https://ekitapligim.com/yardim/gizlilik-politikasi/")
        XCTAssertEqual(config.termsURL.absoluteString, "https://ekitapligim.com/yardim/kurallar/")
    }

    func testProductionRejectsLocalhost() throws {
        let apiBaseURL = try XCTUnwrap(URL(string: "https://localhost/mobile-api/v1/"))
        let webBaseURL = try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        let config = AppConfig(
            environment: .production,
            apiBaseURL: apiBaseURL,
            webBaseURL: webBaseURL
        )

        XCTAssertThrowsError(try config.validateForRelease()) { error in
            XCTAssertEqual(error as? ConfigurationError, .localProductionURL)
        }
    }

    func testProductionRejectsHTTP() throws {
        let apiBaseURL = try XCTUnwrap(URL(string: "http://ekitapligim.com/mobile-api/v1/"))
        let webBaseURL = try XCTUnwrap(URL(string: "https://ekitapligim.com/"))
        let config = AppConfig(
            environment: .production,
            apiBaseURL: apiBaseURL,
            webBaseURL: webBaseURL
        )

        XCTAssertThrowsError(try config.validateForRelease()) { error in
            XCTAssertEqual(error as? ConfigurationError, .insecureProductionURL)
        }
    }
}
