import XCTest
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class PushNotificationManagerTests: XCTestCase {
    private enum TestError: Error {
        case unavailable
    }

    func testFailedRegistrationIsRetriedWhenRequested() async {
        var attempts = 0
        let manager = PushNotificationManager(registerToken: { _ in
            attempts += 1
            if attempts == 1 { throw TestError.unavailable }
        })

        await manager.didReceiveDeviceToken("device-token")
        let failedStatus = manager.registrationStatus
        XCTAssertEqual(failedStatus, .failed)

        await manager.retryPendingRegistration()
        XCTAssertEqual(attempts, 2)
        let registeredStatus = manager.registrationStatus
        XCTAssertEqual(registeredStatus, .registered)
    }

    func testSuccessfulRegistrationIsNotRepeatedForSameToken() async {
        var attempts = 0
        let manager = PushNotificationManager(registerToken: { _ in attempts += 1 })

        await manager.didReceiveDeviceToken("device-token")
        await manager.didReceiveDeviceToken("device-token")
        await manager.retryPendingRegistration()

        XCTAssertEqual(attempts, 1)
        let registeredStatus = manager.registrationStatus
        XCTAssertEqual(registeredStatus, .registered)
    }

    func testLogoutUnregistersOnlySuccessfullyRegisteredToken() async {
        var unregistered: [String] = []
        let manager = PushNotificationManager(
            registerToken: { _ in },
            unregisterToken: { unregistered.append($0) }
        )

        await manager.didReceiveDeviceToken("device-token")
        await manager.unregisterToken()

        XCTAssertEqual(unregistered, ["device-token"])
        let idleStatus = manager.registrationStatus
        XCTAssertEqual(idleStatus, .idle)
    }

    func testNotificationTapRoutesAndAcknowledgesAlert() {
        let manager = PushNotificationManager(registerToken: { _ in })
        var route: AppRoute?
        var readTarget: PushNotificationManager.ReadTarget?
        manager.setRouteHandler { route = $0 }
        manager.setReadHandler { readTarget = $0 }

        manager.handleNotificationTap(userInfo: [
            "route": "thread/15",
            "type": "post",
            "content_id": 99,
            "alert_id": "73"
        ])

        XCTAssertEqual(route, .thread(15))
        XCTAssertEqual(readTarget, .alert(73))
    }

    func testConversationPushUsesConversationAcknowledgement() {
        let manager = PushNotificationManager(registerToken: { _ in })
        var readTarget: PushNotificationManager.ReadTarget?
        manager.setReadHandler { readTarget = $0 }

        manager.handleNotificationTap(userInfo: [
            "route": "conversation/12",
            "type": "conversation_message",
            "conversation_id": 12
        ])

        XCTAssertEqual(readTarget, .conversation(12))
    }
}
