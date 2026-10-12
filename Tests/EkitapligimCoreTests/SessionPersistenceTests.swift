import XCTest
@testable import EkitapligimCore

final class SessionPersistenceTests: XCTestCase {
    func testPreviousAppVersionSessionDecodesWithoutUserID() throws {
        let data = Data(#"{"accessToken":"previous-access","refreshToken":"previous-refresh","username":"reader"}"#.utf8)
        let session = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(session.accessToken, "previous-access")
        XCTAssertEqual(session.refreshToken, "previous-refresh")
        XCTAssertNil(session.userID)
        let reopened = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(reopened, session)
    }

    func testSessionSnapshotPreservesBothTokensAndStableIdentity() throws {
        let session = Session(accessToken: "next-access", refreshToken: "next-refresh", username: "reader", userID: "7")
        let reopened = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(reopened, session)
        XCTAssertTrue(reopened.belongsToSameAccount(as: Session(accessToken: "later", refreshToken: "later-refresh", username: "renamed", userID: "7")))
        XCTAssertFalse(reopened.belongsToSameAccount(as: Session(accessToken: "other", refreshToken: "other-refresh", username: "reader", userID: "8")))
    }
}
