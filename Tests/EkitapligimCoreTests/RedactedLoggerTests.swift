import XCTest
@testable import EkitapligimCore

final class RedactedLoggerTests: XCTestCase {
    func testRedactsSensitiveHeaders() {
        let logger = RedactedLogger()
        let redacted = logger.redact(headers: [
            "Authorization": "Bearer secret",
            "Accept": "application/json",
            "Cookie": "xf_user=1"
        ])

        XCTAssertEqual(redacted["Authorization"], "[REDACTED]")
        XCTAssertEqual(redacted["Cookie"], "[REDACTED]")
        XCTAssertEqual(redacted["Accept"], "application/json")
    }

    func testRedactsSensitiveMessageFields() {
        let logger = RedactedLogger()
        let message = logger.redact(message: "password=secret access_token=abc nonce=one-time-value")

        XCTAssertFalse(message.contains("secret"))
        XCTAssertFalse(message.contains("abc"))
        XCTAssertFalse(message.contains("one-time-value"))
    }
}
