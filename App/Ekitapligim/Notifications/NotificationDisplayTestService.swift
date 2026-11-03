import Foundation
import UserNotifications
import EkitapligimCore

/// Schedules an explicitly requested, device-local display test. This is never APNs-delivery evidence.
@MainActor
final class NotificationDisplayTestService {
    private let canPresent: () async -> Bool
    private let schedule: (UNNotificationRequest) async throws -> Void

    init(canPresent: @escaping () async -> Bool, schedule: @escaping (UNNotificationRequest) async throws -> Void) {
        self.canPresent = canPresent
        self.schedule = schedule
    }

    convenience init() {
        let center = UNUserNotificationCenter.current()
        self.init(canPresent: { Self.bannersEnabled(await center.notificationSettings()) },
                  schedule: { try await center.add($0) })
    }

    static func bannersEnabled(_ settings: UNNotificationSettings) -> Bool {
        NotificationPresentationPolicy.bannersEnabled(fullyAuthorized: settings.authorizationStatus == .authorized,
            alertsEnabled: settings.alertSetting == .enabled, bannerStyleEnabled: settings.alertStyle != .none)
    }

    func scheduleTest() async throws {
        guard await canPresent() else { throw DisplayError.bannersUnavailable }
        try Task.checkCancellation()
        let content = UNMutableNotificationContent()
        content.title = CommunityDesignL10n.text("notifications.testTitle")
        content.body = CommunityDesignL10n.text("notifications.testBody")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ekitapligim.notification-display-test", content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
        try await schedule(request)
    }

    private enum DisplayError: LocalizedError {
        case bannersUnavailable
        var errorDescription: String? { CommunityDesignL10n.text("notifications.bannerDisabledBody") }
    }
}
