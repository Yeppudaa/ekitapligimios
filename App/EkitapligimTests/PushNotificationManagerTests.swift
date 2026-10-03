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

    func testLogoutUnregistersRegisteredToken() async {
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

    func testLogoutWaitsForInFlightTokenUploadThenRemovesIt() async {
        let started = expectation(description: "registration in flight")
        var registrationGate: CheckedContinuation<Void, Never>?
        var removed: [String] = []
        let manager = PushNotificationManager(registerToken: { _ in
            started.fulfill()
            await withCheckedContinuation { registrationGate = $0 }
        }, unregisterToken: { removed.append($0) })
        let registration = Task { await manager.didReceiveDeviceToken("old-account-token") }
        await fulfillment(of: [started], timeout: 3)
        let logoutStarted = expectation(description: "logout started")
        let logout = Task { logoutStarted.fulfill(); await manager.unregisterToken() }
        await fulfillment(of: [logoutStarted], timeout: 3)
        XCTAssertTrue(removed.isEmpty)
        await manager.didReceiveDeviceToken("late-token")
        registrationGate?.resume()
        await registration.value
        await logout.value
        XCTAssertEqual(removed, ["old-account-token"])
        XCTAssertEqual(manager.registrationStatus, .idle)
        await manager.retryPendingRegistration()
        XCTAssertEqual(manager.registrationStatus, .idle)
    }

    func testLostTokenUploadAcknowledgementStillAttemptsRemovalOnLogout() async {
        var removed: [String] = []
        let manager = PushNotificationManager(registerToken: { _ in throw TestError.unavailable },
            unregisterToken: { removed.append($0) })
        await manager.didReceiveDeviceToken("possibly-registered-token")
        XCTAssertEqual(manager.registrationStatus, .failed)
        await manager.unregisterToken()
        XCTAssertEqual(removed, ["possibly-registered-token"])
        XCTAssertEqual(manager.registrationStatus, .idle)
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
