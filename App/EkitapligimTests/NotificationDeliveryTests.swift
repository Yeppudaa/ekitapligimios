import XCTest
import UserNotifications
import EkitapligimCore
@testable import Ekitapligim

@MainActor
final class NotificationDeliveryTests: XCTestCase {
    func testColdStartTapWaitsForSessionRestorationAndIsConsumedOnce() {
        let delegate = AppDelegate()
        let manager = PushNotificationManager(registerToken: { _ in })
        defer { withExtendedLifetime(manager) {} }
        var routes: [AppRoute] = []
        manager.setRouteHandler { routes.append($0) }
        delegate.pushManager = manager
        delegate.routeNotificationTap(["route": "conversation/12", "conversation_id": 12])
        XCTAssertTrue(routes.isEmpty)
        delegate.completeNotificationStartup()
        delegate.completeNotificationStartup()
        XCTAssertEqual(routes, [.conversation(12)])
    }

    func testTapAlsoWaitsForLateManagerWiring() {
        let delegate = AppDelegate()
        let manager = PushNotificationManager(registerToken: { _ in })
        defer { withExtendedLifetime(manager) {} }
        var routes: [AppRoute] = []
        manager.setRouteHandler { routes.append($0) }
        delegate.completeNotificationStartup()
        delegate.routeNotificationTap(["route": "member/7"])
        delegate.pushManager = manager
        XCTAssertEqual(routes, [.member(7)])
    }

    func testLocalDisplayTestSchedulesOnlySyntheticContentWithoutAnAccountRoute() async throws {
        var requests: [UNNotificationRequest] = []
        let service = NotificationDisplayTestService(canPresent: { true }, schedule: { requests.append($0) })
        try await service.scheduleTest()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.identifier, "ekitapligim.notification-display-test")
        XCTAssertTrue(request.content.userInfo.isEmpty)
        XCTAssertFalse(request.content.title.isEmpty)
        XCTAssertNotNil(request.content.sound)
        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 3)
        XCTAssertFalse(trigger.repeats)
    }

    func testLocalDisplayTestDoesNotScheduleWhenBannersAreUnavailable() async {
        var calls = 0
        let service = NotificationDisplayTestService(canPresent: { false }, schedule: { _ in calls += 1 })
        do { try await service.scheduleTest(); XCTFail("Banner settings must be checked first") }
        catch { XCTAssertEqual(calls, 0) }
    }
}
