import XCTest
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
}
