import XCTest
import Security
import EkitapligimCore
@testable import Ekitapligim

final class KeychainSessionPersistenceTests: XCTestCase {
    func testPreviouslyStoredSessionSurvivesStoreReinitializationAndRotation() async throws {
        // Isolated Keychain namespace: no real account or production credential is read.
        let service = "com.ekitapligim.tests.session-upgrade.\(UUID().uuidString)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "session"
        ]
        defer { SecItemDelete(query as CFDictionary) }
        var seed = query
        seed[kSecValueData as String] = Data(#"{"accessToken":"previous-access","refreshToken":"previous-refresh","username":"reader"}"#.utf8)
        seed[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        XCTAssertEqual(SecItemAdd(seed as CFDictionary, nil), errSecSuccess)

        let reopened = KeychainTokenStore(service: service)
        let loaded = try await reopened.loadSession()
        let restored = try XCTUnwrap(loaded)
        XCTAssertEqual(restored.accessToken, "previous-access")
        XCTAssertEqual(restored.refreshToken, "previous-refresh")
        XCTAssertNil(restored.userID)

        let rotated = Session(accessToken: "next-access", refreshToken: "next-refresh", username: "reader", userID: "7")
        let replaced = try await reopened.replaceSession(rotated, ifMatching: restored)
        XCTAssertTrue(replaced)
        let afterRestart = KeychainTokenStore(service: service)
        let persisted = try await afterRestart.loadSession()
        XCTAssertEqual(persisted, rotated)
    }
}
